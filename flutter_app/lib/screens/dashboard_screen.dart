import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../models/equipment.dart';
import '../services/auth_service.dart';
import '../widgets/progress_bar.dart';
import '../widgets/alert_card.dart';
import '../widgets/status_badge.dart';
import '../models/user_role.dart';
import '../models/user.dart';

/// Dashboard screen - main overview of equipment management
class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService().currentUser;
    final role = currentUser?.role;

    // Calculate statistics
    final total = mockEquipment.length;
    final disponible = mockEquipment.where((e) => e.status == EquipmentStatus.disponible).length;
    final enUsage = mockEquipment.where((e) => e.status == EquipmentStatus.enUsage).length;
    final enMaintenance = mockEquipment.where((e) => e.status == EquipmentStatus.enMaintenance).length;
    final horsService = mockEquipment.where((e) => e.status == EquipmentStatus.horsService).length;

    // Incidents filtrés selon le rôle
    final myIssues = role == UserRole.hospitalStaff
      ? mockIssues.where((i) => 
          i.reporter.contains(currentUser?.name.split(' ').last ?? '')).toList()
      : role == UserRole.technician
      ? mockIssues.where((i) => 
          i.assignedTechnician?.contains(currentUser?.name.split(' ').last ?? '') ?? false).toList()
      : mockIssues.where((i) => i.status.displayName != 'Résolu').take(4).toList();

    final departmentIssues = role == UserRole.hospitalStaff
      ? mockIssues.where((i) => 
          i.department == currentUser?.department && 
          !i.reporter.contains(currentUser?.name.split(' ').last ?? '')).take(3).toList()
      : [];

    // Critical alerts
    final criticalEquipment = mockEquipment.where((e) => 
      e.status == EquipmentStatus.horsService
    ).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 0), // espace vide en haut
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  _getDashboardTitle(role),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getDashboardSubtitle(role),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // Quick Actions - NOW ADAPTED TO ROLE
                _buildQuickActions(role),
                const SizedBox(height: 24),

                if (role != UserRole.hospitalStaff) ...[
                  Row(
                    children: [
                      Expanded(child: _buildCompactStatCard('Total', '$total', Icons.inventory_2_outlined, AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildCompactStatCard('Disponibles', '$disponible', Icons.check_circle_outline, AppColors.success)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildCompactStatCard('Maintenance', '$enMaintenance', Icons.build_outlined, AppColors.warning)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildCompactStatCard('Hors Service', '$horsService', Icons.cancel_outlined, AppColors.error)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Status Overview
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Statut des équipements',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          LabeledProgressBar(label: 'Disponible', current: disponible, total: total, color: AppColors.success),
                          const SizedBox(height: 12),
                          LabeledProgressBar(label: 'En usage', current: enUsage, total: total, color: AppColors.primary),
                          const SizedBox(height: 12),
                          LabeledProgressBar(label: 'En maintenance', current: enMaintenance, total: total, color: AppColors.warning),
                          const SizedBox(height: 12),
                          LabeledProgressBar(label: 'Hors service', current: horsService, total: total, color: AppColors.error),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Incidents + Alertes
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildRecentIssues(myIssues, departmentIssues, role, currentUser)),
                          if (role != UserRole.hospitalStaff) ...[
                            const SizedBox(width: 24),
                            Expanded(child: _buildCriticalAlerts(criticalEquipment, role)),
                          ],
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildRecentIssues(myIssues, departmentIssues, role, currentUser),
                        if (role != UserRole.hospitalStaff) ...[
                          const SizedBox(height: 24),
                          _buildCriticalAlerts(criticalEquipment, role),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(UserRole? role) {
    switch (role) {
      case UserRole.technician:
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate(1),
              icon: const Icon(Icons.build, size: 18),
              label: const Text('Mes interventions'),
            ),
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate(3),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              icon: const Icon(Icons.report_problem_outlined, size: 18),
              label: const Text('Signaler un problème'),
            ),
          ],
        );
      case UserRole.supervisor:
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate(2),
              icon: const Icon(Icons.approval, size: 18),
              label: const Text('Incidents à approuver'),
            ),
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate(1),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              icon: const Icon(Icons.inventory_2, size: 18),
              label: const Text('Voir les équipements'),
            ),
          ],
        );
      case UserRole.admin:
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate(1),
              icon: const Icon(Icons.inventory_2, size: 18),
              label: const Text('Voir les équipements'),
            ),
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate(3),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              icon: const Icon(Icons.report_problem_outlined, size: 18),
              label: const Text('Signaler un problème'),
            ),
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate(2),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              icon: const Icon(Icons.list_alt, size: 18),
              label: const Text('Voir les incidents'),
            ),
          ],
        );
      default: // hospitalStaff
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate(3),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              icon: const Icon(Icons.report_problem_outlined, size: 18),
              label: const Text('Signaler un problème'),
            ),
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate(2),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              icon: const Icon(Icons.list_alt, size: 18),
              label: const Text('Mes signalements'),
            ),
          ],
        );
    }
  }

  Widget _buildRecentIssues(List myIssues, List departmentIssues, UserRole? role, User? currentUser) {
    final title = role == UserRole.hospitalStaff
      ? 'Mes signalements'
      : role == UserRole.technician
      ? 'Mes interventions'
      : 'Derniers incidents signalés';

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (myIssues.isEmpty)
                  const Text('Aucun incident', style: TextStyle(color: AppColors.textSecondary))
                else
                  ...myIssues.map((issue) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: issue.status.displayName == 'Ouvert' 
                          ? AppColors.errorLight 
                          : AppColors.warningLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: issue.status.displayName == 'Ouvert' 
                          ? AppColors.error 
                          : AppColors.warning,
                        size: 16,
                      ),
                    ),
                    title: Text(issue.equipmentName, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      issue.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IssueStatusBadge(status: issue.status.displayName),
                  )),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => widget.onNavigate(2),
                    child: const Text('Voir tous les incidents'),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Section département (uniquement pour hospitalStaff)
        if (role == UserRole.hospitalStaff && departmentIssues.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Incidents dans mon département (${currentUser?.department})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...departmentIssues.map((issue) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                    ),
                    title: Text(issue.equipmentName, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      issue.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IssueStatusBadge(status: issue.status.displayName),
                  )),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCriticalAlerts(List<Equipment> criticalEquipment, UserRole? role) {
    final sortedAlerts = [...criticalEquipment]
      ..sort((a, b) {
        if (a.status == EquipmentStatus.horsService) return -1;
        if (b.status == EquipmentStatus.horsService) return 1;
        return 0;
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alertes urgentes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (sortedAlerts.isEmpty)
              const Text('Aucune alerte urgente', style: TextStyle(color: AppColors.textSecondary))
            else
              ...sortedAlerts.map((eq) => AlertCard(
                title: 'Panne critique',
                message: '${eq.name} - ${eq.department}',
                severity: AlertSeverity.critical,
              )),
            if (role != UserRole.hospitalStaff)
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

  String _getDashboardTitle(UserRole? role) {
    switch (role) {
      case UserRole.technician:
        return 'Mes interventions';
      case UserRole.supervisor:
        return 'Tableau de bord superviseur';
      case UserRole.admin:
        return 'Tableau de bord administrateur';
      default:
        return 'Tableau de bord';
    }
  }

  String _getDashboardSubtitle(UserRole? role) {
    switch (role) {
      case UserRole.technician:
        return 'Suivi de vos interventions en cours';
      case UserRole.supervisor:
        return 'Vue d\'ensemble de votre département';
      case UserRole.admin:
        return 'Vue complète de la gestion des équipements';
      default:
        return 'Vue d\'ensemble de la gestion des équipements';
    }
  }
}
