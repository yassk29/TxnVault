import '../parser/parsed_transaction.dart';
import '../parser/sms_date_parser.dart';
import '../parser/sms_parser.dart';

/// "INR 71.64 spent on IndusInd Card XX0986 on 11-04-2026 09:19:45 am at
/// DMRC. Avl Lmt: INR 102,928.36. ..."
class IndusindParser extends SmsParser {
  @override
  String get id => 'indusind';

  static final _spend = RegExp(
    r'INR ?([\d,]+\.\d{2}) spent on IndusInd Card X+(\d+) on (\d{2}-\d{2}-\d{4}) (\d{2}:\d{2}:\d{2}) ?(am|pm|AM|PM) at (.+?)\. Avl Lmt: ?INR ?([\d,]+\.\d{2})',
  );

  @override
  bool canHandle(String sender, String body) => sender.contains('INDUSB');

  @override
  ParsedTransaction? parse(String body, DateTime receivedAt) {
    final match = _spend.firstMatch(body);
    if (match == null) return null;

    return ParsedTransaction(
      amount: SmsDateParser.parseAmount(match.group(1)!),
      direction: TransactionDirection.debit,
      bankName: 'IndusInd',
      paymentMethodType: PaymentMethodType.creditCard,
      transactionDate: SmsDateParser.ddMmYyyyWithTime12h(
          match.group(3)!, match.group(4)!, match.group(5)!),
      cardOrAccountLastFour: match.group(2),
      counterparty: match.group(6),
      availableBalanceOrLimit: SmsDateParser.parseAmount(match.group(7)!),
    );
  }
}
