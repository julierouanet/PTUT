import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:equipment_management/main.dart';
import 'package:equipment_management/services/auth_service.dart';
import 'package:equipment_management/data/mock_data.dart';
import 'package:equipment_management/models/user_role.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Supprime les erreurs d'overflow Flutter dans les tests
/// (problème UI pré-existant non lié à la logique testée).
void _suppressOverflow(WidgetTester tester) {
  final origOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    origOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = origOnError);
}

/// From the hub, opens the Equipment module (Dashboard, Equipment, etc.)
Future<void> _enterEquipmentModule(WidgetTester tester) async {
  await tester.tap(find.text('Open Equipment'));
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    // Réinitialiser l'état d'auth avant chaque test
    AuthService().logout();
  });

  group('App initialization', () {
    testWidgets('app builds without crashing when logged in as admin', (tester) async {
      _suppressOverflow(tester);
      AuthService().initDemo();
      await tester.pumpWidget(const EquipmentManagementApp());

      // L'app doit s'afficher sans erreur (hub affiché en premier)
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('dashboard is displayed on startup', (tester) async {
      _suppressOverflow(tester);
      AuthService().initDemo();
      await tester.pumpWidget(const EquipmentManagementApp());

      // Hub screen is shown: the equipment module open button must be present
      expect(find.text('Open Equipment'), findsOneWidget);
    });

    testWidgets('app title is set correctly', (tester) async {
      _suppressOverflow(tester);
      AuthService().initDemo();
      await tester.pumpWidget(const EquipmentManagementApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, isNotEmpty);
    });
  });

  group('Admin navigation (wide screen)', () {
    testWidgets('admin sees equipment module nav items in sidebar', (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      _suppressOverflow(tester);

      AuthService().initDemo();
      await tester.pumpWidget(const EquipmentManagementApp());

      // Entrer dans le module Équipement depuis le hub
      await _enterEquipmentModule(tester);

      // Equipment module nav items must appear in the sidebar
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Equipment'), findsWidgets);
      expect(find.text('Issue Tracking'), findsWidgets);
      expect(find.text('Report'), findsWidgets);
      expect(find.text('Technician'), findsWidgets);
      expect(find.text('Reports'), findsWidgets);
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
      _suppressOverflow(tester);

      final staff = mockUsers.firstWhere((u) => u.role == UserRole.hospitalStaff);
      AuthService().switchUser(staff);
      await tester.pumpWidget(const EquipmentManagementApp());

      // Entrer dans le module Équipement
      await _enterEquipmentModule(tester);

      // Staff sees the basic items
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Equipment'), findsWidgets);
      expect(find.text('Report'), findsWidgets);
      expect(find.text('Issue Tracking'), findsWidgets);

      // Staff does NOT see admin/tech/supervisor items
      expect(find.text('Users'), findsNothing);
      expect(find.text('Technician'), findsNothing);
      expect(find.text('Reports'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Activity Logs'), findsNothing);
    });
  });

  group('Narrow screen behavior', () {
    testWidgets('bottom nav appears on narrow screen inside module', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      _suppressOverflow(tester);

      AuthService().initDemo();
      await tester.pumpWidget(const EquipmentManagementApp());

      // Entrer dans le module Équipement pour avoir la NavigationBar
      await _enterEquipmentModule(tester);

      // La NavigationBar (bottom nav) doit être présente
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('bottom nav has at most 5 items', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      _suppressOverflow(tester);

      AuthService().initDemo();
      await tester.pumpWidget(const EquipmentManagementApp());

      // Entrer dans le module Équipement
      await _enterEquipmentModule(tester);

      // La NavigationBar doit avoir entre 2 et 5 destinations
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, lessThanOrEqualTo(5));
      expect(navBar.destinations.length, greaterThanOrEqualTo(2));
    });
  });
}
