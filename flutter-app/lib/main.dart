import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/equipment_hub_screen.dart';
import 'screens/issue_tracking_screen.dart';
import 'screens/issue_form_screen.dart';
import 'screens/technician_update_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/account_settings_screen.dart';
import 'screens/logs_screen.dart';
import 'services/auth_service.dart';
import 'services/data_service.dart';
import 'services/notification_service.dart';
import 'services/os_notification_service.dart';
import 'services/api_client.dart';
import 'models/user_role.dart';
import 'models/nav_item.dart';
import 'models/issue.dart';
import 'providers/locale_provider.dart';
import 'widgets/issue_category_selector.dart';
import 'widgets/notification_preferences_dialog.dart';
import 'widgets/role_request_dialog.dart';
import 'widgets/layout/app_sidebar.dart';
import 'widgets/layout/app_top_bar.dart';
import 'widgets/layout/app_bottom_nav.dart';
import 'screens/home_hub_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/backup_management_screen.dart';
import 'screens/debug_test_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleProvider().loadSavedLocale();
  await OsNotificationService.initialize();

  // Configurer le callback de session expirée
  ApiClient.onSessionExpired = () {
    AuthService().handleSessionExpired();
  };

  // Tenter l'auto-login si des tokens sont stockés
  try {
    if (await ApiClient.hasStoredTokens()) {
      final restored = await AuthService().restoreSession();
      if (restored) {
        await ApiClient.armProactiveRefreshFromStorage();
        await DataService().loadAll();
        NotificationService().generateFromLoadedData();
      }
    }
  } catch (_) {
    // En cas d'erreur (secure storage indisponible, etc.), afficher le login normalement
  }

  runApp(const EquipmentManagementApp());
}

class EquipmentManagementApp extends StatelessWidget {
  const EquipmentManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleProvider(),
      builder: (context, _) {
        return MaterialApp(
          title: 'Gestion des Equipements - Kabutare Hospital',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: LocaleProvider().locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('fr'),
            Locale('en'),
          ],
          home: ListenableBuilder(
            listenable: AuthService(),
            builder: (context, _) {
              if (!AuthService().isLoggedIn) return const LoginScreen();
              return ListenableBuilder(
                listenable: DataService(),
                builder: (context, _) {
                  if (DataService().isLoading) return const _LoadingScreen();
                  return const _AppRoot();
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.loadingData),
          ],
        ),
      ),
    );
  }
}

// ── Hub root — gère la sélection du module ──────────────────────────────────

enum _HubModule { equipment, settings, inventory }

class _AppRoot extends StatefulWidget {
  const _AppRoot();
  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  _HubModule? _activeModule;
  // Écran de démarrage injecté lors de la redirection automatique par rôle
  ScreenType? _initialScreenType;
  // Filtre département injecté lors de la navigation depuis le hub staff
  String? _initialDepartmentFilter;

  @override
  void initState() {
    super.initState();
    _applyRoleRedirect();
    // Affiche la modal de préférences email si c'est la 1ère connexion de cet utilisateur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AuthService().needsPreferencesSetup) {
        AuthService().clearPreferencesSetupFlag();
        showNotificationPreferencesDialog(context, isFirstSetup: true);
      }
      if (AuthService().needsRoleSelectionSetup) {
        AuthService().clearRoleSelectionSetupFlag();
        showRoleRequestDialog(context, isFirstSetup: true);
      }
    });
  }

  /// Redirige les techniciens directement vers le suivi des incidents
  /// sans passer par le hub — supprime un clic inutile au démarrage.
  void _applyRoleRedirect() {
    const techRoles = {
      UserRole.technician,
      UserRole.technicianBiomedical,
      UserRole.technicianIt,
      UserRole.technicianInfra,
    };
    final role = AuthService().primaryRole;
    if (role != null && techRoles.contains(role)) {
      _activeModule = _HubModule.equipment;
      _initialScreenType = ScreenType.issueTracking;
    }
  }

  static const _equipmentScreens = [
    ScreenType.dashboard,
    ScreenType.equipment,
    ScreenType.issueTracking,
    ScreenType.issueForm,
    ScreenType.technician,
    // Analytique accessible depuis le module équipement : indispensable au
    // supervisor (generateReports) qui n'a pas accès au module Réglages.
    ScreenType.analytics,
  ];
  static const _settingsScreens = [
    ScreenType.settings,
    ScreenType.users,
    ScreenType.logs,
    ScreenType.analytics,
    ScreenType.backupManagement,
    ScreenType.debugTest,
  ];
  static const _inventoryScreens = [ScreenType.inventory];

  List<ScreenType>? _filterFor(_HubModule m) {
    switch (m) {
      case _HubModule.equipment: return _equipmentScreens;
      case _HubModule.settings:  return _settingsScreens;
      case _HubModule.inventory: return _inventoryScreens;
    }
  }

  /// Bascule directement sur l'écran de suivi des incidents, avec un filtre
  /// département optionnel — utilisé par les boutons "incidents" du hub staff.
  void _goToIssueTracking({String? departmentFilter}) {
    setState(() {
      _activeModule = _HubModule.equipment;
      _initialScreenType = ScreenType.issueTracking;
      _initialDepartmentFilter = departmentFilter;
    });
  }

  /// Bascule directement sur TechnicianUpdateScreen depuis le hub mobile.
  void _goToTechnicianScreen() {
    setState(() {
      _activeModule = _HubModule.equipment;
      _initialScreenType = ScreenType.technician;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeModule == null) {
      return HomeHubScreen(
        onEquipmentModule:  () => setState(() => _activeModule = _HubModule.equipment),
        onTechnicianModule: _goToTechnicianScreen,
        onSettingsModule:   () => setState(() => _activeModule = _HubModule.settings),
        onInventoryModule:  () => setState(() => _activeModule = _HubModule.inventory),
        onMyActiveIssues:   () => _goToIssueTracking(),
        onDepartmentIssues: (department) => _goToIssueTracking(departmentFilter: department),
      );
    }
    return MainScaffold(
      moduleFilter: _filterFor(_activeModule!),
      onBackToHub: () => setState(() {
        _activeModule = null;
        _initialScreenType = null; // retour au hub : plus de redirection automatique
        _initialDepartmentFilter = null;
      }),
      initialScreenType: _initialScreenType,
      initialDepartmentFilter: _initialDepartmentFilter,
    );
  }
}

// ── Main scaffold ────────────────────────────────────────────────────────────

/// Scaffold principal — gère la navigation entre écrans via sidebar (desktop)
/// ou bottom nav / drawer (mobile). Délègue le rendu de la sidebar, topbar
/// et bottom nav à des widgets dédiés (AppSidebar, AppTopBar, AppBottomNav).
class MainScaffold extends StatefulWidget {
  final List<ScreenType>? moduleFilter;
  final VoidCallback? onBackToHub;
  final ScreenType? initialScreenType;
  final String? initialDepartmentFilter;
  const MainScaffold({super.key, this.moduleFilter, this.onBackToHub, this.initialScreenType, this.initialDepartmentFilter});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  String? _selectedEquipmentId;
  String? _selectedIssueId;
  final AuthService _authService = AuthService();
  final List<int> _history = [];
  final GlobalKey<IssueFormScreenState> _issueFormKey = GlobalKey<IssueFormScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NotificationService().generateFromLoadedData();
      // Appliquer l'écran initial si une redirection par rôle a été demandée
      final initType = widget.initialScreenType;
      if (initType != null) {
        final l10n = AppLocalizations.of(context)!;
        final items = _navItems(l10n);
        final idx = items.indexWhere((item) => item.screenType == initType);
        if (idx != -1 && idx != _currentIndex) {
          setState(() => _currentIndex = idx);
        }
      }
    });
  }

  /// Compteur d'incidents "Reported" validables par le technicien connecté,
  /// pour le badge sidebar de l'item "Technicien". Calcul dérivé de
  /// DataService().issues (déjà en mémoire) — aucun appel réseau.
  /// null pour admin/superviseur/technicien générique (pas de badge).
  int? _technicianValidationBadgeCount() {
    final roles = AuthService().currentRoles;
    final groups = <String>{};
    if (roles.contains(UserRole.technicianBiomedical)) groups.add('Biomédical');
    if (roles.contains(UserRole.technicianIt)) groups.add('IT');
    if (roles.contains(UserRole.technicianInfra)) groups.add('Infrastructure');
    if (groups.isEmpty) return null;
    final count = DataService().issues.where((i) =>
      i.status == IssueStatus.reported &&
      (i.assignedGroup == null || groups.contains(i.assignedGroup))
    ).length;
    return count > 0 ? count : null;
  }

  /// Liste complète des items de navigation, sans filtre de permission.
  List<NavItem> _allNavItems(AppLocalizations l10n) => [
    NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: l10n.navDashboard, shortLabel: l10n.navDashboardShort, screenType: ScreenType.dashboard, requiredPermission: null),
    NavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: l10n.navEquipment, shortLabel: l10n.navEquipmentShort, screenType: ScreenType.equipment, requiredPermission: Permission.viewEquipment),
    NavItem(icon: Icons.troubleshoot_outlined, activeIcon: Icons.troubleshoot, label: l10n.navIssueTracking, shortLabel: l10n.navIssueTrackingShort, screenType: ScreenType.issueTracking, requiredPermission: Permission.trackIssues),
    NavItem(icon: Icons.report_problem_outlined, activeIcon: Icons.report_problem, label: l10n.navReportIssue, shortLabel: l10n.navReportIssueShort, screenType: ScreenType.issueForm, requiredPermission: Permission.reportIssue),
    NavItem(icon: Icons.build_outlined, activeIcon: Icons.build, label: l10n.navTechnician, shortLabel: l10n.navTechnicianShort, screenType: ScreenType.technician, requiredPermission: Permission.updateRepairs, alternativePermission: Permission.approveRequests, badgeCount: _technicianValidationBadgeCount()),
    NavItem(icon: Icons.archive_outlined, activeIcon: Icons.archive, label: l10n.navInventory, shortLabel: l10n.navInventoryShort, screenType: ScreenType.inventory, requiredPermission: Permission.viewInventory),
    NavItem(icon: Icons.people_outlined, activeIcon: Icons.people, label: l10n.navUsers, shortLabel: l10n.navUsersShort, screenType: ScreenType.users, requiredPermission: Permission.manageUsers),
    NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: l10n.navSettings, shortLabel: l10n.navSettingsShort, screenType: ScreenType.settings, requiredPermission: Permission.manageDepartments),
    NavItem(icon: Icons.history_outlined, activeIcon: Icons.history, label: l10n.navLogs, shortLabel: l10n.navLogsShort, screenType: ScreenType.logs, requiredPermission: Permission.manageUsers),
    NavItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics, label: l10n.navAnalytics, shortLabel: l10n.navAnalyticsShort, screenType: ScreenType.analytics, requiredPermission: Permission.generateReports),
    NavItem(icon: Icons.backup_outlined, activeIcon: Icons.backup, label: l10n.navBackupManagement, shortLabel: l10n.navBackupManagementShort, screenType: ScreenType.backupManagement, requiredPermission: Permission.manageBackups),
    NavItem(icon: Icons.bug_report_outlined, activeIcon: Icons.bug_report, label: l10n.navDebugTest, shortLabel: l10n.navDebugTestShort, screenType: ScreenType.debugTest, requiredPermission: Permission.manageFeatures),
  ];

  /// Items filtrés par module actif et permissions du user.
  List<NavItem> _navItems(AppLocalizations l10n) {
    final filter = widget.moduleFilter;
    final visible = _allNavItems(l10n).where((item) {
      if (filter != null && !filter.contains(item.screenType)) return false;
      if (item.screenType == ScreenType.debugTest && !_authService.debugModeEnabled) return false;
      if (item.requiredPermission == null) return true;
      return _authService.hasPermission(item.requiredPermission!) ||
             (item.alternativePermission != null &&
              _authService.hasPermission(item.alternativePermission!));
    }).toList();

    // Ordre configuré par l'admin pour le rôle principal (sidebar_config côté API)
    final roleName = _authService.primaryRole?.apiName ?? '';
    final order = DataService().sidebarOrder[roleName];
    if (order != null && order.isNotEmpty) {
      visible.sort((a, b) {
        final aIdx = order.indexOf(a.screenType.name);
        final bIdx = order.indexOf(b.screenType.name);
        return (aIdx == -1 ? order.length : aIdx).compareTo(bIdx == -1 ? order.length : bIdx);
      });
    }
    return visible;
  }

  bool get _canGoBack => _history.isNotEmpty;

  /// Vérifie si on peut quitter le formulaire de signalement.
  /// Affiche un dialog de confirmation si des données ont été saisies.
  Future<bool> _canLeaveIssueForm() async {
    final formState = _issueFormKey.currentState;
    if (formState == null || !formState.hasUnsavedData) return true;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Text(l10n.issueFormLeaveTitle),
        ]),
        content: Text(l10n.issueFormLeaveMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
            child: Text(l10n.issueFormLeaveConfirm),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _goBack() async {
    if (_history.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final navItems = _navItems(l10n);
    final currentItem = _currentIndex < navItems.length ? navItems[_currentIndex] : null;
    if (currentItem?.screenType == ScreenType.issueForm) {
      if (!await _canLeaveIssueForm()) return;
    }
    setState(() {
      _currentIndex = _history.removeLast();
      _selectedEquipmentId = null;
      _selectedIssueId = null;
    });
  }

  Future<void> _navigateTo(int index, {String? equipmentId, String? issueId}) async {
    if (index != _currentIndex) {
      final l10n = AppLocalizations.of(context)!;
      final navItems = _navItems(l10n);
      final currentItem = _currentIndex < navItems.length ? navItems[_currentIndex] : null;
      if (currentItem?.screenType == ScreenType.issueForm) {
        if (!await _canLeaveIssueForm()) return;
      }
    }
    setState(() {
      if (index != _currentIndex) _history.add(_currentIndex);
      _currentIndex = index;
      _selectedEquipmentId = equipmentId;
      _selectedIssueId = issueId;
    });
  }

  Widget _buildCurrentScreen(List<NavItem> navItems) {
    if (_currentIndex >= navItems.length) return _buildAccessDeniedScreen();
    final currentItem = navItems[_currentIndex];
    switch (currentItem.screenType) {
      case ScreenType.dashboard:       return DashboardScreen(onNavigate: _navigateByScreenType);
      case ScreenType.equipment:       return EquipmentHubScreen(onNavigate: _navigateByScreenType);
      case ScreenType.issueTracking:   return IssueTrackingScreen(onNavigate: _navigateByScreenType, initialDepartmentFilter: widget.initialDepartmentFilter);
      case ScreenType.issueForm:       return IssueFormScreen(key: _issueFormKey, equipmentId: _selectedEquipmentId, onCancel: _goBack);
      case ScreenType.technician:      return TechnicianUpdateScreen(issueId: _selectedIssueId);
      case ScreenType.inventory:       return const InventoryScreen();
      case ScreenType.users:           return const UserManagementScreen();
      case ScreenType.settings:        return const SettingsScreen();
      case ScreenType.logs:            return const LogsScreen();
      case ScreenType.analytics:       return const AnalyticsScreen();
      case ScreenType.backupManagement:  return const BackupManagementScreen();
      case ScreenType.debugTest:         return const DebugTestScreen();
    }
  }

  void _navigateByScreenType(int targetIndex, {String? equipmentId, String? issueId}) {
    final l10n = AppLocalizations.of(context)!;
    final navItems = _navItems(l10n);
    final allItems = _allNavItems(l10n);
    final targetScreenTypes = ScreenType.values;
    if (targetIndex >= targetScreenTypes.length) return;
    final targetScreenType = targetScreenTypes[targetIndex];
    final newIndex = navItems.indexWhere((item) => item.screenType == targetScreenType);
    if (newIndex == -1) {
      final targetItem = allItems.where((item) => item.screenType == targetScreenType).firstOrNull;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.lock, color: Colors.white),
          const SizedBox(width: 12),
          Text(l10n.accessDeniedNav(targetItem?.label ?? '?')),
        ]),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    _navigateTo(newIndex, equipmentId: equipmentId, issueId: issueId);
  }

  Widget _buildAccessDeniedScreen() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 80, color: AppColors.error.withValues(alpha: 0.5)),
          const SizedBox(height: 24),
          Text(l10n.accessDenied, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(l10n.accessDeniedMessage, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: () => _navigateTo(0), icon: const Icon(Icons.home), label: Text(l10n.backToDashboard)),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.logout, color: AppColors.error),
          const SizedBox(width: 12),
          Text(l10n.logoutConfirmTitle),
        ]),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _authService.logoutApi();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Sous-titre de la sidebar selon l'écran actif.
  String _getSidebarSubtitle(AppLocalizations l10n, List<NavItem> navItems) {
    if (_currentIndex >= navItems.length) return l10n.hospitalSubtitle;
    return switch (navItems[_currentIndex].screenType) {
      ScreenType.equipment         => l10n.sidebarTitleEquipment,
      ScreenType.inventory         => l10n.sidebarTitleInventory,
      ScreenType.analytics         => l10n.sidebarTitleAnalytics,
      ScreenType.settings          => l10n.sidebarTitleSettings,
      ScreenType.users             => l10n.sidebarTitleSettings,
      ScreenType.logs              => l10n.sidebarTitleSettings,
      ScreenType.backupManagement  => l10n.sidebarTitleSettings,
      ScreenType.debugTest         => l10n.sidebarTitleSettings,
      _                            => l10n.hospitalSubtitle,
    };
  }

  Widget _buildDrawer(AppLocalizations l10n, List<NavItem> navItems) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Image.asset('assets/images/logo_hopital.png', height: 44, width: 44, fit: BoxFit.contain),
                ),
                const SizedBox(height: 12),
                Text(l10n.hospitalName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(l10n.hospitalSubtitleLong, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          if (widget.onBackToHub != null)
            ListTile(
              leading: const Icon(Icons.grid_view_rounded, color: AppColors.primary),
              title: Text(l10n.backToModules, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              tileColor: AppColors.primaryLight,
              onTap: () { Navigator.pop(context); widget.onBackToHub!(); },
            ),
          if (widget.onBackToHub != null) const Divider(height: 1),
          ...navItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = _currentIndex == index;
            return ListTile(
              leading: Icon(isSelected ? item.activeIcon : item.icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
              title: Text(item.label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
              selected: isSelected,
              selectedTileColor: AppColors.primaryLight,
              onTap: () {
                Navigator.pop(context);
                if (item.screenType == ScreenType.issueForm) {
                  showIssueCategorySelector(context);
                } else {
                  _navigateTo(index);
                }
              },
            );
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined, color: AppColors.primary),
            title: Text(l10n.settingsAccountSection, style: const TextStyle(fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > AppBreakpoints.desktop;
    final l10n = AppLocalizations.of(context)!;
    final navItems = _navItems(l10n);
    final currentTitle = _currentIndex < navItems.length ? navItems[_currentIndex].label : '';

    return Scaffold(
      body: Builder(
        builder: (scaffoldContext) => Row(
          children: [
            if (isWide)
              AppSidebar(
                navItems: navItems,
                currentIndex: _currentIndex,
                subtitle: _getSidebarSubtitle(l10n, navItems),
                onNavTap: (ctx, item, index) => _navigateTo(index),
                onBackToHub: widget.onBackToHub,
                onLogout: () => _confirmLogout(l10n),
              ),
            Expanded(
              child: Column(
                children: [
                  AppTopBar(
                    title: currentTitle,
                    canGoBack: _canGoBack,
                    onBack: _goBack,
                    isWide: isWide,
                    onBackToHub: widget.onBackToHub,
                    onOpenDrawer: () => Scaffold.of(scaffoldContext).openDrawer(),
                    onNavigate: _navigateByScreenType,
                  ),
                  Expanded(child: _buildCurrentScreen(navItems)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : AppBottomNav(
              navItems: navItems,
              currentIndex: _currentIndex,
              onTap: (ctx, item, index) => _navigateTo(index),
            ),
      drawer: isWide ? null : _buildDrawer(l10n, navItems),
    );
  }
}
