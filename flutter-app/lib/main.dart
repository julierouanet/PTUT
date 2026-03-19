import 'package:flutter/material.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EquipmentManagementApp());
}

class EquipmentManagementApp extends StatelessWidget {
  const EquipmentManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion des Équipements - Kabutare Hospital',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement des données...'),
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
  List<_NavItem> get _allNavItems => [
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Tableau de bord',
      requiredPermission: null, // Everyone can access
    ),
    _NavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      label: 'Équipements',
      requiredPermission: Permission.viewEquipment,
    ),
    _NavItem(
      icon: Icons.warning_amber_outlined,
      activeIcon: Icons.warning_amber,
      label: 'Suivi incidents',
      requiredPermission: Permission.trackIssues,
    ),
    _NavItem(
      icon: Icons.report_problem_outlined,
      activeIcon: Icons.report_problem,
      label: 'Signaler',
      requiredPermission: Permission.reportIssue,
    ),
    _NavItem(
      icon: Icons.build_outlined,
      activeIcon: Icons.build,
      label: 'Technicien',
      requiredPermission: Permission.updateRepairs, // Only technicians and admins
    ),
    _NavItem(
      icon: Icons.archive_outlined,
      activeIcon: Icons.archive,
      label: 'Inventaire',
      requiredPermission: Permission.viewInventory,
    ),
    _NavItem(
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
      label: 'Rapports',
      requiredPermission: Permission.generateReports,
    ),
    _NavItem(
      icon: Icons.people_outlined,
      activeIcon: Icons.people,
      label: 'Utilisateurs',
      requiredPermission: Permission.manageUsers, // Admin only
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Paramètres',
      requiredPermission: Permission.manageDepartments, // Admin only
    ),
  ];

  /// Get only nav items the current user has permission to access
  List<_NavItem> get _navItems {
    return _allNavItems.where((item) {
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

  Widget _buildCurrentScreen() {
    if (_currentIndex >= _navItems.length) {
      return _buildAccessDeniedScreen();
    }
    
    final currentItem = _navItems[_currentIndex];
    
    // Map label to screen
    switch (currentItem.label) {
      case 'Tableau de bord':
        return DashboardScreen(onNavigate: _navigateByLabel);
      case 'Équipements':
        return EquipmentListScreen(onNavigate: _navigateByLabel);
      case 'Suivi incidents':
        return IssueTrackingScreen(onNavigate: _navigateByLabel);
      case 'Signaler':
        return IssueFormScreen(equipmentId: _selectedEquipmentId);
      case 'Technicien':
        return TechnicianUpdateScreen(issueId: _selectedIssueId);
      case 'Inventaire':
        return const InventoryScreen();
      case 'Rapports':
        return const ReportsScreen();
      case 'Utilisateurs':
        return const UserManagementScreen();
      case 'Paramètres':
        return const SettingsScreen();
      default:
        return DashboardScreen(onNavigate: _navigateByLabel);
    }
  }
  
  /// Navigate by finding the index of a specific screen type
  void _navigateByLabel(int targetIndex, {String? equipmentId, String? issueId}) {
    // Map old indexes to labels
    final targetLabels = ['Tableau de bord', 'Équipements', 'Suivi incidents', 'Signaler', 'Technicien', 'Inventaire', 'Rapports', 'Utilisateurs', 'Paramètres'];
    if (targetIndex >= targetLabels.length) return;
    
    final targetLabel = targetLabels[targetIndex];
    final newIndex = _navItems.indexWhere((item) => item.label == targetLabel);
    
    if (newIndex == -1) {
      // User doesn't have permission - show message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock, color: Colors.white),
              const SizedBox(width: 12),
              Text('Accès refusé: vous n\'avez pas la permission d\'accéder à "$targetLabel"'),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _currentIndex = newIndex;
      _selectedEquipmentId = equipmentId;
      _selectedIssueId = issueId;
    });
  }
  
  Widget _buildAccessDeniedScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 80, color: AppColors.error.withValues(alpha: 0.5)),
          const SizedBox(height: 24),
          const Text(
            'Accès refusé',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vous n\'avez pas les permissions nécessaires pour accéder à cette page.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateTo(0),
            icon: const Icon(Icons.home),
            label: const Text('Retour au tableau de bord'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar for wide screens
          if (isWide) _buildSidebar(),
          
          // Main content
          Expanded(
            child: _buildCurrentScreen(),
          ),
        ],
      ),
      // Bottom navigation for narrow screens
      bottomNavigationBar: isWide ? null : _buildBottomNav(),
      // Drawer for narrow screens
      drawer: isWide ? null : _buildDrawer(),
    );
  }

  Widget _buildSidebar() {
    final currentUser = _authService.currentUser;
    
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Logo/Title
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_hospital, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kabutare Hospital',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'Gestion Équipements',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Navigation items - only show permitted ones
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = _currentIndex == index;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: ListTile(
                    leading: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: AppColors.primaryLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onTap: () => _navigateTo(index),
                  ),
                );
              },
            ),
          ),
          
          // Bouton de déconnexion
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Se déconnecter',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () async {
                await _authService.logoutApi();
              },
            ),
          ),
          
          // Footer with current user
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(currentUser?.role ?? UserRole.hospitalStaff).withValues(alpha: 0.2),
                  child: Icon(
                    _getRoleIconData(currentUser?.role ?? UserRole.hospitalStaff),
                    color: _getRoleColor(currentUser?.role ?? UserRole.hospitalStaff),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentUser?.name ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.w500)),
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
  
  Widget _getRoleIcon(UserRole role) {
    return Icon(_getRoleIconData(role), size: 16, color: _getRoleColor(role));
  }
  
  IconData _getRoleIconData(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.supervisor:
        return Icons.supervisor_account;
      case UserRole.technician:
        return Icons.build;
      case UserRole.hospitalStaff:
        return Icons.medical_services;
    }
  }
  
  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppColors.error;
      case UserRole.supervisor:
        return AppColors.warning;
      case UserRole.technician:
        return AppColors.success;
      case UserRole.hospitalStaff:
        return AppColors.primary;
    }
  }

  Widget _buildBottomNav() {
    final visibleItems = _navItems.take(5).toList();
    if (visibleItems.length < 2) {
      return const SizedBox.shrink();
    }
    return NavigationBar(
      selectedIndex: _currentIndex < visibleItems.length ? _currentIndex : 0,
      onDestinationSelected: _navigateTo,
      destinations: visibleItems.map((item) => NavigationDestination(
        icon: Icon(item.icon),
        selectedIcon: Icon(item.activeIcon),
        label: item.label,
      )).toList(),
    );
  }

  Widget _buildDrawer() {
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
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_hospital, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Kabutare Hospital',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Gestion des Équipements',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          ..._navItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = _currentIndex == index;
            
            return ListTile(
              leading: Icon(
                isSelected ? item.activeIcon : item.icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              title: Text(
                item.label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedTileColor: AppColors.primaryLight,
              onTap: () {
                Navigator.pop(context);
                _navigateTo(index);
              },
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
  final Permission? requiredPermission;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.requiredPermission,
  });
}
