import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../models/equipment.dart';
import '../models/user_role.dart';
import '../models/issue.dart';
import '../widgets/progress_bar.dart';
import '../widgets/alert_card.dart';
import '../widgets/status_badge.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = AuthService().currentUser;
    final role = currentUser?.role;

    final total = DataService().equipment.length;
    final disponible = DataService().equipment.where((e) => e.status == EquipmentStatus.disponible).length;
    final enUsage = DataService().equipment.where((e) => e.status == EquipmentStatus.enUsage).length;
    final enMaintenance = DataService().equipment.where((e) => e.status == EquipmentStatus.enMaintenance).length;
    final horsService = DataService().equipment.where((e) => e.status == EquipmentStatus.horsService).length;

    // Incidents filtrés selon le rôle
    final myIssues = role == UserRole.hospitalStaff
      ? DataService().issues.where((i) =>
          i.reporter.contains(currentUser?.name.split(' ').last ?? '')).toList()
      : role == UserRole.technician
      ? DataService().issues.where((i) =>
          i.assignedTechnician?.contains(currentUser?.name.split(' ').last ?? '') ?? false).toList()
      : DataService().issues.where((i) => i.status.displayName != 'Résolu').take(4).toList();

    final departmentIssues = role == UserRole.hospitalStaff
      ? DataService().issues.where((i) =>
          i.department == currentUser?.department &&
          !i.reporter.contains(currentUser?.name.split(' ').last ?? '')).take(3).toList()
      : <dynamic>[];

    // Alertes critiques triées par priorité
    final criticalEquipment = (role == UserRole.technician
      ? DataService().equipment.where((e) => e.status == EquipmentStatus.enMaintenance).toList()
      : DataService().equipment.where((e) => e.status == EquipmentStatus.horsService).toList())
      ..sort((a, b) {
        if (a.status == EquipmentStatus.horsService) return -1;
        if (b.status == EquipmentStatus.horsService) return 1;
        return 0;
      });

    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header adapté par rôle
          Text(
            _getDashboardTitle(l10n, role),
            style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(_getDashboardSubtitle(l10n, role), style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),

          // Actions rapides adaptées par rôle
          _buildQuickActions(l10n, role),
          const SizedBox(height: 24),

          // Stats masquées pour le personnel hospitalier
          if (role != UserRole.hospitalStaff) ...[
            if (isMobile) ...[
              Row(children: [
                Expanded(child: _buildCompactStatCard(l10n.dashboardTotal, '$total', Icons.inventory_2_outlined, AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _buildCompactStatCard(l10n.dashboardAvailable, '$disponible', Icons.check_circle_outline, AppColors.success)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildCompactStatCard(l10n.dashboardMaintenance, '$enMaintenance', Icons.build_outlined, AppColors.warning)),
                const SizedBox(width: 12),
                Expanded(child: _buildCompactStatCard(l10n.dashboardOutOfService, '$horsService', Icons.cancel_outlined, AppColors.error)),
              ]),
            ] else
              Row(children: [
                Expanded(child: _buildCompactStatCard(l10n.dashboardTotal, '$total', Icons.inventory_2_outlined, AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _buildCompactStatCard(l10n.dashboardAvailable, '$disponible', Icons.check_circle_outline, AppColors.success)),
                const SizedBox(width: 12),
                Expanded(child: _buildCompactStatCard(l10n.dashboardMaintenance, '$enMaintenance', Icons.build_outlined, AppColors.warning)),
                const SizedBox(width: 12),
                Expanded(child: _buildCompactStatCard(l10n.dashboardOutOfService, '$horsService', Icons.cancel_outlined, AppColors.error)),
              ]),
            const SizedBox(height: 24),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.dashboardEquipmentStatus, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              LabeledProgressBar(label: l10n.dashboardAvailableStatus, current: disponible, total: total, color: AppColors.success),
              const SizedBox(height: 12),
              LabeledProgressBar(label: l10n.dashboardInUse, current: enUsage, total: total, color: AppColors.primary),
              const SizedBox(height: 12),
              LabeledProgressBar(label: l10n.dashboardInMaintenance, current: enMaintenance, total: total, color: AppColors.warning),
              const SizedBox(height: 12),
              LabeledProgressBar(label: l10n.dashboardOutOfServiceStatus, current: horsService, total: total, color: AppColors.error),
            ]))),
            const SizedBox(height: 24),
          ],

          // Incidents + Alertes
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _buildRecentIssues(l10n, myIssues, departmentIssues, role, currentUser?.department)),
                if (role != UserRole.hospitalStaff) ...[
                  const SizedBox(width: 24),
                  Expanded(child: _buildCriticalAlerts(l10n, criticalEquipment, role)),
                ],
              ]);
            }
            return Column(children: [
              _buildRecentIssues(l10n, myIssues, departmentIssues, role, currentUser?.department),
              if (role != UserRole.hospitalStaff) ...[
                const SizedBox(height: 24),
                _buildCriticalAlerts(l10n, criticalEquipment, role),
              ],
            ]);
          }),
        ],
      ),
    );
  }

  String _getDashboardTitle(AppLocalizations l10n, UserRole? role) {
    switch (role) {
      case UserRole.technician:
        return 'Mes interventions';
      case UserRole.supervisor:
        return 'Tableau de bord superviseur';
      case UserRole.admin:
        return 'Tableau de bord administrateur';
      default:
        return l10n.dashboardTitle;
    }
  }

  String _getDashboardSubtitle(AppLocalizations l10n, UserRole? role) {
    switch (role) {
      case UserRole.technician:
        return 'Suivi de vos interventions en cours';
      case UserRole.supervisor:
        return 'Vue d\'ensemble de votre département';
      case UserRole.admin:
        return 'Vue complète de la gestion des équipements';
      default:
        return l10n.dashboardSubtitle;
    }
  }

  Widget _buildQuickActions(AppLocalizations l10n, UserRole? role) {
    switch (role) {
      case UserRole.technician:
        return Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton.icon(onPressed: () => widget.onNavigate(1), icon: const Icon(Icons.build, size: 18), label: const Text('Mes interventions')),
          ElevatedButton.icon(onPressed: () => widget.onNavigate(3), style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning), icon: const Icon(Icons.report_problem_outlined, size: 18), label: Text(l10n.dashboardReportProblem)),
        ]);
      case UserRole.supervisor:
        return Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton.icon(onPressed: () => widget.onNavigate(2), icon: const Icon(Icons.approval, size: 18), label: const Text('Incidents à approuver')),
          ElevatedButton.icon(onPressed: () => widget.onNavigate(1), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success), icon: const Icon(Icons.inventory_2, size: 18), label: Text(l10n.dashboardViewEquipment)),
        ]);
      case UserRole.admin:
        return Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton.icon(onPressed: () => widget.onNavigate(1), icon: const Icon(Icons.inventory_2, size: 18), label: Text(l10n.dashboardViewEquipment)),
          ElevatedButton.icon(onPressed: () => widget.onNavigate(3), style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning), icon: const Icon(Icons.report_problem_outlined, size: 18), label: Text(l10n.dashboardReportProblem)),
          ElevatedButton.icon(onPressed: () => widget.onNavigate(2), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success), icon: const Icon(Icons.list_alt, size: 18), label: Text(l10n.dashboardViewIssues)),
        ]);
      default:
        return Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton.icon(onPressed: () => widget.onNavigate(3), style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning), icon: const Icon(Icons.report_problem_outlined, size: 18), label: Text(l10n.dashboardReportProblem)),
          ElevatedButton.icon(onPressed: () => widget.onNavigate(2), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success), icon: const Icon(Icons.list_alt, size: 18), label: const Text('Mes signalements')),
        ]);
    }
  }

  Widget _buildCompactStatCard(String title, String value, IconData icon, Color color) {
    return Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), child: Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ])),
    ])));
  }

  Widget _buildRecentIssues(AppLocalizations l10n, List myIssues, List departmentIssues, UserRole? role, String? department) {
    final title = role == UserRole.hospitalStaff
      ? 'Mes signalements'
      : role == UserRole.technician
      ? 'Mes interventions'
      : l10n.dashboardRecentIssues;

    return Column(
      children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          if (myIssues.isEmpty)
            Text(l10n.dashboardNoIssues, style: const TextStyle(color: AppColors.textSecondary))
          else
            ...myIssues.map((issue) => ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: issue.status.displayName == 'Ouvert' ? AppColors.errorLight : AppColors.warningLight, borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.warning_amber_rounded, color: issue.status.displayName == 'Ouvert' ? AppColors.error : AppColors.warning, size: 16)),
              title: Text(issue.equipmentName, style: const TextStyle(fontSize: 14)),
              subtitle: Text(issue.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              trailing: IssueStatusBadge(status: issue.status.displayName),
            )),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => widget.onNavigate(2), child: Text(l10n.dashboardViewAllIssues))),
        ]))),

        // Incidents du département pour le personnel hospitalier
        if (role == UserRole.hospitalStaff && departmentIssues.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Incidents dans mon département ($department)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            ...departmentIssues.map((issue) => ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16)),
              title: Text(issue.equipmentName, style: const TextStyle(fontSize: 14)),
              subtitle: Text(issue.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              trailing: IssueStatusBadge(status: issue.status.displayName),
            )),
          ]))),
        ],
      ],
    );
  }

  Widget _buildCriticalAlerts(AppLocalizations l10n, List<Equipment> criticalEquipment, UserRole? role) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.dashboardUrgentAlerts, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      if (criticalEquipment.isEmpty)
        Text(l10n.dashboardNoAlerts, style: const TextStyle(color: AppColors.textSecondary))
      else
        ...criticalEquipment.map((eq) => AlertCard(title: l10n.dashboardCriticalFailure, message: '${eq.name} - ${eq.department}', severity: AlertSeverity.critical)),
      ...DataService().issues.where((i) => i.status.displayName == 'Ouvert').take(2).map((issue) =>
        AlertCard(title: l10n.dashboardOpenIssue, message: '${issue.equipmentName} - ${issue.description}', severity: AlertSeverity.warning)),
    ])));
  }
}