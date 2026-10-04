import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../../constants/theme.dart';
import '../../models/models.dart';
import '../../providers/branch_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_booking_provider.dart';

class ChicksTab extends ConsumerStatefulWidget {
  const ChicksTab({super.key});

  @override
  ConsumerState<ChicksTab> createState() => _ChicksTabState();
}

class _ChicksTabState extends ConsumerState<ChicksTab> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '50');
  String _chickType = 'BROILER';
  String? _breed;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(orderBookingStateProvider);
    final branchState = ref.watch(branchStateProvider);
    final selectedBranch = branchState.selectedBranch;
    final optionsForType = bookingState.chickBatches
        .where((option) => option.chickType == _chickType)
        .toList();
    final breeds = optionsForType.map((option) => option.breed).toSet().toList()
      ..sort();
    if (_breed != null && !breeds.contains(_breed)) _breed = null;
    final option = _selectedOption(optionsForType);
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final total = option == null ? 0.0 : option.pricePerChick * quantity;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Order Day-Old Chicks'),
        actions: [
          IconButton(
            tooltip: 'Refresh ordering windows',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(orderBookingStateProvider.notifier).refreshAll(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(orderBookingStateProvider.notifier).refreshAll(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _introCard(),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Chick order details',
                        style: TextStyle(
                          color: AppColors.primaryNavy,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Branch>(
                        value: selectedBranch,
                        decoration: const InputDecoration(
                          labelText: 'Pickup branch',
                          prefixIcon: Icon(Icons.store_outlined),
                        ),
                        items: branchState.branches
                            .where(
                              (branch) =>
                                  branch.collectionEnabled && branch.active,
                            )
                            .map(
                              (branch) => DropdownMenuItem(
                                value: branch,
                                child: Text(branch.name),
                              ),
                            )
                            .toList(),
                        validator: (value) =>
                            value == null ? 'Select a pickup branch' : null,
                        onChanged: bookingState.isSubmitting
                            ? null
                            : (branch) async {
                                if (branch == null) return;
                                setState(() => _breed = null);
                                await ref
                                    .read(branchStateProvider.notifier)
                                    .selectBranch(branch);
                              },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _chickType,
                        decoration: const InputDecoration(
                          labelText: 'Type of chicks',
                          prefixIcon: Icon(Icons.egg_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'BROILER',
                            child: Text('Broiler'),
                          ),
                          DropdownMenuItem(
                            value: 'LAYER',
                            child: Text('Layer'),
                          ),
                        ],
                        onChanged: bookingState.isSubmitting
                            ? null
                            : (value) => setState(() {
                                _chickType = value ?? 'BROILER';
                                _breed = null;
                              }),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _breed,
                        decoration: const InputDecoration(
                          labelText: 'Breed',
                          prefixIcon: Icon(Icons.egg_alt_outlined),
                        ),
                        items: breeds
                            .map(
                              (breed) => DropdownMenuItem(
                                value: breed,
                                child: Text(breed),
                              ),
                            )
                            .toList(),
                        validator: (value) =>
                            value == null ? 'Select a breed' : null,
                        onChanged: breeds.isEmpty || bookingState.isSubmitting
                            ? null
                            : (value) => setState(() => _breed = value),
                      ),
                      if (selectedBranch != null && breeds.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'No open $_chickType ordering batch is available at ${selectedBranch.name}. '
                          'Orders will become available when the next batch is opened.',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Number of chicks',
                          suffixText: 'chicks',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        validator: (value) {
                          final parsed = int.tryParse(value?.trim() ?? '');
                          if (parsed == null || parsed < 1)
                            return 'Enter a valid quantity';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 18),
                      _quoteCard(option, quantity, total),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: bookingState.isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          bookingState.isSubmitting
                              ? 'Placing order…'
                              : 'Place chick order',
                        ),
                        onPressed: option == null || bookingState.isSubmitting
                            ? null
                            : () => _submit(option),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ChickBatch? _selectedOption(List<ChickBatch> options) {
    if (_breed == null) return null;
    for (final option in options) {
      if (option.breed == _breed) return option;
    }
    return null;
  }

  Widget _introCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.primaryNavy.withOpacity(0.05),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: AppColors.primaryNavy),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Choose the chick type, breed, quantity and pickup branch. Your bill and '
            'delivery batch are calculated before you order. Orders placed after a '
            'cutoff automatically join the next open batch.',
            style: TextStyle(
              color: AppColors.primaryNavy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _quoteCard(ChickBatch? option, int quantity, double total) {
    final money = option == null
        ? '—'
        : '${option.currency} ${total.toStringAsFixed(2)}';
    final unit = option == null
        ? 'Select a breed'
        : '${option.currency} ${option.pricePerChick.toStringAsFixed(2)} per chick';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _quoteRow('Unit price', unit),
          const Divider(height: 20),
          _quoteRow('Quantity', quantity > 0 ? '$quantity chicks' : '—'),
          const Divider(height: 20),
          _quoteRow('Total bill', money, emphasize: true),
          if (option != null && option.depositRequired) ...[
            const Divider(height: 20),
            _quoteRow(
              'Deposit due (${option.depositPercentage.toStringAsFixed(option.depositPercentage % 1 == 0 ? 0 : 2)}%)',
              '${option.currency} ${(total * option.depositPercentage / 100).toStringAsFixed(2)}',
              emphasize: true,
            ),
          ],
          if (option != null) ...[
            const Divider(height: 20),
            _quoteRow(
              'Order cutoff',
              DateFormat('d MMM yyyy, HH:mm').format(option.cutoffAt.toLocal()),
            ),
            const SizedBox(height: 8),
            _quoteRow(
              'Expected pickup',
              DateFormat(
                'EEEE, d MMMM yyyy',
              ).format(DateTime.parse(option.deliveryDate)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quoteRow(String label, String value, {bool emphasize = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: AppColors.textLight)),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: emphasize ? AppColors.brandOrange : AppColors.primaryNavy,
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
            fontSize: emphasize ? 17 : 14,
          ),
        ),
      ),
    ],
  );

  Future<void> _submit(ChickBatch option) async {
    if (!_formKey.currentState!.validate()) return;
    final quantity = int.parse(_quantityController.text.trim());
    final receipt = await ref
        .read(orderBookingStateProvider.notifier)
        .bookChicks(
          branchId: option.branchId,
          chickType: option.chickType,
          breed: option.breed,
          quantity: quantity,
        );
    if (!mounted) return;
    if (receipt != null && receipt['depositRequired'] == true) {
      await _showDepositCheckout(receipt);
      return;
    }
    final error = ref.read(orderBookingStateProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: receipt != null ? AppColors.success : AppColors.error,
        content: Text(
          receipt != null
              ? 'Order placed. We will notify you if the batch delivery date changes.'
              : error ?? 'Chick order failed',
        ),
      ),
    );
  }

  Future<void> _showDepositCheckout(Map<String, dynamic> receipt) async {
    String method = 'PAY_ON_APP';
    bool submitting = false;
    final email = ref.read(authStateProvider).customerProfile?.email;
    final canPayOnline = email != null && email.trim().isNotEmpty;
    if (!canPayOnline) method = 'PAY_AT_BRANCH';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 54,
                  color: AppColors.brandOrange,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pay chick order deposit',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order number: ${receipt['reference']}',
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${receipt['currency']} ${receipt['depositAmount']} deposit required',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.brandOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                RadioListTile<String>(
                  value: 'PAY_ON_APP',
                  groupValue: method,
                  title: const Text('Pay deposit online'),
                  subtitle: const Text('Paynow will send a payment prompt.'),
                  onChanged: canPayOnline && !submitting
                      ? (value) => setSheetState(() => method = value!)
                      : null,
                ),
                if (!canPayOnline)
                  const Text(
                    'Update your email under My Account to enable online payment.',
                    style: TextStyle(
                      color: AppColors.brandOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                RadioListTile<String>(
                  value: 'PAY_AT_BRANCH',
                  groupValue: method,
                  title: const Text('Pay deposit at pickup branch'),
                  subtitle: const Text(
                    'Your chick order is only guaranteed after the deposit is received.',
                    style: TextStyle(
                      color: AppColors.brandOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onChanged: submitting
                      ? null
                      : (value) => setSheetState(() => method = value!),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setSheetState(() => submitting = true);
                          try {
                            final response = await ref
                                .read(apiClientProvider)
                                .dio
                                .post(
                                  '/chicks/bookings/${receipt['id']}/checkout',
                                  data: {'paymentMethod': method},
                                );
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                            final data = Map<String, dynamic>.from(
                              response.data,
                            );
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.success,
                                content: Text('${data['instructions']}'),
                              ),
                            );
                            await ref
                                .read(orderBookingStateProvider.notifier)
                                .refreshAll();
                          } on DioException catch (error) {
                            setSheetState(() => submitting = false);
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.error,
                                  content: Text(error.errorMessage),
                                ),
                              );
                            }
                          }
                        },
                  child: Text(
                    submitting
                        ? 'Processing…'
                        : method == 'PAY_ON_APP'
                        ? 'Pay Deposit'
                        : 'Generate Branch Payment Order',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
