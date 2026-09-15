import '../parser/parsed_transaction.dart';
import '../parser/sms_date_parser.dart';
import '../parser/sms_parser.dart';

/// Handles slice's three templates: UPI sent (from a linked bank a/c), a
/// slice credit card spend, and a UPI credit into the slice account.
class SliceParser extends SmsParser {
  @override
  String get id => 'slice';

  static final _sent = RegExp(
    r'Rs\.\s?([\d,]+(?:\.\d+)?) sent from a/c (\w+) on (\d{1,2}-[A-Za-z]{3}-\d{2}) to (.+?) \(UPI Ref: (\d+)\)',
  );

  static final _cardSpend = RegExp(
    r'Rs\.\s?([\d,]+(?:\.\d+)?) spent on your credit card (\w+) at (.+?) on (\d{1,2}-[A-Za-z]{3}-\d{2}) \(UPI Ref: (\d+)\)',
  );

  static final _received = RegExp(
    r'Rs\.\s?([\d,]+(?:\.\d+)?) received in slice A/c (\w+) on (\d{1,2}-[A-Za-z]{3}-\d{2}) from (.+?) via UPI \(Ref ID: (\d+)\)\. Avl\. Bal\. Rs\.\s?([\d,]+\.\d{2})',
  );

  static final _autoPay = RegExp(
    r'Successfully paid Rs\.\s?([\d,]+(?:\.\d+)?) from slice (?:savings )?a/c (\w+) to (.+?) on (\d{1,2}-[A-Za-z]{3}-\d{2}) via UPI AutoPay',
  );

  static final _autoPayRevoked = RegExp(
    r'UPI AutoPay for (.+?) from slice (?:savings )?a/c (\w+) for Rs\.\s?([\d,]+(?:\.\d+)?) is revoked',
  );

  static final _autoPayCreated = RegExp(
    r"UPI AutoPay successfully created towards (.+?) from (\d{1,2} [A-Za-z]{3} '\d{2}) to "
    r"\d{1,2} [A-Za-z]{3} '\d{2} for Rs\.\s?([\d,]+(?:\.\d+)?) with \w+ frequency",
  );

  @override
  bool canHandle(String sender, String body) =>
      sender.contains('SLCBNK') || sender.contains('SLCEIT');

  @override
  ParsedTransaction? parse(String body, DateTime receivedAt) {
    final sentMatch = _sent.firstMatch(body);
    if (sentMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(sentMatch.group(1)!),
        direction: TransactionDirection.debit,
        bankName: 'slice',
        paymentMethodType: PaymentMethodType.upi,
        transactionDate: SmsDateParser.ddMonYyDashed(sentMatch.group(3)!),
        cardOrAccountLastFour: sentMatch.group(2),
        counterparty: sentMatch.group(4),
        referenceId: sentMatch.group(5),
      );
    }

    final cardMatch = _cardSpend.firstMatch(body);
    if (cardMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(cardMatch.group(1)!),
        direction: TransactionDirection.debit,
        bankName: 'slice',
        paymentMethodType: PaymentMethodType.creditCard,
        transactionDate: SmsDateParser.ddMonYyDashed(cardMatch.group(4)!),
        cardOrAccountLastFour: cardMatch.group(2),
        counterparty: cardMatch.group(3),
        referenceId: cardMatch.group(5),
      );
    }

    final receivedMatch = _received.firstMatch(body);
    if (receivedMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(receivedMatch.group(1)!),
        direction: TransactionDirection.credit,
        bankName: 'slice',
        paymentMethodType: PaymentMethodType.upi,
        transactionDate: SmsDateParser.ddMonYyDashed(receivedMatch.group(3)!),
        cardOrAccountLastFour: receivedMatch.group(2),
        counterparty: receivedMatch.group(4),
        referenceId: receivedMatch.group(5),
        availableBalanceOrLimit:
            SmsDateParser.parseAmount(receivedMatch.group(6)!),
      );
    }

    final autoPayMatch = _autoPay.firstMatch(body);
    if (autoPayMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(autoPayMatch.group(1)!),
        direction: TransactionDirection.debit,
        bankName: 'slice',
        paymentMethodType: PaymentMethodType.upi,
        transactionDate: SmsDateParser.ddMonYyDashed(autoPayMatch.group(4)!),
        cardOrAccountLastFour: autoPayMatch.group(2),
        counterparty: autoPayMatch.group(3),
      );
    }

    return null;
  }

  @override
  ParsedAutopayEvent? parseAutopayEvent(String body, DateTime receivedAt) {
    // IPO application mandates ("UPI-IPO mandate...") are a one-time fund
    // block for a stock application, not a recurring subscription autopay -
    // a different thing conceptually, so they're left out of this bucket
    // rather than being mislabeled as autopay activity.
    if (body.contains('IPO')) return null;

    final revokedMatch = _autoPayRevoked.firstMatch(body);
    if (revokedMatch != null) {
      return ParsedAutopayEvent(
        eventType: AutopayEventType.revoked,
        merchantName: revokedMatch.group(1)!,
        amount: SmsDateParser.parseAmount(revokedMatch.group(3)!),
        bankName: 'slice',
        eventDate: receivedAt,
      );
    }

    final createdMatch = _autoPayCreated.firstMatch(body);
    if (createdMatch != null) {
      return ParsedAutopayEvent(
        eventType: AutopayEventType.created,
        merchantName: createdMatch.group(1)!,
        amount: SmsDateParser.parseAmount(createdMatch.group(3)!),
        bankName: 'slice',
        eventDate: SmsDateParser.dMonQuoteYy(createdMatch.group(2)!),
      );
    }

    return null;
  }
}
