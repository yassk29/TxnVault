import 'package:flutter_test/flutter_test.dart';
import 'package:txnvault/shared/helpers/currency_formatter.dart';

void main() {
  test('formats amounts using Indian digit grouping', () {
    expect(formatIndianCurrency(4113931), '₹41,13,931.00');
    expect(formatIndianCurrency(100000), '₹1,00,000.00');
    expect(formatIndianCurrency(1234567890), '₹1,23,45,67,890.00');
    expect(formatIndianCurrency(999), '₹999.00');
    expect(formatIndianCurrency(1000), '₹1,000.00');
    expect(formatIndianCurrency(1234.5), '₹1,234.50');
    expect(formatIndianCurrency(-5000), '-₹5,000.00');
    expect(formatIndianCurrency(0), '₹0.00');
    expect(formatIndianCurrency(100, withSymbol: false), '100.00');
  });
}
