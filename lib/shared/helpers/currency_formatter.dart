/// Formats an amount using Indian digit grouping (last 3 digits, then groups
/// of 2): 4113931 -> "41,13,931", not the international "4,113,931".
String formatIndianCurrency(double amount, {bool withSymbol = true}) {
  final isNegative = amount < 0;
  final fixed = amount.abs().toStringAsFixed(2);
  final dotIndex = fixed.indexOf('.');
  final intPart = fixed.substring(0, dotIndex);
  final decPart = fixed.substring(dotIndex + 1);

  final grouped = _groupIndian(intPart);
  final sign = isNegative ? '-' : '';
  final symbol = withSymbol ? '₹' : '';
  return '$sign$symbol$grouped.$decPart';
}

String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;

  final lastThree = digits.substring(digits.length - 3);
  var remaining = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (remaining.length > 2) {
    groups.insert(0, remaining.substring(remaining.length - 2));
    remaining = remaining.substring(0, remaining.length - 2);
  }
  if (remaining.isNotEmpty) groups.insert(0, remaining);
  return '${groups.join(',')},$lastThree';
}
