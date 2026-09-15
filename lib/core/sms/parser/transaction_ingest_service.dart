import 'package:drift/drift.dart';

import '../../database/app_database.dart';
import 'parsed_transaction.dart';
import 'parser_registry.dart';

/// Runs unparsed SMS through [ParserRegistry] and turns any resulting
/// [ParsedTransaction] into merchant/payment_method/card/transaction rows,
/// then marks the source SMS as handled so it isn't re-processed.
///
/// A heavy real user can easily have thousands of transaction SMS in their
/// history, so this batches everything into one SQLite transaction (avoiding
/// an implicit commit/fsync per row) and caches merchant/payment-method/card
/// lookups in memory for the lifetime of the service, since the same
/// merchant or card recurs across many messages.
class TransactionIngestService {
  TransactionIngestService(this._db, this._registry);

  final AppDatabase _db;
  final ParserRegistry _registry;

  final Map<String, int> _merchantCache = {};
  final Map<String, int> _paymentMethodCache = {};
  final Map<String, int> _cardCache = {};

  /// Bounds how much work one call does, so a large backlog is processed in
  /// visible increments (each poll tick) rather than one long blocking pass.
  static const _chunkSize = 500;

  Future<int> ingestUnparsedMessages() async {
    final unparsed = await (_db.select(_db.smsMessages)
          ..where((t) => t.isParsed.equals(false))
          ..limit(_chunkSize))
        .get();
    if (unparsed.isEmpty) return 0;

    var created = 0;
    // Outer transaction batches the whole chunk's commits into one fsync.
    // Each message additionally gets its own nested transaction (a SQLite
    // savepoint, since Drift nests automatically) so a single malformed or
    // unexpected SMS - real-world messages are wildly inconsistent at scale
    // - only rolls back its own partial writes and gets marked 'error',
    // instead of an uncaught exception killing the whole ingestion stream
    // permanently (which is what silently stopped a prior run partway
    // through a large backlog).
    await _db.transaction(() async {
      for (final sms in unparsed) {
        var status = 'error';
        try {
          await _db.transaction(() async {
            final result =
                _registry.parse(sms.sender, sms.messageBody, sms.receivedAt);
            if (result.transaction != null) {
              await _createTransaction(
                  result.transaction!, sms.messageBody, sms.receivedAt);
              created++;
            } else if (result.autopayEvent != null) {
              await _createAutopayEvent(result.autopayEvent!, sms.messageBody);
            }
            status = result.status.name;
          });
        } catch (_) {
          // Isolated by the nested transaction above; nothing from this
          // message was committed.
        }

        await (_db.update(_db.smsMessages)..where((t) => t.id.equals(sms.id)))
            .write(SmsMessagesCompanion(
          isParsed: const Value(true),
          parseStatus: Value(status),
        ));
      }
    });
    return created;
  }

  /// User manually recategorized an "ignored"/"unmatched" SMS as an actual
  /// transaction, from the SMS review screen - covers the gap where a
  /// parser doesn't recognize the format at all yet.
  Future<void> createManualTransaction({
    required int smsMessageId,
    required String smsBody,
    required double amount,
    required TransactionDirection direction,
    required TransactionKind category,
    required DateTime transactionDate,
    required DateTime smsReceivedAt,
    String? merchantName,
    String? bankName,
  }) async {
    await _db.transaction(() async {
      await _createTransaction(
        ParsedTransaction(
          amount: amount,
          direction: direction,
          bankName: bankName ?? 'Unknown',
          paymentMethodType: PaymentMethodType.bankTransfer,
          transactionDate: transactionDate,
          counterparty: merchantName,
          category: category,
        ),
        smsBody,
        smsReceivedAt,
      );
      await (_db.update(_db.smsMessages)..where((t) => t.id.equals(smsMessageId)))
          .write(const SmsMessagesCompanion(
        isParsed: Value(true),
        parseStatus: Value('parsed'),
      ));
    });
  }

  /// User manually recategorized an SMS as an autopay reference event.
  Future<void> createManualAutopayEvent({
    required int smsMessageId,
    required String smsBody,
    required AutopayEventType eventType,
    required String merchantName,
    required double amount,
    required String bankName,
    required DateTime eventDate,
  }) async {
    await _db.transaction(() async {
      await _createAutopayEvent(
        ParsedAutopayEvent(
          eventType: eventType,
          merchantName: merchantName,
          amount: amount,
          bankName: bankName,
          eventDate: eventDate,
        ),
        smsBody,
      );
      await (_db.update(_db.smsMessages)..where((t) => t.id.equals(smsMessageId)))
          .write(const SmsMessagesCompanion(
        isParsed: Value(true),
        parseStatus: Value('autopayReference'),
      ));
    });
  }

  Future<void> _createTransaction(
      ParsedTransaction parsed, String smsBody, DateTime smsReceivedAt) async {
    final merchantId = parsed.counterparty == null
        ? null
        : await _getOrCreateMerchant(parsed.counterparty!);

    final paymentMethodId = await _getOrCreatePaymentMethod(
      _paymentMethodTypeName(parsed.paymentMethodType),
      parsed.bankName,
    );

    final cardId = _isCard(parsed.paymentMethodType) &&
            parsed.cardOrAccountLastFour != null
        ? await _getOrCreateCard(
            parsed.bankName,
            parsed.cardOrAccountLastFour!,
            parsed.paymentMethodType == PaymentMethodType.creditCard
                ? 'CREDIT'
                : 'DEBIT',
          )
        : null;

    final description = parsed.description ??
        (!_isCard(parsed.paymentMethodType) &&
                parsed.cardOrAccountLastFour != null
            ? 'A/c ${parsed.cardOrAccountLastFour}'
            : null);

    // Null category means "derive from direction": a plain debit is a spend,
    // a plain credit is income. Parsers only set it explicitly for
    // repayments, which are neither.
    final category = parsed.category ??
        (parsed.direction == TransactionDirection.credit
            ? TransactionKind.income
            : TransactionKind.spend);

    final transactionId =
        await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
              amount: parsed.amount,
              direction: Value(parsed.direction.name.toUpperCase()),
              transactionDate: parsed.transactionDate,
              smsReceivedAt: Value(smsReceivedAt),
              category: Value(category.name.toUpperCase()),
              status: 'SUCCESS',
              merchantId: Value(merchantId),
              paymentMethodId: Value(paymentMethodId),
              cardId: Value(cardId),
              bankName: Value(parsed.bankName),
              description: Value(description),
              externalTransactionId: Value(parsed.referenceId),
              smsSource: Value(smsBody),
            ));

    await _db.into(_db.transactionEvents).insert(
          TransactionEventsCompanion.insert(
            transactionId: transactionId,
            newStatus: 'SUCCESS',
            remarks: const Value('Created from SMS'),
          ),
        );
  }

  Future<void> _createAutopayEvent(
      ParsedAutopayEvent parsed, String smsBody) async {
    await _db.into(_db.autopayEvents).insert(
          AutopayEventsCompanion.insert(
            eventType: parsed.eventType.name.toUpperCase(),
            merchantName: parsed.merchantName,
            amount: parsed.amount,
            bankName: parsed.bankName,
            eventDate: parsed.eventDate,
            referenceId: Value(parsed.referenceId),
            smsSource: Value(smsBody),
          ),
        );
  }

  bool _isCard(PaymentMethodType type) =>
      type == PaymentMethodType.creditCard || type == PaymentMethodType.debitCard;

  String _paymentMethodTypeName(PaymentMethodType type) => switch (type) {
        PaymentMethodType.upi => 'UPI',
        PaymentMethodType.creditCard => 'CREDIT_CARD',
        PaymentMethodType.debitCard => 'DEBIT_CARD',
        PaymentMethodType.bankTransfer => 'BANK_TRANSFER',
      };

  Future<int> _getOrCreateMerchant(String name) async {
    final cached = _merchantCache[name];
    if (cached != null) return cached;

    final existing = await (_db.select(_db.merchants)
          ..where((t) => t.name.equals(name)))
        .getSingleOrNull();
    final id = existing?.id ??
        await _db.into(_db.merchants).insert(
              MerchantsCompanion.insert(name: name),
            );
    _merchantCache[name] = id;
    return id;
  }

  Future<int> _getOrCreatePaymentMethod(String type, String provider) async {
    final key = '$type|$provider';
    final cached = _paymentMethodCache[key];
    if (cached != null) return cached;

    final existing = await (_db.select(_db.paymentMethods)
          ..where((t) => t.type.equals(type) & t.provider.equals(provider)))
        .getSingleOrNull();
    final id = existing?.id ??
        await _db.into(_db.paymentMethods).insert(
              PaymentMethodsCompanion.insert(
                type: type,
                provider: Value(provider),
              ),
            );
    _paymentMethodCache[key] = id;
    return id;
  }

  Future<int> _getOrCreateCard(
      String bankName, String lastFourDigits, String cardType) async {
    final key = '$bankName|$lastFourDigits';
    final cached = _cardCache[key];
    if (cached != null) return cached;

    final existing = await (_db.select(_db.cards)
          ..where((t) =>
              t.bankName.equals(bankName) &
              t.lastFourDigits.equals(lastFourDigits)))
        .getSingleOrNull();
    final id = existing?.id ??
        await _db.into(_db.cards).insert(
              CardsCompanion.insert(
                bankName: bankName,
                lastFourDigits: lastFourDigits,
                cardType: cardType,
              ),
            );
    _cardCache[key] = id;
    return id;
  }
}
