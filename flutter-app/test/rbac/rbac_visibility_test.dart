// ── Tests de visibilité RBAC — Hôpital de Kabutare ──────────────────────────
//
// Vérifient que l'UI affiche ou masque les éléments selon le rôle Keycloak.
// N'utilisent que des données mock (AuthService.switchUser / initDemo) —
// aucun appel réseau réel. Chaque test réinitialise AuthService en setUp.
//
// Conventions :
//   • Texte entre guillemets = valeur de la clé l10n en anglais (locale de test)
//   • physicalSize 1800×1000 = mode desktop (sidebar visible)
//   • physicalSize 400×800  = mode mobile  (bottom nav / drawer)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:equipment_management/main.dart';
import 'package:equipment_management/models/user.dart';
import 'package:equipment_management/services/auth_service.dart';
import 'package:equipment_management/data/mock_data.dart';
import 'package:equipment_management/models/user_role.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Supprime les erreurs d'overflow dans les tests — problème UI non lié au RBAC.
void _suppressOverflow(WidgetTester tester) {
  final orig = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    orig?.call(d);
  };
  addTearDown(() => FlutterError.onError = orig);
}

/// Configure l'écran en mode desktop (largeur 1800 px) — fait apparaître la sidebar.
void _setDesktopSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1800, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Configure l'écran en mode mobile (largeur 400 px) — fait apparaître la bottom nav.
void _setMobileSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Entre dans le module Équipement depuis le Hub.
/// - Admin/supervisor/tech : bouton "Open Equipment" sur la carte module.
/// - hospitalStaff         : OutlinedButton "Mes incidents actifs" (hub simplifié).
Future<void> _enterEquipmentModule(WidgetTester tester) async {
  final btn = find.text('Open Equipment');
  if (btn.evaluate().isNotEmpty) {
    await tester.tap(btn);
  } else {
    await tester.tap(find.byType(OutlinedButton).first);
  }
  await tester.pump();
}

// ── Données mock ─────────────────────────────────────────────────────────────

User get _supervisor    => mockUsers.firstWhere((u) => u.hasRole(UserRole.supervisor));
User get _techBio       => mockUsers.firstWhere((u) => u.hasRole(UserRole.technicianBiomedical));
User get _hospitalStaff => mockUsers.firstWhere((u) => u.hasRole(UserRole.hospitalStaff));

// =============================================================================
// Tests principaux
// =============================================================================

void main() {
  setUp(() {
    // Réinitialiser l'état d'authentification avant chaque test
    AuthService().logout();
  });

  // ===========================================================================
  // 1. Hub screen — routage de la vue par rôle
  // ===========================================================================

  group('Hub — routage de la vue par rôle', () {
    testWidgets(
      'hospitalStaff voit la vue simplifiée ("What would you like to do?")',
      (tester) async {
        _suppressOverflow(tester);
        AuthService().switchUser(_hospitalStaff);

        await tester.pumpWidget(const EquipmentManagementApp());
        await tester.pump();

        // La vue staff affiche son titre spécifique
        expect(find.text('What would you like to do?'), findsOneWidget);
        // Pas de "Global Dashboard" (vue manager)
        expect(find.text('Global Dashboard'), findsNothing);
        // Pas de "My workplan for today" (vue tech)
        expect(find.text('My workplan for today'), findsNothing);
      },
    );

    testWidgets(
      'technician_biomedical voit le plan de travail ("My workplan for today")',
      (tester) async {
        _suppressOverflow(tester);
        AuthService().switchUser(_techBio);

        await tester.pumpWidget(const EquipmentManagementApp());
        await tester.pump();

        expect(find.text('My workplan for today'), findsOneWidget);
        expect(find.text('What would you like to do?'), findsNothing);
        expect(find.text('Global Dashboard'), findsNothing);
      },
    );

    testWidgets(
      'admin voit le tableau de bord manager ("Global Dashboard")',
      (tester) async {
        _suppressOverflow(tester);
        AuthService().initDemo(); // admin par défaut

        await tester.pumpWidget(const EquipmentManagementApp());
        await tester.pump();

        expect(find.text('Global Dashboard'), findsOneWidget);
        expect(find.text('What would you like to do?'), findsNothing);
        expect(find.text('My workplan for today'), findsNothing);
      },
    );

    testWidgets(
      'supervisor voit le tableau de bord manager ("Global Dashboard")',
      (tester) async {
        _suppressOverflow(tester);
        AuthService().switchUser(_supervisor);

        await tester.pumpWidget(const EquipmentManagementApp());
        await tester.pump();

        expect(find.text('Global Dashboard'), findsOneWidget);
        expect(find.text('What would you like to do?'), findsNothing);
      },
    );
  });

  // ===========================================================================
  // 2. Hub screen — visibilité des cartes modules (accès rapide)
  // ===========================================================================

  group('Hub — visibilité des cartes modules RBAC', () {
    testWidgets(
      'admin voit les 3 cartes (Equipment, Inventory, Settings)',
      (tester) async {
        _suppressOverflow(tester);
        AuthService().initDemo(); // admin

        await tester.pumpWidget(const EquipmentManagementApp());
        await tester.pump();

        // L'admin a toutes les permissions : 3 modules visibles
        expect(find.text('Equipment'),  findsWidgets); // au moins 1
        expect(find.text('Inventory'),  findsWidgets);
        expect(find.text('Settings'),   findsWidgets);
        // La section "Quick access to modules" est visible
        expect(find.text('Quick access to modules'), findsOneWidget);
      },
    );

    testWidgets(
      'supervisor voit la carte Equipment mais PAS Inventory ni Settings',
      (tester) async {
        _suppressOverflow(tester);
        AuthService().switchUser(_supervisor);
        // Supervisor : viewEquipment, reportIssue, trackIssues, approveRequests, assignTasks
        // Pas de viewInventory → pas de carte Inventory
        // Pas de manageDepartments/manageUsers → pas de carte Settings

        await tester.pumpWidget(const EquipmentManagementApp());
        await tester.pump();

        // "Quick access to modules" visible (view manager)
        expect(find.text('Quick access to modules'), findsOneWidget);

        // Equipment card visible
        expect(find.text('Equipment'), findsWidgets);

        // Inventory et Settings absents dans la vue hub (la carte module n'est pas affichée)
        // Note : "Inventory" peut apparaître dans la nav si le module équipement est ouvert,
        // mais ici on est au hub — la carte "Inventory Module" n'existe pas.
        // On vérifie l'absence de la carte Inventory dans le contexte hub.
        expect(find.textContaining('Inventory'), findsNothing);
        expect(find.textContaining('Settings'), findsNothing);
      },
    );

    testWidgets(
      'hospitalStaff ne voit PAS les cartes modules (vue simplifiée)',
      (tester) async {
        _suppressOverflow(tester);
        AuthService().switchUser(_hospitalStaff);

        await tester.pumpWidget(const EquipmentManagementApp());
        await tester.pump();

        // La vue staff n'affiche pas de cartes modules
        expect(find.text('Quick access to modules'), findsNothing);
        expect(find.text('Global Dashboard'), findsNothing);

        // L'accès rapide aux incidents actifs est présent (bouton hub staff)
        // Le FAB "Report" est toujours là
        expect(find.byType(FloatingActionButton), findsOneWidget);
      },
    );

    testWidgets(
      'technician_biomedical ne voit PAS les cartes modules (vue workplan)',
      (tester) async {
        _suppressOverflow(tester);
        AuthService().switchUser(_techBio);

        await tester.pumpWidget(const EquipmentManagementApp());
        await tester.pump();

        // Le workplan tech n'est pas la vue manager → pas de cartes modules
        expect(find.text('Quick access to modules'), findsNothing);
        expect(find.text('Global Dashboard'), findsNothing);
      },
    );
  });

  // ===========================================================================
  // 3. Navigation sidebar — éléments visibles par rôle (mode desktop)
  // ===========================================================================

  group('Navigation sidebar — RBAC (mode desktop ≥ 800 px)', () {
    testWidgets(
      'admin voit tous les éléments de navigation dans le module équipement',
      (tester) async {
        _setDesktopSize(tester);
        _suppressOverflow(tester);
        AuthService().initDemo(); // admin

        await tester.pumpWidget(const EquipmentManagementApp());
        await _enterEquipmentModule(tester);

        // Éléments attendus pour l'admin
        expect(find.text('Dashboard'),      findsWidgets);
        expect(find.text('Equipment'),      findsWidgets);
        expect(find.text('Issue Tracking'), findsWidgets);
        expect(find.text('Report'),         findsWidgets);
        expect(find.text('Technician'),     findsWidgets);
        expect(find.text('Reports'),        findsWidgets);
      },
    );

    testWidgets(
      'hospitalStaff ne voit PAS Users, Technician, Reports, Admin dans la sidebar',
      (tester) async {
        _setDesktopSize(tester);
        _suppressOverflow(tester);
        AuthService().switchUser(_hospitalStaff);

        await tester.pumpWidget(const EquipmentManagementApp());
        await _enterEquipmentModule(tester);

        // Éléments de base disponibles pour le personnel soignant
        expect(find.text('Dashboard'),      findsWidgets);
        expect(find.text('Equipment'),      findsWidgets);
        expect(find.text('Report'),         findsWidgets);
        expect(find.text('Issue Tracking'), findsWidgets);

        // Éléments admin/supervisor/tech — absents pour hospitalStaff
        expect(find.text('Users'),          findsNothing);
        expect(find.text('Technician'),     findsNothing);
        expect(find.text('Reports'),        findsNothing);
        expect(find.text('Settings'),       findsNothing);
        expect(find.text('Activity Logs'),  findsNothing);
      },
    );

    testWidgets(
      'technician_biomedical voit Technician mais PAS Users ni Admin',
      (tester) async {
        _setDesktopSize(tester);
        _suppressOverflow(tester);
        AuthService().switchUser(_techBio);

        await tester.pumpWidget(const EquipmentManagementApp());
        await _enterEquipmentModule(tester);

        // Les techniciens ont accès à l'écran Technician Update
        expect(find.text('Technician'), findsWidgets);

        // Mais pas à l'administration ni aux rapports
        expect(find.text('Users'),         findsNothing);
        expect(find.text('Activity Logs'), findsNothing);
      },
    );
  });

  // ===========================================================================
  // 4. Navigation mobile — bottom nav (mode mobile < 800 px)
  // ===========================================================================

  group('Navigation mobile — bottom nav RBAC', () {
    testWidgets(
      'admin a une NavigationBar dans le module équipement en mode mobile',
      (tester) async {
        _setMobileSize(tester);
        _suppressOverflow(tester);
        AuthService().initDemo();

        await tester.pumpWidget(const EquipmentManagementApp());
        await _enterEquipmentModule(tester);

        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );

    testWidgets(
      'hospitalStaff a une NavigationBar en mode mobile (≤ 5 destinations)',
      (tester) async {
        _setMobileSize(tester);
        _suppressOverflow(tester);
        AuthService().switchUser(_hospitalStaff);

        await tester.pumpWidget(const EquipmentManagementApp());
        await _enterEquipmentModule(tester);

        final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        // Moins de destinations pour hospitalStaff
        expect(navBar.destinations.length, lessThanOrEqualTo(5));
        expect(navBar.destinations.length, greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      'hospitalStaff a moins de destinations nav que admin',
      (tester) async {
        _setMobileSize(tester);
        _suppressOverflow(tester);

        // Mesurer le nombre de destinations pour admin
        AuthService().initDemo();
        await tester.pumpWidget(const EquipmentManagementApp());
        await _enterEquipmentModule(tester);

        final adminNavBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        final adminDestCount = adminNavBar.destinations.length;

        // Réinitialiser et mesurer pour hospitalStaff
        AuthService().logout();
        AuthService().switchUser(_hospitalStaff);
        await tester.pumpWidget(const EquipmentManagementApp());
        await _enterEquipmentModule(tester);

        final staffNavBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        final staffDestCount = staffNavBar.destinations.length;

        // Le staff a strictement moins de destinations nav que l'admin
        expect(staffDestCount, lessThan(adminDestCount));
      },
    );
  });

  // ===========================================================================
  // 5. Dashboard screen — différenciation de la vue par rôle
  // ===========================================================================

  group('Dashboard — contenu conditionnel par rôle', () {
    testWidgets(
      'hospitalStaff voit une vue dashboard allégée (météo hôpital)',
      (tester) async {
        _suppressOverflow(tester);
        AuthService().switchUser(_hospitalStaff);

        await tester.pumpWidget(const EquipmentManagementApp());
        await _enterEquipmentModule(tester);

        // Le titre du dashboard est visible
        expect(find.text('Dashboard'), findsWidgets);

        // La vue staff ne dispose pas d'indicateurs KPI opérationnels complexes
        // (pas de StatCards avec "Operational" / "Maintenance" counts)
        // Elle ne contient que le widget météo + bouton signalement
        expect(find.byType(FloatingActionButton), findsOneWidget);
      },
    );

    testWidgets(
      'admin voit le dashboard avec le bouton refresh',
      (tester) async {
        _suppressOverflow(tester);
        AuthService().initDemo();

        await tester.pumpWidget(const EquipmentManagementApp());
        await _enterEquipmentModule(tester);

        // Le titre Dashboard est visible
        expect(find.text('Dashboard'), findsWidgets);
        // L'admin dispose d'un bouton refresh (IconButton dans le header)
        expect(find.byIcon(Icons.refresh), findsWidgets);
      },
    );

    testWidgets(
      'technician_biomedical voit le dashboard avec indicateurs opérationnels',
      (tester) async {
        _suppressOverflow(tester);
        AuthService().switchUser(_techBio);

        await tester.pumpWidget(const EquipmentManagementApp());
        await _enterEquipmentModule(tester);

        // Le dashboard tech affiche "Dashboard" et le bouton refresh
        expect(find.text('Dashboard'), findsWidgets);
        expect(find.byIcon(Icons.refresh), findsWidgets);
      },
    );
  });

  // ===========================================================================
  // 6. Vérification des permissions dans AuthService
  //    (tests unitaires purs — pas de widget rendering)
  // ===========================================================================

  group('AuthService — permissions RBAC sans widget', () {
    test('hospitalStaff ne peut PAS accéder à manageUsers', () {
      AuthService().switchUser(_hospitalStaff);

      expect(AuthService().hasPermission(Permission.manageUsers),    isFalse);
      expect(AuthService().hasPermission(Permission.manageDepartments), isFalse);
      expect(AuthService().hasPermission(Permission.viewInventory),  isFalse);
      expect(AuthService().hasPermission(Permission.updateRepairs),  isFalse);
      expect(AuthService().hasPermission(Permission.approveRequests), isFalse);
    });

    test('hospitalStaff PEUT signaler un incident et voir les équipements', () {
      AuthService().switchUser(_hospitalStaff);

      expect(AuthService().hasPermission(Permission.viewEquipment), isTrue);
      expect(AuthService().hasPermission(Permission.reportIssue),   isTrue);
      expect(AuthService().hasPermission(Permission.trackIssues),   isTrue);
    });

    test('admin a TOUTES les permissions', () {
      AuthService().initDemo(); // admin

      for (final perm in Permission.values) {
        expect(
          AuthService().hasPermission(perm),
          isTrue,
          reason: 'Admin doit avoir la permission ${perm.name}',
        );
      }
    });

    test('technician_biomedical peut mettre à jour une réparation mais PAS gérer des utilisateurs', () {
      AuthService().switchUser(_techBio);

      expect(AuthService().hasPermission(Permission.updateRepairs), isTrue);
      expect(AuthService().hasPermission(Permission.registerParts), isTrue);
      expect(AuthService().hasPermission(Permission.manageUsers),   isFalse);
      expect(AuthService().hasPermission(Permission.viewInventory), isFalse);
    });

    test('supervisor peut approuver et assigner mais PAS mettre à jour des réparations', () {
      AuthService().switchUser(_supervisor);

      expect(AuthService().hasPermission(Permission.approveRequests), isTrue);
      expect(AuthService().hasPermission(Permission.assignTasks),     isTrue);
      expect(AuthService().hasPermission(Permission.updateRepairs),   isFalse);
      expect(AuthService().hasPermission(Permission.manageUsers),     isFalse);
      expect(AuthService().hasPermission(Permission.viewInventory),   isFalse);
    });

    test('getters de commodité canXxx correspondent à hasPermission', () {
      AuthService().initDemo(); // admin

      expect(AuthService().canViewEquipment, isTrue);
      expect(AuthService().canManageUsers,   isTrue);
      expect(AuthService().canViewInventory, isTrue);
      expect(AuthService().canUpdateRepairs, isTrue);

      AuthService().logout();
      AuthService().switchUser(_hospitalStaff);

      expect(AuthService().canViewEquipment, isTrue);
      expect(AuthService().canManageUsers,   isFalse);
      expect(AuthService().canViewInventory, isFalse);
      expect(AuthService().canUpdateRepairs, isFalse);
    });
  });

  // ===========================================================================
  // 7. Identité du rôle principal (primaryRole) — logique de priorité
  // ===========================================================================

  group('AuthService — primaryRole (logique de priorité RBAC)', () {
    test('admin a le primaryRole admin', () {
      AuthService().initDemo();
      expect(AuthService().primaryRole, UserRole.admin);
    });

    test('supervisor a le primaryRole supervisor', () {
      AuthService().switchUser(_supervisor);
      expect(AuthService().primaryRole, UserRole.supervisor);
    });

    test('technician_biomedical a le primaryRole technicianBiomedical', () {
      AuthService().switchUser(_techBio);
      expect(AuthService().primaryRole, UserRole.technicianBiomedical);
    });

    test('hospitalStaff a le primaryRole hospitalStaff', () {
      AuthService().switchUser(_hospitalStaff);
      expect(AuthService().primaryRole, UserRole.hospitalStaff);
    });

    test('utilisateur non connecté a un primaryRole null', () {
      // AuthService est déjà logout dans setUp
      expect(AuthService().primaryRole, isNull);
      expect(AuthService().isLoggedIn,  isFalse);
    });
  });
}
