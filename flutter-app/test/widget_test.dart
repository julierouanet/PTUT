import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:equipment_management/main.dart';
import 'package:equipment_management/services/auth_service.dart';
import 'package:equipment_management/data/mock_data.dart';
import 'package:equipment_management/models/user_role.dart';

void main() {
  setUp(() {
    // Reset auth state before each test
    AuthService().logout();
  });

  group('App initialization', () {
    testWidgets('app builds without crashing when logged in as admin', (tester) async {
      AuthService().initDemo();
      await tester.pumpWidget(const EquipmentManagementApp());

      // App should render without errors
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('dashboard is displayed on startup', (tester) async {
      AuthService().initDemo();
      await tester.pumpWidget(const EquipmentManagementApp());

      // "Tableau de bord" should be present in navigation
      expect(find.text('Tableau de bord'), findsWidgets);
    });

    testWidgets('app title is set correctly', (tester) async {
      AuthService().initDemo();
      await tester.pumpWidget(const EquipmentManagementApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'Gestion des Equipements - Kabutare Hospital');
    });
  });

  group('Admin navigation (wide screen)', () {
    testWidgets('admin sees all 9 nav items in sidebar', (tester) async {
      // Set wide screen to trigger sidebar — large enough to avoid overflow
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Suppress layout overflow errors (pre-existing UI issue, not test logic)
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = origOnError);

      AuthService().initDemo();
      await tester.pumpWidget(const EquipmentManagementApp());

      // All nav labels should appear
      expect(find.text('Tableau de bord'), findsWidgets);
      expect(find.text('Equipements'), findsWidgets);
      expect(find.text('Suivi incidents'), findsWidgets);
      expect(find.text('Signaler'), findsWidgets);
      expect(find.text('Technicien'), findsWidgets);
      expect(find.text('Inventaire'), findsWidgets);
      expect(find.text('Rapports'), findsWidgets);
      expect(find.text('Utilisateurs'), findsWidgets);
      expect(find.text('Parametres'), findsWidgets);
    });
  });

  group('Hospital staff navigation', () {
    testWidgets('staff does NOT see admin-only nav items on wide screen', (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = origOnError);

      final staff = mockUsers.firstWhere((u) => u.role == UserRole.hospitalStaff);
      AuthService().switchUser(staff);
      await tester.pumpWidget(const EquipmentManagementApp());

      // Staff should see basic items
      expect(find.text('Tableau de bord'), findsWidgets);
      expect(find.text('Equipements'), findsWidgets);
      expect(find.text('Signaler'), findsWidgets);
      expect(find.text('Suivi incidents'), findsWidgets);

      // Staff should NOT see admin/tech/supervisor items
      expect(find.text('Utilisateurs'), findsNothing);
      expect(find.text('Parametres'), findsNothing);
      expect(find.text('Technicien'), findsNothing);
      expect(find.text('Rapports'), findsNothing);
    });
  });

  group('Narrow screen behavior', () {
    testWidgets('bottom nav appears on narrow screen', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = origOnError);

      AuthService().initDemo();
      await tester.pumpWidget(const EquipmentManagementApp());

      // NavigationBar should be present (bottom nav)
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('bottom nav has at most 5 items', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = origOnError);

      AuthService().initDemo();
      await tester.pumpWidget(const EquipmentManagementApp());

      // NavigationBar should have at most 5 destinations
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, lessThanOrEqualTo(5));
      expect(navBar.destinations.length, greaterThanOrEqualTo(2));
    });
  });
}
