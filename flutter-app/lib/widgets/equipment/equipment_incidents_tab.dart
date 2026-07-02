import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/issue.dart';
import '../../screens/issue_detail_screen.dart';
import '../../theme/app_theme.dart';
import '../issue/intervention_documents_section.dart';
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
              ...issues.map(
                  (issue) => _IssueCard(key: ValueKey(issue.id), issue: issue)),
          ],
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

/// Carte d'un incident — gère elle-même son état de dépliage (indépendant
/// des autres cartes de la liste) pour éviter de reconstruire toute la
/// colonne d'incidents à chaque toggle.
class _IssueCard extends StatefulWidget {
  final Issue issue;

  const _IssueCard({super.key, required this.issue});

  @override
  State<_IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<_IssueCard> {
  bool _expanded = false;

  /// Lignes de détail exploitables pour cet incident (diagnostic, actions,
  /// pièces, durée, coût, date de résolution). Construites une seule fois et
  /// réutilisées à la fois pour savoir si le bouton "Voir détails" doit
  /// s'afficher et pour peupler le panneau déplié.
  List<Widget> _detailRows(AppLocalizations l10n) {
    final issue = widget.issue;
    return [
      if (issue.diagnosis?.isNotEmpty ?? false)
        DetailInfoRow(l10n.equipIncidentDiagnosisLabel, issue.diagnosis!),
      if (issue.actions?.isNotEmpty ?? false)
        DetailInfoRow(l10n.equipIncidentActionsLabel, issue.actions!),
      if (issue.partsReplaced?.isNotEmpty ?? false)
        DetailInfoRow(l10n.equipIncidentPartsLabel, issue.partsReplaced!),
      if (issue.reportDurationHours != null)
        DetailInfoRow(l10n.equipIncidentDurationLabel,
            '${issue.reportDurationHours} h'),
      if (issue.reportEstimatedCost != null)
        DetailInfoRow(l10n.equipIncidentCostLabel,
            '${issue.reportEstimatedCost!.toStringAsFixed(0)} RWF'),
      if (issue.resolvedAt?.isNotEmpty ?? false)
        DetailInfoRow(l10n.equipIncidentResolvedAtLabel,
            formatDetailDateShort(issue.resolvedAt!)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final issue = widget.issue;
    final detailRows = _detailRows(l10n);
    final expandable = detailRows.isNotEmpty || issue.documentsCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Zone informative : tap → détail de l'incident ───────────
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IssueDetailScreen(issueId: issue.id),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                    if (issue.documentsCount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined,
                              size: 13, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            l10n.equipIncidentDocumentsBadge(
                                issue.documentsCount),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Bouton de dépliage — hors de l'InkWell de navigation ────
            if (expandable) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _expanded = !_expanded),
                    icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 16),
                    label: Text(
                      _expanded
                          ? l10n.equipIncidentHideDetails
                          : l10n.equipIncidentShowDetails,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...detailRows,
                      if (issue.documentsCount > 0) ...[
                        const SizedBox(height: 8),
                        InterventionDocumentsSection(issueId: issue.id),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
