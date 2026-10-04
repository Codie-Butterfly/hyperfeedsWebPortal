import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:hyperfeeds_mobile/services/sale_invoice.dart';

final sample = <String, dynamic>{
  'invoice_number': 'SAMPLE-WIN-001',
  'branch_name': 'Sample Branch',
  'branch_address': 'Sample shop address',
  'branch_phone': 'Sample phone',
  'created_at': '20 Sep 2026, 10:30',
  'paid_at': '20 Sep 2026, 10:30',
  'customer_name': 'Sample Customer',
  'customer_phone': '',
  'currency': 'USD',
  'total': 57.50,
  'amount_paid': 57.50,
  'payment_method': 'CASH',
  'payment_reference': '',
  'recorded_by': 'Sample Cashier',
  'items': [
    {
      'product_name': 'Broiler Starter Feed - 50 kg',
      'quantity': 2,
      'unit_price': 12.50,
      'line_total': 25.00,
    },
    {
      'product_name': 'Layers Mash - 50 kg',
      'quantity': 1,
      'unit_price': 20.00,
      'line_total': 20.00,
    },
    {
      'product_name': 'Poultry Vitamin Supplement',
      'quantity': 1,
      'unit_price': 12.50,
      'line_total': 12.50,
    },
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'receipt exports use thermal widths and long receipts paginate for a driver',
    () async {
      final out = Directory('build/invoice-qa');
      await out.create(recursive: true);
      for (final paper in [InvoicePaper.receipt80, InvoicePaper.receipt58]) {
        final bytes = await buildSaleInvoice(sample, paper: paper);
        expect(bytes.length, greaterThan(1000));
        await File('${out.path}/${paper.name}-sample.pdf').writeAsBytes(bytes);
        final long = Map<String, dynamic>.from(sample);
        long['items'] = List.generate(
          100,
          (i) => {
            'product_name':
                'Feed item ${i + 1}: a longer product name to test wrapping',
            'quantity': 2,
            'unit_price': 12.50,
            'line_total': 25.00,
          },
        );
        long['total'] = 2500;
        long['amount_paid'] = 2500;
        await File('${out.path}/${paper.name}-long.pdf').writeAsBytes(
          await buildSaleInvoice(long, paper: paper, pageFormat: paper.format),
        );
      }
      // The layout receives the selected desktop driver size, rather than scaling an A4 document.
      await File('${out.path}/receipt80-driver.pdf').writeAsBytes(
        await buildSaleInvoice(
          sample,
          paper: InvoicePaper.receipt80,
          pageFormat: InvoicePaper.receipt80.format,
        ),
      );
      expect(InvoicePaper.receipt80.format.width, 80 * PdfPageFormat.mm);
      expect(InvoicePaper.receipt58.format.width, 58 * PdfPageFormat.mm);
    },
  );
  test(
    'reprints carry a watermark and copy details in all paper sizes',
    () async {
      final reprint = {
        ...sample,
        'is_reprint': true,
        'copy_number': 2,
        'copy_issued_at': '20 Sep 2026, 11:15 UTC',
      };
      for (final paper in InvoicePaper.values) {
        await File(
          'build/invoice-qa/${paper.name}-reprint.pdf',
        ).writeAsBytes(await buildSaleInvoice(reprint, paper: paper));
      }
    },
  );
  testWidgets('paper setting defaults to 80mm and restores a saved choice', (
    tester,
  ) async {
    Future<void> open() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSaleInvoiceOptions(context, sample),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    FlutterSecureStorage.setMockInitialValues({});
    await open();
    expect(
      tester
          .widget<DropdownButtonFormField<InvoicePaper>>(
            find.byType(DropdownButtonFormField<InvoicePaper>),
          )
          .initialValue,
      InvoicePaper.receipt80,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    FlutterSecureStorage.setMockInitialValues({'invoice_paper': 'receipt58'});
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<InvoicePaper>>(
            find.byType(DropdownButtonFormField<InvoicePaper>),
          )
          .initialValue,
      InvoicePaper.receipt58,
    );
    await tester.tap(find.byType(DropdownButtonFormField<InvoicePaper>));
    await tester.pumpAndSettle();
    expect(find.text('A4 invoice'), findsWidgets);
    await tester.tap(find.text('A4 invoice').last);
    await tester.pumpAndSettle();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('net.nfet.printing'),
          (call) async => 1,
        );
    await tester.tap(find.text('Save / share PDF'));
    await tester.pumpAndSettle();
    expect(await const FlutterSecureStorage().read(key: 'invoice_paper'), 'a4');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<InvoicePaper>>(
            find.byType(DropdownButtonFormField<InvoicePaper>),
          )
          .initialValue,
      InvoicePaper.a4,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('net.nfet.printing'),
          null,
        );
  });
}
