import '../parser/parsed_transaction.dart';
import '../parser/sms_date_parser.dart';
import '../parser/sms_parser.dart';

/// "Spent Rs.326 On HDFC Bank Card 3804 At BLINKIT On
/// 2026-09-05:21:08:37.Not You? ..."
class HdfcParser extends SmsParser {
  @override
  String get id => 'hdfc';

  static final _spend = RegExp(
    r'Spent Rs\.([\d,]+(?:\.\d+)?) On HDFC Bank Card (\d+) At (.+?) On (\d{4}-\d{2}-\d{2}):(\d{2}:\d{2}:\d{2})',
  );

  @override
  bool canHandle(String sender, String body) => sender.contains('HDFCBK');

  @override
  ParsedTransaction? parse(String body, DateTime receivedAt) {
    final match = _spend.firstMatch(body);
    if (match == null) return null;

    return ParsedTransaction(
      amount: SmsDateParser.parseAmount(match.group(1)!),
      direction: TransactionDirection.debit,
      bankName: 'HDFC',
      paymentMethodType: PaymentMethodType.creditCard,
      transactionDate:
          SmsDateParser.isoDateWithTime(match.group(4)!, match.group(5)!),
      cardOrAccountLastFour: match.group(2),
      counterparty: match.group(3),
    );
  }
}
