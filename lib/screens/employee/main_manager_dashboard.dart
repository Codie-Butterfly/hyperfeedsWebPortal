import 'staff_scaffold.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../constants/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/branch_provider.dart';
import 'advertising_launcher.dart';
import 'executive_dashboard.dart';

class MainManagerDashboard extends ConsumerStatefulWidget {
  const MainManagerDashboard({super.key});
  @override
  ConsumerState<MainManagerDashboard> createState() =>
      _MainManagerDashboardState();
}

class _MainManagerDashboardState extends ConsumerState<MainManagerDashboard> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      const _Configs(),
      const _Employees(),
      const _ChickPlanning(allowConfiguration: false),
      const _StockRequests(),
      const _Broadcasts(),
      AdvertisingLauncher(branches: ref.watch(branchStateProvider).branches),
    ];
    return StaffScaffold(
      appBar: AppBar(
        title: const Text('Main Manager'),
        actions: [
          IconButton(
            tooltip: 'CEO dashboard',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExecutiveDashboard()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
              context.go('/welcome');
            },
          ),
        ],
      ),
      body: pages[page],
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (v) => setState(() => page = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.settings), label: 'Configs'),
          NavigationDestination(icon: Icon(Icons.badge), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.egg), label: 'Chicks'),
          NavigationDestination(
            icon: Icon(Icons.inventory_2),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: 'Notify',
          ),
          NavigationDestination(icon: Icon(Icons.campaign), label: 'Ads'),
        ],
      ),
    );
  }
}

class _Configs extends StatelessWidget {
  const _Configs();

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            child: TabBar(
              tabs: [
                Tab(icon: Icon(Icons.price_change), text: 'Prices'),
                Tab(icon: Icon(Icons.egg), text: 'Chick bookings'),
                Tab(icon: Icon(Icons.tune), text: 'Other'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _GlobalPrices(),
                _ChickBreedConfigs(),
                _OtherConfigs(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OtherConfigs extends ConsumerStatefulWidget {
  const _OtherConfigs();
  @override
  ConsumerState<_OtherConfigs> createState() => _OtherConfigsState();
}

class _OtherConfigsState extends ConsumerState<_OtherConfigs> {
  final hours = TextEditingController(text: '24');
  final depositPercentage = TextEditingController(text: '0');
  bool depositEnabled = false;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    hours.dispose();
    depositPercentage.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/management/order-config');
      if (mounted) {
        hours.text = response.data['unpaidOrderExpiryHours'].toString();
        depositEnabled = response.data['chickOrderDepositEnabled'] == true;
        depositPercentage.text = response.data['chickOrderDepositPercentage']
            .toString();
      }
    } on DioException catch (error) {
      if (mounted) _message(error.errorMessage, error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    final value = int.tryParse(hours.text.trim());
    if (value == null || value < 1 || value > 720) {
      _message('Enter a value between 1 and 720 hours.', error: true);
      return;
    }
    final percentage = double.tryParse(depositPercentage.text.trim());
    if (percentage == null || percentage < 0 || percentage > 100) {
      _message(
        'Enter a chick deposit percentage between 0 and 100.',
        error: true,
      );
      return;
    }
    if (depositEnabled && percentage <= 0) {
      _message(
        'Enter a deposit percentage greater than 0 when deposits are enabled.',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .put(
            '/management/order-config',
            data: {
              'unpaidOrderExpiryHours': value,
              'chickOrderDepositEnabled': depositEnabled,
              'chickOrderDepositPercentage': percentage,
            },
          );
      if (mounted) _message('Unpaid order expiry updated.');
    } on DioException catch (error) {
      if (mounted) _message(error.errorMessage, error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? AppColors.error : AppColors.success,
        ),
      );

  @override
  Widget build(BuildContext context) => loading
      ? const Center(child: CircularProgressIndicator())
      : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Other configurations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose how long unpaid shop-payment orders remain reserved before they are removed.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: hours,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Unpaid order expiry',
                suffixText: 'hours',
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Chick order deposit'),
              subtitle: Text(
                depositEnabled
                    ? 'Customers must pay a percentage of the total chick order price.'
                    : 'Customers are not required to pay a deposit for chick orders.',
              ),
              value: depositEnabled,
              onChanged: saving
                  ? null
                  : (value) => setState(() => depositEnabled = value),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: depositPercentage,
              enabled: depositEnabled && !saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Deposit percentage',
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: saving ? null : _save,
              child: Text(saving ? 'Saving…' : 'Save configuration'),
            ),
          ],
        );
}

class _GlobalPrices extends ConsumerStatefulWidget {
  const _GlobalPrices();
  @override
  ConsumerState<_GlobalPrices> createState() => _GlobalPricesState();
}

class _GlobalPricesState extends ConsumerState<_GlobalPrices> {
  List<dynamic> products = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      final r = await ref.read(apiClientProvider).dio.get('/management/prices');
      if (mounted)
        setState(() {
          products = r.data;
          loading = false;
        });
    } on DioException catch (e) {
      if (mounted)
        setState(() {
          loading = false;
          error = e.errorMessage;
        });
    }
  }

  Future<void> _edit(dynamic p) async {
    final amount = TextEditingController(text: p['amount']?.toString() ?? '');
    final currency = TextEditingController(
      text: p['currency']?.toString().trim() ?? 'USD',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Company price: ${p['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            TextField(
              controller: currency,
              decoration: const InputDecoration(labelText: 'Currency'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Apply to all branches'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .put(
            '/management/prices/${p['id']}',
            data: {
              'amount': double.parse(amount.text),
              'currency': currency.text,
            },
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Price applied to every active branch')),
        );
        _load();
      }
    } on DioException catch (e) {
      _error(e.errorMessage);
    }
  }

  Future<void> _addProduct() async {
    final name = TextEditingController();
    final sku = TextEditingController();
    final category = TextEditingController();
    final packSize = TextEditingController();
    final description = TextEditingController();
    final amount = TextEditingController();
    final currency = TextEditingController(text: 'USD');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Item name'),
              ),
              TextField(
                controller: sku,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'SKU'),
              ),
              TextField(
                controller: category,
                decoration: const InputDecoration(
                  labelText: 'Category (e.g. Dog Feed or Medicine)',
                ),
              ),
              TextField(
                controller: packSize,
                decoration: const InputDecoration(
                  labelText: 'Pack size (e.g. 20 kg or 500 ml)',
                ),
              ),
              TextField(
                controller: description,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              TextField(
                controller: currency,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Currency'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Add to all branches'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final price = double.tryParse(amount.text.trim());
    if ([
          name,
          sku,
          category,
          packSize,
          currency,
        ].any((field) => field.text.trim().isEmpty) ||
        price == null) {
      _error('Complete all required fields and enter a valid price');
      return;
    }
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post(
            '/management/products',
            data: {
              'name': name.text,
              'sku': sku.text,
              'category': category.text,
              'packSize': packSize.text,
              'description': description.text,
              'amount': price,
              'currency': currency.text,
            },
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added to every active branch')),
        );
        _load();
      }
    } on DioException catch (e) {
      _error(e.errorMessage);
    }
  }

  void _error(String m) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: AppColors.error),
      );
  }

  @override
  Widget build(BuildContext c) => loading
      ? const Center(child: CircularProgressIndicator())
      : error != null
      ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        )
      : RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Products and prices',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addProduct,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ],
              ),
              const Text('Changes apply to every active branch.'),
              const SizedBox(height: 12),
              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No active products found')),
                ),
              ...products.map(
                (p) => Card(
                  child: ListTile(
                    title: Text(p['name']),
                    subtitle: Text(
                      '${p['sku']} • ${p['amount'] == null ? 'Price not set' : '${p['currency']} ${p['amount']}'}',
                    ),
                    trailing: IconButton(
                      onPressed: () => _edit(p),
                      icon: const Icon(Icons.edit),
                      tooltip: 'Set price',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
}

class _Employees extends ConsumerStatefulWidget {
  const _Employees();
  @override
  ConsumerState<_Employees> createState() => _EmployeesState();
}

class _EmployeesState extends ConsumerState<_Employees> {
  final phone = TextEditingController(),
      first = TextEditingController(),
      last = TextEditingController(),
      password = TextEditingController();
  String role = 'BRANCH_MANAGER';
  String? branch;
  bool busy = false;
  @override
  Widget build(BuildContext c) {
    final branches = ref.watch(branchStateProvider).branches;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Create employee',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        TextField(
          controller: first,
          decoration: const InputDecoration(labelText: 'First name'),
        ),
        TextField(
          controller: last,
          decoration: const InputDecoration(labelText: 'Last name'),
        ),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone number'),
        ),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Temporary password (10+ characters)',
          ),
        ),
        DropdownButtonFormField(
          value: role,
          items:
              const [
                    'CEO',
                    'MAIN_MANAGER',
                    'BRANCH_MANAGER',
                    'ANIMAL_HEALTH_EXPERT',
                    'CUSTOMER_SERVICE',
                  ]
                  .map(
                    (x) => DropdownMenuItem(
                      value: x,
                      child: Text(x.replaceAll('_', ' ')),
                    ),
                  )
                  .toList(),
          onChanged: (v) => setState(() => role = v!),
          decoration: const InputDecoration(labelText: 'Role'),
        ),
        if (role == 'BRANCH_MANAGER')
          DropdownButtonFormField<String>(
            value: branch,
            items: branches
                .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                .toList(),
            onChanged: (v) => setState(() => branch = v),
            decoration: const InputDecoration(labelText: 'Assigned branch'),
          ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: busy ? null : _submit,
          child: Text(busy ? 'Creating…' : 'Create employee'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post(
            '/management/employees',
            data: {
              'phoneNumber': phone.text,
              'firstName': first.text,
              'lastName': last.text,
              'password': password.text,
              'role': role,
              'branchId': role == 'BRANCH_MANAGER' ? branch : null,
            },
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Employee created')));
        phone.clear();
        first.clear();
        last.clear();
        password.clear();
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
}

class _ChickBreedConfigs extends ConsumerStatefulWidget {
  const _ChickBreedConfigs();
  @override
  ConsumerState<_ChickBreedConfigs> createState() => _ChickBreedConfigsState();
}

class _ChickBreedConfigsState extends ConsumerState<_ChickBreedConfigs> {
  List<dynamic> breeds = [];
  List<dynamic> bookingBatches = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final responses = await Future.wait([
        ref.read(apiClientProvider).dio.get('/management/chicks/breeds'),
        ref
            .read(apiClientProvider)
            .dio
            .get('/management/chicks/booking-batches'),
      ]);
      if (mounted)
        setState(() {
          breeds = responses[0].data;
          bookingBatches = responses[1].data;
          loading = false;
        });
    } on DioException catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _error(e.errorMessage);
      }
    }
  }

  Future<void> _createBookingBatch([dynamic existing]) async {
    final name = TextEditingController(text: existing?['name']?.toString());
    DateTime start = existing == null
        ? DateTime.now()
        : DateTime.parse(existing['start_date'].toString());
    DateTime end = existing == null
        ? DateTime.now().add(const Duration(days: 30))
        : DateTime.parse(existing['end_date'].toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Create booking batch' : 'Edit booking batch',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Batch name'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start date'),
                subtitle: Text(_date(start)),
                onTap: () async {
                  final v = await showDatePicker(
                    context: c,
                    initialDate: start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (v != null) setDialogState(() => start = v);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End date'),
                subtitle: Text(_date(end)),
                onTap: () async {
                  final v = await showDatePicker(
                    context: c,
                    initialDate: end,
                    firstDate: start,
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (v != null) setDialogState(() => end = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(existing == null ? 'Create draft' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      final data = {
        'name': name.text,
        'startDate': _date(start),
        'endDate': _date(end),
      };
      if (existing == null) {
        await ref
            .read(apiClientProvider)
            .dio
            .post('/management/chicks/booking-batches', data: data);
      } else {
        await ref
            .read(apiClientProvider)
            .dio
            .put(
              '/management/chicks/booking-batches/${existing['id']}',
              data: data,
            );
      }
      await _load();
    } on DioException catch (e) {
      _error(e.errorMessage);
    }
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _changeBatch(dynamic batch, String action) async {
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post('/management/chicks/booking-batches/${batch['id']}/$action');
      await _load();
    } on DioException catch (e) {
      _error(e.errorMessage);
    }
  }

  Future<void> _edit([dynamic existing]) async {
    String type = existing?['chick_type']?.toString() ?? 'BROILER';
    bool available = existing?['available'] as bool? ?? true;
    final breed = TextEditingController(text: existing?['breed']?.toString());
    final price = TextEditingController(
      text: existing?['price_per_chick']?.toString(),
    );
    final currency = TextEditingController(
      text: existing?['currency']?.toString().trim() ?? 'USD',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Add chick breed' : 'Edit chick breed',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  items: const ['BROILER', 'LAYER']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v!),
                  decoration: const InputDecoration(labelText: 'Chick type'),
                ),
                TextField(
                  controller: breed,
                  decoration: const InputDecoration(labelText: 'Breed'),
                ),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price per chick',
                  ),
                ),
                TextField(
                  controller: currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available for booking'),
                  value: available,
                  onChanged: (v) => setDialogState(() => available = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final amount = double.tryParse(price.text.trim());
    if (breed.text.trim().isEmpty ||
        amount == null ||
        currency.text.trim().length != 3) {
      _error('Enter a breed, valid price, and three-letter currency');
      return;
    }
    try {
      final data = {
        'chickType': type,
        'breed': breed.text,
        'pricePerChick': amount,
        'currency': currency.text,
        'available': available,
      };
      if (existing == null) {
        await ref
            .read(apiClientProvider)
            .dio
            .post('/management/chicks/breeds', data: data);
      } else {
        await ref
            .read(apiClientProvider)
            .dio
            .put('/management/chicks/breeds/${existing['id']}', data: data);
      }
      await _load();
    } on DioException catch (e) {
      _error(e.errorMessage);
    }
  }

  void _error(String message) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
  }

  @override
  Widget build(BuildContext context) => loading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Booking batches',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _createBookingBatch,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add batch'),
                  ),
                ],
              ),
              const Text(
                'Only one batch can be open. Customers cannot book when none is open.',
              ),
              const SizedBox(height: 8),
              ...bookingBatches.map(
                (batch) => Card(
                  child: ListTile(
                    title: Text(batch['name']),
                    subtitle: Text(
                      '${batch['start_date']} to ${batch['end_date']} • ${batch['status']}',
                    ),
                    leading: Icon(
                      batch['status'] == 'OPEN' ? Icons.lock_open : Icons.lock,
                      color: batch['status'] == 'OPEN'
                          ? Colors.green
                          : Colors.grey,
                    ),
                    trailing: batch['status'] == 'CLOSED'
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'edit') {
                                _createBookingBatch(batch);
                              } else {
                                _changeBatch(batch, action);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: batch['status'] == 'DRAFT'
                                    ? 'open'
                                    : 'close',
                                child: Text(
                                  batch['status'] == 'DRAFT' ? 'Open' : 'Close',
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const Divider(height: 32),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Breeds and availability',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _edit(),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add breed'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...breeds.map(
                (breed) => Card(
                  child: ListTile(
                    title: Text('${breed['breed']} (${breed['chick_type']})'),
                    subtitle: Text(
                      '${breed['currency'].toString().trim()} ${breed['price_per_chick']} per chick',
                    ),
                    leading: Icon(
                      breed['available'] == true
                          ? Icons.check_circle
                          : Icons.pause_circle,
                      color: breed['available'] == true
                          ? Colors.green
                          : Colors.grey,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit price and availability',
                      onPressed: () => _edit(breed),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
}

class _ChickPlanning extends ConsumerStatefulWidget {
  const _ChickPlanning({required this.allowConfiguration});

  final bool allowConfiguration;
  @override
  ConsumerState<_ChickPlanning> createState() => _ChickPlanningState();
}

class _ChickPlanningState extends ConsumerState<_ChickPlanning> {
  List<dynamic> demand = [];
  Map<String, dynamic> currentBatch = {};
  bool loading = true;

  List<Map<String, dynamic>> get branchSummaries {
    final grouped = <String, Map<String, dynamic>>{};
    for (final raw in demand) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['branch_id'].toString();
      final item = grouped.putIfAbsent(
        id,
        () => {
          'name': row['branch_name'],
          'total': 0,
          'breeds': <Map<String, dynamic>>[],
        },
      );
      final chicks = int.tryParse(row['total_chicks'].toString()) ?? 0;
      item['total'] = (item['total'] as int) + chicks;
      (item['breeds'] as List<Map<String, dynamic>>).add(row);
    }
    return grouped.values.toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final responses = await Future.wait([
        ref.read(apiClientProvider).dio.get('/management/chicks/demand'),
        ref.read(apiClientProvider).dio.get('/management/chicks/current-batch'),
      ]);
      if (mounted)
        setState(() {
          demand = responses[0].data;
          currentBatch = Map<String, dynamic>.from(responses[1].data);
          loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  String _date(Object? value) {
    if (value == null) return 'Not set';
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null
        ? value.toString()
        : DateFormat('d MMM yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext c) => Column(
    children: [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryNavy,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current open batch',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            if (currentBatch.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                '${currentBatch['name']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Orders: ${_date(currentBatch['start_date'])} – ${_date(currentBatch['delivery_date'])}',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'Delivery: ${_date(currentBatch['delivery_date'])}',
                style: const TextStyle(
                  color: AppColors.brandOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else if (!loading)
              const Text(
                'No booking batch is currently open.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (demand.isEmpty)
                      SizedBox(
                        height: 430,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.egg_alt_outlined,
                                size: 72,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No chick orders yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (demand.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text(
                          '${branchSummaries.length} branch${branchSummaries.length == 1 ? '' : 'es'} with confirmed orders',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...branchSummaries.map((summary) {
                        return Card(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: ExpansionTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primaryNavy,
                              child: Icon(Icons.store, color: Colors.white),
                            ),
                            title: Text(
                              '${summary['name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            subtitle: Text(
                              '${summary['total']} chicks required',
                            ),
                            trailing: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'View more',
                                  style: TextStyle(
                                    color: AppColors.brandOrange,
                                    fontSize: 11,
                                  ),
                                ),
                                Icon(Icons.expand_more),
                              ],
                            ),
                            children: [
                              const Divider(height: 1),
                              ...(summary['breeds']
                                      as List<Map<String, dynamic>>)
                                  .map(
                                    (breed) => ListTile(
                                      leading: const Icon(
                                        Icons.egg_alt_outlined,
                                        color: AppColors.brandOrange,
                                      ),
                                      title: Text('${breed['breed']}'),
                                      subtitle: Text(
                                        '${breed['order_count']} confirmed order${breed['order_count'].toString() == '1' ? '' : 's'}',
                                      ),
                                      trailing: Text(
                                        '${breed['total_chicks']} chicks',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
      ),
    ],
  );

  Future<void> _batchDialog(BuildContext c) async {
    final branches = ref.read(branchStateProvider).branches;
    String? b = branches.isEmpty ? null : branches.first.id;
    final type = TextEditingController(text: 'BROILER'),
        breed = TextEditingController(),
        delivery = TextEditingController(),
        cutoff = TextEditingController(),
        price = TextEditingController(),
        currency = TextEditingController(text: 'USD');
    final ok = await showDialog<bool>(
      context: c,
      builder: (x) => StatefulBuilder(
        builder: (x, set) => AlertDialog(
          title: const Text('Set chick batch period'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: b,
                  items: branches
                      .map(
                        (v) =>
                            DropdownMenuItem(value: v.id, child: Text(v.name)),
                      )
                      .toList(),
                  onChanged: (v) => set(() => b = v),
                  decoration: const InputDecoration(labelText: 'Branch'),
                ),
                TextField(
                  controller: type,
                  decoration: const InputDecoration(labelText: 'Chick type'),
                ),
                TextField(
                  controller: breed,
                  decoration: const InputDecoration(labelText: 'Breed'),
                ),
                TextField(
                  controller: cutoff,
                  decoration: const InputDecoration(
                    labelText: 'Order cutoff (2026-09-20T17:00:00+02:00)',
                  ),
                ),
                TextField(
                  controller: delivery,
                  decoration: const InputDecoration(
                    labelText: 'Delivery date (2026-09-25)',
                  ),
                ),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price per chick',
                  ),
                ),
                TextField(
                  controller: currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(x, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(x, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post(
            '/chicks/batches',
            data: {
              'branchId': b,
              'chickType': type.text,
              'breed': breed.text,
              'cutoffAt': cutoff.text,
              'deliveryDate': delivery.text,
              'pricePerChick': double.parse(price.text),
              'currency': currency.text,
            },
          );
      _load();
    } on DioException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }
}

class _StockRequests extends ConsumerStatefulWidget {
  const _StockRequests();
  @override
  ConsumerState<_StockRequests> createState() => _StockRequestsState();
}

class _StockRequestsState extends ConsumerState<_StockRequests> {
  List<dynamic> items = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref
        .read(apiClientProvider)
        .dio
        .get('/management/stock-requests');
    if (mounted)
      setState(() {
        items = r.data;
        loading = false;
      });
  }

  Future<void> _set(dynamic i, String s) async {
    await ref
        .read(apiClientProvider)
        .dio
        .patch('/management/stock-requests/${i['id']}', data: {'status': s});
    _load();
  }

  @override
  Widget build(BuildContext c) => loading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text(
                'Branch stock requests',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (items.isEmpty)
                SizedBox(
                  height: 500,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 72,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No branch requests',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ...items.map(
                (i) => Card(
                  child: ListTile(
                    title: Text('${i['branch_name']} • ${i['product_name']}'),
                    subtitle: Text(
                      '${i['requested_quantity']} requested\n${i['note'] ?? ''}',
                    ),
                    trailing: PopupMenuButton<String>(
                      initialValue: i['status'],
                      onSelected: (s) => _set(i, s),
                      itemBuilder: (_) =>
                          const ['APPROVED', 'REJECTED', 'FULFILLED']
                              .map(
                                (s) => PopupMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
}

class _Broadcasts extends ConsumerStatefulWidget {
  const _Broadcasts();
  @override
  ConsumerState<_Broadcasts> createState() => _BroadcastsState();
}

class _BroadcastsState extends ConsumerState<_Broadcasts> {
  final title = TextEditingController(), body = TextEditingController();
  String audience = 'BRANCH_MANAGERS';
  String? branch;
  @override
  Widget build(BuildContext c) {
    final branches = ref.watch(branchStateProvider).branches;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Send app notification',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        DropdownButtonFormField(
          value: audience,
          items: const ['BRANCH_MANAGERS', 'CUSTOMERS', 'ALL']
              .map(
                (x) => DropdownMenuItem(
                  value: x,
                  child: Text(x.replaceAll('_', ' ')),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => audience = v!),
          decoration: const InputDecoration(labelText: 'Audience'),
        ),
        DropdownButtonFormField<String>(
          value: branch,
          items: [
            const DropdownMenuItem(value: null, child: Text('All branches')),
            ...branches.map(
              (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
            ),
          ],
          onChanged: (v) => setState(() => branch = v),
          decoration: const InputDecoration(labelText: 'Branch filter'),
        ),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        TextField(
          controller: body,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _send,
          icon: const Icon(Icons.send),
          label: const Text('Send notification'),
        ),
      ],
    );
  }

  Future<void> _send() async {
    try {
      final r = await ref
          .read(apiClientProvider)
          .dio
          .post(
            '/management/notifications',
            data: {
              'audience': audience,
              'branchId': branch,
              'title': title.text,
              'body': body.text,
            },
          );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sent to ${r.data} users')));
    } on DioException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }
}
