import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_config.dart';
import 'account_settings_screen.dart';

/// Écran hub — affiché après connexion, permet de choisir un module.
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
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, user),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isWide ? 32 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.hubSelectModule,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.hubSelectModuleSubtitle,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildEquipmentCard(l10n)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildSettingsCard(l10n)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildInventoryCard(l10n)),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildEquipmentCard(l10n),
                          const SizedBox(height: 16),
                          _buildSettingsCard(l10n),
                          const SizedBox(height: 16),
                          _buildInventoryCard(l10n),
                        ],
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            _buildVersionFooter(context),
          ],
        ),
      ),
    );
  }

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

  Widget _buildEquipmentCard(AppLocalizations l10n) => _HubModuleCard(
        color: AppColors.primary,
        lightColor: AppColors.primaryLight,
        icon: Icons.medical_services_outlined,
        title: l10n.hubEquipmentTitle,
        description: l10n.hubEquipmentDesc,
        pages: [
          _PageEntry(l10n.navDashboard,      Icons.dashboard_outlined),
          _PageEntry(l10n.navEquipment,      Icons.inventory_2_outlined),
          _PageEntry(l10n.navIssueTracking,  Icons.troubleshoot_outlined),
          _PageEntry(l10n.navReportIssue,    Icons.report_problem_outlined),
          _PageEntry(l10n.navTechnician,     Icons.build_outlined),
          _PageEntry(l10n.navReports,        Icons.analytics_outlined),
        ],
        onTap: onEquipmentModule,
      );

  Widget _buildSettingsCard(AppLocalizations l10n) => _HubModuleCard(
        color: AppColors.warning,
        lightColor: AppColors.warningLight,
        icon: Icons.settings_outlined,
        title: l10n.hubSettingsTitle,
        description: l10n.hubSettingsDesc,
        pages: [
          _PageEntry(l10n.navSettings, Icons.tune_outlined),
          _PageEntry(l10n.navUsers,    Icons.people_outlined),
          _PageEntry(l10n.navLogs,     Icons.history_outlined),
        ],
        onTap: onSettingsModule,
      );

  Widget _buildInventoryCard(AppLocalizations l10n) => _HubModuleCard(
        color: AppColors.success,
        lightColor: AppColors.successLight,
        icon: Icons.archive_outlined,
        title: l10n.hubInventoryTitle,
        description: l10n.hubInventoryDesc,
        pages: [
          _PageEntry(l10n.navInventory, Icons.inventory_outlined),
        ],
        onTap: onInventoryModule,
      );
}

// ── Modèle interne ──────────────────────────────────────────────────────────

class _PageEntry {
  final String name;
  final IconData icon;
  const _PageEntry(this.name, this.icon);
}

// ── Carte de module ─────────────────────────────────────────────────────────

class _HubModuleCard extends StatelessWidget {
  final Color color;
  final Color lightColor;
  final IconData icon;
  final String title;
  final String description;
  final List<_PageEntry> pages;
  final VoidCallback onTap;

  const _HubModuleCard({
    required this.color,
    required this.lightColor,
    required this.icon,
    required this.title,
    required this.description,
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
              // En-tête icône
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.6), size: 16),
                ],
              ),
              const SizedBox(height: 18),
              // Titre
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // Chips des pages
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
              // Bouton ouvrir
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
