import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/issue.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/urgency_badge.dart';
import '../widgets/issue/intervention_report_section.dart';

/// Vue lecture seule d'un incident pour le personnel hospitalier (hospitalStaff).
/// Masque le diagnostic, les actions et les pièces — affiche le statut et la timeline.
class IssueStaffDetailScreen extends StatelessWidget {
  final Issue issue;

  const IssueStaffDetailScreen({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.issueStaffDetailTitle),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Badge statut + urgence ──────────────────────────────────
            Row(children: [
              StatusBadge(status: issue.status.displayName),
              const SizedBox(width: 12),
              UrgencyBadge(urgency: issue.urgency),
            ]),
            const SizedBox(height: 20),

            // ── Infos de base ────────────────────────────────────────────
            _InfoCard(children: [
              _InfoRow(
                  label: l10n.issueDetailTypeLabel,
                  value: issue.displayName),
              _InfoRow(
                  label: l10n.equipmentColumnInstallDate.isEmpty
                      ? 'Équipement'
                      : l10n.issueDetailCategory,
                  value: issue.equipmentName ?? issue.department),
              _InfoRow(
                  label: l10n.commonDepartment,
                  value: issue.department),
              _InfoRow(
                  label: l10n.issueDetailReporter,
                  value: issue.reporter),
              _InfoRow(
                  label: l10n.issueDetailReportDate,
                  value: _formatDate(issue.createdAt)),
              if (issue.assignedTechnician != null)
                _InfoRow(
                    label: l10n.issueDetailAssignedTech,
                    value: issue.assignedTechnician!),
              if (issue.takenAt != null)
                _InfoRow(
                    label: l10n.issueDetailUpdatedAt,
                    value: _formatDate(issue.takenAt!)),
            ]),
            const SizedBox(height: 24),

            // ── Description ──────────────────────────────────────────────
            if (issue.description.isNotEmpty) ...[
              Text(
                l10n.issueDetailSectionFailure,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(issue.description,
                    style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 24),
            ],

            // ── Timeline de progression ──────────────────────────────────
            Text(
              l10n.issueDetailSectionHistory,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            _IssueTimeline(issue: issue, l10n: l10n),

            // ── Rapport d'intervention finalisé (lecture seule) ──────────
            const SizedBox(height: 24),
            InterventionReportSection(
              key: ValueKey('staff-report-${issue.id}'),
              issueId: issue.id,
              readOnly: true,
            ),
          ],
        ),
      ),
    );
  }

  /// Formatte une date ISO ou datetime → "DD/MM/YYYY"
  String _formatDate(String raw) {
    if (raw.length < 10) return raw;
    final part = raw.substring(0, 10).split('-');
    if (part.length == 3) return '${part[2]}/${part[1]}/${part[0]}';
    return raw;
  }
}

// ── Widget de timeline ────────────────────────────────────────────────────────

class _IssueTimeline extends StatelessWidget {
  final Issue issue;
  final AppLocalizations l10n;

  const _IssueTimeline({required this.issue, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();

    return Column(
      children: steps.asMap().entries.map((entry) {
        final isLast  = entry.key == steps.length - 1;
        final step    = entry.value;
        return _TimelineStep(
          label:    step.label,
          date:     step.date,
          isDone:   step.isDone,
          isCurrent: step.isCurrent,
          isLast:   isLast,
        );
      }).toList(),
    );
  }

  List<_StepData> _buildSteps() {
    // Determine la position actuelle dans le workflow
    final currentIndex = _statusIndex(issue.status);

    return [
      _StepData(
        label:     l10n.issueTimelineReported,
        date:      _fmt(issue.createdAt),
        isDone:    currentIndex >= 0,
        isCurrent: currentIndex == 0,
      ),
      _StepData(
        label:     l10n.issueTimelineAcknowledged,
        date:      currentIndex >= 1 && issue.takenAt != null
            ? _fmt(issue.takenAt!)
            : null,
        isDone:    currentIndex >= 1,
        isCurrent: currentIndex == 1,
      ),
      _StepData(
        label:     l10n.issueTimelineInProgress,
        date:      currentIndex >= 2 && issue.takenAt != null
            ? _fmt(issue.takenAt!)
            : null,
        isDone:    currentIndex >= 2,
        isCurrent: currentIndex == 2,
      ),
      _StepData(
        label:     l10n.issueTimelineResolved,
        date:      null,
        isDone:    currentIndex >= 3,
        isCurrent: currentIndex == 3,
      ),
    ];
  }

  /// Convertit un IssueStatus en index de la timeline (0 = signalé, 3 = résolu)
  int _statusIndex(IssueStatus s) {
    switch (s) {
      case IssueStatus.reported:
        return 0;
      case IssueStatus.acknowledged:
      case IssueStatus.assigned:
        return 1;
      case IssueStatus.inProgress:
      case IssueStatus.waitingMaterials:
      case IssueStatus.redirected:
        return 2;
      case IssueStatus.completed:
      case IssueStatus.verified:
      case IssueStatus.closed:
        return 3;
    }
  }

  String _fmt(String raw) {
    if (raw.length < 10) return raw;
    final p = raw.substring(0, 10).split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : raw;
  }
}

class _StepData {
  final String  label;
  final String? date;
  final bool    isDone;
  final bool    isCurrent;

  const _StepData({
    required this.label,
    required this.date,
    required this.isDone,
    required this.isCurrent,
  });
}

class _TimelineStep extends StatelessWidget {
  final String  label;
  final String? date;
  final bool    isDone;
  final bool    isCurrent;
  final bool    isLast;

  const _TimelineStep({
    required this.label,
    required this.date,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCurrent
        ? AppColors.primary
        : isDone
            ? AppColors.success
            : AppColors.border;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicateur circulaire + ligne verticale
        SizedBox(
          width: 32,
          child: Column(children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color:  isDone || isCurrent ? color : Colors.white,
                shape:  BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: isDone && !isCurrent
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                  : isCurrent
                      ? Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        )
                      : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isDone ? AppColors.success : AppColors.border,
              ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent
                        ? AppColors.primary
                        : isDone
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
                if (date != null)
                  Text(
                    date!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Widgets helpers ───────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
