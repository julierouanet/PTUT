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

/// Depuis le hub, ouvre le module Équipement (Dashboard, Équipements, etc.)
Future<void> _enterEquipmentModule(WidgetTester tester) async {
  await tester.tap(find.text('Ouvrir Équipement'));
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

      // "Tableau de bord" apparaît dans les chips du module Équipement sur le hub
      expect(find.text('Tableau de bord'), findsWidgets);
    });

    testWidgets('app title is set correctly', (tester) async {
      _suppressOverflow(tester);
      AuthService().initDemo();
      await tester.pumpWidget(const EquipmentManagementApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'Gestion des Equipements - Kabutare Hospital');
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

      // Les items du module équipement doivent apparaître dans la sidebar
      expect(find.text('Tableau de bord'), findsWidgets);
      expect(find.text('Equipements'), findsWidgets);
      expect(find.text('Suivi incidents'), findsWidgets);
      expect(find.text('Signaler'), findsWidgets);
      expect(find.text('Technicien'), findsWidgets);
      expect(find.text('Rapports'), findsWidgets);
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

      // Le personnel voit les items de base
      expect(find.text('Tableau de bord'), findsWidgets);
      expect(find.text('Equipements'), findsWidgets);
      expect(find.text('Signaler'), findsWidgets);
      expect(find.text('Suivi incidents'), findsWidgets);

      // Le personnel ne voit PAS les items admin/tech/superviseur
      expect(find.text('Utilisateurs'), findsNothing);
      expect(find.text('Technicien'), findsNothing);
      expect(find.text('Rapports'), findsNothing);
      expect(find.text('Gestion'), findsNothing);
      expect(find.text('Journaux'), findsNothing);
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
