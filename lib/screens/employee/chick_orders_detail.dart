import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/theme.dart';
import '../../models/models.dart';
import 'walk_in_chick_booking_screen.dart';
import '../../providers/auth_provider.dart';

class ChickOrdersDetailScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const ChickOrdersDetailScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ChickOrdersDetailScreen> createState() =>
      _ChickOrdersDetailScreenState();
}

class _ChickOrdersDetailScreenState
    extends ConsumerState<ChickOrdersDetailScreen> {
  List<dynamic> orders = [];
  List<dynamic> batches = [];
  final customerPhone = TextEditingController();
  String status = '';
  String batchId = '';
  DateTime? startDate;
  DateTime? endDate;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _load();
  }

  Future<void> _loadBatches() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/management/chicks/order-batches');
      if (mounted) setState(() => batches = response.data as List);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get(
            '/management/chicks/orders',
            queryParameters: {
              if (status.isNotEmpty) 'status': status,
              if (customerPhone.text.trim().isNotEmpty)
                'customerPhone': customerPhone.text.trim(),
              if (batchId.isNotEmpty) 'batchId': batchId,
              if (startDate != null)
                'startDate': DateFormat('yyyy-MM-dd').format(startDate!),
              if (endDate != null)
                'endDate': DateFormat('yyyy-MM-dd').format(endDate!),
            },
          );
      if (mounted) setState(() => orders = response.data);
    } on DioException catch (e) {
      if (mounted) setState(() => error = e.errorMessage);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: endDate ?? DateTime.now(),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        startDate = selected.start;
        endDate = selected.end;
      });
    }
  }

  @override
  void dispose() {
    customerPhone.dispose();
    super.dispose();
  }

  Future<void> _markPaid(Map<String, dynamic> order) async {
    await _action(order, 'paid-at-branch', 'Mark deposit as paid');
  }

  Future<void> _action(
    Map<String, dynamic> order,
    String action,
    String label,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: Text('$label for ${order['reference']}?'),
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
          .patch('/management/chicks/orders/${order['id']}/$action');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('$label recorded.'),
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

  Map<String, int> get breedTotals {
    final totals = <String, int>{};
    for (final raw in orders) {
      final d = Map<String, dynamic>.from(raw as Map);
      final breed = d['breed']?.toString() ?? 'Unknown breed';
      totals[breed] =
          (totals[breed] ?? 0) + (int.tryParse(d['quantity'].toString()) ?? 0);
    }
    return totals;
  }

  String _date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null ? 'Not set' : DateFormat('d MMM yyyy').format(parsed);
  }

  Future<void> _markCollected(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm collection'),
        content: Text(
          'Mark ${order['reference']} for ${order['customer_name']} as collected?',
        ),
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
          .patch('/management/chicks/orders/${order['id']}/collected');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Chick order marked as collected.'),
        ),
      );
      await _load();
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
    final content = loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                if ([
                  UserRole.branchManager,
                  UserRole.customerService,
                ].contains(ref.watch(authStateProvider).role))
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandOrange,
                      foregroundColor: AppColors.primaryNavy,
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WalkInChickBookingScreen(),
                        ),
                      );
                      if (mounted) await _load();
                    },
                    icon: const Icon(Icons.egg_alt),
                    label: const Text('New walk-in chick booking'),
                  ),
                const SizedBox(height: 12),
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
                  initialValue: batchId,
                  decoration: const InputDecoration(labelText: 'Booking batch'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('All batches'),
                    ),
                    ...batches.map((raw) {
                      final batch = Map<String, dynamic>.from(raw as Map);
                      return DropdownMenuItem<String>(
                        value: batch['id'].toString(),
                        child: Text(
                          '${batch['name']} • ends ${_date(batch['end_date'])}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) => setState(() => batchId = value ?? ''),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Order status'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All statuses')),
                    DropdownMenuItem(
                      value: 'AWAITING_DEPOSIT_AT_BRANCH',
                      child: Text('Awaiting branch payment'),
                    ),
                    DropdownMenuItem(
                      value: 'CONFIRMED',
                      child: Text('Paid / confirmed'),
                    ),
                    DropdownMenuItem(
                      value: 'COLLECTED',
                      child: Text('Collected'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    status = value ?? '';
                    if (status.isNotEmpty && startDate == null) {
                      startDate = DateTime.now().subtract(
                        const Duration(days: 30),
                      );
                      endDate = DateTime.now();
                    }
                  }),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    startDate == null || endDate == null
                        ? 'Any date'
                        : '${DateFormat('d MMM yyyy').format(startDate!)} – ${DateFormat('d MMM yyyy').format(endDate!)}',
                  ),
                ),
                if (startDate != null)
                  TextButton(
                    onPressed: () => setState(() {
                      startDate = null;
                      endDate = null;
                    }),
                    child: const Text('Clear date range'),
                  ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.search),
                  label: const Text('Search chick orders'),
                ),
                const SizedBox(height: 16),
                if (error != null)
                  Text(error!, style: const TextStyle(color: AppColors.error)),
                if (orders.isEmpty && error == null)
                  const SizedBox(
                    height: 500,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.egg_alt_outlined,
                            size: 72,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No chick orders yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (orders.isNotEmpty) ...[
                  const Text(
                    'Totals per breed',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: breedTotals.entries
                        .map(
                          (entry) => Chip(
                            avatar: const Icon(
                              Icons.egg_alt_outlined,
                              size: 18,
                              color: AppColors.brandOrange,
                            ),
                            label: Text('${entry.key}: ${entry.value}'),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  ...orders.map((raw) {
                    final d = Map<String, dynamic>.from(raw as Map);
                    final guaranteed =
                        d['deposit_required'] != true ||
                        d['status'] == 'CONFIRMED' ||
                        d['status'] == 'COLLECTED';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${d['customer_name']}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryNavy,
                                    ),
                                  ),
                                ),
                                Text(
                                  d['status'] == 'COLLECTED'
                                      ? 'COLLECTED'
                                      : guaranteed
                                      ? 'GUARANTEED'
                                      : 'DEPOSIT PENDING',
                                  style: TextStyle(
                                    color: guaranteed
                                        ? AppColors.success
                                        : AppColors.brandOrange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${d['reference']} • ${d['customer_phone']}',
                              style: const TextStyle(
                                color: AppColors.textLight,
                              ),
                            ),
                            const Divider(height: 24),
                            Text(
                              '${d['quantity']} ${d['breed']} chicks',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text('Delivery: ${_date(d['delivery_date'])}'),
                            Text(
                              d['deposit_required'] == true
                                  ? 'Deposit: ${d['currency']} ${d['deposit_amount']} • ${d['deposit_payment_method']?.toString().replaceAll('_', ' ') ?? 'method not selected'}'
                                  : 'No deposit required',
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Total: ${d['currency']} ${d['total_amount']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                            ),
                            if (d['sales_channel'] == 'WALK_IN' &&
                                [
                                  UserRole.branchManager,
                                  UserRole.customerService,
                                ].contains(
                                  ref.watch(authStateProvider).role,
                                )) ...[
                              Text(
                                'Walk-in • Paid: ${d['currency']} ${d['amount_paid']}',
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WalkInChickBookingScreen(
                                        bookingId: d['id'].toString(),
                                      ),
                                    ),
                                  );
                                  if (mounted) await _load();
                                },
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('Invoice / balance payment'),
                              ),
                            ],
                            if (d['status'] == 'CONFIRMED' &&
                                d['collected_at'] == null) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _markCollected(d),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Mark as collected'),
                                ),
                              ),
                            ],
                            if (d['status'] ==
                                'AWAITING_DEPOSIT_AT_BRANCH') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _markPaid(d),
                                  icon: const Icon(Icons.payments_outlined),
                                  label: const Text('Mark deposit as paid'),
                                ),
                              ),
                            ],
                            if (d['status'] == 'COLLECTED')
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: AppColors.success,
                                    ),
                                    SizedBox(width: 7),
                                    Text(
                                      'Collected',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Chick Orders')),
      body: content,
    );
  }
}
