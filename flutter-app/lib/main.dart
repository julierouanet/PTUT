import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/equipment_list_screen.dart';
import 'screens/issue_tracking_screen.dart';
import 'screens/issue_form_screen.dart';
import 'screens/technician_update_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/account_settings_screen.dart';
import 'screens/logs_screen.dart';
import 'services/auth_service.dart';
import 'services/data_service.dart';
import 'services/notification_service.dart';
import 'services/api_client.dart';
import 'models/user_role.dart';
import 'providers/locale_provider.dart';
import 'widgets/notification_bell.dart';
import 'widgets/issue_category_selector.dart';
import 'screens/home_hub_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/feature_management_screen.dart';
import 'screens/backup_management_screen.dart';

/// Screen types for navigation (no more string matching)
enum ScreenType {
  dashboard,
  equipment,
  issueTracking,
  issueForm,
  technician,
  inventory,
  reports,
  users,
  settings,
  logs,
  analytics,
  featureManagement,
  backupManagement,
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleProvider().loadSavedLocale();

  // Configurer le callback de session expiree
  ApiClient.onSessionExpired = () {
    AuthService().handleSessionExpired();
  };

  // Tenter l'auto-login si des tokens sont stockes
  try {
    if (await ApiClient.hasStoredTokens()) {
      final restored = await AuthService().restoreSession();
      if (restored) {
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

  @override
  void initState() {
    super.initState();
    _applyRoleRedirect();
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
    ScreenType.reports,
  ];
  static const _settingsScreens = [
    ScreenType.settings,
    ScreenType.users,
    ScreenType.logs,
    ScreenType.analytics,
    ScreenType.featureManagement,
    ScreenType.backupManagement,
  ];
  static const _inventoryScreens = [ScreenType.inventory];

  List<ScreenType>? _filterFor(_HubModule m) {
    switch (m) {
      case _HubModule.equipment: return _equipmentScreens;
      case _HubModule.settings:  return _settingsScreens;
      case _HubModule.inventory: return _inventoryScreens;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeModule == null) {
      return HomeHubScreen(
        onEquipmentModule: () => setState(() => _activeModule = _HubModule.equipment),
        onSettingsModule:  () => setState(() => _activeModule = _HubModule.settings),
        onInventoryModule: () => setState(() => _activeModule = _HubModule.inventory),
      );
    }
    return MainScaffold(
      moduleFilter: _filterFor(_activeModule!),
      onBackToHub: () => setState(() {
        _activeModule = null;
        _initialScreenType = null; // retour au hub : plus de redirection automatique
      }),
      initialScreenType: _initialScreenType,
    );
  }
}

// ── Main scaffold ────────────────────────────────────────────────────────────

/// Main scaffold with sidebar navigation
class MainScaffold extends StatefulWidget {
  final List<ScreenType>? moduleFilter;
  final VoidCallback? onBackToHub;
  final ScreenType? initialScreenType;
  const MainScaffold({super.key, this.moduleFilter, this.onBackToHub, this.initialScreenType});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  String? _selectedEquipmentId;
  String? _selectedIssueId;
  bool _isSidebarCollapsed = false;
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

  /// Define all nav items with their required permissions
  List<_NavItem> _allNavItems(AppLocalizations l10n) => [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: l10n.navDashboard, shortLabel: l10n.navDashboardShort, screenType: ScreenType.dashboard, requiredPermission: null),
    _NavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: l10n.navEquipment, shortLabel: l10n.navEquipmentShort, screenType: ScreenType.equipment, requiredPermission: Permission.viewEquipment),
    _NavItem(icon: Icons.troubleshoot_outlined, activeIcon: Icons.troubleshoot, label: l10n.navIssueTracking, shortLabel: l10n.navIssueTrackingShort, screenType: ScreenType.issueTracking, requiredPermission: Permission.trackIssues),
    _NavItem(icon: Icons.report_problem_outlined, activeIcon: Icons.report_problem, label: l10n.navReportIssue, shortLabel: l10n.navReportIssueShort, screenType: ScreenType.issueForm, requiredPermission: Permission.reportIssue),
    _NavItem(icon: Icons.build_outlined, activeIcon: Icons.build, label: l10n.navTechnician, shortLabel: l10n.navTechnicianShort, screenType: ScreenType.technician, requiredPermission: Permission.updateRepairs),
    _NavItem(icon: Icons.archive_outlined, activeIcon: Icons.archive, label: l10n.navInventory, shortLabel: l10n.navInventoryShort, screenType: ScreenType.inventory, requiredPermission: Permission.viewInventory),
    _NavItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics, label: l10n.navReports, shortLabel: l10n.navReportsShort, screenType: ScreenType.reports, requiredPermission: Permission.generateReports),
    _NavItem(icon: Icons.people_outlined, activeIcon: Icons.people, label: l10n.navUsers, shortLabel: l10n.navUsersShort, screenType: ScreenType.users, requiredPermission: Permission.manageUsers),
    _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: l10n.navSettings, shortLabel: l10n.navSettingsShort, screenType: ScreenType.settings, requiredPermission: Permission.manageDepartments),
    _NavItem(icon: Icons.history_outlined, activeIcon: Icons.history, label: l10n.navLogs, shortLabel: l10n.navLogsShort, screenType: ScreenType.logs, requiredPermission: Permission.manageUsers),
    _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: l10n.navAnalytics, shortLabel: l10n.navAnalyticsShort, screenType: ScreenType.analytics, requiredPermission: Permission.generateReports),
    _NavItem(icon: Icons.tune_outlined, activeIcon: Icons.tune, label: l10n.navFeatureManagement, shortLabel: l10n.navFeatureManagementShort, screenType: ScreenType.featureManagement, requiredPermission: Permission.manageFeatures),
    _NavItem(icon: Icons.backup_outlined, activeIcon: Icons.backup, label: l10n.navBackupManagement, shortLabel: l10n.navBackupManagementShort, screenType: ScreenType.backupManagement, requiredPermission: Permission.manageBackups),
  ];

  List<_NavItem> _navItems(AppLocalizations l10n) {
    final filter = widget.moduleFilter;
    final visible = _allNavItems(l10n).where((item) {
      if (filter != null && !filter.contains(item.screenType)) return false;
      if (item.requiredPermission == null) return true;
      return _authService.hasPermission(item.requiredPermission!);
    }).toList();

    // Appliquer l'ordre configuré par l'admin pour le rôle "principal" du user
    // (la sidebar_config est indexée par un seul nom de rôle côté API).
    final roleName = _authService.primaryRole?.apiName ?? '';
    final order = DataService().sidebarOrder[roleName];
    if (order != null && order.isNotEmpty) {
      visible.sort((a, b) {
        final ai = order.indexOf(a.screenType.name);
        final bi = order.indexOf(b.screenType.name);
        final aIdx = ai == -1 ? order.length : ai;
        final bIdx = bi == -1 ? order.length : bi;
        return aIdx.compareTo(bIdx);
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
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

  Widget _buildCurrentScreen(List<_NavItem> navItems) {
    if (_currentIndex >= navItems.length) return _buildAccessDeniedScreen();
    final currentItem = navItems[_currentIndex];
    switch (currentItem.screenType) {
      case ScreenType.dashboard:
        return DashboardScreen(onNavigate: _navigateByScreenType);
      case ScreenType.equipment:
        return EquipmentListScreen(onNavigate: _navigateByScreenType);
      case ScreenType.issueTracking:
        return IssueTrackingScreen(onNavigate: _navigateByScreenType);
      case ScreenType.issueForm:
        return IssueFormScreen(key: _issueFormKey, equipmentId: _selectedEquipmentId, onCancel: _goBack);
      case ScreenType.technician:
        return TechnicianUpdateScreen(issueId: _selectedIssueId);
      case ScreenType.inventory:
        return const InventoryScreen();
      case ScreenType.reports:
        return const ReportsScreen();
      case ScreenType.users:
        return const UserManagementScreen();
      case ScreenType.settings:
        return const SettingsScreen();
      case ScreenType.logs:
        return const LogsScreen();
      case ScreenType.analytics:
        return const AnalyticsScreen();
      case ScreenType.featureManagement:
        return const FeatureManagementScreen();
      case ScreenType.backupManagement:
        return const BackupManagementScreen();
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

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final l10n = AppLocalizations.of(context)!;
    final navItems = _navItems(l10n);

    return Scaffold(
      body: Builder(
        builder: (scaffoldContext) => Row(
          children: [
            if (isWide) _buildSidebar(l10n, navItems),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(l10n, navItems, isWide, scaffoldContext),
                  Expanded(child: _buildCurrentScreen(navItems)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isWide ? null : _buildBottomNav(navItems),
      drawer: isWide ? null : _buildDrawer(l10n, navItems),
    );
  }

  /// Barre de titre en haut du contenu avec la cloche de notifications
  Widget _buildTopBar(
    AppLocalizations l10n,
    List<_NavItem> navItems,
    bool isWide,
    BuildContext scaffoldContext,
  ) {
    final currentLabel = _currentIndex < navItems.length
        ? navItems[_currentIndex].label
        : '';
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Bouton menu sur écran étroit
          if (!isWide) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textSecondary),
              onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
              tooltip: l10n.tooltipMenu,
            ),
          ],
          if (isWide && widget.onBackToHub != null) ...[
            IconButton(
              icon: const Icon(Icons.grid_view_rounded, color: AppColors.primary),
              onPressed: widget.onBackToHub,
              tooltip: l10n.backToModulesLabel,
            ),
          ],
          // Bouton retour
          if (_canGoBack) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
              onPressed: _goBack,
              tooltip: l10n.tooltipBack,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            currentLabel,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined, color: AppColors.textSecondary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen())),
            tooltip: l10n.tooltipAccountSettings,
          ),
          const SizedBox(width: 8),
          NotificationBell(onNavigate: _navigateByScreenType),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: AppColors.error),
            const SizedBox(width: 12),
            Text(l10n.logoutConfirmTitle),
          ],
        ),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
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

  void _handleNavTap(BuildContext context, _NavItem item, int index) {
    if (item.screenType == ScreenType.issueForm) {
      showIssueCategorySelector(context);
    } else {
      _navigateTo(index);
    }
  }

  Widget _buildSidebar(AppLocalizations l10n, List<_NavItem> navItems) {
    final currentUser = _authService.currentUser;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _isSidebarCollapsed ? 70.0 : 260.0,
      decoration: const BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: AppColors.border))),
      child: Column(
        children: [
          // ── En-tête : logo + nom hôpital + bouton bascule ──────────────────
          Container(
            padding: _isSidebarCollapsed
                ? const EdgeInsets.symmetric(vertical: 8)
                : const EdgeInsets.all(20),
            child: _isSidebarCollapsed
                ? Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                        tooltip: l10n.tooltipMenu,
                        onPressed: () => setState(() => _isSidebarCollapsed = false),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: Image.asset('assets/images/logo_hopital.png', height: 36, width: 36, fit: BoxFit.contain),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: Image.asset('assets/images/logo_hopital.png', height: 36, width: 36, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.hospitalName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                            Text(l10n.hospitalSubtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
                        tooltip: l10n.tooltipMenu,
                        onPressed: () => setState(() => _isSidebarCollapsed = true),
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          // ── Bouton retour aux modules ───────────────────────────────────────
          if (widget.onBackToHub != null) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(_isSidebarCollapsed ? 4 : 12, 8, _isSidebarCollapsed ? 4 : 12, 4),
              child: _isSidebarCollapsed
                  ? Tooltip(
                      message: l10n.backToModules,
                      child: Material(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: widget.onBackToHub,
                          borderRadius: BorderRadius.circular(8),
                          child: const SizedBox(height: 44, child: Center(child: Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 20))),
                        ),
                      ),
                    )
                  : ListTile(
                      leading: const Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 20),
                      title: Builder(builder: (ctx) => Text(AppLocalizations.of(ctx)!.backToModules, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14))),
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      tileColor: AppColors.primaryLight,
                      onTap: widget.onBackToHub,
                    ),
            ),
            const Divider(height: 1),
          ],
          // ── Liste des items de navigation ──────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = _currentIndex == index;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: _isSidebarCollapsed ? 4 : 12, vertical: 2),
                  child: _isSidebarCollapsed
                      ? Tooltip(
                          message: item.label,
                          child: Material(
                            color: isSelected ? AppColors.primaryLight : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () => _handleNavTap(context, item, index),
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                height: 48,
                                child: Center(
                                  child: Icon(isSelected ? item.activeIcon : item.icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListTile(
                          leading: Icon(isSelected ? item.activeIcon : item.icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                          title: Text(item.label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                          selected: isSelected,
                          selectedTileColor: AppColors.primaryLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () => _handleNavTap(context, item, index),
                        ),
                );
              },
            ),
          ),
          // ── Bouton déconnexion ─────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _isSidebarCollapsed ? 4 : 12, vertical: 4),
            child: _isSidebarCollapsed
                ? Tooltip(
                    message: l10n.logout,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => _confirmLogout(l10n),
                        borderRadius: BorderRadius.circular(8),
                        child: const SizedBox(height: 48, child: Center(child: Icon(Icons.logout, color: AppColors.error))),
                      ),
                    ),
                  )
                : ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.error),
                    title: Text(l10n.logout, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onTap: () => _confirmLogout(l10n),
                  ),
          ),
          const Divider(height: 1),
          // ── Pied de page : profil utilisateur ─────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(_isSidebarCollapsed ? 0 : 16, 8, _isSidebarCollapsed ? 0 : 8, 8),
            child: _isSidebarCollapsed
                ? Center(
                    child: Tooltip(
                      message: currentUser?.fullName ?? l10n.user,
                      child: CircleAvatar(
                        backgroundColor: _getRoleColor(_authService.primaryRole ?? UserRole.hospitalStaff).withValues(alpha: 0.2),
                        child: Icon(_getRoleIconData(_authService.primaryRole ?? UserRole.hospitalStaff), color: _getRoleColor(_authService.primaryRole ?? UserRole.hospitalStaff)),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getRoleColor(_authService.primaryRole ?? UserRole.hospitalStaff).withValues(alpha: 0.2),
                        child: Icon(_getRoleIconData(_authService.primaryRole ?? UserRole.hospitalStaff), color: _getRoleColor(_authService.primaryRole ?? UserRole.hospitalStaff)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentUser?.fullName ?? l10n.user, style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              currentUser?.roles.map((r) => r.displayName).join(', ') ?? '',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 20),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen())),
                        tooltip: l10n.tooltipAccountSettings,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIconData(UserRole role) {
    switch (role) {
      case UserRole.admin: return Icons.admin_panel_settings;
      case UserRole.supervisor: return Icons.supervisor_account;
      case UserRole.technician:
      case UserRole.technicianBiomedical:
      case UserRole.technicianIt:
      case UserRole.technicianInfra:
        return Icons.build;
      case UserRole.hospitalStaff: return Icons.medical_services;
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin: return AppColors.error;
      case UserRole.supervisor: return AppColors.warning;
      case UserRole.technician: return AppColors.success;
      case UserRole.technicianBiomedical: return AppColors.success;
      case UserRole.technicianIt: return AppColors.primary;
      case UserRole.technicianInfra: return AppColors.warning;
      case UserRole.hospitalStaff: return AppColors.primary;
    }
  }

  Widget _buildBottomNav(List<_NavItem> navItems) {
    final visibleItems = navItems.take(5).toList();
    if (visibleItems.length < 2) return const SizedBox.shrink();
    return NavigationBar(
      selectedIndex: _currentIndex < visibleItems.length ? _currentIndex : 0,
      onDestinationSelected: (index) {
        final item = visibleItems[index];
        if (item.screenType == ScreenType.issueForm) {
          showIssueCategorySelector(context);
        } else {
          _navigateTo(index);
        }
      },
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: visibleItems.map((item) => NavigationDestination(
        icon: Icon(item.icon),
        selectedIcon: Icon(item.activeIcon),
        label: item.shortLabel,
      )).toList(),
    );
  }

  Widget _buildDrawer(AppLocalizations l10n, List<_NavItem> navItems) {
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
                  child: Image.asset(
                    'assets/images/logo_hopital.png',
                    height: 44,
                    width: 44,
                    fit: BoxFit.contain,
                  ),
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
                Navigator.pop(context); // ferme le drawer
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
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String shortLabel;
  final ScreenType screenType;
  final Permission? requiredPermission;

  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.shortLabel, required this.screenType, this.requiredPermission});
}
