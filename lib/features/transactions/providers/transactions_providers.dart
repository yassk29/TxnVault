import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sms/parser/parser_registry.dart';
import '../../../core/sms/parser/transaction_ingest_service.dart';
import '../../../core/sms/sms_providers.dart';
import '../../../shared/providers/date_filter_provider.dart';
import '../domain/transaction_filter.dart';

final parserRegistryProvider = Provider<ParserRegistry>((ref) => ParserRegistry());

final transactionIngestServiceProvider =
    Provider<TransactionIngestService>((ref) {
  return TransactionIngestService(
    ref.watch(databaseProvider),
    ref.watch(parserRegistryProvider),
  );
});

/// Periodically converts any newly-captured SMS into transactions. This is
/// necessary (not just cosmetic polling) because SmsReceiver.kt writes new
/// SMS directly into SQLite, bypassing Dart entirely - nothing else drives
/// ingestion of messages that arrive while the app is open.
///
/// Deliberately NOT `.autoDispose`: it needs to keep running for the whole
/// app lifetime regardless of which screen is visible, kept alive by
/// MainScaffold (see shared/widgets/main_scaffold.dart) rather than by
/// being watched from inside another provider - watching it from
/// transactionsListProvider used to restart that provider (and its own
/// polling loop) on every ingestion tick, which is what caused the UI to
/// flicker/reload constantly.
final transactionIngestionLoopProvider = StreamProvider<int>((ref) async* {
  final service = ref.watch(transactionIngestServiceProvider);
  while (true) {
    try {
      yield await service.ingestUnparsedMessages();
    } catch (_) {
      // Belt-and-suspenders: TransactionIngestService already isolates
      // per-message failures, but this loop is a permanent app-wide
      // singleton (see class doc above) - an uncaught exception here would
      // otherwise end the stream for good with no way to recover short of
      // restarting the app.
      yield 0;
    }
    await Future.delayed(const Duration(seconds: 4));
  }
});

final transactionFilterProvider =
    StateProvider<TransactionFilter>((ref) => const TransactionFilter());

class TransactionListItem {
  const TransactionListItem({
    required this.id,
    required this.amount,
    required this.direction,
    required this.category,
    required this.status,
    required this.transactionDate,
    required this.bankName,
    required this.isExcluded,
    this.merchantName,
    this.cardLastFour,
  });

  final int id;
  final double amount;
  final String direction;

  /// SPEND | INCOME | REPAYMENT
  final String category;
  final String status;
  final DateTime transactionDate;
  final String? bankName;
  final bool isExcluded;
  final String? merchantName;
  final String? cardLastFour;
}

TransactionListItem _mapRow(AppDatabase db, TypedResult row) {
  final txn = row.readTable(db.transactions);
  final merchant = row.readTableOrNull(db.merchants);
  final card = row.readTableOrNull(db.cards);
  return TransactionListItem(
    id: txn.id,
    amount: txn.amount,
    direction: txn.direction,
    category: txn.category,
    status: txn.status,
    transactionDate: txn.transactionDate,
    bankName: txn.bankName,
    isExcluded: txn.isExcluded,
    merchantName: merchant?.name,
    cardLastFour: card?.lastFourDigits,
  );
}

/// Hides a transaction from the History list and totals without deleting
/// it - reversible via [restoreTransaction], since a parser can be
/// technically correct while the user still doesn't want it counted (e.g.
/// a shared/business card's spend showing up in a personal ledger).
Future<void> excludeTransaction(WidgetRef ref, int transactionId) async {
  final db = ref.read(databaseProvider);
  await (db.update(db.transactions)..where((t) => t.id.equals(transactionId)))
      .write(const TransactionsCompanion(isExcluded: Value(true)));
}

Future<void> restoreTransaction(WidgetRef ref, int transactionId) async {
  final db = ref.read(databaseProvider);
  await (db.update(db.transactions)..where((t) => t.id.equals(transactionId)))
      .write(const TransactionsCompanion(isExcluded: Value(false)));
}

final transactionsListProvider =
    StreamProvider.autoDispose<List<TransactionListItem>>((ref) async* {
  // Deliberately NOT `ref.watch(transactionIngestionLoopProvider)` here: that
  // provider emits every few seconds, and watching it would restart this
  // entire provider (and its own polling loop) on every ingestion tick -
  // two overlapping timers thrashing the same query, which is what caused
  // the UI to flicker/reload constantly. The ingestion loop is kept alive
  // independently by MainScaffold - this just polls the transactions table
  // on its own schedule.
  final db = ref.watch(databaseProvider);
  final filter = ref.watch(transactionFilterProvider);
  // Shared with the Dashboard: picking a range there scopes this list too.
  final dateFilter = ref.watch(sharedDateFilterProvider);

  final query = db.select(db.transactions).join([
    leftOuterJoin(
        db.merchants, db.merchants.id.equalsExp(db.transactions.merchantId)),
    leftOuterJoin(db.cards, db.cards.id.equalsExp(db.transactions.cardId)),
    leftOuterJoin(db.paymentMethods,
        db.paymentMethods.id.equalsExp(db.transactions.paymentMethodId)),
  ]);

  // Excluded transactions never show in the main list or count toward
  // totals; see excludedTransactionsProvider to review/restore them.
  query.where(db.transactions.isExcluded.equals(false));

  final (startDate, endDate) = dateFilter.resolveBounds();
  if (startDate != null) {
    query.where(db.transactions.transactionDate.isBiggerOrEqualValue(startDate));
  }
  if (endDate != null) {
    query.where(db.transactions.transactionDate.isSmallerThanValue(endDate));
  }
  if (filter.minAmount != null) {
    query.where(db.transactions.amount.isBiggerOrEqualValue(filter.minAmount!));
  }
  if (filter.maxAmount != null) {
    query.where(db.transactions.amount.isSmallerOrEqualValue(filter.maxAmount!));
  }
  switch (filter.type) {
    case TransactionTypeFilter.all:
      break;
    case TransactionTypeFilter.credit:
      query.where(db.transactions.direction.equals('CREDIT'));
    case TransactionTypeFilter.debit:
      query.where(db.transactions.direction.equals('DEBIT'));
    case TransactionTypeFilter.refund:
      query.where(db.transactions.status.like('%REFUND%'));
    case TransactionTypeFilter.repayment:
      query.where(db.transactions.category.equals('REPAYMENT'));
  }
  if (filter.paymentMethodType != null) {
    query.where(db.paymentMethods.type.equals(filter.paymentMethodType!));
  }
  if (filter.upiProvider != null) {
    query.where(db.paymentMethods.provider.equals(filter.upiProvider!));
  }
  if (filter.cardId != null) {
    query.where(db.transactions.cardId.equals(filter.cardId!));
  }

  // Ordered by the SMS's actual receipt time, not transactionDate: many bank
  // templates only state a date with no time-of-day, so transactionDate
  // often defaults to midnight and would put same-day transactions in an
  // arbitrary order. smsReceivedAt always has full precision.
  query.orderBy([
    OrderingTerm(
        expression: db.transactions.smsReceivedAt, mode: OrderingMode.desc),
  ]);

  while (true) {
    final rows = await query.get();
    yield rows.map((row) => _mapRow(db, row)).toList();
    await Future.delayed(const Duration(seconds: 3));
  }
});

/// Transactions the user has excluded from the main list/totals - lets them
/// review what's hidden and restore anything hidden by mistake.
final excludedTransactionsProvider =
    StreamProvider.autoDispose<List<TransactionListItem>>((ref) async* {
  final db = ref.watch(databaseProvider);

  final query = db.select(db.transactions).join([
    leftOuterJoin(
        db.merchants, db.merchants.id.equalsExp(db.transactions.merchantId)),
    leftOuterJoin(db.cards, db.cards.id.equalsExp(db.transactions.cardId)),
  ])
    ..where(db.transactions.isExcluded.equals(true))
    ..orderBy([
      OrderingTerm(
          expression: db.transactions.smsReceivedAt, mode: OrderingMode.desc),
    ]);

  while (true) {
    final rows = await query.get();
    yield rows.map((row) => _mapRow(db, row)).toList();
    await Future.delayed(const Duration(seconds: 3));
  }
});

/// Populates the payment-method-type filter's UPI sub-list.
final availableUpiProvidersProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await (db.select(db.paymentMethods)
        ..where((t) => t.type.equals('UPI')))
      .get();
  return rows.map((r) => r.provider ?? '').where((p) => p.isNotEmpty).toSet().toList()..sort();
});

/// Populates the payment-method-type filter's card sub-list.
final availableCardsProvider = FutureProvider.autoDispose<List<Card>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.select(db.cards).get();
});
