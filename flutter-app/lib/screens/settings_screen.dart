import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/app_settings_service.dart';
import '../services/feature_service.dart';
import '../theme/app_theme.dart';
import '../widgets/settings/departments_tab.dart';
import '../widgets/settings/roles_tab.dart';
import '../widgets/settings/activity_tab.dart';
import '../screens/feature_management_screen.dart';
import '../widgets/settings/app_settings_tab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────────────────────────
        Padding(
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

        // ── TabBar style pilule ────────────────────────────────────────────────
        Container(
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
              _tab(Icons.history,                l10n.settingsTabActivity),
              _tab(Icons.tune,                   l10n.settingsTabFeatureFlags),
              _tab(Icons.settings_applications,  l10n.settingsTabAppSettings),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Contenu des onglets ───────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              DepartmentsTab(),
              RolesTab(),
              ActivityTab(),
              FeatureManagementScreen(),
              AppSettingsTab(),
            ],
          ),
        ),
      ],
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
