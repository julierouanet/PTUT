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
import 'services/auth_service.dart';
import 'services/data_service.dart';
import 'models/user_role.dart';
import 'providers/locale_provider.dart';

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
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleProvider().loadSavedLocale();
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
                  return const MainScaffold();
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

/// Main scaffold with sidebar navigation
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  String? _selectedEquipmentId;
  String? _selectedIssueId;
  final AuthService _authService = AuthService();

  /// Define all nav items with their required permissions
  List<_NavItem> _allNavItems(AppLocalizations l10n) => [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: l10n.navDashboard, screenType: ScreenType.dashboard, requiredPermission: null),
    _NavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: l10n.navEquipment, screenType: ScreenType.equipment, requiredPermission: Permission.viewEquipment),
    _NavItem(icon: Icons.warning_amber_outlined, activeIcon: Icons.warning_amber, label: l10n.navIssueTracking, screenType: ScreenType.issueTracking, requiredPermission: Permission.trackIssues),
    _NavItem(icon: Icons.report_problem_outlined, activeIcon: Icons.report_problem, label: l10n.navReportIssue, screenType: ScreenType.issueForm, requiredPermission: Permission.reportIssue),
    _NavItem(icon: Icons.build_outlined, activeIcon: Icons.build, label: l10n.navTechnician, screenType: ScreenType.technician, requiredPermission: Permission.updateRepairs),
    _NavItem(icon: Icons.archive_outlined, activeIcon: Icons.archive, label: l10n.navInventory, screenType: ScreenType.inventory, requiredPermission: Permission.viewInventory),
    _NavItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics, label: l10n.navReports, screenType: ScreenType.reports, requiredPermission: Permission.generateReports),
    _NavItem(icon: Icons.people_outlined, activeIcon: Icons.people, label: l10n.navUsers, screenType: ScreenType.users, requiredPermission: Permission.manageUsers),
    _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: l10n.navSettings, screenType: ScreenType.settings, requiredPermission: null),
  ];

  List<_NavItem> _navItems(AppLocalizations l10n) {
    return _allNavItems(l10n).where((item) {
      if (item.requiredPermission == null) return true;
      return _authService.hasPermission(item.requiredPermission!);
    }).toList();
  }

  void _navigateTo(int index, {String? equipmentId, String? issueId}) {
    setState(() {
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
        return IssueFormScreen(equipmentId: _selectedEquipmentId);
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
    setState(() {
      _currentIndex = newIndex;
      _selectedEquipmentId = equipmentId;
      _selectedIssueId = issueId;
    });
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
      body: Row(
        children: [
          if (isWide) _buildSidebar(l10n, navItems),
          Expanded(child: _buildCurrentScreen(navItems)),
        ],
      ),
      bottomNavigationBar: isWide ? null : _buildBottomNav(navItems),
      drawer: isWide ? null : _buildDrawer(l10n, navItems),
    );
  }

  Widget _buildSidebar(AppLocalizations l10n, List<_NavItem> navItems) {
    final currentUser = _authService.currentUser;
    return Container(
      width: 260,
      decoration: const BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: AppColors.border))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.local_hospital, color: AppColors.primary),
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
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = _currentIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: ListTile(
                    leading: Icon(isSelected ? item.activeIcon : item.icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                    title: Text(item.label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                    selected: isSelected,
                    selectedTileColor: AppColors.primaryLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onTap: () => _navigateTo(index),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: Text(l10n.logout, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () async { await _authService.logoutApi(); },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(currentUser?.role ?? UserRole.hospitalStaff).withValues(alpha: 0.2),
                  child: Icon(_getRoleIconData(currentUser?.role ?? UserRole.hospitalStaff), color: _getRoleColor(currentUser?.role ?? UserRole.hospitalStaff)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentUser?.name ?? l10n.user, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(currentUser?.role.displayName ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
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
      case UserRole.technician: return Icons.build;
      case UserRole.hospitalStaff: return Icons.medical_services;
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin: return AppColors.error;
      case UserRole.supervisor: return AppColors.warning;
      case UserRole.technician: return AppColors.success;
      case UserRole.hospitalStaff: return AppColors.primary;
    }
  }

  Widget _buildBottomNav(List<_NavItem> navItems) {
    final visibleItems = navItems.take(5).toList();
    if (visibleItems.length < 2) return const SizedBox.shrink();
    return NavigationBar(
      selectedIndex: _currentIndex < visibleItems.length ? _currentIndex : 0,
      onDestinationSelected: _navigateTo,
      destinations: visibleItems.map((item) => NavigationDestination(icon: Icon(item.icon), selectedIcon: Icon(item.activeIcon), label: item.label)).toList(),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.local_hospital, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 12),
                Text(l10n.hospitalName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(l10n.hospitalSubtitleLong, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ...navItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = _currentIndex == index;
            return ListTile(
              leading: Icon(isSelected ? item.activeIcon : item.icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
              title: Text(item.label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
              selected: isSelected,
              selectedTileColor: AppColors.primaryLight,
              onTap: () { Navigator.pop(context); _navigateTo(index); },
            );
          }),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ScreenType screenType;
  final Permission? requiredPermission;

  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.screenType, this.requiredPermission});
}
