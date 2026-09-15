/// Bank SMS use a different date (and sometimes date+time) format per
/// template. Each parser calls the one matching helper for its own known
/// format rather than a generic guesser trying every shape.
class SmsDateParser {
  SmsDateParser._();

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static int _month(String name) {
    final key = name.toLowerCase().substring(0, 3);
    final month = _months[key];
    if (month == null) throw FormatException('Unknown month: $name');
    return month;
  }

  /// "12-Sep-26" / "04-Sep-26"
  static DateTime ddMonYyDashed(String input) {
    final parts = input.split('-');
    final day = int.parse(parts[0]);
    final month = _month(parts[1]);
    final year = 2000 + int.parse(parts[2]);
    return DateTime(year, month, day);
  }

  /// "12SEP" - no year in the SMS; fall back to the year the SMS arrived.
  static DateTime ddMonNoYear(String input, DateTime receivedAt) {
    final match = RegExp(r'^(\d{1,2})([A-Za-z]{3})$').firstMatch(input);
    if (match == null) throw FormatException('Unexpected date: $input');
    final day = int.parse(match.group(1)!);
    final month = _month(match.group(2)!);
    return DateTime(receivedAt.year, month, day);
  }

  /// "14Aug26" - no separators.
  static DateTime ddMonYyCompact(String input) {
    final match = RegExp(r'^(\d{1,2})([A-Za-z]{3})(\d{2})$').firstMatch(input);
    if (match == null) throw FormatException('Unexpected date: $input');
    final day = int.parse(match.group(1)!);
    final month = _month(match.group(2)!);
    final year = 2000 + int.parse(match.group(3)!);
    return DateTime(year, month, day);
  }

  /// "06 Sep '26" - day, short month, apostrophe + 2-digit year.
  static DateTime dMonQuoteYy(String input) {
    final match = RegExp(r"^(\d{1,2}) ([A-Za-z]{3}) '(\d{2})$").firstMatch(input);
    if (match == null) throw FormatException('Unexpected date: $input');
    return DateTime(2000 + int.parse(match.group(3)!), _month(match.group(2)!),
        int.parse(match.group(1)!));
  }

  /// "12-09-2026" (DD-MM-YYYY)
  static DateTime ddMmYyyyDashed(String input) {
    final parts = input.split('-');
    return DateTime(
        int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
  }

  /// "07/09/26" (DD/MM/YY)
  static DateTime ddMmYySlashed(String input) {
    final parts = input.split('/');
    return DateTime(
        2000 + int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
  }

  /// "07 Sep 2026" - date only, no time in the SMS.
  static DateTime ddMonYyyySpaced(String input) {
    final match =
        RegExp(r'^(\d{1,2}) ([A-Za-z]{3}) (\d{4})$').firstMatch(input);
    if (match == null) throw FormatException('Unexpected date: $input');
    return DateTime(int.parse(match.group(3)!), _month(match.group(2)!),
        int.parse(match.group(1)!));
  }

  /// "30 AUG 2026" + "03:45 PM"
  static DateTime ddMonYyyySpacedWithTime(String datePart, String timePart) {
    final dateMatch =
        RegExp(r'^(\d{1,2}) ([A-Za-z]{3}) (\d{4})$').firstMatch(datePart);
    if (dateMatch == null) throw FormatException('Unexpected date: $datePart');
    final day = int.parse(dateMatch.group(1)!);
    final month = _month(dateMatch.group(2)!);
    final year = int.parse(dateMatch.group(3)!);

    final timeMatch =
        RegExp(r'^(\d{1,2}):(\d{2}) (AM|PM)$', caseSensitive: false)
            .firstMatch(timePart);
    var hour = 0;
    var minute = 0;
    if (timeMatch != null) {
      hour = int.parse(timeMatch.group(1)!) % 12;
      minute = int.parse(timeMatch.group(2)!);
      if (timeMatch.group(3)!.toUpperCase() == 'PM') hour += 12;
    }
    return DateTime(year, month, day, hour, minute);
  }

  /// "16JUN2024" - no separators, 4-digit year.
  static DateTime ddMonYyyyCompact(String input) {
    final match =
        RegExp(r'^(\d{1,2})([A-Za-z]{3})(\d{4})$').firstMatch(input);
    if (match == null) throw FormatException('Unexpected date: $input');
    return DateTime(int.parse(match.group(3)!), _month(match.group(2)!),
        int.parse(match.group(1)!));
  }

  /// "16JUN2024" + "10:48:12" (24-hour clock)
  static DateTime ddMonYyyyCompactWithTime24h(String datePart, String timePart) {
    final date = ddMonYyyyCompact(datePart);
    final timeParts = timePart.split(':');
    return DateTime(date.year, date.month, date.day, int.parse(timeParts[0]),
        int.parse(timeParts[1]), int.parse(timeParts[2]));
  }

  /// "05-12-2024" + "19:00:25" (DD-MM-YYYY, 24-hour clock)
  static DateTime ddMmYyyyWithTime24h(String datePart, String timePart) {
    final dateParts = datePart.split('-');
    final timeParts = timePart.split(':');
    return DateTime(
      int.parse(dateParts[2]),
      int.parse(dateParts[1]),
      int.parse(dateParts[0]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
      int.parse(timeParts[2]),
    );
  }

  /// "2026-09-05" + "21:08:37"
  static DateTime isoDateWithTime(String datePart, String timePart) {
    final dateParts = datePart.split('-');
    final timeParts = timePart.split(':');
    return DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
      int.parse(timeParts[2]),
    );
  }

  /// "11-04-2026" + "09:19:45" + "am"/"pm"
  static DateTime ddMmYyyyWithTime12h(
      String datePart, String timePart, String meridiem) {
    final dateParts = datePart.split('-');
    final timeParts = timePart.split(':');
    var hour = int.parse(timeParts[0]) % 12;
    if (meridiem.toLowerCase() == 'pm') hour += 12;
    return DateTime(
      int.parse(dateParts[2]),
      int.parse(dateParts[1]),
      int.parse(dateParts[0]),
      hour,
      int.parse(timeParts[1]),
      int.parse(timeParts[2]),
    );
  }

  static double parseAmount(String raw) {
    return double.parse(raw.replaceAll(',', ''));
  }
}
