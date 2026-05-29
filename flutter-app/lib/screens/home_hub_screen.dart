import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/api_config.dart';
import '../models/issue.dart';
import '../models/inventory_item.dart';
import '../models/equipment.dart';
import '../models/user_role.dart';
import '../widgets/issue_category_selector.dart';
import 'account_settings_screen.dart';

/// Hub post-connexion — tableau de bord global GMAO avec KPIs croisés et accès rapide.
class HomeHubScreen extends StatelessWidget {
  final VoidCallback onEquipmentModule;
  final VoidCallback onSettingsModule;
  final VoidCallback onInventoryModule;

  const HomeHubScreen({
    super.key,
    required this.onEquipmentModule,
    required this.onSettingsModule,
    required this.onInventoryModule,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = AuthService().currentUser;
    final auth = AuthService();
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      // FAB d'urgence — déclenche la pré-qualification sans navigation
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showIssueCategorySelector(context),
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.report_problem_rounded),
        label: Text(
          l10n.hubReportUrgentButton,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        tooltip: l10n.hubReportUrgentTooltip,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, user),
            Expanded(
              child: ListenableBuilder(
                listenable: DataService(),
                builder: (context, _) {
                  final data = DataService();
                  final criticalCount    = _countCriticalUrgent(data);
                  final stockAlertCount  = _countStockAlerts(data);
                  final outOfServiceCount = _countOutOfService(data);

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? 32 : 16,
                      20,
                      isWide ? 32 : 16,
                      96, // espace sous le FAB
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Titre du tableau de bord ────────────────────────
                        Text(
                          l10n.hubKpiTitle,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.hubKpiSubtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // ── Tuiles KPI ──────────────────────────────────────
                        _buildKpiRow(
                          l10n,
                          isWide,
                          criticalCount,
                          stockAlertCount,
                          outOfServiceCount,
                        ),
                        const SizedBox(height: 28),
                        // ── Titre accès rapide ──────────────────────────────
                        Text(
                          l10n.hubQuickAccessTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // ── Cartes modules ──────────────────────────────────
                        _buildModuleCards(
                          context,
                          l10n,
                          isWide,
                          auth,
                          criticalCount,
                          stockAlertCount,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              ),
            ),
            _buildVersionFooter(context),
          ],
        ),
      ),
    );
  }

  // ── Calcul des KPIs depuis DataService ────────────────────────────────────

  int _countCriticalUrgent(DataService data) => data.issues.where((i) =>
    (i.urgency == IssueUrgency.critique || i.urgency == IssueUrgency.urgent) &&
    i.status != IssueStatus.completed &&
    i.status != IssueStatus.closed &&
    i.status != IssueStatus.verified,
  ).length;

  int _countStockAlerts(DataService data) => data.inventory.where((i) =>
    i.status == StockStatus.low || i.status == StockStatus.outOfStock,
  ).length;

  int _countOutOfService(DataService data) => data.equipment.where((e) =>
    e.status == EquipmentStatus.outOfService,
  ).length;

  // ── Rangée de tuiles KPI ──────────────────────────────────────────────────

  Widget _buildKpiRow(
    AppLocalizations l10n,
    bool isWide,
    int criticalCount,
    int stockAlertCount,
    int outOfServiceCount,
  ) {
    final tiles = <_KpiTile>[
      _KpiTile(
        label: l10n.hubKpiCriticalUrgentLabel,
        count: criticalCount,
        icon: Icons.warning_amber_rounded,
        color: criticalCount > 0 ? AppColors.error : AppColors.success,
        subtitle: criticalCount == 0 ? l10n.hubKpiNoAlert : l10n.hubKpiOpenIssues,
        onTap: onEquipmentModule,
      ),
      _KpiTile(
        label: l10n.hubKpiStockAlertsLabel,
        count: stockAlertCount,
        icon: Icons.inventory_outlined,
        color: stockAlertCount > 0 ? AppColors.warning : AppColors.success,
        subtitle: stockAlertCount == 0 ? l10n.hubKpiNoAlert : l10n.hubKpiStockAlertsSubtitle,
        onTap: onInventoryModule,
      ),
      _KpiTile(
        label: l10n.hubKpiOutOfServiceLabel,
        count: outOfServiceCount,
        icon: Icons.power_off_outlined,
        color: outOfServiceCount > 0 ? AppColors.warning : AppColors.success,
        subtitle: outOfServiceCount == 0 ? l10n.hubKpiNoAlert : l10n.hubKpiOutOfServiceSubtitle,
        onTap: onEquipmentModule,
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < tiles.length; i++) ...[
          Expanded(child: tiles[i]),
          if (i < tiles.length - 1) SizedBox(width: isWide ? 16 : 8),
        ],
      ],
    );
  }

  // ── Disposition des cartes modules ────────────────────────────────────────

  Widget _buildModuleCards(
    BuildContext context,
    AppLocalizations l10n,
    bool isWide,
    AuthService auth,
    int criticalCount,
    int stockAlertCount,
  ) {
    // Visibilité des modules selon les permissions RBAC
    final showSettings  = auth.hasPermission(Permission.manageDepartments) ||
                          auth.hasPermission(Permission.manageUsers);
    final showInventory = auth.hasPermission(Permission.viewInventory);

    final cards = <Widget>[
      _buildEquipmentCard(l10n, criticalCount),
      if (showSettings)  _buildSettingsCard(l10n),
      if (showInventory) _buildInventoryCard(l10n, stockAlertCount),
    ];

    if (cards.isEmpty) return const SizedBox.shrink();

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i < cards.length - 1) const SizedBox(width: 16),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i < cards.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ── Cartes modules (badgeCount = alertes à afficher) ──────────────────────

  Widget _buildEquipmentCard(AppLocalizations l10n, int badgeCount) => _HubModuleCard(
        color: AppColors.primary,
        lightColor: AppColors.primaryLight,
        icon: Icons.medical_services_outlined,
        title: l10n.hubEquipmentTitle,
        description: l10n.hubEquipmentDesc,
        badgeCount: badgeCount,
        pages: [
          _PageEntry(l10n.navDashboard,     Icons.dashboard_outlined),
          _PageEntry(l10n.navEquipment,     Icons.inventory_2_outlined),
          _PageEntry(l10n.navIssueTracking, Icons.troubleshoot_outlined),
          _PageEntry(l10n.navReportIssue,   Icons.report_problem_outlined),
          _PageEntry(l10n.navTechnician,    Icons.build_outlined),
          _PageEntry(l10n.navReports,       Icons.analytics_outlined),
        ],
        onTap: onEquipmentModule,
      );

  Widget _buildSettingsCard(AppLocalizations l10n) => _HubModuleCard(
        color: AppColors.warning,
        lightColor: AppColors.warningLight,
        icon: Icons.settings_outlined,
        title: l10n.hubSettingsTitle,
        description: l10n.hubSettingsDesc,
        badgeCount: 0,
        pages: [
          _PageEntry(l10n.navSettings, Icons.tune_outlined),
          _PageEntry(l10n.navUsers,    Icons.people_outlined),
          _PageEntry(l10n.navLogs,     Icons.history_outlined),
        ],
        onTap: onSettingsModule,
      );

  Widget _buildInventoryCard(AppLocalizations l10n, int badgeCount) => _HubModuleCard(
        color: AppColors.success,
        lightColor: AppColors.successLight,
        icon: Icons.archive_outlined,
        title: l10n.hubInventoryTitle,
        description: l10n.hubInventoryDesc,
        badgeCount: badgeCount,
        pages: [
          _PageEntry(l10n.navInventory, Icons.inventory_outlined),
        ],
        onTap: onInventoryModule,
      );

  // ── En-tête ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, dynamic user) {
    final l10n = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l10n.greetingMorning
        : hour < 18
            ? l10n.greetingAfternoon
            : l10n.greetingEvening;
    final firstName = (user?.firstName?.isNotEmpty == true)
        ? user!.firstName
        : (user?.name ?? l10n.user);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Image.asset(
              'assets/images/logo_hopital.png',
              height: 42,
              width: 42,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.hospitalName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '$greeting, $firstName',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined, color: AppColors.textSecondary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
            ),
            tooltip: l10n.tooltipAccountSettings,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            tooltip: l10n.logout,
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  final dl10n = AppLocalizations.of(ctx)!;
                  return AlertDialog(
                    title: Row(children: [
                      const Icon(Icons.logout, color: AppColors.error),
                      const SizedBox(width: 12),
                      Text(dl10n.logoutConfirmTitle),
                    ]),
                    content: Text(dl10n.logoutConfirmMessage),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(dl10n.commonCancel),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(dl10n.logout),
                      ),
                    ],
                  );
                },
              );
              if (confirmed == true && context.mounted) {
                await AuthService().logoutApi();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Pied de page version ───────────────────────────────────────────────────

  Widget _buildVersionFooter(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        l10n.appVersionLabel(ApiConfig.appVersion),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.55),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Modèle interne pour les chips de pages ─────────────────────────────────

class _PageEntry {
  final String name;
  final IconData icon;
  const _PageEntry(this.name, this.icon);
}

// ── Tuile KPI ──────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final String subtitle;
  final VoidCallback onTap;

  const _KpiTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 17),
                  ),
                  const Spacer(),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Carte de module ────────────────────────────────────────────────────────

class _HubModuleCard extends StatelessWidget {
  final Color color;
  final Color lightColor;
  final IconData icon;
  final String title;
  final String description;
  final int badgeCount;
  final List<_PageEntry> pages;
  final VoidCallback onTap;

  const _HubModuleCard({
    required this.color,
    required this.lightColor,
    required this.icon,
    required this.title,
    required this.description,
    required this.badgeCount,
    required this.pages,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête icône + badge ──────────────────────────────────
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lightColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                      if (badgeCount > 0)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: color.withValues(alpha: 0.6),
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // ── Titre ──────────────────────────────────────────────────
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // ── Description ────────────────────────────────────────────
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // ── Chips des pages disponibles ────────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pages
                    .map(
                      (p) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: lightColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(p.icon, size: 13, color: color),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                p.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: color,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              // ── Bouton ouvrir ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                  child: Builder(
                    builder: (ctx) => Text(
                      AppLocalizations.of(ctx)!.hubOpenModule(title),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
