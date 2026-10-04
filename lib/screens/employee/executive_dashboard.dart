import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/theme.dart';
import 'feed_stock_charts.dart';
import '../../providers/auth_provider.dart';

class ExecutiveDashboard extends ConsumerStatefulWidget {
  const ExecutiveDashboard({super.key});
  @override
  ConsumerState<ExecutiveDashboard> createState() => _ExecutiveDashboardState();
}

class _ExecutiveDashboardState extends ConsumerState<ExecutiveDashboard> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String? branch, currency, error;
  List<dynamic> branches = [], currencies = [];
  Map<String, dynamic>? report;
  bool busy = true;
  int generation = 0;
  int selectedTab = 0;
  List<dynamic>? stockRequests;
  String get period =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';
  String get scope => branch == null
      ? 'Whole company'
      : branches
            .firstWhere((b) => b['id'].toString() == branch)['name']
            .toString();
  double number(dynamic x) => num.tryParse('$x')?.toDouble() ?? 0;
  String money(dynamic x) => '$currency ${number(x).toStringAsFixed(2)}';
  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      final data =
          (await ref
                      .read(apiClientProvider)
                      .dio
                      .get('/management/executive/options'))
                  .data
              as Map;
      branches = data['branches'];
      currencies = data['currencies'];
      if (currencies.isEmpty) {
        setState(() {
          busy = false;
          error =
              'No currency is configured. Add product or chick prices first.';
        });
        return;
      }
      currency = currencies.contains('USD')
          ? 'USD'
          : currencies.first.toString();
      await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is DioException
              ? e.errorMessage
              : 'Unable to load dashboard.';
        });
      }
    }
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() {
      busy = true;
      error = null;
      report = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get(
            '/management/executive',
            queryParameters: {
              'month': period,
              'currency': currency,
              if (branch != null) 'branchId': branch,
            },
          );
      List<dynamic>? requests;
      try {
        requests =
            (await ref
                        .read(apiClientProvider)
                        .dio
                        .get(
                          '/management/executive/stock-requests',
                          queryParameters: {
                            'month': period,
                            if (branch != null) 'branchId': branch,
                          },
                        ))
                    .data
                as List;
      } on DioException {
        /* Older services can still show the main report. */
      }
      if (mounted && request == generation) {
        stockRequests = requests;
        setState(() => report = Map<String, dynamic>.from(response.data));
      }
    } catch (e) {
      if (mounted && request == generation) {
        setState(
          () => error = e is DioException
              ? e.errorMessage
              : 'Unable to load dashboard.',
        );
      }
    } finally {
      if (mounted && request == generation) setState(() => busy = false);
    }
  }

  Future<void> editTarget() async {
    final controller = TextEditingController(
      text: report?['summary']['target']?.toString() ?? '',
    );
    final key = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$scope target'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$period • $currency\nCompany and branch targets are set independently.',
              ),
              TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Expected net sales',
                ),
                validator: (v) =>
                    !RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(v ?? '') ||
                        number(v) <= 0
                    ? 'Enter a positive amount with up to two decimals'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Save target'),
          ),
        ],
      ),
    );
    if (value == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .put(
            '/management/executive/targets',
            data: {
              'month': period,
              'branchId': branch,
              'currency': currency,
              'amount': value,
            },
          );
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is DioException
              ? e.errorMessage
              : 'Target could not be saved.',
        );
      }
    }
  }

  Widget title(String s) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      s,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryNavy,
      ),
    ),
  );
  Widget metric(
    String label,
    String value, {
    Color color = AppColors.primaryNavy,
  }) => SizedBox(
    width: ((MediaQuery.sizeOf(context).width - 48) / 2).clamp(140, 260),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget bar(
    String label,
    double value,
    double max, {
    String? detail,
    Color color = AppColors.brandOrange,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label • ${detail ?? value.toStringAsFixed(0)}'),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 12,
            value: max <= 0 ? 0 : (value / max).clamp(0, 1),
            color: color,
            backgroundColor: AppColors.border,
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 7,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('CEO dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: busy
                ? null
                : () => currency == null ? initialize() : load(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
              context.go('/welcome');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<String>(
                    initialValue: branch ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Company / branch',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Whole company'),
                      ),
                      ...branches.map(
                        (b) => DropdownMenuItem(
                          value: b['id'].toString(),
                          child: Text(b['name'].toString()),
                        ),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            branch = v == '' ? null : v;
                            load();
                          },
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(currency),
                    initialValue: currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: currencies
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.toString(),
                            child: Text(c.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) {
                            currency = v;
                            load();
                          },
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: busy
                          ? null
                          : () {
                              month = DateTime(month.year, month.month - 1);
                              load();
                            },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      period,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: busy
                          ? null
                          : () {
                              month = DateTime(month.year, month.month + 1);
                              load();
                            },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (index) => setState(() => selectedTab = index),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Sales'),
              Tab(text: 'Product Performance'),
              Tab(text: 'Stock Movement'),
              Tab(text: 'Branch Performance'),
              Tab(text: 'Chick Orders'),
              Tab(text: 'Configs'),
            ],
          ),
          Expanded(
            child: ListView(
              key: ValueKey(selectedTab),
              padding: const EdgeInsets.all(16),
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (report != null) ...content(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  List<Widget> content() {
    final s = report!['summary'] as Map;
    final products = List<Map<String, dynamic>>.from(
      (report!['products'] as List).map((p) => Map<String, dynamic>.from(p)),
    );
    final least = [...products]
      ..sort((a, b) => number(a['quantity']).compareTo(number(b['quantity'])));
    final inventory = report!['inventory'] as List;
    final low = inventory.where((i) => i['low_stock'] == true).length;
    final daily = report!['daily'] as List;
    final maxDaily = daily.fold<double>(
      0,
      (m, d) => math.max(m, number(d['amount'])),
    );
    final branchRows = report!['branches'] as List;
    final maxBranch = branchRows.fold<double>(
      0,
      (m, b) => math.max(m, math.max(number(b['actual']), number(b['target']))),
    );
    return [
      title('$scope • $period'),
      if (selectedTab == 0) ...[
        const Text(
          'Net sales = paid product orders plus confirmed chick bookings, dated when ordered. Discounts are deducted. Cash received is shown separately; deposits are not added to sales twice. Currencies are never combined.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            metric('Net sales', money(s['net_sales'])),
            metric('Cash received', money(s['cash_received'])),
            metric('Discounts given', money(s['discounts'])),
            metric(
              'Monthly target',
              s['target'] == null ? 'Not set' : money(s['target']),
            ),
            metric(
              'Expected by today',
              s['expected_to_date'] == null
                  ? 'Set a target'
                  : money(s['expected_to_date']),
            ),
            metric(
              s['pace_gap'] == null
                  ? 'Pace'
                  : number(s['pace_gap']) < 0
                  ? 'Behind pace'
                  : 'Ahead of pace',
              s['pace_gap'] == null
                  ? 'Not available'
                  : money(number(s['pace_gap']).abs()),
              color: AppColors.brandOrange,
            ),
            metric(
              'Still needed for target',
              s['remaining_to_target'] == null
                  ? 'Not available'
                  : money(s['remaining_to_target']),
            ),
            metric(
              'Low / out of stock',
              '$low product / branch pairs',
              color: AppColors.brandOrange,
            ),
          ],
        ),
        if (s['target'] != null) ...[
          title('Target progress: ${s['achievement_percent']}%'),
          bar(
            'Actual net sales',
            number(s['net_sales']),
            number(s['target']),
            detail: money(s['net_sales']),
          ),
          bar(
            'Expected after ${s['days_elapsed']} of ${s['days_in_month']} days',
            number(s['expected_to_date']),
            number(s['target']),
            detail: money(s['expected_to_date']),
            color: AppColors.primaryNavy,
          ),
          const Text(
            'Expected progress assumes sales are spread evenly across calendar days.',
          ),
        ],
      ],
      if (selectedTab == 1) ...[
        title('Daily sales'),
        if (daily.isEmpty)
          const Text('No qualifying sales in this month.')
        else
          SizedBox(
            height: 180,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(monthEnd(), (i) {
                  final key = '$period-${(i + 1).toString().padLeft(2, '0')}';
                  final row = daily.where(
                    (d) => d['day'].toString().startsWith(key),
                  );
                  final value = row.isEmpty ? 0.0 : number(row.first['amount']);
                  return Tooltip(
                    triggerMode: TooltipTriggerMode.tap,
                    waitDuration: const Duration(milliseconds: 150),
                    showDuration: const Duration(seconds: 3),
                    message: '$key: ${money(value)}',
                    child: SizedBox(
                      width: 34,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 22,
                            height: maxDaily == 0
                                ? 1
                                : math.max(1, value / maxDaily * 145),
                            decoration: BoxDecoration(
                              color: AppColors.brandOrange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('${i + 1}'),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
      if (selectedTab == 4) ...[
        title('Branch performance'),
        const Text(
          'Orange bars show actual sales. Each branch target is shown alongside it.',
        ),
        ...branchRows.map(
          (b) => bar(
            b['name'].toString(),
            number(b['actual']),
            maxBranch,
            detail:
                '${money(b['actual'])} / ${b['target'] == null ? 'target not set' : money(b['target'])}',
          ),
        ),
      ],
      if (selectedTab == 2) ...[
        title('Most sold products • by units'),
        if (products.isEmpty)
          const Text('No products available for this selection.'),
        ...products
            .take(10)
            .map(
              (p) => bar(
                '${p['name']} (${p['pack_size']})',
                number(p['quantity']),
                products.isEmpty ? 0 : number(products.first['quantity']),
                detail: '${p['quantity']} units • ${money(p['net_sales'])}',
              ),
            ),
        title('Least sold products • includes zero sales'),
        ...least
            .take(10)
            .map(
              (p) => bar(
                '${p['name']} (${p['pack_size']})',
                number(p['quantity']),
                products.isEmpty ? 0 : number(products.first['quantity']),
                detail: '${p['quantity']} units • ${money(p['net_sales'])}',
                color: AppColors.primaryNavy,
              ),
            ),
      ],
      if (selectedTab == 5) ...[
        title('Chick orders'),
        if ((report!['chicks'] as List).isEmpty)
          const Text('No chick bookings in this period.'),
        ...(report!['chicks'] as List).map(
          (c) => Card(
            child: ListTile(
              leading: const Icon(Icons.egg_alt, color: AppColors.brandOrange),
              title: Text('${c['chick_type']} / ${c['breed']}'),
              subtitle: Text(
                '${c['status']} • ${c['bookings']} bookings • ${c['chicks']} chicks',
              ),
              trailing: Text(money(c['value'])),
            ),
          ),
        ),
      ],
      if (selectedTab == 3) ...[
        title('Feed stock by category'),
        FeedStockCharts(rows: report!['feed_stock'] as List?, period: period),
        title('Stock requests'),
        const Text(
          'Requests created in the selected month. Request status does not establish a physical stock receipt or transfer.',
        ),
        if (stockRequests == null)
          const Text(
            'Stock request history is unavailable. Refresh after the reporting service is updated.',
          ),
        if (stockRequests != null && stockRequests!.isEmpty)
          const Text('No stock requests in this period.'),
        ...?stockRequests?.map(
          (r) => Card(
            child: ListTile(
              title: Text(
                '${r['product_name']} • ${r['requested_quantity']} packs',
              ),
              subtitle: Text(
                '${r['branch_name']} • ${r['status']}\n${r['created_at']}',
              ),
            ),
          ),
        ),
      ],
      if (selectedTab == 6) ...[
        title('Sales targets'),
        Text(
          'Set the monthly target for $scope, $period, in $currency. Company and branch targets are independent.',
        ),
        metric(
          'Current target',
          s['target'] == null ? 'Not set' : money(s['target']),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: busy ? null : editTarget,
            icon: const Icon(Icons.flag),
            label: const Text('Set monthly target'),
          ),
        ),
      ],
      const SizedBox(height: 20),
      Text('Updated: ${report!['as_of']}'),
    ];
  }

  int monthEnd() => DateTime(month.year, month.month + 1, 0).day;
}
