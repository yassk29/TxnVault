import '../parser/parsed_transaction.dart';
import '../parser/sms_date_parser.dart';
import '../parser/sms_parser.dart';

/// IPO application lifecycle messages from NSE's IPO system and various
/// registrars/banks (NSEIPO, MUFGIN, BSSIPO, LNKRTA, KFINCR) - a different
/// thing from slice's "UPI-IPO mandate" messages (handled in SliceParser,
/// which explicitly excludes IPO text from its own autopay detection so the
/// two don't collide).
///
/// Fund blocking/unblocking for an IPO application isn't a real spend or a
/// subscription - it maps naturally onto the same created/revoked shape as
/// autopay mandates: a block is a commitment with no money actually spent
/// yet, and it either gets released back (non-allotment - "revoked") or
/// converted into an actual purchase of shares (allotment - a real
/// transaction, handled by [parse] instead).
class IpoParser extends SmsParser {
  @override
  String get id => 'ipo';

  static final _sharesAllotted = RegExp(
    r'IPO (.+?):\s*(\d+) shares allotted at Rs ([\d,]+(?:\.\d+)?) for App no (\S+)',
  );

  static final _fundBlocked = RegExp(
    r'IPO (.+?)\s*: App no (\S+) UPI ID (\S+) for Rs ([\d,]+(?:\.\d+)?) received',
  );

  // Sender wording varies ("Informed your Bnk."/"Informed your Bank"/"Your
  // bank is instructed"/"Your bank has been instructed") and so does the
  // "applno" spelling (some senders drop a letter: "aplno").
  static final _fundUnblocked = RegExp(
    r'(?:Informed your (?:Bnk\.?|Bank)|Your bank (?:is instructed|has been instructed)) '
    r'to unbl(?:k|ock) Rs\.?\s?([\d,]+(?:\.\d+)?) for (.+?) IPO ap?plno\.?\s?(\S+) '
    r'due to non-allotment',
  );

  @override
  bool canHandle(String sender, String body) =>
      sender.contains('NSEIPO') ||
      sender.contains('MUFGIN') ||
      sender.contains('BSSIPO') ||
      sender.contains('LNKRTA') ||
      sender.contains('KFINCR');

  @override
  ParsedTransaction? parse(String body, DateTime receivedAt) {
    final allottedMatch = _sharesAllotted.firstMatch(body);
    if (allottedMatch == null) return null;

    final perShare = SmsDateParser.parseAmount(allottedMatch.group(3)!);
    final shareCount = int.parse(allottedMatch.group(2)!);
    return ParsedTransaction(
      amount: perShare * shareCount,
      direction: TransactionDirection.debit,
      bankName: 'IPO',
      paymentMethodType: PaymentMethodType.bankTransfer,
      transactionDate: receivedAt,
      counterparty: allottedMatch.group(1)!.trim(),
      referenceId: allottedMatch.group(4),
      description: '$shareCount shares allotted',
    );
  }

  @override
  ParsedAutopayEvent? parseAutopayEvent(String body, DateTime receivedAt) {
    final blockedMatch = _fundBlocked.firstMatch(body);
    if (blockedMatch != null) {
      return ParsedAutopayEvent(
        eventType: AutopayEventType.created,
        merchantName: blockedMatch.group(1)!.trim(),
        amount: SmsDateParser.parseAmount(blockedMatch.group(4)!),
        bankName: 'IPO',
        eventDate: receivedAt,
        referenceId: blockedMatch.group(2),
      );
    }

    final unblockedMatch = _fundUnblocked.firstMatch(body);
    if (unblockedMatch != null) {
      return ParsedAutopayEvent(
        eventType: AutopayEventType.revoked,
        merchantName: unblockedMatch.group(2)!.trim(),
        amount: SmsDateParser.parseAmount(unblockedMatch.group(1)!),
        bankName: 'IPO',
        eventDate: receivedAt,
        referenceId: unblockedMatch.group(3),
      );
    }

    return null;
  }
}
