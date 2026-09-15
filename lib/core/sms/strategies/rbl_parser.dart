import '../parser/parsed_transaction.dart';
import '../parser/sms_date_parser.dart';
import '../parser/sms_parser.dart';

/// Handles RBL Bank credit card spends and bill payments.
///
/// Also recognizes (and deliberately ignores) the "credit card bill has been
/// generated" reminder sent via CRED - it mentions "RBL Bank" but is a bill
/// notice, not a money movement.
class RblParser extends SmsParser {
  @override
  String get id => 'rbl';

  static final _spend = RegExp(
    r'INR ?([\d,]+\.\d{2}) spent at (.+?) on RBL Bank credit card \((\w+)\) on (\d{2}-\d{2}-\d{4})\.AVL limit- ?INR ?([\d,]+\.\d{2})',
  );

  static final _paymentReceived = RegExp(
    r'Payment of INR ?([\d,]+\.\d{2}) received on RBL Bank Credit Card (\w+) on (\d{2}-\d{2}-\d{4}), Avl Limit INR ?([\d,]+\.\d{2})',
  );

  // Matches on the DLT sender code (RBLCRD), not body text: other banks'
  // SMS sometimes mention "RBL Bank Credit Card" as a third-party reference
  // (e.g. an SBI transfer paying off an RBL card), which made a body-text
  // check wrongly claim the message before SbiParser got a chance to.
  @override
  bool canHandle(String sender, String body) => sender.contains('RBLCRD');

  @override
  ParsedTransaction? parse(String body, DateTime receivedAt) {
    if (body.contains('credit card bill for RBL Bank') &&
        body.contains('has been generated')) {
      return null;
    }

    final spendMatch = _spend.firstMatch(body);
    if (spendMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(spendMatch.group(1)!),
        direction: TransactionDirection.debit,
        bankName: 'RBL',
        paymentMethodType: PaymentMethodType.creditCard,
        transactionDate: SmsDateParser.ddMmYyyyDashed(spendMatch.group(4)!),
        cardOrAccountLastFour: spendMatch.group(3),
        counterparty: spendMatch.group(2)!.trim(),
        availableBalanceOrLimit:
            SmsDateParser.parseAmount(spendMatch.group(5)!),
      );
    }

    final paymentMatch = _paymentReceived.firstMatch(body);
    if (paymentMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(paymentMatch.group(1)!),
        direction: TransactionDirection.credit,
        bankName: 'RBL',
        paymentMethodType: PaymentMethodType.creditCard,
        transactionDate: SmsDateParser.ddMmYyyyDashed(paymentMatch.group(3)!),
        cardOrAccountLastFour: paymentMatch.group(2),
        description: 'Credit card bill payment',
        category: TransactionKind.repayment,
        availableBalanceOrLimit:
            SmsDateParser.parseAmount(paymentMatch.group(4)!),
      );
    }

    return null;
  }
}
