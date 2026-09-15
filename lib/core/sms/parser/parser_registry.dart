import '../strategies/federal_bank_parser.dart';
import '../strategies/hdfc_parser.dart';
import '../strategies/hsbc_parser.dart';
import '../strategies/icici_parser.dart';
import '../strategies/idfc_first_parser.dart';
import '../strategies/indusind_parser.dart';
import '../strategies/ipo_parser.dart';
import '../strategies/rbl_parser.dart';
import '../strategies/sbi_parser.dart';
import '../strategies/slice_parser.dart';
import 'parsed_transaction.dart';
import 'sms_parser.dart';

enum SmsParseStatus { parsed, autopayReference, ignored, unmatched }

class SmsParseResult {
  const SmsParseResult(this.status, {this.transaction, this.autopayEvent});

  final SmsParseStatus status;
  final ParsedTransaction? transaction;
  final ParsedAutopayEvent? autopayEvent;
}

/// Tries each registered parser in turn; the first one that claims the
/// message (via canHandle) decides the outcome. Add new bank/provider
/// parsers here as new SMS formats are seen.
class ParserRegistry {
  final List<SmsParser> _parsers = [
    HsbcParser(),
    RblParser(),
    SbiParser(),
    SliceParser(),
    IdfcFirstParser(),
    IciciParser(),
    HdfcParser(),
    IndusindParser(),
    FederalBankParser(),
    IpoParser(),
  ];

  SmsParseResult parse(String sender, String body, DateTime receivedAt) {
    for (final parser in _parsers) {
      if (!parser.canHandle(sender, body)) continue;

      final transaction = parser.parse(body, receivedAt);
      if (transaction != null) {
        return SmsParseResult(SmsParseStatus.parsed, transaction: transaction);
      }

      final autopayEvent = parser.parseAutopayEvent(body, receivedAt);
      if (autopayEvent != null) {
        return SmsParseResult(SmsParseStatus.autopayReference,
            autopayEvent: autopayEvent);
      }

      return const SmsParseResult(SmsParseStatus.ignored);
    }
    return const SmsParseResult(SmsParseStatus.unmatched);
  }
}
