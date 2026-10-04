import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../providers/auth_provider.dart';
import '../../constants/theme.dart';
import '../../services/sale_invoice.dart';

class WalkInSaleScreen extends ConsumerStatefulWidget {
  const WalkInSaleScreen({super.key});
  @override
  ConsumerState<WalkInSaleScreen> createState() => _WalkInSaleScreenState();
}

class _WalkInSaleScreenState extends ConsumerState<WalkInSaleScreen> {
  final name = TextEditingController(),
      phone = TextEditingController(),
      paymentRef = TextEditingController(),
      amount = TextEditingController();
  final discountValue = TextEditingController(),
      discountReason = TextEditingController();
  bool discountEnabled = false;
  String discountType = 'PERCENTAGE';
  final form = GlobalKey<FormState>();
  final customerSearch = TextEditingController();
  List<Map<String, dynamic>> customerMatches = [];
  String? customerId;
  bool newCustomer = false,
      searchingCustomers = false,
      searchedCustomers = false;
  final quantities = <String, TextEditingController>{};
  List<Map<String, dynamic>> branches = [], products = [];
  String? branchId, error, pendingKey;
  String paymentMethod = 'CASH', search = '';
  bool busy = true, confirmed = false;
  Map<String, dynamic>? pending, invoice;
  static const storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in [
      discountValue,
      discountReason,
      name,
      phone,
      paymentRef,
      amount,
      customerSearch,
      ...quantities.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final token = await ref.read(secureStorageProvider).getAccessToken();
      final payload =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token!.split('.')[1])),
                ),
              )
              as Map;
      pendingKey = 'walk_in_pending_${payload['sub']}';
      final saved = await storage.read(key: pendingKey!);
      if (saved != null) pending = Map<String, dynamic>.from(jsonDecode(saved));
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/commerce/walk-in-sales/branches');
      branches = (response.data as List)
          .map((b) => Map<String, dynamic>.from(b))
          .toList();
      if (branches.length == 1) {
        branchId = branches.first['id'].toString();
        await loadProducts();
      }
    } catch (e) {
      error = e is DioException
          ? e.errorMessage
          : 'Unable to load walk-in sales. Please try again.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> findCustomers() async {
    if (customerSearch.text.trim().length < 2) {
      setState(
        () => error =
            'Enter at least two characters of the customer name or phone.',
      );
      return;
    }
    setState(() {
      searchingCustomers = true;
      error = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get(
            '/commerce/walk-in-sales/customers',
            queryParameters: {'q': customerSearch.text.trim()},
          );
      if (mounted) {
        setState(() {
          searchedCustomers = true;
          customerMatches = (response.data as List)
              .map((c) => Map<String, dynamic>.from(c))
              .toList();
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => error = e.errorMessage);
    } finally {
      if (mounted) setState(() => searchingCustomers = false);
    }
  }

  Future<void> loadProducts() async {
    final response = await ref
        .read(apiClientProvider)
        .dio
        .get('/catalogue/products', queryParameters: {'branchId': branchId});
    products = (response.data as List)
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
  }

  List<Map<String, dynamic>> get selected =>
      products.where((p) => p['amount'] != null && quantity(p) > 0).toList();
  double quantity(Map<String, dynamic> p) {
    final value = double.tryParse(quantities[p['id']]?.text ?? '') ?? 0;
    return value.isFinite && value >= 0 ? value : 0;
  }

  int lineCents(Map<String, dynamic> p) =>
      ((p['amount'] as num).toDouble() * quantity(p) * 100).round();
  int get subtotalCents => selected.fold(0, (sum, p) => sum + lineCents(p));
  int get discountCents {
    if (!discountEnabled) return 0;
    final value = double.tryParse(discountValue.text) ?? 0;
    if (!value.isFinite || value < 0) return 0;
    return discountType == 'PERCENTAGE'
        ? (subtotalCents * value / 100).round()
        : (value * 100).round();
  }

  int get totalCents => (subtotalCents - discountCents).clamp(0, subtotalCents);
  String get currency =>
      selected.isEmpty ? '' : selected.first['currency'].toString().trim();

  Future<void> changeBranch(String? id) async {
    setState(() {
      busy = true;
      branchId = id;
      products = [];
      error = null;
      confirmed = false;
      amount.clear();
    });
    for (final c in quantities.values) {
      c.dispose();
    }
    quantities.clear();
    try {
      await loadProducts();
    } on DioException catch (e) {
      error = e.errorMessage;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String requestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> save() async {
    if (pending == null) {
      if (!form.currentState!.validate()) return;
      if (!newCustomer && customerId == null) {
        setState(
          () => error =
              'Select a returning customer or choose First-time customer.',
        );
        return;
      }
      if (branchId == null || selected.isEmpty) {
        setState(() => error = 'Select a branch and at least one item.');
        return;
      }
      if (selected.map((p) => p['currency'].toString().trim()).toSet().length !=
          1) {
        setState(() => error = 'Select items with the same currency.');
        return;
      }
      if (!confirmed) {
        setState(
          () => error = 'Confirm that you have received the full payment.',
        );
        return;
      }
      pending = {
        'requestId': requestId(),
        'branchId': branchId,
        'customerId': customerId,
        'customerName': name.text.trim(),
        'customerPhone': phone.text.trim(),
        'items': selected
            .map((p) => {'productId': p['id'], 'quantity': quantity(p)})
            .toList(),
        'paymentMethod': paymentMethod,
        'paymentReference': paymentRef.text.trim(),
        'amountPaid': amount.text.trim(),
        'currency': currency,
        'discountType': discountEnabled ? discountType : 'NONE',
        'discountValue': discountEnabled ? discountValue.text.trim() : '0',
        'discountReason': discountEnabled ? discountReason.text.trim() : null,
      };
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Save before sending so app restarts can retry the same request safely.
      await storage.write(key: pendingKey!, value: jsonEncode(pending));
      final response = await ref
          .read(apiClientProvider)
          .dio
          .post('/commerce/walk-in-sales', data: pending);
      invoice = Map<String, dynamic>.from(response.data);
      await storage.delete(key: pendingKey!);
      pending = null;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 403 || status == 409) {
        await storage.delete(key: pendingKey!);
        pending = null;
        confirmed = false;
      }
      error = e.errorMessage;
    } catch (_) {
      error =
          'Unable to complete the record. Retry this sale to check its status safely.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> printInvoice() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await showSaleInvoiceOptions(
        context,
        invoice!,
        issueCopy: () async {
          final response = await ref
              .read(apiClientProvider)
              .dio
              .post('/commerce/walk-in-sales/${invoice!['id']}/invoice-copies');
          return Map<String, dynamic>.from(response.data);
        },
      );
    } catch (_) {
      error =
          'Sale saved. Printing could not start; try printing again from this screen or Orders.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Walk-in sale'),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(4),
        child: SizedBox(
          height: 4,
          child: ColoredBox(
            color: AppColors.brandOrange,
            child: SizedBox.expand(),
          ),
        ),
      ),
    ),
    body: busy
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (invoice != null) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 56),
                const Text(
                  'Sale and payment recorded',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text('Order: ${invoice!['reference']}'),
                Text('Customer: ${invoice!['customer_name']}'),
                Text('Paid: ${invoice!['currency']} ${invoice!['total']}'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: AppColors.primaryNavy,
                  ),
                  onPressed: printInvoice,
                  icon: const Icon(Icons.print),
                  label: const Text('Print invoice'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(context, invoice!['reference']),
                  child: const Text('Back to orders'),
                ),
              ] else if (pending != null) ...[
                const Text(
                  'Complete previous sale',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text('Customer: ${pending!['customerName']}'),
                Text(
                  'Payment: ${pending!['currency']} ${pending!['amountPaid']}',
                ),
                const Text(
                  'The previous result was not confirmed. Retry to retrieve or record this same sale. Do not take payment again.',
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: save,
                  child: const Text('Retry same sale'),
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
                          color: AppColors.brandOrange.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: const Border(
                            left: BorderSide(
                              color: AppColors.brandOrange,
                              width: 4,
                            ),
                          ),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.storefront,
                              color: AppColors.brandOrange,
                              size: 30,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Help a customer buy in store',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text('No customer account or smartphone required.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (branches.isEmpty) ...[
                        const Text(
                          'No branches are available. Ask an administrator to check your branch access.',
                        ),
                        OutlinedButton(
                          onPressed: () {
                            setState(() => busy = true);
                            load();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                      DropdownButtonFormField<String>(
                        initialValue: branchId,
                        isExpanded: true,
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
                        onChanged: changeBranch,
                        validator: (v) => v == null ? 'Select a branch' : null,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Customer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextField(
                        controller: customerSearch,
                        decoration: const InputDecoration(
                          labelText: 'Find customer by name or phone',
                          prefixIcon: Icon(Icons.person_search),
                        ),
                        onSubmitted: (_) => findCustomers(),
                      ),
                      OutlinedButton.icon(
                        onPressed: searchingCustomers ? null : findCustomers,
                        icon: const Icon(Icons.search),
                        label: Text(
                          searchingCustomers
                              ? 'Searching…'
                              : 'Search customers',
                        ),
                      ),
                      if (searchedCustomers && customerMatches.isEmpty)
                        const Text(
                          'No matching customers. Choose First-time customer to add them.',
                        ),
                      ...customerMatches.map(
                        (c) => ListTile(
                          title: Text(c['name'].toString()),
                          subtitle: Text(
                            c['phone_number']?.toString() ??
                                'No phone recorded',
                          ),
                          trailing: customerId == c['id']
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : null,
                          onTap: () => setState(() {
                            customerId = c['id'].toString();
                            newCustomer = false;
                            name.text = c['name'].toString();
                            phone.text = c['phone_number']?.toString() ?? '';
                            confirmed = false;
                          }),
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.brandOrange.withValues(
                            alpha: 0.10,
                          ),
                          side: const BorderSide(color: AppColors.brandOrange),
                        ),
                        onPressed: () => setState(() {
                          customerId = null;
                          newCustomer = true;
                          name.clear();
                          phone.clear();
                          confirmed = false;
                        }),
                        icon: const Icon(Icons.person_add),
                        label: const Text('First-time customer'),
                      ),
                      if (newCustomer)
                        const Text(
                          'This customer will be saved when the sale is recorded.',
                        ),
                      if (customerId != null)
                        const Text(
                          'Returning customer selected. Details will be reused.',
                        ),
                      TextFormField(
                        readOnly: !newCustomer,
                        controller: name,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Customer name',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter the customer name'
                            : null,
                      ),
                      TextFormField(
                        readOnly: !newCustomer,
                        controller: phone,
                        maxLength: 32,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Customer phone (optional)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search by item name or code',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) =>
                            setState(() => search = v.toLowerCase()),
                      ),
                      const SizedBox(height: 12),
                      if (branchId != null && products.isEmpty)
                        const Text('No products available for this branch.'),
                      ...products
                          .where(
                            (p) => '${p['name']} ${p['sku']}'
                                .toLowerCase()
                                .contains(search),
                          )
                          .map((p) {
                            final available =
                                (p['available'] as num?)?.toDouble() ?? 0;
                            final priced = p['amount'] != null;
                            final controller = quantities.putIfAbsent(
                              p['id'].toString(),
                              () => TextEditingController(),
                            );
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['name'].toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${p['packSize']} • Available: $available',
                                          ),
                                          Text(
                                            priced
                                                ? '${p['currency']} ${p['amount']}'
                                                : 'Price unavailable',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 90,
                                      child: TextFormField(
                                        controller: controller,
                                        enabled: priced && available > 0,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Quantity',
                                        ),
                                        onChanged: (_) => setState(() {
                                          confirmed = false;
                                        }),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return null;
                                          }
                                          final q = double.tryParse(v);
                                          if (q == null ||
                                              !q.isFinite ||
                                              q < 0 ||
                                              !RegExp(
                                                r'^\d+(\.\d{1,3})?$',
                                              ).hasMatch(v)) {
                                            return 'Invalid quantity';
                                          }
                                          if (q > available) {
                                            return 'Exceeds stock';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      const SizedBox(height: 16),
                      const Text(
                        'Selected items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ...selected.map(
                        (p) => Text(
                          '${p['name']} × ${quantity(p)} — ${p['currency']} ${(lineCents(p) / 100).toStringAsFixed(2)}',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: AppColors.brandOrange,
                        title: const Text('Apply a discount'),
                        subtitle: const Text(
                          'Recorded on this sale and invoice',
                        ),
                        value: discountEnabled,
                        onChanged: (v) => setState(() {
                          discountEnabled = v;
                          confirmed = false;
                        }),
                      ),
                      if (discountEnabled) ...[
                        DropdownButtonFormField<String>(
                          initialValue: discountType,
                          decoration: const InputDecoration(
                            labelText: 'Discount type',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'PERCENTAGE',
                              child: Text('Percentage (%)'),
                            ),
                            DropdownMenuItem(
                              value: 'FIXED',
                              child: Text('Fixed amount'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            discountType = v!;
                            confirmed = false;
                          }),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: discountValue,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: discountType == 'PERCENTAGE'
                                ? 'Discount percentage'
                                : 'Discount amount ($currency)',
                          ),
                          onChanged: (_) => setState(() => confirmed = false),
                          validator: (v) {
                            final value = double.tryParse(v ?? '');
                            if (value == null ||
                                !value.isFinite ||
                                value <= 0 ||
                                !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v!)) {
                              return 'Enter a positive discount with up to two decimals';
                            }
                            if (discountType == 'PERCENTAGE' && value > 100) {
                              return 'Maximum discount is 100%';
                            }
                            if (discountCents > subtotalCents) {
                              return 'Discount cannot exceed the subtotal';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: discountReason,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            labelText: 'Discount reason',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Enter the reason for this discount'
                              : null,
                        ),
                        Text(
                          'Subtotal: $currency ${(subtotalCents / 100).toStringAsFixed(2)}',
                        ),
                        Text(
                          'Discount: -$currency ${(discountCents / 100).toStringAsFixed(2)}',
                        ),
                      ],
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.brandOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Total: $currency ${(totalCents / 100).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Payment received',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Take payment using the shop’s usual payment process, then record it here.',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment method',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                          DropdownMenuItem(
                            value: 'CARD',
                            child: Text('Card / POS'),
                          ),
                          DropdownMenuItem(
                            value: 'MOBILE_MONEY',
                            child: Text('Mobile money'),
                          ),
                          DropdownMenuItem(
                            value: 'BANK_TRANSFER',
                            child: Text('Bank transfer'),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          paymentMethod = v!;
                          confirmed = false;
                        }),
                      ),
                      TextFormField(
                        controller: paymentRef,
                        maxLength: 120,
                        decoration: InputDecoration(
                          labelText: paymentMethod == 'CASH'
                              ? 'Receipt reference (optional)'
                              : 'Payment reference',
                        ),
                        validator: (v) =>
                            paymentMethod != 'CASH' &&
                                (v == null || v.trim().isEmpty)
                            ? 'Enter the payment reference'
                            : null,
                      ),
                      TextFormField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Amount applied to sale ($currency)',
                        ),
                        onChanged: (_) => setState(() => confirmed = false),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null ||
                              !n.isFinite ||
                              !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v!) ||
                              (n * 100).round() != totalCents) {
                            return 'Enter the full sale total';
                          }
                          return null;
                        },
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: confirmed,
                        onChanged: (v) => setState(() => confirmed = v!),
                        title: const Text(
                          'I confirm the full payment has been received.',
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandOrange,
                          foregroundColor: AppColors.primaryNavy,
                        ),
                        onPressed: save,
                        icon: const Icon(Icons.save),
                        label: const Text('Record sale and payment'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );
}
