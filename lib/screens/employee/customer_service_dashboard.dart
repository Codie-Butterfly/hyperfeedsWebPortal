import 'staff_scaffold.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/theme.dart';
import '../../providers/auth_provider.dart';
import 'chick_orders_detail.dart';
import 'expert_dashboard.dart';
import 'walk_in_sale_screen.dart';
import '../../services/sale_invoice.dart';
import '../../models/models.dart';

class CustomerServiceDashboard extends ConsumerStatefulWidget {
  final bool embedded;
  const CustomerServiceDashboard({super.key, this.embedded = false});
  @override
  ConsumerState<CustomerServiceDashboard> createState() =>
      _CustomerServiceDashboardState();
}

class _CustomerServiceDashboardState
    extends ConsumerState<CustomerServiceDashboard> {
  final reference = TextEditingController();
  final customerPhone = TextEditingController();
  String status = '';
  List<dynamic> filteredOrders = [];
  Map<String, dynamic>? order;
  bool chickOrder = false;
  bool loading = false;
  String? error;
  int page = 0;

  @override
  void dispose() {
    reference.dispose();
    customerPhone.dispose();
    super.dispose();
  }

  Future<void> _filterOrders() async {
    setState(() {
      loading = true;
      error = null;
      order = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get(
            '/commerce/orders/search',
            queryParameters: {
              if (status.isNotEmpty) 'status': status,
              if (customerPhone.text.trim().isNotEmpty)
                'customerPhone': customerPhone.text.trim(),
            },
          );
      if (mounted) setState(() => filteredOrders = response.data as List);
    } on DioException catch (e) {
      if (mounted) setState(() => error = e.errorMessage);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _search() async {
    if (reference.text.trim().isEmpty) return;
    setState(() {
      loading = true;
      error = null;
      order = null;
    });
    try {
      final isChick = reference.text.trim().toUpperCase().startsWith('CHK-');
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get(
            isChick ? '/chicks/bookings/lookup' : '/commerce/orders/lookup',
            queryParameters: {'reference': reference.text.trim()},
          );
      if (mounted) {
        setState(() {
          chickOrder = isChick;
          order = Map<String, dynamic>.from(response.data);
        });
      }
    } on DioException catch (exception) {
      if (mounted) setState(() => error = exception.errorMessage);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _markChickOrderCollected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm collection'),
        content: Text('Mark ${order!['reference']} as collected?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark collected'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .patch('/management/chicks/orders/${order!['id']}/collected');
      await _search();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Chick order marked as collected.'),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(e.errorMessage),
          ),
        );
      }
    }
  }

  Future<void> _productOrderAction(String action, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: Text('$label for order ${order!['reference']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .patch('/commerce/orders/${order!['id']}/$action');
      await _search();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('$label successfully recorded.'),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(e.errorMessage),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: _content(),
    );
    if (widget.embedded) return content;
    return StaffScaffold(
      appBar: AppBar(
        title: const Text('Customer Service'),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
              context.go('/welcome');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: page == 0
          ? content
          : page == 1
          ? const ChickOrdersDetailScreen(embedded: true)
          : const ExpertDashboard(embedded: true),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (value) => setState(() => page = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.egg_alt), label: 'Chicks'),
          NavigationDestination(icon: Icon(Icons.pets), label: 'Animal Help'),
        ],
      ),
    );
  }

  Future<void> _walkInSale() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const WalkInSaleScreen()));
    if (result != null && mounted) {
      reference.text = result;
      await _search();
    }
  }

  Future<void> _printWalkInInvoice() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/commerce/walk-in-sales/${order!['id']}/invoice');
      if (!mounted) return;
      await showSaleInvoiceOptions(
        context,
        Map<String, dynamic>.from(response.data),
        issueCopy: () async {
          final copy = await ref
              .read(apiClientProvider)
              .dio
              .post('/commerce/walk-in-sales/${order!['id']}/invoice-copies');
          return Map<String, dynamic>.from(copy.data);
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to print invoice. Please try again.'),
          ),
        );
      }
    }
  }

  bool get canSellWalkIn => [
    UserRole.branchManager,
    UserRole.customerService,
  ].contains(ref.watch(authStateProvider).role);

  List<Widget> _content() => [
    if (canSellWalkIn)
      ElevatedButton.icon(
        onPressed: _walkInSale,
        icon: const Icon(Icons.point_of_sale),
        label: const Text('New walk-in sale'),
      ),
    const SizedBox(height: 20),
    const Text(
      'Find customer order',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryNavy,
      ),
    ),
    const SizedBox(height: 8),
    const Text('Enter the order number supplied by the customer.'),
    const SizedBox(height: 16),
    TextField(
      controller: reference,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(
        labelText: 'Order number',
        prefixIcon: Icon(Icons.receipt_long),
      ),
    ),
    const SizedBox(height: 12),
    ElevatedButton(
      onPressed: loading ? null : _search,
      child: Text(loading ? 'Searching…' : 'Search order'),
    ),
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Divider(),
    ),
    const Text(
      'Search feed and medicine orders',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: customerPhone,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(
        labelText: 'Customer phone number',
        prefixIcon: Icon(Icons.phone_outlined),
      ),
    ),
    const SizedBox(height: 10),
    DropdownButtonFormField<String>(
      initialValue: status,
      decoration: const InputDecoration(labelText: 'Order status'),
      items: const [
        DropdownMenuItem(value: '', child: Text('All statuses')),
        DropdownMenuItem(
          value: 'AWAITING_PAYMENT_AT_SHOP',
          child: Text('Awaiting branch payment'),
        ),
        DropdownMenuItem(
          value: 'PAYMENT_PENDING',
          child: Text('Online payment pending'),
        ),
        DropdownMenuItem(value: 'PAID', child: Text('Paid')),
        DropdownMenuItem(value: 'COLLECTED', child: Text('Collected')),
      ],
      onChanged: (value) => setState(() => status = value ?? ''),
    ),
    const SizedBox(height: 10),
    OutlinedButton.icon(
      onPressed: loading ? null : _filterOrders,
      icon: const Icon(Icons.manage_search),
      label: const Text('Search by phone and status'),
    ),
    ...filteredOrders.map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      return Card(
        child: ListTile(
          title: Text('${item['reference']} • ${item['customer_name']}'),
          subtitle: Text(
            '${item['phone_number']}\n${item['status'].toString().replaceAll('_', ' ')}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            reference.text = item['reference'].toString();
            _search();
          },
        ),
      );
    }),
    if (error != null)
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(error!, style: const TextStyle(color: AppColors.error)),
      ),
    if (order != null) ...[
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order!['reference'].toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (!chickOrder || order!['deposit_required'] == true)
                _row(
                  chickOrder ? 'Deposit payment' : 'Payment',
                  chickOrder
                      ? order!['deposit_status']
                      : order!['payment_status'],
                ),
              if (chickOrder && order!['deposit_required'] != true)
                _row('Deposit', 'Not required'),
              _row('Order status', order!['status']),
              if (!chickOrder) _row('Receive by', order!['fulfilment_method']),
              _row('Branch', order!['branch_name']),
              _row(
                'Customer',
                order!['customer_name'] ?? order!['phone_number'],
              ),
              if (canSellWalkIn &&
                  !chickOrder &&
                  order!['sales_channel'] == 'WALK_IN')
                OutlinedButton.icon(
                  onPressed: _printWalkInInvoice,
                  icon: const Icon(Icons.print),
                  label: const Text('Print invoice'),
                ),
              if (chickOrder) ...[
                _row('Chicks', '${order!['quantity']} ${order!['breed']}'),
                _row('Delivery date', order!['delivery_date']),
                _row(
                  'Total price',
                  '${order!['currency']} ${order!['total_amount']}',
                ),
                if (order!['deposit_required'] == true)
                  _row(
                    'Deposit required',
                    '${order!['currency']} ${order!['deposit_amount']}',
                  ),
                _row(
                  'Owed on collection',
                  '${order!['currency']} ${order!['amount_owed']}',
                ),
                if (order!['deposit_required'] == true)
                  _row('Payment method', order!['deposit_payment_method']),
                const SizedBox(height: 10),
                Text(
                  order!['status'] == 'COLLECTED'
                      ? 'This chick order has been collected.'
                      : order!['deposit_required'] != true
                      ? 'No deposit is required. This chick order is guaranteed.'
                      : order!['deposit_paid_at'] == null
                      ? 'This order is not guaranteed until the deposit is paid.'
                      : 'Deposit received. This chick order is guaranteed.',
                  style: TextStyle(
                    color:
                        order!['deposit_required'] == true &&
                            order!['deposit_paid_at'] == null &&
                            order!['status'] != 'COLLECTED'
                        ? AppColors.brandOrange
                        : AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (order!['status'] == 'CONFIRMED' &&
                    order!['collected_at'] == null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _markChickOrderCollected,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark as collected'),
                    ),
                  ),
                ],
              ] else ...[
                _row('Total', '${order!['currency']} ${order!['total']}'),
                const Divider(height: 28),
                const Text(
                  'Items',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...((order!['items'] as List? ?? const []).map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['product_name'].toString()),
                    subtitle: Text('Quantity: ${item['quantity']}'),
                    trailing: Text(
                      '${order!['currency']} ${item['line_total']}',
                    ),
                  ),
                )),
                if (order!['status'] == 'AWAITING_PAYMENT_AT_SHOP') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _productOrderAction(
                        'paid-at-branch',
                        'Record branch payment',
                      ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Record branch payment'),
                    ),
                  ),
                ],
                if (order!['status'] == 'PAID' &&
                    order!['fulfilment_method'] == 'PICKUP') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _productOrderAction('collected', 'Mark as collected'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark as collected'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ],
  ];

  Widget _row(String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textLight),
          ),
        ),
        Text(
          value?.toString().replaceAll('_', ' ') ?? '—',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
