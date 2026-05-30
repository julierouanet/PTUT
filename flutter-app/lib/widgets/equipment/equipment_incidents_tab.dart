import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/issue.dart';
import '../../screens/issue_detail_screen.dart';
import '../../theme/app_theme.dart';
import '../status_badge.dart';
import '../urgency_badge.dart';
import 'equipment_detail_helpers.dart';

/// Onglet Incidents — incidents actifs, historique et bouton de signalement.
class EquipmentIncidentsTab extends StatelessWidget {
  final List<Issue> issues;
  final bool loading;
  final String? error;

  /// Callback déclenché quand l'utilisateur clique sur "Signaler un problème".
  final VoidCallback? onReport;

  const EquipmentIncidentsTab({
    super.key,
    required this.issues,
    this.loading = false,
    this.error,
    this.onReport,
  });

  List<Issue> get _active =>
      issues.where((i) => kActiveIssueStatuses.contains(i.status)).toList();

  List<Issue> get _resolved =>
      issues.where((i) => !kActiveIssueStatuses.contains(i.status)).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (loading && issues.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Incidents actifs ──────────────────────────────────────
          _buildIssueGroup(
            context,
            l10n,
            title: l10n.equipDetailCurrentIssues,
            issues: _active,
            emptyMessage: l10n.equipDetailNoCurrentIssues,
            icon: Icons.warning_amber_outlined,
            iconColor: AppColors.warning,
          ),
          const SizedBox(height: 12),

          // ── Historique ────────────────────────────────────────────
          _buildIssueGroup(
            context,
            l10n,
            title: l10n.equipDetailPastIssues,
            issues: _resolved,
            emptyMessage: l10n.equipDetailNoPastIssues,
            icon: Icons.history,
            iconColor: AppColors.textSecondary,
          ),

          // ── Bouton signaler ───────────────────────────────────────
          if (onReport != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.report_problem_outlined, size: 16),
                label: Text(l10n.equipmentReportProblem),
              ),
            ),
          ],

          // ── Bannière d'erreur ─────────────────────────────────────
          if (error != null && !loading) ...[
            const SizedBox(height: 8),
            _buildErrorBanner(l10n),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Groupe d'incidents ───────────────────────────────────────────────────────

  Widget _buildIssueGroup(
    BuildContext context,
    AppLocalizations l10n, {
    required String title,
    required List<Issue> issues,
    required String emptyMessage,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (issues.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${issues.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (issues.isEmpty)
              Text(
                emptyMessage,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              )
            else
              ...issues.map((issue) => _buildIssueCard(context, l10n, issue)),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueCard(
      BuildContext context, AppLocalizations l10n, Issue issue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IssueDetailScreen(issueId: issue.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UrgencyBadge(urgency: issue.urgency, isCompact: true),
                  const SizedBox(width: 8),
                  IssueStatusBadge(status: issue.status.displayName),
                  const Spacer(),
                  Text(
                    formatDetailDateShort(issue.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      size: 16, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                issue.type,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                issue.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              if (issue.assignedTechnician != null &&
                  issue.assignedTechnician!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      issue.assignedTechnician!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_outlined,
              size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.equipDetailLoadingError,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
