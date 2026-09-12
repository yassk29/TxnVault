import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txnvault/app/app.dart';

void main() {
  testWidgets('App launches and shows the bottom navigation bar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TxnVaultApp()));
    // Not pumpAndSettle: the SMS feed polls on a timer and never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Refunds'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
