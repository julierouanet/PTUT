import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/feature_service.dart';
import '../services/auth_service.dart';
import '../models/user_role.dart';
import '../theme/app_theme.dart';
import '../widgets/settings/departments_tab.dart';
import '../widgets/settings/roles_tab.dart';
import '../screens/feature_management_screen.dart';
import '../widgets/settings/app_settings_tab.dart';
import '../widgets/settings/push_diagnostics_tab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final bool _isAdmin;

  @override
  void initState() {
    super.initState();
    _isAdmin = AuthService().currentUser?.hasRole(UserRole.admin) ?? false;
    _tabController = TabController(length: _isAdmin ? 5 : 4, vsync: this);

    // Charger les données des deux onglets ajoutés si pas déjà chargées
    final featureSvc = FeatureService();
    if (featureSvc.features.isEmpty && !featureSvc.isLoading) {
      featureSvc.loadFeatures();
    }
    final settingsSvc = AppSettingsService();
    if (settingsSvc.settings == null && !settingsSvc.isLoading) {
      settingsSvc.loadAdmin();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < AppBreakpoints.tablet;
    final hPad = isMobile ? 16.0 : 24.0;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        // ── Header (défile hors champ) ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(hPad),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsAdminSection,
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.settingsAdminSubtitle,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── TabBar style pilule (fixée en haut) ──────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarHeaderDelegate(
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: hPad),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(3),
                  tabs: [
                    _tab(Icons.business,               l10n.settingsTabDepartments),
                    _tab(Icons.admin_panel_settings,   l10n.settingsTabRoles),
                    _tab(Icons.tune,                   l10n.settingsTabFeatureFlags),
                    _tab(Icons.settings_applications,  l10n.settingsTabAppSettings),
                    if (_isAdmin)
                      _tab(Icons.troubleshoot,          l10n.settingsTabPushDiagnostics),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      // ── Contenu des onglets ─────────────────────────────────────────────────
      body: TabBarView(
        controller: _tabController,
        children: [
          const DepartmentsTab(),
          const RolesTab(),
          const FeatureManagementScreen(),
          const AppSettingsTab(),
          if (_isAdmin) const PushDiagnosticsTab(),
        ],
      ),
    );
  }

  Tab _tab(IconData icon, String label) => Tab(
        height: 34,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}

/// Delegate pour fixer la TabBar en haut du NestedScrollView pendant le scroll.
class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _TabBarHeaderDelegate({required this.child});

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) => false;
}
