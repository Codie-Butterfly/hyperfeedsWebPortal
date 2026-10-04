import 'package:flutter/material.dart';
import '../../constants/theme.dart';

class StaffLoginFrame extends StatelessWidget {
  final Widget child;
  const StaffLoginFrame({super.key, required this.child});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final form = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child,
        ),
      );
      if (size.maxWidth < 1000) return form;
      return Row(
        children: [
          Expanded(
            child: Container(
              color: AppColors.primaryNavy,
              padding: const EdgeInsets.all(64),
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.security_outlined,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'A better day\nat the branch.',
                      style: TextStyle(
                        fontSize: 46,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Serve customers, manage orders and keep your branches moving.',
                      style: TextStyle(
                        fontSize: 19,
                        height: 1.6,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 40),
                    for (final label in [
                      'Customer service',
                      'Branch management',
                      'Company operations',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.brandOrange,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              label,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(32), child: form),
          ),
        ],
      );
    },
  );
}
