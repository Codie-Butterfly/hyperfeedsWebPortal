import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperfeeds_mobile/providers/auth_provider.dart';
import 'package:hyperfeeds_mobile/screens/employee/walk_in_sale_screen.dart';
import 'package:hyperfeeds_mobile/services/sale_invoice.dart';

void main() {
  final dio = Dio();
  final api = ApiClient(dio: dio);
  Map<String, dynamic>? submitted;
  int requests = 0;
  bool failOnce = false;
  final sale = <String, dynamic>{
    'id': 'order-1',
    'reference': 'WIN-123456789012345678901234',
    'invoice_number': 'WIN-123456789012345678901234',
    'customer_name': 'Test Customer',
    'customer_phone': '0771234567',
    'currency': 'USD',
    'total': 25.00,
    'amount_paid': 25.00,
    'branch_name': 'Harare Branch',
    'branch_address': '123 Test Street, Harare',
    'branch_phone': '0242000000',
    'created_at': '2026-09-19 14:00',
    'paid_at': '2026-09-19 14:00',
    'payment_method': 'CASH',
    'payment_reference': '',
    'recorded_by': 'Test Cashier',
    'items': [
      {
        'product_name': 'Broiler Starter Feed 50kg',
        'quantity': 2,
        'unit_price': 12.5,
        'line_total': 25.0,
      },
    ],
  };
  setUp(() {
    final token =
        'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'employee-1'})))}.signature';
    FlutterSecureStorage.setMockInitialValues({'access_token': token});
    submitted = null;
    requests = 0;
    failOnce = false;
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          dynamic data;
          if (options.path.endsWith('/branches')) {
            data = [
              {'id': 'branch-1', 'name': 'Harare Branch'},
            ];
          } else if (options.path == '/catalogue/products') {
            data = [
              {
                'id': 'product-1',
                'name': 'Broiler Starter Feed',
                'sku': 'BR01',
                'packSize': '50kg',
                'available': 10,
                'amount': 12.5,
                'currency': 'USD',
              },
            ];
          } else if (options.path.endsWith('/customers')) {
            data = [
              {
                'id': 'customer-1',
                'name': 'Regular Customer',
                'phone_number': '0771234567',
              },
            ];
          } else if (options.path == '/commerce/walk-in-sales') {
            requests++;
            final previous = submitted;
            submitted = Map<String, dynamic>.from(options.data);
            if (failOnce && requests == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.receiveTimeout,
                ),
              );
              return;
            }
            if (requests > 1) expect(submitted, equals(previous));
            data = sale;
          }
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: data),
          );
        },
      ),
    );
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: WalkInSaleScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pumpAndSettle();
  }

  Future<void> fillPayment(WidgetTester tester) async {
    await enter(tester, 'Quantity', '2');
    await enter(tester, 'Amount applied to sale (USD)', '25.00');
    await tap(tester, 'I confirm the full payment has been received.');
  }

  testWidgets(
    'first-time customer is saved with sale and invoice can be printed',
    (tester) async {
      await open(tester);
      await tap(tester, 'First-time customer');
      await enter(tester, 'Customer name', 'New Customer');
      await fillPayment(tester);
      await tap(tester, 'Record sale and payment');
      expect(submitted!['customerName'], 'New Customer');
      expect(submitted!['customerId'], isNull);
      expect(submitted!['customerPhone'], '');
      expect(find.text('Sale and payment recorded'), findsOneWidget);
      expect(find.text('Print invoice'), findsOneWidget);
    },
  );
  testWidgets('returning customer selection reuses saved details', (
    tester,
  ) async {
    await open(tester);
    final search = find.widgetWithText(
      TextField,
      'Find customer by name or phone',
    );
    await tester.ensureVisible(search);
    await tester.enterText(search, 'Regular');
    await tap(tester, 'Search customers');
    await tap(tester, 'Regular Customer');
    await fillPayment(tester);
    await tap(tester, 'Record sale and payment');
    expect(submitted!['customerId'], 'customer-1');
    expect(submitted!['customerName'], 'Regular Customer');
    expect(submitted!['customerPhone'], '0771234567');
  });
  testWidgets('uncertain response retries the exact same saved sale', (
    tester,
  ) async {
    failOnce = true;
    await open(tester);
    await tap(tester, 'First-time customer');
    await enter(tester, 'Customer name', 'New Customer');
    await fillPayment(tester);
    await tap(tester, 'Record sale and payment');
    expect(find.text('Retry same sale'), findsOneWidget);
    await tap(tester, 'Retry same sale');
    expect(requests, 2);
    expect(find.text('Sale and payment recorded'), findsOneWidget);
  });
  testWidgets(
    'percentage discount requires a reason and submits the reduced payment',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      await tap(tester, 'First-time customer');
      await enter(tester, 'Customer name', 'Discount Customer');
      await enter(tester, 'Quantity', '2');
      await tap(tester, 'Apply a discount');
      await enter(tester, 'Discount percentage', '10');
      await enter(tester, 'Amount applied to sale (USD)', '22.50');
      await tap(tester, 'I confirm the full payment has been received.');
      await tap(tester, 'Record sale and payment');
      expect(submitted, isNull);
      await enter(tester, 'Discount reason', 'Regular customer');
      await tap(tester, 'Record sale and payment');
      expect(submitted!['discountType'], 'PERCENTAGE');
      expect(submitted!['discountValue'], '10');
      expect(submitted!['discountReason'], 'Regular customer');
      expect(submitted!['amountPaid'], '22.50');
    },
  );
  test('invoice PDF supports a long multi-page item list', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bytes = await buildSaleInvoice(sale);
    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    await Directory('build/invoice-qa').create(recursive: true);
    await File('build/invoice-qa/walk-in-invoice.pdf').writeAsBytes(bytes);
    final many = Map<String, dynamic>.from(sale);
    many['items'] = List.generate(
      100,
      (i) => {
        'product_name':
            'Feed item ${i + 1} with a longer product description, 50kg bag',
        'quantity': 2,
        'unit_price': 12.5,
        'line_total': 25.0,
      },
    );
    many['total'] = 2500.0;
    many['amount_paid'] = 2500.0;
    await File(
      'build/invoice-qa/multi-page-invoice.pdf',
    ).writeAsBytes(await buildSaleInvoice(many));
  });
}
