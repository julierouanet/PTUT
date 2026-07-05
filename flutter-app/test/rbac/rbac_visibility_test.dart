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
import 'package:equipment_management/services/data_service.dart';
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
/// - Techniciens       : déjà dans MainScaffold (redirection auto), pompe
///                       pour que le postFrameCallback traite _initialScreenType.
/// - Admin/supervisor  : bouton "Open Equipment" — scrolle si hors écran.
/// - hospitalStaff     : OutlinedButton "Mes incidents actifs" (hub simplifié).
Future<void> _enterEquipmentModule(WidgetTester tester) async {
  // Les techniciens sont redirigés directement dans MainScaffold au démarrage.
  if (find.byType(MainScaffold).evaluate().isNotEmpty) {
    await tester.pump(); // laisse le postFrameCallback appliquer _initialScreenType
    return;
  }

  final btn = find.text('Open Equipment');
  if (btn.evaluate().isNotEmpty) {
    // Scroll si le bouton est hors de la zone visible (hub manager view).
    await tester.ensureVisible(btn);
    await tester.pump();
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
      'technician_biomedical est redirigé directement dans le module équipement (sans passer par le hub)',
      (tester) async {
        _suppressOverflow(tester);
        AuthService().switchUser(_techBio);

        await tester.pumpWidget(const EquipmentManagementApp());
        await tester.pump();
        // Pompe supplémentaire pour que le postFrameCallback de MainScaffold
        // applique _initialScreenType = issueTracking.
        await tester.pump();

        // _applyRoleRedirect envoie les techniciens directement dans MainScaffold.
        expect(find.byType(MainScaffold), findsOneWidget);
        // Le hub n'est pas affiché pour les techniciens.
        expect(find.text('My workplan for today'), findsNothing);
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

    testWidgets(
      'supervisor : nav Dashboard → Reports en tête, Analytics présent, PAS de page Technician',
      (tester) async {
        _setDesktopSize(tester);
        _suppressOverflow(tester);
        AuthService().switchUser(_supervisor);
        // Simule le seed sidebar_config du supervisor servi par db-service
        DataService().sidebarOrder = {
          'supervisor': ['dashboard', 'reports', 'analytics', 'equipment', 'issueTracking', 'issueForm'],
        };
        addTearDown(() => DataService().sidebarOrder = {});

        await tester.pumpWidget(const EquipmentManagementApp());
        await _enterEquipmentModule(tester);

        // Rapports et Analytique accessibles (generateReports)
        expect(find.text('Reports'),   findsWidgets);
        expect(find.text('Analytics'), findsWidgets);

        // Plus de page technicien (ni updateRepairs ni approveRequests)
        expect(find.text('Technician'), findsNothing);

        // Ordre : Dashboard au-dessus de Reports, Reports au-dessus d'Equipment
        final dashboardY = tester.getTopLeft(find.text('Dashboard').first).dy;
        final reportsY   = tester.getTopLeft(find.text('Reports').first).dy;
        final equipmentY = tester.getTopLeft(find.text('Equipment').first).dy;
        expect(dashboardY, lessThan(reportsY));
        expect(reportsY,   lessThan(equipmentY));
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

    // NOTE : Ce test était fusionné (admin + staff dans le même pumpWidget).
    // Il a été scindé en deux parce que _MainScaffoldState ne possède pas
    // de didUpdateWidget → le second pumpWidget réutilisait l'arbre admin sans
    // recalculer _navItems, donnant 5 destinations pour le staff aussi.
    // Chaque testWidgets commence avec un arbre widget vierge, ce qui garantit
    // une mesure indépendante et juste.

    testWidgets(
      'admin a 5 destinations nav en mode mobile (6 items cappés à 5 par _buildBottomNav)',
      (tester) async {
        _setMobileSize(tester);
        _suppressOverflow(tester);
        AuthService().initDemo();

        await tester.pumpWidget(const EquipmentManagementApp());
        await _enterEquipmentModule(tester);

        final adminNavBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        // Admin a 6 items dans _equipmentScreens, NavigationBar.take(5) → 5.
        expect(adminNavBar.destinations.length, equals(5));
      },
    );

    testWidgets(
      'hospitalStaff a 4 destinations nav (moins que les 5 de l\'admin)',
      (tester) async {
        _setMobileSize(tester);
        _suppressOverflow(tester);
        AuthService().switchUser(_hospitalStaff);

        await tester.pumpWidget(const EquipmentManagementApp());
        await _enterEquipmentModule(tester);

        final staffNavBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        // Staff : Dashboard, Équipements, Incidents, Signaler = 4 items.
        // Technician (updateRepairs) et Reports (generateReports) sont absents.
        expect(staffNavBar.destinations.length, equals(4));
        expect(staffNavBar.destinations.length, lessThan(5)); // < admin's 5
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

        // Le titre du dashboard est visible dans la navigation
        expect(find.text('Dashboard'), findsWidgets);

        // DashboardScreen expose un bouton refresh (IconButton) mais pas de FAB.
        // Le FAB "Signaler" est dans HomeHubScreen, pas dans MainScaffold.
        expect(find.byIcon(Icons.refresh), findsWidgets);
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
      'technician_biomedical arrive sur le suivi des incidents (redirection automatique)',
      (tester) async {
        _suppressOverflow(tester);
        AuthService().switchUser(_techBio);

        await tester.pumpWidget(const EquipmentManagementApp());
        await tester.pump();
        await tester.pump(); // postFrameCallback → _initialScreenType = issueTracking

        // Les techniciens sont redirigés vers IssueTrackingScreen, pas DashboardScreen.
        expect(find.byType(MainScaffold), findsOneWidget);
        // "Issue Tracking" apparaît dans la navigation (sidebar ou bottom nav).
        expect(find.text('Issue Tracking'), findsWidgets);
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

    test('supervisor = consultation + rapports : generateReports mais PAS de validation', () {
      AuthService().switchUser(_supervisor);

      expect(AuthService().hasPermission(Permission.viewEquipment),   isTrue);
      expect(AuthService().hasPermission(Permission.reportIssue),     isTrue);
      expect(AuthService().hasPermission(Permission.trackIssues),     isTrue);
      expect(AuthService().hasPermission(Permission.viewInterventionDocuments), isTrue);
      expect(AuthService().hasPermission(Permission.generateReports), isTrue);
      expect(AuthService().hasPermission(Permission.approveRequests), isFalse);
      expect(AuthService().hasPermission(Permission.assignTasks),     isFalse);
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
