import '../parser/parsed_transaction.dart';
import '../parser/sms_date_parser.dart';
import '../parser/sms_parser.dart';

/// Federal Bank (DLT sender code FEDBNK) - by far the highest-volume
/// previously-unrecognized sender found once real user data was sampled
/// (300+ messages). Handles UPI debits, IMPS credits, FEDNET netbanking
/// debits, card spends, and UPI AutoPay mandate executions; recognizes (and
/// ignores) mandate-creation notices, which aren't money movements.
class FederalBankParser extends SmsParser {
  @override
  String get id => 'federal_bank';

  static final _upiDebit = RegExp(
    r'Rs\.?\s?([\d,]+(?:\.\d+)?) debited (?:from your A/c )?via UPI on '
    r'(\d{2}-\d{2}-\d{4}) (\d{2}:\d{2}:\d{2}) to VPA (\S+?)\.Ref No (\d+)',
  );

  static final _impsCredit = RegExp(
    r'Rs\.?([\d,]+(?:\.\d+)?) credited to your A/c X*(\d+) via IMPS on '
    r'(\d{2}[A-Za-z]{3}\d{4}) (\d{2}:\d{2}:\d{2})\. \(IMPS Ref no-(\d+)\) '
    r'BAL-Rs\.([\d,]+\.\d{2})',
  );

  static final _fednetDebit = RegExp(
    r'Thank you for using FEDNET\.Rs\.([\d,]+(?:\.\d+)?) debited from your '
    r'A/c X*(\d+) on (\d{2}[A-Za-z]{3}\d{4}) (\d{2}:\d{2}:\d{2})\. '
    r'BAL-Rs\.([\d,]+\.\d{2})',
  );

  static final _cardSpend = RegExp(
    r'Rs ?([\d,]+(?:\.\d+)?) spent@(.+?)\s+on (\d{2}[A-Za-z]{3}\d{2}) '
    r'(\d{2}:\d{2})\.BAL:Rs ?([\d,]+\.\d{2})',
  );

  static final _mandateExecuted = RegExp(
    r'Your mandate with ref no- (\S+) registered against (.+?) for Rs ?'
    r'([\d,]+(?:\.\d+)?) successfully executed on (\d{2}-\d{2}-\d{4}) '
    r'(\d{2}:\d{2}:\d{2})\. TXN Ref No -(\S+)',
  );

  static final _mandateCreated = RegExp(
    r'You have successfully created a mandate on (.+?) for a \w+ frequency '
    r'starting from (\d{2}-\d{2}-\d{4}) for a maximum amount of Rs ?'
    r'([\d,]+(?:\.\d+)?)',
  );

  @override
  bool canHandle(String sender, String body) => sender.contains('FEDBNK');

  @override
  ParsedTransaction? parse(String body, DateTime receivedAt) {
    final upiMatch = _upiDebit.firstMatch(body);
    if (upiMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(upiMatch.group(1)!),
        direction: TransactionDirection.debit,
        bankName: 'Federal Bank',
        paymentMethodType: PaymentMethodType.upi,
        transactionDate: SmsDateParser.ddMmYyyyWithTime24h(
            upiMatch.group(2)!, upiMatch.group(3)!),
        counterparty: upiMatch.group(4),
        referenceId: upiMatch.group(5),
      );
    }

    final impsMatch = _impsCredit.firstMatch(body);
    if (impsMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(impsMatch.group(1)!),
        direction: TransactionDirection.credit,
        bankName: 'Federal Bank',
        paymentMethodType: PaymentMethodType.bankTransfer,
        transactionDate: SmsDateParser.ddMonYyyyCompactWithTime24h(
            impsMatch.group(3)!, impsMatch.group(4)!),
        cardOrAccountLastFour: impsMatch.group(2),
        referenceId: impsMatch.group(5),
        availableBalanceOrLimit: SmsDateParser.parseAmount(impsMatch.group(6)!),
      );
    }

    final fednetMatch = _fednetDebit.firstMatch(body);
    if (fednetMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(fednetMatch.group(1)!),
        direction: TransactionDirection.debit,
        bankName: 'Federal Bank',
        paymentMethodType: PaymentMethodType.bankTransfer,
        transactionDate: SmsDateParser.ddMonYyyyCompactWithTime24h(
            fednetMatch.group(3)!, fednetMatch.group(4)!),
        cardOrAccountLastFour: fednetMatch.group(2),
        availableBalanceOrLimit:
            SmsDateParser.parseAmount(fednetMatch.group(5)!),
      );
    }

    final cardMatch = _cardSpend.firstMatch(body);
    if (cardMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(cardMatch.group(1)!),
        direction: TransactionDirection.debit,
        bankName: 'Federal Bank',
        paymentMethodType: PaymentMethodType.debitCard,
        transactionDate: SmsDateParser.ddMonYyCompact(cardMatch.group(3)!),
        counterparty: cardMatch.group(2)!.trim(),
        availableBalanceOrLimit: SmsDateParser.parseAmount(cardMatch.group(5)!),
      );
    }

    final mandateMatch = _mandateExecuted.firstMatch(body);
    if (mandateMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(mandateMatch.group(3)!),
        direction: TransactionDirection.debit,
        bankName: 'Federal Bank',
        paymentMethodType: PaymentMethodType.upi,
        transactionDate: SmsDateParser.ddMmYyyyWithTime24h(
            mandateMatch.group(4)!, mandateMatch.group(5)!),
        counterparty: mandateMatch.group(2),
        referenceId: mandateMatch.group(6),
        description: 'UPI AutoPay',
      );
    }

    return null;
  }

  @override
  ParsedAutopayEvent? parseAutopayEvent(String body, DateTime receivedAt) {
    final match = _mandateCreated.firstMatch(body);
    if (match == null) return null;

    return ParsedAutopayEvent(
      eventType: AutopayEventType.created,
      merchantName: match.group(1)!,
      amount: SmsDateParser.parseAmount(match.group(3)!),
      bankName: 'Federal Bank',
      eventDate: SmsDateParser.ddMmYyyyDashed(match.group(2)!),
    );
  }
}
