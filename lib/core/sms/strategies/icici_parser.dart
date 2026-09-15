import '../parser/parsed_transaction.dart';
import '../parser/sms_date_parser.dart';
import '../parser/sms_parser.dart';

/// "INR 408.00 spent using ICICI Bank Card XX3009 on 16-Aug-26 on AMAZON PAY
/// IN G. Avl Limit: INR 1,22,888.77. ..."
///
/// Amounts use Indian lakh-style comma grouping (1,22,888.77) - stripping
/// commas before parsing handles that regardless of grouping style.
class IciciParser extends SmsParser {
  @override
  String get id => 'icici';

  static final _spend = RegExp(
    r'INR ?([\d,]+\.\d{2}) spent using ICICI Bank Card X+(\d+) on (\d{1,2}-[A-Za-z]{3}-\d{2}) on (.+?)\. Avl Limit: ?INR ?([\d,]+\.\d{2})',
  );

  @override
  bool canHandle(String sender, String body) => sender.contains('ICICIT');

  @override
  ParsedTransaction? parse(String body, DateTime receivedAt) {
    final match = _spend.firstMatch(body);
    if (match == null) return null;

    return ParsedTransaction(
      amount: SmsDateParser.parseAmount(match.group(1)!),
      direction: TransactionDirection.debit,
      bankName: 'ICICI',
      paymentMethodType: PaymentMethodType.creditCard,
      transactionDate: SmsDateParser.ddMonYyDashed(match.group(3)!),
      cardOrAccountLastFour: match.group(2),
      counterparty: match.group(4),
      availableBalanceOrLimit: SmsDateParser.parseAmount(match.group(5)!),
    );
  }
}
