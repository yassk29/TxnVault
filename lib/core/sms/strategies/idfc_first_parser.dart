import '../parser/parsed_transaction.dart';
import '../parser/sms_date_parser.dart';
import '../parser/sms_parser.dart';

/// "Delicious Purchase! INR 499.00 spent on your IDFC FIRST Bank Credit Card
/// ending XX3663 at RAJASTHALI on 30 AUG 2026 at 03:45 PM Avbl Limit:
/// INR 341865.91 ..."
///
/// The leading exclamation ("Delicious Purchase!") varies by merchant
/// category, so the pattern searches rather than anchors to it.
class IdfcFirstParser extends SmsParser {
  @override
  String get id => 'idfc_first';

  static final _spend = RegExp(
    r'INR ?([\d,]+\.\d{2}) spent on your IDFC FIRST Bank Credit Card ending X+(\d+) at (.+?) on (\d{1,2} [A-Za-z]{3} \d{4}) at (\d{1,2}:\d{2} [AP]M) Avbl Limit: ?INR ?([\d,]+\.\d{2})',
  );

  static final _billPayment = RegExp(
    r'Thank you for payment of INR ?([\d,]+\.\d{2}) towards your FIRST Select Credit Card X+(\d+) on (\d{1,2} [A-Za-z]{3} \d{4})',
  );

  @override
  bool canHandle(String sender, String body) => sender.contains('IDFCFB');

  @override
  ParsedTransaction? parse(String body, DateTime receivedAt) {
    final match = _spend.firstMatch(body);
    if (match != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(match.group(1)!),
        direction: TransactionDirection.debit,
        bankName: 'IDFC FIRST',
        paymentMethodType: PaymentMethodType.creditCard,
        transactionDate: SmsDateParser.ddMonYyyySpacedWithTime(
            match.group(4)!, match.group(5)!),
        cardOrAccountLastFour: match.group(2),
        counterparty: match.group(3),
        availableBalanceOrLimit: SmsDateParser.parseAmount(match.group(6)!),
      );
    }

    final billPaymentMatch = _billPayment.firstMatch(body);
    if (billPaymentMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(billPaymentMatch.group(1)!),
        direction: TransactionDirection.credit,
        bankName: 'IDFC FIRST',
        paymentMethodType: PaymentMethodType.creditCard,
        transactionDate:
            SmsDateParser.ddMonYyyySpaced(billPaymentMatch.group(3)!),
        cardOrAccountLastFour: billPaymentMatch.group(2),
        description: 'Credit card bill payment',
        category: TransactionKind.repayment,
      );
    }

    return null;
  }
}
