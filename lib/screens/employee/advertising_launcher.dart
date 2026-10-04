import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';

class AdvertisingLauncher extends ConsumerStatefulWidget {
  final List<Branch> branches;
  final String? fixedBranchId;
  const AdvertisingLauncher({
    super.key,
    required this.branches,
    this.fixedBranchId,
  });
  @override
  ConsumerState<AdvertisingLauncher> createState() =>
      _AdvertisingLauncherState();
}

class _AdvertisingLauncherState extends ConsumerState<AdvertisingLauncher> {
  static const presets = {
    'DISCOUNT': (
      'Discount offer',
      'Save more for a limited time',
      'Shop now',
      '/shop',
      Icons.percent,
      Color(0xFFD84315),
    ),
    'SPECIAL': (
      'Today’s special',
      'A special offer selected for you',
      'View special',
      '/shop',
      Icons.local_offer,
      Color(0xFFEF6C00),
    ),
    'CHICKS': (
      'Chick bookings open',
      'Reserve chicks before the ordering window closes',
      'Book chicks',
      '/chicks',
      Icons.egg,
      Color(0xFFF9A825),
    ),
    'NEW_PRODUCT': (
      'New product available',
      'Discover our newest product',
      'View product',
      '/shop',
      Icons.new_releases,
      Color(0xFF2E7D32),
    ),
  };
  String type = 'DISCOUNT';
  String? branch;
  final title = TextEditingController(),
      body = TextEditingController(),
      hours = TextEditingController(text: '72'),
      image = TextEditingController();
  bool busy = false;
  @override
  void initState() {
    super.initState();
    branch = widget.fixedBranchId;
    _apply();
  }

  void _apply() {
    final p = presets[type]!;
    title.text = p.$1;
    body.text = p.$2;
  }

  Future<void> _launch() async {
    final duration = int.tryParse(hours.text.trim());
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      _message('Enter both a headline and message.', error: true);
      return;
    }
    if (duration == null || duration < 1 || duration > 2160) {
      _message(
        'Display duration must be between 1 and 2160 hours.',
        error: true,
      );
      return;
    }
    setState(() => busy = true);
    final p = presets[type]!;
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post(
            '/advertisements',
            data: {
              'templateType': type,
              'branchId': widget.fixedBranchId ?? branch,
              'title': title.text.trim(),
              'body': body.text.trim(),
              'imageUrl': image.text.trim().isEmpty ? null : image.text.trim(),
              'ctaLabel': p.$3,
              'ctaRoute': p.$4,
              'durationHours': duration,
            },
          );
      if (mounted) {
        _message('Advertisement launched successfully.');
      }
    } on DioException catch (e) {
      if (mounted) _message(e.errorMessage, error: true);
    } catch (e) {
      if (mounted)
        _message(
          'Unable to launch advertisement. Please try again.',
          error: true,
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final p = presets[type]!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Launch advertisement',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Choose a template, customise it, and control how long customers see it.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.entries
              .map(
                (e) => ChoiceChip(
                  selected: type == e.key,
                  avatar: Icon(e.value.$5, size: 18),
                  label: Text(e.key.replaceAll('_', ' ')),
                  onSelected: (_) => setState(() {
                    type = e.key;
                    _apply();
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.$6,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(p.$5, color: Colors.white, size: 32),
              const SizedBox(height: 10),
              Text(
                title.text.isEmpty ? p.$1 : title.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                body.text.isEmpty ? p.$2 : body.text,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        if (widget.fixedBranchId == null)
          DropdownButtonFormField<String>(
            value: branch,
            items: [
              const DropdownMenuItem(value: null, child: Text('All customers')),
              ...widget.branches.map(
                (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
              ),
            ],
            onChanged: (v) => setState(() => branch = v),
            decoration: const InputDecoration(labelText: 'Audience'),
          ),
        TextField(
          controller: title,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Headline'),
        ),
        TextField(
          controller: body,
          onChanged: (_) => setState(() {}),
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        TextField(
          controller: image,
          decoration: const InputDecoration(labelText: 'Image URL (optional)'),
        ),
        TextField(
          controller: hours,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Display duration in hours',
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: busy ? null : _launch,
          icon: const Icon(Icons.campaign),
          label: Text(busy ? 'Launching…' : 'Launch advert'),
        ),
      ],
    );
  }
}
