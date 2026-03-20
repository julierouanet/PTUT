import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../models/issue.dart';
import '../widgets/status_badge.dart';

/// Issue tracking screen - view and manage all issues
class IssueTrackingScreen extends StatefulWidget {
  final Function(int, {String? issueId}) onNavigate;

  const IssueTrackingScreen({super.key, required this.onNavigate});

  @override
  State<IssueTrackingScreen> createState() => _IssueTrackingScreenState();
}

class _IssueTrackingScreenState extends State<IssueTrackingScreen> {
  String _statusFilter = 'Tous';

  List<Issue> get _filteredIssues {
    final l10n = AppLocalizations.of(context)!;
    if (_statusFilter == l10n.commonAll) return DataService().issues;
    return DataService().issues.where((i) => i.status.displayName == _statusFilter).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    if (_statusFilter == 'Tous') _statusFilter = l10n.commonAll;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Filter chip labels: use l10n for "Tous", keep status displayNames for matching
    final statuses = [l10n.commonAll, 'Ouvert', 'En cours', 'Résolu'];

    // Summary stats
    final openCount = DataService().issues.where((i) => i.status == IssueStatus.open).length;
    final inProgressCount = DataService().issues.where((i) => i.status == IssueStatus.inProgress).length;
    final resolvedCount = DataService().issues.where((i) => i.status == IssueStatus.resolved).length;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              l10n.issuesTitle,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.issuesSubtitle,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Mini Summary Cards
            Row(
              children: [
                _buildMiniStat(l10n.issuesOpen, openCount, AppColors.error),
                const SizedBox(width: 12),
                _buildMiniStat(l10n.issuesInProgress, inProgressCount, AppColors.warning),
                const SizedBox(width: 12),
                _buildMiniStat(l10n.issuesResolved, resolvedCount, AppColors.success),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => widget.onNavigate(3),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.issuesReport),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter chips
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(l10n.issuesFilterByStatus, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    ...statuses.map((status) {
                      final isSelected = _statusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(status),
                          onSelected: (_) => setState(() => _statusFilter = status),
                          selectedColor: AppColors.primaryLight,
                          checkmarkColor: AppColors.primary,
                        ),
                      );
                    }),
                    const Spacer(),
                    Text(
                      l10n.issuesCount(_filteredIssues.length),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Issues List - FULL WIDTH
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Column(
                  children: _filteredIssues.map((issue) => _buildIssueItem(issue)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildIssueItem(Issue issue) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () => _showIssueDetail(issue),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getStatusColor(issue.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: _getStatusColor(issue.status),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.equipmentName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    issue.description,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.issuesReportedByDate(issue.reporter, issue.createdAt),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            IssueStatusBadge(status: issue.status.displayName),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: () => _showIssueDetail(issue),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(IssueStatus status) {
    switch (status) {
      case IssueStatus.open:
        return AppColors.error;
      case IssueStatus.inProgress:
        return AppColors.warning;
      case IssueStatus.resolved:
        return AppColors.success;
    }
  }

  void _showIssueDetail(Issue issue) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.issuesIncidentId(issue.id), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              IssueStatusBadge(status: issue.status.displayName),
              const SizedBox(height: 20),
              _buildDetailRow(l10n.issuesEquipment, issue.equipmentName),
              _buildDetailRow(l10n.issuesType, issue.type),
              _buildDetailRow(l10n.issuesDescription, issue.description),
              _buildDetailRow(l10n.issuesReportedBy, issue.reporter),
              _buildDetailRow(l10n.issuesReportDate, issue.createdAt),
              if (issue.assignedTechnician != null)
                _buildDetailRow(l10n.issuesAssignedTech, issue.assignedTechnician!),
              if (issue.diagnosis != null)
                _buildDetailRow(l10n.issuesDiagnosis, issue.diagnosis!),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onNavigate(4, issueId: issue.id);
                      },
                      icon: const Icon(Icons.build),
                      label: Text(l10n.issuesUpdate),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
