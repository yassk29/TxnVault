import '../parser/parsed_transaction.dart';
import '../parser/sms_date_parser.dart';
import '../parser/sms_parser.dart';

/// Handles two known SBI templates - a P2P transfer credit, and a generic
/// "has credit for VREF ..." credit whose reference blob is opaque/messy
/// (kept as-is rather than fully parsed).
class SbiParser extends SmsParser {
  @override
  String get id => 'sbi';

  static final _transferCredit = RegExp(
    r'Dear SBI User, your A/c (\w+)-credited by Rs\.([\d,]+(?:\.\d+)?) on (\d{1,2}[A-Za-z]{3}\d{2}) transfer from (.+?) Ref No (\d+) -SBI',
  );

  static final _vrefCredit = RegExp(
    r'Your A/C (\w+) has credit for (.*?) of Rs ([\d,]+\.\d{2}) on (\d{2}/\d{2}/\d{2})\. Avl Bal Rs ([\d,]+\.\d{2})\.-SBI',
  );

  /// A payment/transfer made via SBI towards something else (often paying
  /// off another bank's credit card) - no date in the SMS itself, so the
  /// SMS's own received time is used as the transaction date.
  static final _transactionSuccessful = RegExp(
    r'Transaction of Rs\.? ?([\d,]+\.\d{2}) for (.+?) with reference no\. (\S+) is Successful-SBI',
  );

  @override
  bool canHandle(String sender, String body) =>
      sender.contains('SBIUPI') || sender.contains('CBSSBI');

  @override
  ParsedTransaction? parse(String body, DateTime receivedAt) {
    final transferMatch = _transferCredit.firstMatch(body);
    if (transferMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(transferMatch.group(2)!),
        direction: TransactionDirection.credit,
        bankName: 'SBI',
        paymentMethodType: PaymentMethodType.bankTransfer,
        transactionDate: SmsDateParser.ddMonYyCompact(transferMatch.group(3)!),
        cardOrAccountLastFour: transferMatch.group(1),
        counterparty: transferMatch.group(4),
        referenceId: transferMatch.group(5),
      );
    }

    final vrefMatch = _vrefCredit.firstMatch(body);
    if (vrefMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(vrefMatch.group(3)!),
        direction: TransactionDirection.credit,
        bankName: 'SBI',
        paymentMethodType: PaymentMethodType.bankTransfer,
        transactionDate: SmsDateParser.ddMmYySlashed(vrefMatch.group(4)!),
        cardOrAccountLastFour: vrefMatch.group(1),
        referenceId: vrefMatch.group(2),
        availableBalanceOrLimit:
            SmsDateParser.parseAmount(vrefMatch.group(5)!),
      );
    }

    final successMatch = _transactionSuccessful.firstMatch(body);
    if (successMatch != null) {
      return ParsedTransaction(
        amount: SmsDateParser.parseAmount(successMatch.group(1)!),
        direction: TransactionDirection.debit,
        bankName: 'SBI',
        paymentMethodType: PaymentMethodType.bankTransfer,
        transactionDate: receivedAt,
        counterparty: successMatch.group(2)!.replaceAll('...', '').trim(),
        referenceId: successMatch.group(3),
        category: TransactionKind.repayment,
      );
    }

    return null;
  }
}
