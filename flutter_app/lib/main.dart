import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/equipment_list_screen.dart';
import 'screens/issue_tracking_screen.dart';
import 'screens/issue_form_screen.dart';
import 'screens/technician_update_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reports_screen.dart';

void main() {
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
      home: const MainScaffold(),
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

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Tableau de bord'),
    _NavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Équipements'),
    _NavItem(icon: Icons.warning_amber_outlined, activeIcon: Icons.warning_amber, label: 'Suivi incidents'),
    _NavItem(icon: Icons.report_problem_outlined, activeIcon: Icons.report_problem, label: 'Signaler'),
    _NavItem(icon: Icons.build_outlined, activeIcon: Icons.build, label: 'Technicien'),
    _NavItem(icon: Icons.archive_outlined, activeIcon: Icons.archive, label: 'Inventaire'),
    _NavItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics, label: 'Rapports'),
  ];

  void _navigateTo(int index, {String? equipmentId, String? issueId}) {
    setState(() {
      _currentIndex = index;
      _selectedEquipmentId = equipmentId;
      _selectedIssueId = issueId;
    });
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return DashboardScreen(onNavigate: _navigateTo);
      case 1:
        return EquipmentListScreen(onNavigate: _navigateTo);
      case 2:
        return IssueTrackingScreen(onNavigate: _navigateTo);
      case 3:
        return IssueFormScreen(equipmentId: _selectedEquipmentId);
      case 4:
        return TechnicianUpdateScreen(issueId: _selectedIssueId);
      case 5:
        return const InventoryScreen();
      case 6:
        return const ReportsScreen();
      default:
        return DashboardScreen(onNavigate: _navigateTo);
    }
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
          
          // Navigation items
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
          
          // Footer
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text('Administrateur', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _currentIndex < 5 ? _currentIndex : 0,
      onDestinationSelected: _navigateTo,
      destinations: _navItems.take(5).map((item) => NavigationDestination(
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

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
