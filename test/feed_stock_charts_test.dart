import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperfeeds_mobile/screens/employee/feed_stock_charts.dart';

void main() {
  testWidgets(
    'groups feeds and overlays remaining on a shared quantity scale',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedStockCharts(
                period: '2026-09',
                rows: [
                  {
                    'id': 'a',
                    'name': 'Beef finisher',
                    'pack_size': '50 kg',
                    'category': 'Cattle Feed',
                    'sold': 20,
                    'remaining': 80,
                  },
                  {
                    'id': 'b',
                    'name': 'Dairy meal',
                    'pack_size': '50 kg',
                    'category': 'Cattle Feed',
                    'sold': 30,
                    'remaining': 20,
                  },
                  {
                    'id': 'c',
                    'name': 'Starter',
                    'pack_size': '25 kg',
                    'category': 'Poultry Feed',
                    'sold': 0,
                    'remaining': 0,
                  },
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Cattle Feed'), findsOneWidget);
      expect(find.text('Poultry Feed'), findsOneWidget);
      double width(String key) =>
          tester.getSize(find.byKey(ValueKey(key))).width;
      expect(width('remaining-a') / width('total-a'), closeTo(0.8, 0.001));
      expect(width('total-b') / width('total-a'), closeTo(0.5, 0.001));
      expect(width('total-c'), 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Beef finisher (50 kg)'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('Sold: 20 • Remaining: 80 • Total: 100'),
        findsNWidgets(2),
      );
    },
  );
}
