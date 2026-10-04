import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum InvoicePaper { receipt80, receipt58, a4 }

extension InvoicePaperDetails on InvoicePaper {
  String get label => switch (this) {
    InvoicePaper.receipt80 => '80 mm receipt',
    InvoicePaper.receipt58 => '58 mm receipt',
    InvoicePaper.a4 => 'A4 invoice',
  };
  PdfPageFormat get format => switch (this) {
    InvoicePaper.receipt80 => const PdfPageFormat(
      80 * PdfPageFormat.mm,
      200 * PdfPageFormat.mm,
      marginAll: 4 * PdfPageFormat.mm,
    ),
    InvoicePaper.receipt58 => const PdfPageFormat(
      58 * PdfPageFormat.mm,
      200 * PdfPageFormat.mm,
      marginAll: 4 * PdfPageFormat.mm,
    ),
    InvoicePaper.a4 => PdfPageFormat.a4,
  };
}

bool _isReprint(Map<String, dynamic> sale) => sale['is_reprint'] == true;

pw.PageTheme _invoiceTheme(
  Map<String, dynamic> sale,
  PdfPageFormat format, {
  pw.EdgeInsets? margin,
  pw.ThemeData? theme,
  double watermarkSize = 32,
}) => pw.PageTheme(
  pageFormat: format,
  margin: margin,
  theme: theme,
  buildBackground: _isReprint(sale)
      ? (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.max,
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: List.generate(
              (context.page.pageFormat.height / (watermarkSize * 3))
                  .floor()
                  .clamp(3, 1000),
              (_) => pw.Center(
                child: pw.Transform.rotate(
                  angle: 0.55,
                  child: pw.Text(
                    'REPRINT',
                    style: pw.TextStyle(
                      fontSize: watermarkSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey300,
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
      : null,
);

List<pw.Widget> _reprintLabel(
  Map<String, dynamic> sale, {
  double fontSize = 10,
}) => !_isReprint(sale)
    ? []
    : [
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            'REPRINT',
            style: pw.TextStyle(
              fontSize: fontSize + 2,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        if (sale['copy_number'] != null)
          pw.Text(
            'Copy number: ${sale['copy_number']}',
            style: pw.TextStyle(fontSize: fontSize),
          ),
        pw.Text(
          'Reprinted: ${sale['copy_issued_at'] ?? ''}',
          style: pw.TextStyle(fontSize: fontSize),
        ),
        pw.SizedBox(height: 6),
      ];

Future<Uint8List> buildSaleInvoice(
  Map<String, dynamic> sale, {
  InvoicePaper paper = InvoicePaper.a4,
  PdfPageFormat? pageFormat,
}) async {
  if (paper != InvoicePaper.a4) {
    return _buildReceipt(sale, paper, pageFormat);
  }
  final document = pw.Document();
  final logo = pw.MemoryImage(
    (await rootBundle.load(
      'assets/images/hyperfeeds_logo.png',
    )).buffer.asUint8List(),
  );
  String text(String key) => sale[key]?.toString() ?? '';
  String money(dynamic value) =>
      (num.tryParse(value.toString()) ?? 0).toStringAsFixed(2);
  final currency = text('currency');
  document.addPage(
    pw.MultiPage(
      pageTheme: _invoiceTheme(
        sale,
        pageFormat ?? PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        watermarkSize: 70,
      ),
      header: (_) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Image(logo, width: 120, height: 55, fit: pw.BoxFit.contain),
          pw.Text(
            'INVOICE - PAID',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      build: (_) => [
        ..._reprintLabel(sale),
        pw.SizedBox(height: 20),
        pw.Text(
          text('branch_name'),
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(text('branch_address')),
        pw.Text('Phone: ${text('branch_phone')}'),
        pw.SizedBox(height: 16),
        pw.Text('Invoice / Order: ${text('invoice_number')}'),
        pw.Text('Date: ${text('created_at')}'),
        pw.SizedBox(height: 12),
        pw.Text('Customer: ${text('customer_name')}'),
        if (text('customer_phone').isNotEmpty)
          pw.Text('Phone: ${text('customer_phone')}'),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: [
            'Item',
            'Qty',
            'Unit price ($currency)',
            'Total ($currency)',
          ],
          data: (sale['items'] as List)
              .map(
                (item) => [
                  item['product_name'],
                  item['quantity'].toString(),
                  money(item['unit_price']),
                  money(item['line_total']),
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColors.blueGrey800,
          ),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
        ),
        pw.SizedBox(height: 18),
        if ((num.tryParse(text('discount_amount')) ?? 0) > 0) ...[
          pw.Text('Subtotal: $currency ${money(sale['subtotal'])}'),
          pw.Text('Discount: -$currency ${money(sale['discount_amount'])}'),
          pw.Text('Reason: ${text('discount_reason')}'),
        ],
        pw.Text(
          'Total: $currency ${money(sale['total'])}',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('Amount paid: $currency ${money(sale['amount_paid'])}'),
        pw.Text(
          'Balance: $currency ${money((num.tryParse(text('total')) ?? 0) - (num.tryParse(text('amount_paid')) ?? 0))}',
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Payment method: ${text('payment_method').replaceAll('_', ' ')}',
        ),
        if (text('payment_reference').isNotEmpty)
          pw.Text('Payment reference: ${text('payment_reference')}'),
        pw.Text('Payment recorded: ${text('paid_at')}'),
        pw.Text('Recorded by: ${text('recorded_by')}'),
        pw.SizedBox(height: 20),
        pw.Text('Thank you for shopping with Hyperfeeds.'),
      ],
    ),
  );
  return document.save();
}

Future<Uint8List> _buildReceipt(
  Map<String, dynamic> sale,
  InvoicePaper paper,
  PdfPageFormat? pageFormat,
) async {
  final document = pw.Document();
  final logo = pw.MemoryImage(
    (await rootBundle.load(
      'assets/images/hyperfeeds_logo.png',
    )).buffer.asUint8List(),
  );
  String text(String key) => sale[key]?.toString() ?? '';
  String money(dynamic value) =>
      (num.tryParse(value.toString()) ?? 0).toStringAsFixed(2);
  final narrow = paper == InvoicePaper.receipt58;
  final style = pw.TextStyle(fontSize: narrow ? 8 : 9);
  final bold = pw.TextStyle(
    fontSize: narrow ? 9 : 10,
    fontWeight: pw.FontWeight.bold,
  );
  pw.Widget amountRow(String label, dynamic value, {bool emphasis = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(child: pw.Text(label, style: emphasis ? bold : style)),
            pw.SizedBox(width: 6),
            pw.Text(money(value), style: emphasis ? bold : style),
          ],
        ),
      );
  final contents = <pw.Widget>[
    pw.Center(
      child: pw.Image(
        logo,
        width: (narrow ? 46 : 64) * PdfPageFormat.mm,
        height: (narrow ? 20 : 26) * PdfPageFormat.mm,
        fit: pw.BoxFit.contain,
      ),
    ),
    pw.SizedBox(height: 5),
    pw.Center(
      child: pw.Text(text('branch_name'), textAlign: pw.TextAlign.center),
    ),
    pw.Center(
      child: pw.Text(text('branch_address'), textAlign: pw.TextAlign.center),
    ),
    pw.Center(
      child: pw.Text(
        'Tel: ${text('branch_phone')}',
        textAlign: pw.TextAlign.center,
      ),
    ),
    pw.Divider(),
    pw.Center(child: pw.Text('INVOICE - PAID', style: bold)),
    ..._reprintLabel(sale, fontSize: narrow ? 8 : 9),
    pw.SizedBox(height: 6),
    pw.Text('Invoice / Order:'),
    pw.Text(text('invoice_number'), style: bold),
    pw.Text('Date: ${text('created_at')}'),
    pw.SizedBox(height: 6),
    pw.Text('Customer: ${text('customer_name')}'),
    if (text('customer_phone').isNotEmpty)
      pw.Text('Phone: ${text('customer_phone')}'),
    pw.Divider(),
    pw.Text('ITEM / QTY x UNIT PRICE', style: bold),
    pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('AMOUNT (${text('currency')})', style: bold),
    ),
    pw.SizedBox(height: 5),
    ...(sale['items'] as List).map(
      (item) => pw.Inseparable(
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 7),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(item['product_name'].toString(), style: bold),
              amountRow(
                '${item['quantity']} x ${money(item['unit_price'])}',
                item['line_total'],
              ),
            ],
          ),
        ),
      ),
    ),
    pw.Divider(),
    if ((num.tryParse(text('discount_amount')) ?? 0) > 0) ...[
      amountRow('Subtotal', sale['subtotal']),
      amountRow('Discount', -(num.tryParse(text('discount_amount')) ?? 0)),
      pw.Text('Reason: ${text('discount_reason')}'),
    ],
    amountRow('TOTAL ${text('currency')}', sale['total'], emphasis: true),
    amountRow('Paid', sale['amount_paid']),
    amountRow(
      'Balance',
      (num.tryParse(text('total')) ?? 0) -
          (num.tryParse(text('amount_paid')) ?? 0),
    ),
    pw.Divider(),
    pw.Text('Payment: ${text('payment_method').replaceAll('_', ' ')}'),
    if (text('payment_reference').isNotEmpty)
      pw.Text('Reference: ${text('payment_reference')}'),
    pw.Text('Recorded by: ${text('recorded_by')}'),
    pw.Text('Recorded: ${text('paid_at')}'),
    pw.SizedBox(height: 12),
    pw.Center(
      child: pw.Text(
        'Thank you for shopping\nwith Hyperfeeds.',
        textAlign: pw.TextAlign.center,
      ),
    ),
  ];
  // Export a receipt of exactly the required length. For printing, honour the
  // finite paper size supplied by the desktop driver and paginate long sales.
  final theme = pw.ThemeData.withFont().copyWith(defaultTextStyle: style);
  if (pageFormat == null) {
    document.addPage(
      pw.Page(
        pageTheme: _invoiceTheme(
          sale,
          PdfPageFormat(
            paper.format.width,
            double.infinity,
            marginAll: 4 * PdfPageFormat.mm,
          ),
          theme: theme,
          watermarkSize: narrow ? 24 : 32,
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: contents,
        ),
      ),
    );
  } else {
    document.addPage(
      pw.MultiPage(
        pageTheme: _invoiceTheme(
          sale,
          pageFormat,
          theme: theme,
          watermarkSize: narrow ? 24 : 32,
        ),
        maxPages: 200,
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 5),
          child: pw.Text(
            'Page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7),
          ),
        ),
        build: (_) => contents,
      ),
    );
  }
  return document.save();
}

Future<void> printSaleInvoice(
  Map<String, dynamic> sale, {
  InvoicePaper paper = InvoicePaper.receipt80,
}) async {
  await Printing.layoutPdf(
    name: 'Invoice-${sale['invoice_number']}',
    format: paper.format,
    onLayout: (format) =>
        buildSaleInvoice(sale, paper: paper, pageFormat: format),
  );
}

Future<void> showSaleInvoiceOptions(
  BuildContext context,
  Map<String, dynamic> sale, {
  Future<Map<String, dynamic>> Function()? issueCopy,
}) async {
  const storage = FlutterSecureStorage();
  String? saved;
  try {
    saved = await storage.read(key: 'invoice_paper');
  } catch (_) {
    /* Use default when storage is unavailable. */
  }
  if (!context.mounted) return;
  var preferred = InvoicePaper.receipt80;
  for (final option in InvoicePaper.values) {
    if (option.name == saved) preferred = option;
  }
  final choice = await showDialog<({InvoicePaper paper, bool save})>(
    context: context,
    builder: (dialogContext) {
      var paper = preferred;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Print invoice'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose the paper used by your printer. This device remembers your choice.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<InvoicePaper>(
                initialValue: paper,
                isExpanded: true,
                items: InvoicePaper.values
                    .map(
                      (p) => DropdownMenuItem(value: p, child: Text(p.label)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => paper = value!),
              ),
              const SizedBox(height: 12),
              const Text(
                'For a printer connected to a desktop, print on that computer or save the PDF and open it there.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (paper: paper, save: true)),
              child: const Text('Save / share PDF'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (paper: paper, save: false)),
              child: const Text('Print'),
            ),
          ],
        ),
      );
    },
  );
  if (choice == null) return;
  try {
    await storage.write(key: 'invoice_paper', value: choice.paper.name);
  } catch (_) {
    /* Printing can continue without saving the preference. */
  }
  final issuedSale = issueCopy == null ? sale : await issueCopy();
  if (choice.save) {
    await Printing.sharePdf(
      bytes: await buildSaleInvoice(issuedSale, paper: choice.paper),
      filename: 'Invoice-${sale['invoice_number']}.pdf',
    );
  } else {
    await printSaleInvoice(issuedSale, paper: choice.paper);
  }
}
