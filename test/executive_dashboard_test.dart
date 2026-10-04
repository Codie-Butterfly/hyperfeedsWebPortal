import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperfeeds_mobile/providers/auth_provider.dart';
import 'package:hyperfeeds_mobile/constants/theme.dart';
import 'package:hyperfeeds_mobile/screens/employee/executive_dashboard.dart';

void main() {
  testWidgets('CEO filters by branch and saves its monthly target', (
    tester,
  ) async {
    final preview = Platform.environment['HYPERFEEDS_DASHBOARD_PREVIEW'];
    final fontDir = Platform.environment['HYPERFEEDS_TEST_FONT_DIR'];
    if (preview != null && fontDir != null) {
      await tester.runAsync(() async {
        for (final entry in {
          'Roboto': 'Roboto-Regular.ttf',
          'MaterialIcons': 'MaterialIcons-Regular.otf',
        }.entries) {
          final loader = FontLoader(entry.key)
            ..addFont(
              File(
                '$fontDir/${entry.value}',
              ).readAsBytes().then((v) => ByteData.sublistView(v)),
            );
          await loader.load();
        }
      });
    }
    tester.view.physicalSize = const Size(1100, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio();
    final api = ApiClient(dio: dio);
    dio.interceptors.clear();
    Map? target;
    String? selectedBranch;
    final period =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) {
          dynamic data;
          if (r.path.endsWith('/options')) {
            data = {
              'branches': [
                {'id': 'branch-1', 'name': 'Harare'},
                {'id': 'branch-2', 'name': 'Bulawayo'},
              ],
              'currencies': ['USD', 'ZAR'],
            };
          } else if (r.path.endsWith('/stock-requests')) {
            data = [];
          } else if (r.path.endsWith('/targets')) {
            target = Map.from(r.data);
            data = {};
          } else {
            selectedBranch = r.queryParameters['branchId'];
            data = {
              'summary': {
                'net_sales': 42000,
                'cash_received': 39000,
                'discounts': 1200,
                'target': 60000,
                'expected_to_date': 44000,
                'pace_gap': -2000,
                'remaining_to_target': 18000,
                'achievement_percent': 70,
                'days_elapsed': 22,
                'days_in_month': 30,
              },
              'daily': [
                {'day': '$period-01', 'amount': 2500},
                {'day': '$period-02', 'amount': 3900},
                {'day': '$period-03', 'amount': 3000},
              ],
              'branches': [
                {
                  'id': 'branch-1',
                  'name': 'Harare',
                  'actual': 27000,
                  'target': 35000,
                },
                {
                  'id': 'branch-2',
                  'name': 'Bulawayo',
                  'actual': 15000,
                  'target': 25000,
                },
              ],
              'products': [
                {
                  'id': 'p1',
                  'name': 'Broiler starter',
                  'sku': 'BS01',
                  'pack_size': '50kg',
                  'quantity': 120,
                  'net_sales': 3600,
                },
                {
                  'id': 'p2',
                  'name': 'Layer mash',
                  'sku': 'LM01',
                  'pack_size': '50kg',
                  'quantity': 0,
                  'net_sales': 0,
                },
              ],
              'inventory': [
                {
                  'branch_name': 'Harare',
                  'product_name': 'Broiler starter',
                  'pack_size': '50kg',
                  'on_hand': 10,
                  'reserved': 4,
                  'available': 6,
                  'low_stock_threshold': 10,
                  'low_stock': true,
                },
              ],
              'chicks': [
                {
                  'status': 'CONFIRMED',
                  'chick_type': 'BROILER',
                  'breed': 'Ross',
                  'bookings': 10,
                  'chicks': 1000,
                  'value': 2000,
                },
              ],
              'as_of': '2026-09-22T07:00:00Z',
            };
          }
          h.resolve(Response(requestOptions: r, data: data, statusCode: 200));
        },
      ),
    );
    final boundary = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: AppTheme.lightTheme.copyWith(
            textTheme: AppTheme.lightTheme.textTheme.apply(
              fontFamily: 'Roboto',
            ),
          ),
          home: RepaintBoundary(
            key: boundary,
            child: const ExecutiveDashboard(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Behind pace'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (preview != null)
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(preview).writeAsBytes(bytes!.buffer.asUint8List());
      });
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Company / branch'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harare').last);
    await tester.pumpAndSettle();
    expect(selectedBranch, 'branch-1');
    await tester.ensureVisible(find.text('Configs'));
    await tester.tap(find.text('Configs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set monthly target'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Expected net sales'),
      '75000',
    );
    await tester.tap(find.text('Save target'));
    await tester.pumpAndSettle();
    expect(target?['branchId'], 'branch-1');
    expect(target?['amount'], '75000');
    expect(target?['currency'], 'USD');
    expect(target?['month'], period);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    for (final tab in [
      'Overview',
      'Sales',
      'Product Performance',
      'Stock Movement',
      'Branch Performance',
      'Chick Orders',
      'Configs',
    ]) {
      final finder = find.widgetWithText(Tab, tab);
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
      expect(selectedBranch, 'branch-1');
      if (tab == 'Stock Movement') {
        expect(find.text('Feed stock by category'), findsOneWidget);
      }
    }
  });
}
