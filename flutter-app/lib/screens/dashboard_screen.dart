import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../models/equipment.dart';
import '../models/issue.dart';
import '../widgets/progress_bar.dart';
import '../widgets/alert_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/issue_category_selector.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = DataService().equipment.length;
    final operational = DataService().equipment.where((e) => e.status == EquipmentStatus.operational).length;
    final maintenance = DataService().equipment.where((e) => e.status == EquipmentStatus.maintenance).length;
    final outOfService = DataService().equipment.where((e) => e.status == EquipmentStatus.outOfService).length;
    final recentIssues = DataService().issues.where((i) => i.status != IssueStatus.completed && i.status != IssueStatus.closed && i.status != IssueStatus.verified).take(4).toList();
    final criticalEquipment = DataService().equipment.where((e) => e.status == EquipmentStatus.outOfService).toList();
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.dashboardTitle, style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(l10n.dashboardSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton.icon(onPressed: () => onNavigate(1), icon: const Icon(Icons.inventory_2, size: 18), label: Text(l10n.dashboardViewEquipment)),
            ElevatedButton.icon(onPressed: () => showIssueCategorySelector(context), style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning), icon: const Icon(Icons.report_problem_outlined, size: 18), label: Text(l10n.dashboardReportProblem)),
            ElevatedButton.icon(onPressed: () => onNavigate(2), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success), icon: const Icon(Icons.list_alt, size: 18), label: Text(l10n.dashboardViewIssues)),
          ]),
          const SizedBox(height: 24),
          if (isMobile) ...[
            Row(children: [
              Expanded(child: _buildCompactStatCard(l10n.dashboardTotal, '$total', Icons.inventory_2_outlined, AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _buildCompactStatCard(l10n.dashboardOperational, '$operational', Icons.check_circle_outline, AppColors.success)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _buildCompactStatCard(l10n.dashboardMaintenance, '$maintenance', Icons.build_outlined, AppColors.warning)),
              const SizedBox(width: 12),
              Expanded(child: _buildCompactStatCard(l10n.dashboardOutOfService, '$outOfService', Icons.cancel_outlined, AppColors.error)),
            ]),
          ] else
            Row(children: [
              Expanded(child: _buildCompactStatCard(l10n.dashboardTotal, '$total', Icons.inventory_2_outlined, AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _buildCompactStatCard(l10n.dashboardOperational, '$operational', Icons.check_circle_outline, AppColors.success)),
              const SizedBox(width: 12),
              Expanded(child: _buildCompactStatCard(l10n.dashboardMaintenance, '$maintenance', Icons.build_outlined, AppColors.warning)),
              const SizedBox(width: 12),
              Expanded(child: _buildCompactStatCard(l10n.dashboardOutOfService, '$outOfService', Icons.cancel_outlined, AppColors.error)),
            ]),
          const SizedBox(height: 24),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.dashboardEquipmentStatus, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            LabeledProgressBar(label: l10n.dashboardOperationalStatus, current: operational, total: total, color: AppColors.success),
            const SizedBox(height: 12),
            LabeledProgressBar(label: l10n.dashboardInMaintenance, current: maintenance, total: total, color: AppColors.warning),
            const SizedBox(height: 12),
            LabeledProgressBar(label: l10n.dashboardOutOfServiceStatus, current: outOfService, total: total, color: AppColors.error),
          ]))),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _buildRecentIssues(l10n, recentIssues)),
                const SizedBox(width: 24),
                Expanded(child: _buildCriticalAlerts(l10n, criticalEquipment)),
              ]);
            }
            return Column(children: [_buildRecentIssues(l10n, recentIssues), const SizedBox(height: 24), _buildCriticalAlerts(l10n, criticalEquipment)]);
          }),
        ],
      ),
    );
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

  Widget _buildRecentIssues(AppLocalizations l10n, List recentIssues) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.dashboardRecentIssues, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      if (recentIssues.isEmpty) Text(l10n.dashboardNoIssues, style: const TextStyle(color: AppColors.textSecondary))
      else ...recentIssues.map((issue) => ListTile(
        dense: true, contentPadding: EdgeInsets.zero,
        leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: issue.status == IssueStatus.reported ? AppColors.errorLight : AppColors.warningLight, borderRadius: BorderRadius.circular(6)),
          child: Icon(Icons.warning_amber_rounded, color: issue.status == IssueStatus.reported ? AppColors.error : AppColors.warning, size: 16)),
        title: Text(issue.displayName, style: const TextStyle(fontSize: 14)),
        subtitle: Text(issue.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        trailing: IssueStatusBadge(status: issue.status.displayName),
      )),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => onNavigate(2), child: Text(l10n.dashboardViewAllIssues))),
    ])));
  }

  Widget _buildCriticalAlerts(AppLocalizations l10n, List<Equipment> criticalEquipment) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.dashboardUrgentAlerts, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      if (criticalEquipment.isEmpty) Text(l10n.dashboardNoAlerts, style: const TextStyle(color: AppColors.textSecondary))
      else ...criticalEquipment.map((eq) => AlertCard(title: l10n.dashboardCriticalFailure, message: '${eq.name} - ${eq.department}', severity: AlertSeverity.critical)),
      ...DataService().issues.where((i) => i.status == IssueStatus.reported).take(2).map((issue) =>
        AlertCard(title: l10n.dashboardOpenIssue, message: '${issue.displayName} - ${issue.description}', severity: AlertSeverity.warning)),
    ])));
  }
}
