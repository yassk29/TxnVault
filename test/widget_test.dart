import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txnvault/app/app.dart';

void main() {
  testWidgets('App launches and shows the bottom navigation bar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TxnVaultApp()));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Refunds'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
