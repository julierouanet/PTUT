import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
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
                    const Text(
                      'Sélectionnez un module',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choisissez le module auquel vous souhaitez accéder',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildEquipmentCard()),
                          const SizedBox(width: 20),
                          Expanded(child: _buildSettingsCard()),
                          const SizedBox(width: 20),
                          Expanded(child: _buildInventoryCard()),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildEquipmentCard(),
                          const SizedBox(height: 16),
                          _buildSettingsCard(),
                          const SizedBox(height: 16),
                          _buildInventoryCard(),
                        ],
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bonjour' : hour < 18 ? 'Bon après-midi' : 'Bonsoir';
    final firstName = (user?.firstName?.isNotEmpty == true)
        ? user!.firstName
        : (user?.name ?? 'Utilisateur');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_hospital, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kabutare Hospital',
                  style: TextStyle(
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
            tooltip: 'Paramètres du compte',
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentCard() => _HubModuleCard(
        color: AppColors.primary,
        lightColor: AppColors.primaryLight,
        icon: Icons.medical_services_outlined,
        title: 'Équipement',
        description:
            'Gérez les équipements médicaux, suivez les incidents et planifiez les interventions.',
        pages: const [
          _PageEntry('Tableau de bord', Icons.dashboard_outlined),
          _PageEntry('Équipement', Icons.inventory_2_outlined),
          _PageEntry('Suivi incident', Icons.troubleshoot_outlined),
          _PageEntry('Signaler', Icons.report_problem_outlined),
          _PageEntry('Technicien', Icons.build_outlined),
          _PageEntry('Rapport', Icons.analytics_outlined),
        ],
        onTap: onEquipmentModule,
      );

  Widget _buildSettingsCard() => _HubModuleCard(
        color: AppColors.warning,
        lightColor: AppColors.warningLight,
        icon: Icons.settings_outlined,
        title: 'Paramètres',
        description:
            'Administrez les utilisateurs, configurez le système et consultez les journaux.',
        pages: const [
          _PageEntry('Gestion', Icons.tune_outlined),
          _PageEntry('Utilisateurs', Icons.people_outlined),
          _PageEntry('Journaux', Icons.history_outlined),
        ],
        onTap: onSettingsModule,
      );

  Widget _buildInventoryCard() => _HubModuleCard(
        color: AppColors.success,
        lightColor: AppColors.successLight,
        icon: Icons.archive_outlined,
        title: 'Inventaire',
        description:
            'Consultez et gérez les stocks de fournitures médicales et consommables.',
        pages: const [
          _PageEntry('Inventaire', Icons.inventory_outlined),
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
                  child: Text(
                    'Ouvrir $title',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
