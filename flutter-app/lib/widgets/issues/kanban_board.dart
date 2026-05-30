import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/issue.dart';
import '../../theme/app_theme.dart';
import '../urgency_badge.dart';

// ── Carte d'un incident dans une colonne ────────────────────────────────────

class _KanbanCard extends StatelessWidget {
  final Issue issue;
  final void Function(Issue) onTap;

  const _KanbanCard({required this.issue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => onTap(issue),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                issue.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                issue.description,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(children: [
                UrgencyBadge(urgency: issue.urgency, isCompact: true),
                const Spacer(),
                Text(
                  issue.createdAt.length >= 10
                      ? issue.createdAt.substring(0, 10)
                      : issue.createdAt,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ]),
              if (issue.department.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  issue.department,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Colonne du tableau Kanban ────────────────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  final String title;
  final Color color;
  final List<Issue> issues;
  final void Function(Issue) onTap;

  const _KanbanColumn({
    required this.title,
    required this.color,
    required this.issues,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── En-tête de colonne ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${issues.length}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ]),
          ),

          // ── Corps de la colonne ─────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  left:   BorderSide(color: color.withValues(alpha: 0.2)),
                  right:  BorderSide(color: color.withValues(alpha: 0.2)),
                  bottom: BorderSide(color: color.withValues(alpha: 0.2)),
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: issues.isEmpty
                  ? Center(
                      child: Text(
                        l10n.issuesKanbanEmpty,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: issues.length,
                      itemBuilder: (_, i) => _KanbanCard(issue: issues[i], onTap: onTap),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vue Kanban publique ─────────────────────────────────────────────────────

/// Tableau Kanban à 4 colonnes (À faire / En cours / En attente / Terminé).
///
/// À utiliser uniquement sur Desktop (≥ 800 px) ; l'écran parent gère
/// la condition de visibilité.
class IssueKanbanBoard extends StatelessWidget {
  final List<Issue> issues;
  final void Function(Issue) onIssueTap;

  const IssueKanbanBoard({
    super.key,
    required this.issues,
    required this.onIssueTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Regroupement GMAO en 4 colonnes
    final todo       = issues.where((i) => i.status == IssueStatus.reported || i.status == IssueStatus.acknowledged).toList();
    final inProgress = issues.where((i) => i.status == IssueStatus.assigned  || i.status == IssueStatus.inProgress).toList();
    final waiting    = issues.where((i) => i.status == IssueStatus.waitingMaterials || i.status == IssueStatus.redirected).toList();
    final done       = issues.where((i) => i.status == IssueStatus.completed  || i.status == IssueStatus.verified || i.status == IssueStatus.closed).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        height: double.infinity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KanbanColumn(title: l10n.issuesKanbanColTodo,        color: AppColors.error,                  issues: todo,       onTap: onIssueTap),
            const SizedBox(width: 12),
            _KanbanColumn(title: l10n.issuesKanbanColInProgress,  color: AppColors.warning,                issues: inProgress, onTap: onIssueTap),
            const SizedBox(width: 12),
            _KanbanColumn(title: l10n.issuesKanbanColWaiting,     color: const Color(0xFF6A1B9A),          issues: waiting,    onTap: onIssueTap),
            const SizedBox(width: 12),
            _KanbanColumn(title: l10n.issuesKanbanColDone,        color: AppColors.success,                issues: done,       onTap: onIssueTap),
          ],
        ),
      ),
    );
  }
}
