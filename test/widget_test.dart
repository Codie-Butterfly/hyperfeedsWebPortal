import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyperfeeds_mobile/main.dart';

void main() {
  testWidgets('Hyperfeeds app welcome screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: HyperfeedsApp(),
      ),
    );

    // Let the GoRouter redirect and layout build settle.
    await tester.pumpAndSettle();

    // Verify that the welcome screen elements are found.
    expect(find.text('HYPERFEEDS'), findsOneWidget);
    expect(find.text('Customer Portal'), findsOneWidget);
    expect(find.text('Employee Login'), findsOneWidget);
  });
}
