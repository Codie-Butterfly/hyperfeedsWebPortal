import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../repositories/api_client.dart';

class FeedCalculatorScreen extends StatefulWidget {
  const FeedCalculatorScreen({super.key});

  @override
  State<FeedCalculatorScreen> createState() => _FeedCalculatorScreenState();
}

class _FeedCalculatorScreenState extends State<FeedCalculatorScreen> {
  final _animalCountController = TextEditingController(text: '100');
  final _daysController = TextEditingController(text: '30');
  List<Map<String, dynamic>> _profiles = [];
  Map<String, dynamic>? _selectedProfile;
  Map<String, dynamic>? _result;
  bool _loading = true;
  bool _calculating = false;
  String? _error;

  String get _selectedCode => _selectedProfile?['code']?.toString() ?? '';
  bool get _usesSelectedDays =>
      !const {'BROILER', 'PIG', 'CALF'}.contains(_selectedCode);

  void _selectProfile(Map<String, dynamic> profile) {
    final code = profile['code']?.toString() ?? '';
    setState(() {
      _selectedProfile = profile;
      _daysController.text = '${profile['defaultDays']}';
      _animalCountController.text = _defaultAnimalCount(code).toString();
      _result = null;
      _error = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _animalCountController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    try {
      final response = await ApiClient().dio.get('/feed-calculator/profiles');
      final profiles = (response.data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _selectedProfile = profiles.isEmpty ? null : profiles.first;
        if (_selectedProfile != null) {
          _daysController.text = '${_selectedProfile!['defaultDays']}';
        }
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.errorMessage;
        _loading = false;
      });
    }
  }

  Future<void> _calculate() async {
    final animalCount = int.tryParse(_animalCountController.text);
    final days = int.tryParse(_daysController.text);
    if (_selectedProfile == null ||
        animalCount == null ||
        animalCount < 1 ||
        days == null ||
        days < 1) {
      setState(
        () => _error = 'Enter a valid number of animals and feeding days.',
      );
      return;
    }
    setState(() {
      _calculating = true;
      _error = null;
      _result = null;
    });
    try {
      final response = await ApiClient().dio.post(
        '/feed-calculator/calculate',
        data: {
          'profileCode': _selectedProfile!['code'],
          'animalCount': animalCount,
          'days': days,
          'bagSizeKg': 50,
        },
      );
      if (!mounted) return;
      setState(() => _result = Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.errorMessage);
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed Calculator')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Plan your feed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose an animal and get a demo estimate of feed and 50 kg bags required.',
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select an animal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 10),
                _AnimalSelector(
                  profiles: _profiles,
                  selectedCode: _selectedCode,
                  onSelected: _selectProfile,
                ),
                if (_selectedProfile != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _animalIcon(_selectedCode),
                          size: 38,
                          color: AppColors.brandOrange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedProfile!['animalName'].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              Text(
                                _selectedProfile!['description'].toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _animalCountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _animalCountLabel(_selectedCode),
                    prefixIcon: Icon(_animalIcon(_selectedCode)),
                  ),
                ),
                if (_usesSelectedDays) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _selectedCode == 'LAYER'
                          ? 'Days in lay'
                          : 'Feeding days',
                      prefixIcon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _calculating ? null : _calculate,
                  icon: _calculating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.calculate),
                  label: Text(_calculating ? 'Calculating…' : 'Calculate Feed'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 20),
                  _ResultCard(result: _result!),
                ],
              ],
            ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final phases = (result['phases'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: AppColors.primaryNavy,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const Text(
                  'Estimated total',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  '${result['totalKg']} kg',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${result['bagsToBuy']} × ${result['bagSizeKg']} kg bags to purchase',
                  style: const TextStyle(
                    color: AppColors.brandOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...phases.map(
          (phase) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFFFE8D2),
                backgroundImage: phase['imageUrl'] != null
                    ? NetworkImage(phase['imageUrl'].toString())
                    : null,
                child: phase['imageUrl'] == null
                    ? const Icon(Icons.grass, color: AppColors.brandOrange)
                    : null,
              ),
              title: Text(phase['phaseName']?.toString() ?? ''),
              subtitle: Text(
                '${phase['productName'] ?? 'Hyperfeeds product'}\n'
                '${phase['kgPerAnimal']} kg per animal',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${phase['totalKg']} kg',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('${phase['bagsToBuy']} bags'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Basis: ${result['sourceLabel'] ?? 'Demo planning assumption'}',
          style: const TextStyle(fontSize: 11, color: AppColors.textLight),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            result['disclaimer']?.toString() ?? 'Demo estimate only.',
            style: const TextStyle(fontSize: 12, color: AppColors.warning),
          ),
        ),
      ],
    );
  }
}

class _AnimalSelector extends StatelessWidget {
  const _AnimalSelector({
    required this.profiles,
    required this.selectedCode,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> profiles;
  final String selectedCode;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: profiles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final profile = profiles[index];
          final code = profile['code'].toString();
          final selected = code == selectedCode;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(profile),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 98,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryNavy : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.brandOrange : AppColors.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _animalIcon(code),
                    color: selected
                        ? AppColors.brandOrange
                        : AppColors.primaryNavy,
                    size: 30,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    profile['animalName'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textDark,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

int _defaultAnimalCount(String code) => switch (code) {
  'BROILER' || 'LAYER' || 'ROAD_RUNNER' => 100,
  'RABBIT' => 20,
  'PIG' || 'GOAT_SHEEP' => 10,
  'DOG' => 2,
  _ => 5,
};

String _animalCountLabel(String code) => switch (code) {
  'BROILER' || 'LAYER' || 'ROAD_RUNNER' => 'Number of birds',
  'DAIRY_CATTLE' => 'Number of dairy cows',
  'BEEF_CATTLE' => 'Number of beef cattle',
  'CALF' => 'Number of calves',
  'PIG' => 'Number of pigs',
  'GOAT_SHEEP' => 'Number of goats or sheep',
  'RABBIT' => 'Number of rabbits',
  'DOG' => 'Number of dogs',
  'GAME' => 'Number of game animals',
  _ => 'Number of animals',
};

IconData _animalIcon(String code) => switch (code) {
  'BROILER' || 'LAYER' || 'ROAD_RUNNER' => Icons.egg_outlined,
  'DAIRY_CATTLE' || 'BEEF_CATTLE' => Icons.agriculture_outlined,
  'CALF' => Icons.cruelty_free_outlined,
  'PIG' => Icons.pets_outlined,
  'GOAT_SHEEP' => Icons.grass_outlined,
  'RABBIT' => Icons.cruelty_free,
  'DOG' => Icons.pets,
  'GAME' => Icons.forest_outlined,
  _ => Icons.calculate_outlined,
};
