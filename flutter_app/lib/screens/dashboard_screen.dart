import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../models/equipment.dart';
import '../widgets/stat_card.dart';
import '../widgets/progress_bar.dart';
import '../widgets/alert_card.dart';
import '../widgets/status_badge.dart';

/// Dashboard screen - main overview of equipment management
class DashboardScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    // Calculate statistics
    final total = mockEquipment.length;
    final disponible = mockEquipment.where((e) => e.status == EquipmentStatus.disponible).length;
    final enUsage = mockEquipment.where((e) => e.status == EquipmentStatus.enUsage).length;
    final enMaintenance = mockEquipment.where((e) => e.status == EquipmentStatus.enMaintenance).length;
    final horsService = mockEquipment.where((e) => e.status == EquipmentStatus.horsService).length;

    // Recent issues
    final recentIssues = mockIssues.where((i) => 
      i.status.displayName != 'Résolu'
    ).take(4).toList();

    // Critical alerts
    final criticalEquipment = mockEquipment.where((e) => 
      e.status == EquipmentStatus.horsService
    ).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Tableau de bord',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Vue d'ensemble de la gestion des équipements",
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Stats Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  StatCard(
                    title: 'Total Équipements',
                    value: '$total',
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.primary,
                  ),
                  StatCard(
                    title: 'Disponibles',
                    value: '$disponible',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                  ),
                  StatCard(
                    title: 'En Maintenance',
                    value: '$enMaintenance',
                    icon: Icons.build_outlined,
                    color: AppColors.warning,
                  ),
                  StatCard(
                    title: 'Hors Service',
                    value: '$horsService',
                    icon: Icons.cancel_outlined,
                    color: AppColors.error,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Status Overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statut des équipements',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  LabeledProgressBar(
                    label: 'Disponible',
                    current: disponible,
                    total: total,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 16),
                  LabeledProgressBar(
                    label: 'En usage',
                    current: enUsage,
                    total: total,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  LabeledProgressBar(
                    label: 'En maintenance',
                    current: enMaintenance,
                    total: total,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 16),
                  LabeledProgressBar(
                    label: 'Hors service',
                    current: horsService,
                    total: total,
                    color: AppColors.error,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Two column layout for recent issues and alerts
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildRecentIssues(recentIssues)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildCriticalAlerts(criticalEquipment)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildRecentIssues(recentIssues),
                  const SizedBox(height: 24),
                  _buildCriticalAlerts(criticalEquipment),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Quick Actions
          const Text(
            'Actions rapides',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => onNavigate(1),
                icon: const Icon(Icons.add),
                label: const Text('Voir les équipements'),
              ),
              ElevatedButton.icon(
                onPressed: () => onNavigate(3),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                ),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Signaler un problème'),
              ),
              ElevatedButton.icon(
                onPressed: () => onNavigate(2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
                icon: const Icon(Icons.list_alt),
                label: const Text('Voir les incidents'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentIssues(List recentIssues) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Derniers incidents signalés',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (recentIssues.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun incident en cours'),
              )
            else
              ...recentIssues.map((issue) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: issue.status.displayName == 'Ouvert' 
                      ? AppColors.errorLight 
                      : AppColors.warningLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: issue.status.displayName == 'Ouvert' 
                      ? AppColors.error 
                      : AppColors.warning,
                    size: 20,
                  ),
                ),
                title: Text(issue.equipmentName),
                subtitle: Text(
                  issue.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IssueStatusBadge(status: issue.status.displayName),
              )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => onNavigate(2),
                child: const Text('Voir tous les incidents'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalAlerts(List<Equipment> criticalEquipment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alertes urgentes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (criticalEquipment.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucune alerte urgente'),
              )
            else
              ...criticalEquipment.map((eq) => AlertCard(
                title: 'Panne critique',
                message: '${eq.name} - ${eq.department}',
                severity: AlertSeverity.critical,
              )),
            ...mockIssues.where((i) => i.status.displayName == 'Ouvert').take(2).map((issue) => 
              AlertCard(
                title: 'Incident ouvert',
                message: '${issue.equipmentName} - ${issue.description}',
                severity: AlertSeverity.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
