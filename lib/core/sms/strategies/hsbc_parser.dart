import '../parser/parsed_transaction.dart';
import '../parser/sms_date_parser.dart';
import '../parser/sms_parser.dart';

/// Handles two known HSBC templates:
///  - UPI credit: "Your HSBC Acc XXXXXX7006 is credited for INR 1.00 on
///    12-Sep-26 from yassk29@slc. UPI Ref No 625554614687"
///  - Debit card spend: "HSBC:Thank you for using HSBC Debit Card XXXXX8975
///    for INR 1,564.15 on 12SEP at THEHAMPTONS .Your available bal is
///    INR 993.43 ..." (no year in the date - falls back to the SMS's year)
class HsbcParser extends SmsParser {
  @override
  String get id => 'hsbc';

  static final _upiCredit = RegExp(
    r'Your HSBC Acc X+(\d+) is credited for INR ([\d,]+\.\d{2}) on (\d{1,2}-[A-Za-z]{3}-\d{2}) from (\S+?)\.? UPI Ref No (\d+)',
  );

  static final _debitCardSpend = RegExp(
    r'HSBC:Thank you for using HSBC Debit Card X+(\d+) for INR ([\d,]+\.\d{2}) on (\d{1,2}[A-Za-z]{3}) at (.+?)\s*\.Your available bal is INR ([\d,]+\.\d{2})',
  );

  static final _billPay = RegExp(
    r'INR ?([\d,]+\.\d{2}) is paid from HSBC account X+(\d+) to (.+?) on (\d{1,2}-[A-Za-z]{3}-\d{2}) with ref (\d+)',
  );

  @override
  bool canHandle(String sender, String body) => sender.contains('HSBCIN');

  @override
  ParsedTransaction? parse(String body, DateTime receivedAt) {
    final creditMatch = _upiCredit.firstMatch(body);
    if (creditMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(creditMatch.group(2)!),
        direction: TransactionDirection.credit,
        bankName: 'HSBC',
        paymentMethodType: PaymentMethodType.upi,
        transactionDate: SmsDateParser.ddMonYyDashed(creditMatch.group(3)!),
        cardOrAccountLastFour: creditMatch.group(1),
        counterparty: creditMatch.group(4),
        referenceId: creditMatch.group(5),
      );
    }

    final debitMatch = _debitCardSpend.firstMatch(body);
    if (debitMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(debitMatch.group(2)!),
        direction: TransactionDirection.debit,
        bankName: 'HSBC',
        paymentMethodType: PaymentMethodType.debitCard,
        transactionDate:
            SmsDateParser.ddMonNoYear(debitMatch.group(3)!, receivedAt),
        cardOrAccountLastFour: debitMatch.group(1),
        counterparty: debitMatch.group(4),
        availableBalanceOrLimit: SmsDateParser.parseAmount(debitMatch.group(5)!),
      );
    }

    final billPayMatch = _billPay.firstMatch(body);
    if (billPayMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(billPayMatch.group(1)!),
        direction: TransactionDirection.debit,
        bankName: 'HSBC',
        paymentMethodType: PaymentMethodType.bankTransfer,
        transactionDate: SmsDateParser.ddMonYyDashed(billPayMatch.group(4)!),
        cardOrAccountLastFour: billPayMatch.group(2),
        counterparty: billPayMatch.group(3),
        referenceId: billPayMatch.group(5),
      );
    }

    return null;
  }
}
