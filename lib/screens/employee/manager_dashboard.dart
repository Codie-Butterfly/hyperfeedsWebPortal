import 'staff_scaffold.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/branch_provider.dart';
import 'package:dio/dio.dart';
import 'advertising_launcher.dart';
import 'chick_orders_detail.dart';
import 'customer_service_dashboard.dart';
import 'expert_dashboard.dart';

class ManagerDashboard extends ConsumerStatefulWidget {
  const ManagerDashboard({super.key});

  @override
  ConsumerState<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _StockRequestDialog extends ConsumerStatefulWidget {
  final String branchId;
  final Product product;
  const _StockRequestDialog({required this.branchId, required this.product});
  @override
  ConsumerState<_StockRequestDialog> createState() =>
      _StockRequestDialogState();
}

class _StockRequestDialogState extends ConsumerState<_StockRequestDialog> {
  final quantity = TextEditingController(), note = TextEditingController();
  bool busy = false;
  Future<void> submit() async {
    setState(() => busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post(
            '/management/stock-requests',
            data: {
              'branchId': widget.branchId,
              'productId': widget.product.id,
              'quantity': double.parse(quantity.text),
              'note': note.text,
            },
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock request sent to the main manager'),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: Text('Request ${widget.product.name}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: quantity,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity required'),
        ),
        TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason / note'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: busy ? null : submit,
        child: const Text('Send request'),
      ),
    ],
  );
}

class _BranchNotificationDialog extends ConsumerStatefulWidget {
  final Branch branch;
  const _BranchNotificationDialog({required this.branch});
  @override
  ConsumerState<_BranchNotificationDialog> createState() =>
      _BranchNotificationDialogState();
}

class _BranchNotificationDialogState
    extends ConsumerState<_BranchNotificationDialog> {
  final title = TextEditingController(), body = TextEditingController();
  bool busy = false;
  Future<void> send() async {
    setState(() => busy = true);
    try {
      final r = await ref
          .read(apiClientProvider)
          .dio
          .post(
            '/management/notifications',
            data: {
              'audience': 'CUSTOMERS',
              'branchId': widget.branch.id,
              'title': title.text,
              'body': body.text,
            },
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent to ${r.data} branch customers')),
        );
      }
    } on DioException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: Text('Notify ${widget.branch.name} customers'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        TextField(
          controller: body,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Cancel'),
      ),
      ElevatedButton(onPressed: busy ? null : send, child: const Text('Send')),
    ],
  );
}

class _ManagerDashboardState extends ConsumerState<ManagerDashboard> {
  Branch? _selectedBranch;
  Set<String>? _assignedBranchIds;
  int page = 0;

  @override
  void initState() {
    super.initState();
    _loadAssignedBranches();
  }

  Future<void> _loadAssignedBranches() async {
    final token = await ref.read(secureStorageProvider).getAccessToken();
    final ids = <String>{};
    if (token != null) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload =
              jsonDecode(
                    utf8.decode(
                      base64Url.decode(base64Url.normalize(parts[1])),
                    ),
                  )
                  as Map<String, dynamic>;
          ids.addAll(
            (payload['branch_ids'] as List? ?? const []).map(
              (id) => id.toString(),
            ),
          );
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _assignedBranchIds = ids);
  }

  @override
  Widget build(BuildContext context) {
    final branchState = ref.watch(branchStateProvider);
    final branches = _assignedBranchIds == null
        ? <Branch>[]
        : branchState.branches
              .where((branch) => _assignedBranchIds!.contains(branch.id))
              .toList();
    if (_selectedBranch != null &&
        !branches.any((branch) => branch.id == _selectedBranch!.id)) {
      _selectedBranch = null;
    }
    if (_selectedBranch == null && branches.isNotEmpty) {
      _selectedBranch = branches.first;
    }

    return StaffScaffold(
      appBar: AppBar(
        title: const Text('Branch Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
              context.go('/welcome');
            },
          ),
        ],
      ),
      body: page == 0
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Branch selector dropdown
                  DropdownButtonFormField<Branch>(
                    value: _selectedBranch,
                    hint: const Text('Select Managed Branch'),
                    items: branches.map((b) {
                      return DropdownMenuItem<Branch>(
                        value: b,
                        child: Text(b.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBranch = val;
                      });
                    },
                  ),
                  const SizedBox(height: 24.0),
                  if (_selectedBranch != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ChickOrdersDetailScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.egg_alt_outlined),
                        label: const Text('View chick orders'),
                      ),
                    ),
                  if (_selectedBranch != null)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => _BranchNotificationDialog(
                                branch: _selectedBranch!,
                              ),
                            ),
                            icon: const Icon(Icons.notifications),
                            label: const Text('Notify customers'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: const Text('Branch advertising'),
                                  ),
                                  body: AdvertisingLauncher(
                                    branches: branches,
                                    fixedBranchId: _selectedBranch!.id,
                                  ),
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.campaign),
                            label: const Text('Launch advert'),
                          ),
                        ),
                      ],
                    ),
                  if (_selectedBranch == null)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Select a branch above to manage inventory and pricing.',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: _ManagerCatalogView(branch: _selectedBranch!),
                    ),
                ],
              ),
            )
          : _page(branches),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (value) => setState(() => page = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Stock'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(icon: Icon(Icons.egg_alt), label: 'Chicks'),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: 'Notify',
          ),
          NavigationDestination(icon: Icon(Icons.campaign), label: 'Adverts'),
          NavigationDestination(icon: Icon(Icons.pets), label: 'Animal Help'),
        ],
      ),
    );
  }

  Widget _page(List<Branch> branches) {
    if (_selectedBranch == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Select your managed branch under Stock first.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return switch (page) {
      1 => const CustomerServiceDashboard(embedded: true),
      2 => const ChickOrdersDetailScreen(embedded: true),
      3 => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (_) =>
                  _BranchNotificationDialog(branch: _selectedBranch!),
            ),
            icon: const Icon(Icons.notifications),
            label: Text('Notify ${_selectedBranch!.name} customers'),
          ),
        ),
      ),
      4 => AdvertisingLauncher(
        branches: branches,
        fixedBranchId: _selectedBranch!.id,
      ),
      5 => const ExpertDashboard(embedded: true),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ManagerCatalogView extends ConsumerStatefulWidget {
  final Branch branch;
  const _ManagerCatalogView({required this.branch});

  @override
  ConsumerState<_ManagerCatalogView> createState() =>
      _ManagerCatalogViewState();
}

class _ManagerCatalogViewState extends ConsumerState<_ManagerCatalogView> {
  List<Product> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void didUpdateWidget(covariant _ManagerCatalogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branch.id != widget.branch.id) {
      _fetchProducts();
    }
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.dio.get(
        '/catalogue/products',
        queryParameters: {'branchId': widget.branch.id},
      );
      if (mounted) {
        final List<dynamic> data = response.data;
        setState(() {
          _products = data.map((json) => Product.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load products: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _editInventory(Product product) {
    showDialog(
      context: context,
      builder: (context) {
        return _InventoryEditDialog(
          branchId: widget.branch.id,
          product: product,
          onSuccess: _fetchProducts,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_products.isEmpty) {
      return const Center(child: Text('No products currently registered.'));
    }

    return ListView.builder(
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final hasPrice = product.amount != null;
        final onHand = product.onHand ?? 0.0;
        final reserved = product.reserved ?? 0.0;
        final available = product.available ?? 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                    Text(
                      product.sku,
                      style: const TextStyle(
                        fontSize: 12.0,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Price Configuration',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          hasPrice
                              ? '${product.currency} ${product.amount!.toStringAsFixed(2)}'
                              : 'Unconfigured',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.0,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Stock levels',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'On-Hand: ${onHand.toStringAsFixed(0)} | Res: ${reserved.toStringAsFixed(0)} | Avail: ${available.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => _StockRequestDialog(
                            branchId: widget.branch.id,
                            product: product,
                          ),
                        ),
                        icon: const Icon(Icons.outbox, size: 18),
                        label: const Text('Request Stock'),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _editInventory(product),
                        icon: const Icon(Icons.warehouse, size: 18),
                        label: const Text('Update Stock'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Dialog to edit Inventory
class _InventoryEditDialog extends ConsumerStatefulWidget {
  final String branchId;
  final Product product;
  final VoidCallback onSuccess;

  const _InventoryEditDialog({
    required this.branchId,
    required this.product,
    required this.onSuccess,
  });

  @override
  ConsumerState<_InventoryEditDialog> createState() =>
      _InventoryEditDialogState();
}

class _InventoryEditDialogState extends ConsumerState<_InventoryEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _onHandController = TextEditingController();
  final _reservedController = TextEditingController();
  final _thresholdController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _onHandController.text = widget.product.onHand?.toStringAsFixed(0) ?? '0';
    _reservedController.text =
        widget.product.reserved?.toStringAsFixed(0) ?? '0';
    _thresholdController.text = '5'; // default threshold
  }

  @override
  void dispose() {
    _onHandController.dispose();
    _reservedController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiClientProvider);
      await api.dio.put(
        '/catalogue/branches/${widget.branchId}/products/${widget.product.id}/inventory',
        data: {
          'onHand': double.parse(_onHandController.text.trim()),
          'reserved': double.parse(_reservedController.text.trim()),
          'lowStockThreshold': double.parse(_thresholdController.text.trim()),
        },
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.of(context).pop();
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on DioException catch (e) {
      setState(() => _isSubmitting = false);
      final msg = e.errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Inventory: ${widget.product.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _onHandController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Physical Stock On Hand',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Enter quantity';
                if (double.tryParse(val.trim()) == null ||
                    double.parse(val.trim()) < 0) {
                  return 'Enter positive number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12.0),
            TextFormField(
              controller: _reservedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reserved Quantity'),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Enter quantity';
                final reserved = double.tryParse(val.trim());
                final onHand =
                    double.tryParse(_onHandController.text.trim()) ?? 0.0;
                if (reserved == null || reserved < 0)
                  return 'Enter positive number';
                if (reserved > onHand) return 'Reserved cannot exceed on-hand';
                return null;
              },
            ),
            const SizedBox(height: 12.0),
            TextFormField(
              controller: _thresholdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Low Stock Notification Threshold',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Enter threshold';
                if (double.tryParse(val.trim()) == null ||
                    double.parse(val.trim()) < 0) {
                  return 'Enter positive number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Save Stock'),
        ),
      ],
    );
  }
}
