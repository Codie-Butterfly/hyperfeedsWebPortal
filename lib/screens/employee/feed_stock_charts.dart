import 'package:flutter/material.dart';
import '../../constants/theme.dart';

class FeedStockCharts extends StatelessWidget {
  const FeedStockCharts({super.key, required this.rows, required this.period});
  final List<dynamic>? rows;
  final String period;
  double number(dynamic value) => num.tryParse('$value')?.toDouble() ?? 0;
  String quantity(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (rows == null) {
      return const Text('Feed graphs require the updated reporting service.');
    }
    if (rows!.isEmpty) {
      return const Text('No feed stock or sales for this selection.');
    }
    final groups = <String, List<dynamic>>{};
    for (final row in rows!) {
      groups.putIfAbsent('${row['category']}', () => []).add(row);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sold: $period, all currencies. Remaining: current on-hand stock, including reserved units. Quantities are packs in each product’s listed size.',
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              '■ Total (sold + remaining)',
              style: TextStyle(color: Colors.grey),
            ),
            Text('■ Remaining', style: TextStyle(color: AppColors.brandOrange)),
          ],
        ),
        const Text('Exposed grey = sold. Total is not opening stock.'),
        for (final group in groups.entries)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.key,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._bars(context, group.value),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _bars(BuildContext context, List<dynamic> products) {
    final maximum = products.fold<double>(0, (max, p) {
      final total = number(p['sold']) + number(p['remaining']);
      return total > max ? total : max;
    });
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('0'),
          const Text('Quantity (packs)'),
          Text(quantity(maximum)),
        ],
      ),
      for (final p in products)
        Builder(
          builder: (context) {
            final sold = number(p['sold']);
            final remaining = number(p['remaining']);
            final total = sold + remaining;
            final label = '${p['name']} (${p['pack_size']})';
            final detail =
                'Sold: ${quantity(sold)} • Remaining: ${quantity(remaining)} • Total: ${quantity(total)}';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(label),
                    content: Text(detail),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                child: Semantics(
                  label: '$label. $detail',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 24,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            FractionallySizedBox(
                              widthFactor: maximum <= 0
                                  ? 0
                                  : (total / maximum).clamp(0, 1),
                              child: Container(
                                key: ValueKey('total-${p['id']}'),
                                color: Colors.grey.shade300,
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: maximum <= 0
                                  ? 0
                                  : (remaining / maximum).clamp(0, 1),
                              child: Container(
                                key: ValueKey('remaining-${p['id']}'),
                                color: AppColors.brandOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
    ];
  }
}
