import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperfeeds_mobile/models/models.dart';
import 'package:hyperfeeds_mobile/screens/employee/staff_scaffold.dart';
import 'package:hyperfeeds_mobile/database/database_web.dart';

void main() {
  test(
    'Staff roles survive browser session restoration, including legacy values',
    () {
      for (final role in [
        UserRole.mainManager,
        UserRole.branchManager,
        UserRole.customerService,
      ]) {
        expect(UserRole.fromString(role.toJson()), role);
        expect(UserRole.fromString(role.name.toUpperCase()), role);
      }
    },
  );
  test('Browser cache handles an empty session', () async {
    final db = AppDatabase();
    expect(await db.loadBranches(), isEmpty);
    expect(await db.loadCategories(), isEmpty);
    await db.clearProducts();
    expect(await db.loadProducts(), isEmpty);
  });
  for (final width in [1440.0, 390.0]) {
    testWidgets('Staff navigation remains usable at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int page = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return StaffScaffold(
                appBar: AppBar(title: const Text('Main Manager')),
                body: Center(child: Text('Content $page')),
                bottomNavigationBar: NavigationBar(
                  selectedIndex: page,
                  onDestinationSelected: (v) => setState(() => page = v),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.settings),
                      label: 'Configs',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.badge),
                      label: 'Users',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.egg),
                      label: 'Chicks',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory),
                      label: 'Requests',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.notifications),
                      label: 'Notify',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.campaign),
                      label: 'Ads',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Staff workspace'),
        width >= 1000 ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.text('Users'));
      await tester.pumpAndSettle();
      expect(find.text('Content 1'), findsOneWidget);
      await tester.tap(find.text('Ads'));
      await tester.pumpAndSettle();
      expect(find.text('Content 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
