import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../constants/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/sale_invoice.dart';

class WalkInChickBookingScreen extends ConsumerStatefulWidget {
  final String? bookingId;
  const WalkInChickBookingScreen({super.key, this.bookingId});
  @override
  ConsumerState<WalkInChickBookingScreen> createState() =>
      _WalkInChickBookingState();
}

class _WalkInChickBookingState extends ConsumerState<WalkInChickBookingScreen> {
  final name = TextEditingController(),
      phone = TextEditingController(),
      search = TextEditingController(),
      quantity = TextEditingController(text: '100'),
      payment = TextEditingController(text: '0.00'),
      reference = TextEditingController();
  final form = GlobalKey<FormState>();
  final storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> branches = [], options = [], customers = [];
  Map<String, dynamic>? option, invoice, pending;
  String? branch, customerId, error, pendingKey;
  String method = 'CASH';
  bool busy = true, firstTime = true, confirmed = false;
  Dio get api => ref.read(apiClientProvider).dio;
  double get total =>
      (((option?['pricePerChick'] as num?) ?? 0) *
              (int.tryParse(quantity.text) ?? 0))
          .toDouble();
  double get minimum => option?['depositRequired'] == true
      ? (total * ((option?['depositPercentage'] as num?) ?? 0) / 100 * 100)
                .round() /
            100
      : 0;
  String get currency => option?['currency']?.toString().trim() ?? '';
  ButtonStyle get orange => ElevatedButton.styleFrom(
    backgroundColor: AppColors.brandOrange,
    foregroundColor: AppColors.primaryNavy,
  );
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in [name, phone, search, quantity, payment, reference]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.bookingId != null) {
        invoice = Map<String, dynamic>.from(
          (await api.get(
            '/commerce/walk-in-chick-bookings/${widget.bookingId}/invoice',
          )).data,
        );
      } else {
        final token = await ref.read(secureStorageProvider).getAccessToken();
        final claims =
            jsonDecode(
                  utf8.decode(
                    base64Url.decode(base64Url.normalize(token!.split('.')[1])),
                  ),
                )
                as Map;
        pendingKey = 'walk_in_chick_pending_${claims['sub']}';
        final saved = await storage.read(key: pendingKey!);
        if (saved != null) {
          pending = Map<String, dynamic>.from(jsonDecode(saved));
        }
        branches =
            ((await api.get('/commerce/walk-in-sales/branches')).data as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
        if (branches.length == 1) {
          branch = branches.first['id'].toString();
          await loadOptions();
        }
      }
    } catch (e) {
      error = e is DioException
          ? e.errorMessage
          : 'Unable to load chick bookings. Please try again.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadOptions() async {
    options =
        ((await api.get(
                  '/chicks/availability',
                  queryParameters: {'branchId': branch},
                )).data
                as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    option = null;
    confirmed = false;
  }

  Future<void> chooseBranch(String? value) async {
    setState(() {
      branch = value;
      busy = true;
      error = null;
    });
    try {
      await loadOptions();
    } catch (e) {
      error = e is DioException
          ? e.errorMessage
          : 'Unable to load booking options.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> findCustomers() async {
    if (search.text.trim().length < 2) {
      setState(() => error = 'Enter at least two characters to search.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      customers =
          ((await api.get(
                    '/commerce/walk-in-sales/customers',
                    queryParameters: {'q': search.text.trim()},
                  )).data
                  as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      if (customers.isEmpty) {
        error = 'No matching customers. Choose First-time customer.';
      }
    } catch (e) {
      error = e is DioException ? e.errorMessage : 'Customer search failed.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String requestId() {
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final s = bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  Future<void> save() async {
    if (pending == null) {
      if (!(form.currentState?.validate() ?? false) || option == null) return;
      if (!confirmed) {
        setState(
          () => error = 'Confirm the booking details and any payment received.',
        );
        return;
      }
      pending = {
        'requestId': requestId(),
        'branchId': branch,
        'customerId': customerId,
        'customerName': name.text.trim(),
        'customerPhone': phone.text.trim(),
        'chickType': option!['chickType'],
        'breed': option!['breed'],
        'quantity': int.parse(quantity.text),
        'totalAmount': double.parse(total.toStringAsFixed(2)),
        'amountPaid': double.parse(payment.text),
        'currency': currency,
        'paymentMethod': method,
        'paymentReference': reference.text.trim(),
      };
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await storage.write(key: pendingKey!, value: jsonEncode(pending));
      invoice = Map<String, dynamic>.from(
        (await api.post(
          '/commerce/walk-in-chick-bookings',
          data: pending,
        )).data,
      );
      await storage.delete(key: pendingKey!);
      pending = null;
    } catch (e) {
      error = e is DioException
          ? e.errorMessage
          : 'Unable to confirm the booking. Retry the same booking; do not take payment again.';
      if (e is DioException &&
          [400, 403, 404, 409].contains(e.response?.statusCode)) {
        pending = null;
        await storage.delete(key: pendingKey!);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> printInvoice() async {
    try {
      await showSaleInvoiceOptions(
        context,
        invoice!,
        issueCopy: () async => Map<String, dynamic>.from(
          (await api.post(
            '/commerce/walk-in-chick-bookings/${invoice!['id']}/invoice-copies',
          )).data,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Booking saved. Unable to print; try again.');
      }
    }
  }

  Future<void> payBalance() async {
    if (!confirmed) {
      setState(
        () => error = 'Confirm the remaining payment has been received.',
      );
      return;
    }
    if (method != 'CASH' && reference.text.trim().isEmpty) {
      setState(() => error = 'Enter the external payment reference.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      invoice = Map<String, dynamic>.from(
        (await api.post(
          '/commerce/walk-in-chick-bookings/${invoice!['id']}/balance-payment',
          data: {
            'amount': invoice!['amount_owed'],
            'currency': invoice!['currency'],
            'paymentMethod': method,
            'paymentReference': reference.text.trim(),
          },
        )).data,
      );
      confirmed = false;
    } catch (e) {
      error = e is DioException
          ? e.errorMessage
          : 'Unable to confirm payment. Retry; do not take payment again.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryNavy,
      ),
    ),
  );
  Widget paymentFields() => Column(
    children: [
      DropdownButtonFormField<String>(
        initialValue: method,
        decoration: const InputDecoration(labelText: 'Payment received by'),
        items: const [
          DropdownMenuItem(value: 'CASH', child: Text('Cash')),
          DropdownMenuItem(value: 'CARD', child: Text('Card / POS')),
          DropdownMenuItem(value: 'MOBILE_MONEY', child: Text('Mobile money')),
          DropdownMenuItem(
            value: 'BANK_TRANSFER',
            child: Text('Bank transfer'),
          ),
        ],
        onChanged: (v) => setState(() => method = v!),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: reference,
        maxLength: 120,
        decoration: const InputDecoration(
          labelText: 'External payment reference (optional for cash)',
        ),
        validator: (v) =>
            method != 'CASH' &&
                (double.tryParse(payment.text) ?? 0) > 0 &&
                (v == null || v.trim().isEmpty)
            ? 'Enter payment reference'
            : null,
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Walk-in chick booking')),
    body: busy
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: AppColors.error)),
                TextButton(onPressed: load, child: const Text('Reload')),
              ],
              if (invoice != null) ...[
                const Icon(
                  Icons.egg_alt,
                  color: AppColors.brandOrange,
                  size: 48,
                ),
                heading('Chick booking recorded'),
                Text('${invoice!['reference']} • ${invoice!['customer_name']}'),
                Text('${invoice!['quantity']} ${invoice!['breed']} chicks'),
                Text(
                  'Collection: ${invoice!['delivery_date']} • ${invoice!['branch_name']}',
                ),
                heading('Total: ${invoice!['currency']} ${invoice!['total']}'),
                Text(
                  'Paid: ${invoice!['currency']} ${invoice!['amount_paid']}',
                ),
                Text(
                  'Remaining: ${invoice!['currency']} ${invoice!['amount_owed']}',
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: orange,
                  onPressed: printInvoice,
                  icon: const Icon(Icons.print),
                  label: const Text('Print booking invoice'),
                ),
                if ((invoice!['amount_owed'] as num) > 0 &&
                    invoice!['status'] == 'CONFIRMED') ...[
                  heading('Record remaining payment'),
                  paymentFields(),
                  CheckboxListTile(
                    value: confirmed,
                    onChanged: (v) => setState(() => confirmed = v!),
                    title: Text(
                      'I have received the remaining ${invoice!['currency']} ${invoice!['amount_owed']} outside the app.',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: payBalance,
                    child: const Text('Record balance payment'),
                  ),
                ],
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Back to chick orders'),
                ),
              ] else if (pending != null) ...[
                heading('Confirm previous booking'),
                Text(
                  '${pending!['customerName']} • ${pending!['quantity']} ${pending!['breed']} chicks',
                ),
                const Text(
                  'The previous result is not confirmed. Retry the same booking. Do not take payment again.',
                ),
                ElevatedButton(
                  style: orange,
                  onPressed: save,
                  child: const Text('Retry same booking'),
                ),
              ] else
                Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.brandOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.egg_alt,
                              color: AppColors.brandOrange,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Book chicks for a customer in store',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('No customer account or smartphone required.'),
                          ],
                        ),
                      ),
                      heading('Pickup branch'),
                      if (branches.isEmpty && error == null)
                        const Text(
                          'No branches are available for your account.',
                        ),
                      DropdownButtonFormField<String>(
                        initialValue: branch,
                        decoration: const InputDecoration(
                          labelText: 'Shop branch',
                        ),
                        items: branches
                            .map(
                              (b) => DropdownMenuItem(
                                value: b['id'].toString(),
                                child: Text(b['name'].toString()),
                              ),
                            )
                            .toList(),
                        onChanged: chooseBranch,
                        validator: (v) => v == null ? 'Select a branch' : null,
                      ),
                      heading('Customer'),
                      TextField(
                        controller: search,
                        decoration: const InputDecoration(
                          labelText: 'Find customer by name or phone',
                          prefixIcon: Icon(Icons.person_search),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: findCustomers,
                        child: const Text('Search saved customers'),
                      ),
                      ...customers.map(
                        (c) => ListTile(
                          title: Text(c['name'].toString()),
                          subtitle: Text(
                            c['phone_number']?.toString() ??
                                'No phone recorded',
                          ),
                          onTap: () => setState(() {
                            customerId = c['id'].toString();
                            firstTime = false;
                            name.text = c['name'].toString();
                            phone.text = c['phone_number']?.toString() ?? '';
                            customers = [];
                          }),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          customerId = null;
                          firstTime = true;
                          name.clear();
                          phone.clear();
                        }),
                        icon: const Icon(
                          Icons.person_add,
                          color: AppColors.brandOrange,
                        ),
                        label: const Text('First-time customer'),
                      ),
                      TextFormField(
                        controller: name,
                        readOnly: !firstTime,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Customer name',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter customer name'
                            : null,
                      ),
                      TextFormField(
                        controller: phone,
                        readOnly: !firstTime,
                        maxLength: 32,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Customer phone (optional)',
                        ),
                      ),
                      heading('Chicks'),
                      if (branch != null && options.isEmpty)
                        const Text(
                          'No chick booking window is currently open. Ask your manager to check the booking batch.',
                        ),
                      DropdownButtonFormField<String>(
                        initialValue: option?['id']?.toString(),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Chick type and breed',
                        ),
                        items: options
                            .map(
                              (o) => DropdownMenuItem(
                                value: o['id'].toString(),
                                child: Text(
                                  '${o['chickType']} • ${o['breed']}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          option = options.firstWhere(
                            (o) => o['id'].toString() == v,
                          );
                          payment.text = minimum.toStringAsFixed(2);
                          confirmed = false;
                        }),
                        validator: (v) =>
                            v == null ? 'Select chick type and breed' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: quantity,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Number of chicks',
                        ),
                        onChanged: (_) => setState(() {
                          payment.text = minimum.toStringAsFixed(2);
                          confirmed = false;
                        }),
                        validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1
                            ? 'Enter a whole number greater than zero'
                            : null,
                      ),
                      if (option != null) ...[
                        Text('Collection date: ${option!['deliveryDate']}'),
                        Text('Booking closes: ${option!['cutoffAt']}'),
                        heading('Total: $currency ${total.toStringAsFixed(2)}'),
                        Text(
                          'Minimum deposit: $currency ${minimum.toStringAsFixed(2)}',
                        ),
                      ],
                      heading('Payment received'),
                      const Text(
                        'Take payment using the shop’s usual process. Record the deposit or full payment here. If no deposit is required, you can book without payment.',
                      ),
                      TextFormField(
                        controller: payment,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount received',
                        ),
                        onChanged: (_) => setState(() => confirmed = false),
                        validator: (v) {
                          final a = double.tryParse(v ?? '');
                          return a == null ||
                                  !a.isFinite ||
                                  !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v!) ||
                                  a < minimum ||
                                  a > total
                              ? 'Enter an amount between ${minimum.toStringAsFixed(2)} and ${total.toStringAsFixed(2)}'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      paymentFields(),
                      CheckboxListTile(
                        value: confirmed,
                        onChanged: (v) => setState(() => confirmed = v!),
                        title: const Text(
                          'I confirm the booking details and the payment amount received.',
                        ),
                      ),
                      ElevatedButton.icon(
                        style: orange,
                        onPressed: options.isEmpty ? null : save,
                        icon: const Icon(Icons.egg_alt),
                        label: const Text('Record chick booking'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );
}
