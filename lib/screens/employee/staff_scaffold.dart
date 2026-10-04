import 'package:flutter/material.dart';
import '../../constants/theme.dart';

/// Shares every dashboard action with mobile while adapting its navigation.
class StaffScaffold extends StatelessWidget {
  final AppBar appBar;
  final Widget body;
  final NavigationBar bottomNavigationBar;
  const StaffScaffold({
    super.key,
    required this.appBar,
    required this.body,
    required this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      if (size.maxWidth < 1000) {
        return Scaffold(
          appBar: appBar,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
        );
      }
      final destinations = bottomNavigationBar.destinations
          .cast<NavigationDestination>();
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 248,
              color: AppColors.primaryNavy,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 32, 24, 4),
                      child: Text(
                        'HYPERFEEDS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 28),
                      child: Text(
                        'Staff workspace',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: List.generate(destinations.length, (index) {
                          final selected =
                              index == bottomNavigationBar.selectedIndex;
                          final item = destinations[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: selected
                                  ? AppColors.brandOrange
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: ListTile(
                                selected: selected,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                iconColor: Colors.white,
                                textColor: Colors.white,
                                selectedColor: Colors.white,
                                leading: selected
                                    ? item.selectedIcon ?? item.icon
                                    : item.icon,
                                title: Text(item.label),
                                onTap: () => bottomNavigationBar
                                    .onDestinationSelected
                                    ?.call(index),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Customer care • Branch operations',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Material(
                    color: Colors.white,
                    child: SizedBox(
                      height: 80,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Row(
                          children: [
                            Expanded(
                              child: DefaultTextStyle(
                                style: const TextStyle(
                                  color: AppColors.primaryNavy,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                ),
                                child: appBar.title ?? const SizedBox(),
                              ),
                            ),
                            IconTheme(
                              data: const IconThemeData(
                                color: AppColors.primaryNavy,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: appBar.actions ?? [],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ColoredBox(color: Colors.white, child: body),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
