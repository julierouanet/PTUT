import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/issue.dart';
import '../models/issue_detail.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/urgency_badge.dart';
import 'equipment_detail_screen.dart';

/// Page complète de détail d'un incident — standard GMAO.
///
/// Paramètre : [issueId] (String). Les données sont chargées via
/// GET /api/issues/:id (enrichi avec équipement, audit trail, maintenance).
class IssueDetailScreen extends StatefulWidget {
  final String issueId;
  final Function(int, {String? issueId})? onNavigate;

  const IssueDetailScreen({
    super.key,
    required this.issueId,
    this.onNavigate,
  });

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  IssueDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await DbApiService.instance.getIssueDetail(widget.issueId);
      if (mounted) setState(() { _detail = detail; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _detail != null
              ? l10n.issuesIncidentId(_detail!.issue.id)
              : l10n.issueDetailTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
        actions: [
          if (_detail != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IssueStatusBadge(status: _detail!.issue.status.displayName),
                const SizedBox(width: 8),
                UrgencyBadge(urgency: _detail!.issue.urgency),
              ]),
            ),
        ],
      ),
      body: _buildBody(l10n),
      bottomNavigationBar: _detail != null ? _buildBottomBar(l10n) : null,
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l10n.issueDetailLoading, style: const TextStyle(color: AppColors.textSecondary)),
        ]),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(l10n.issueDetailLoadError, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ]),
      );
    }

    final detail = _detail!;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final padding = EdgeInsets.all(isMobile ? 12 : 20);

    return RefreshIndicator(
      onRefresh: () async { setState(() { _loading = true; _error = null; }); await _load(); },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(l10n, detail),
            const SizedBox(height: 12),
            _buildContextCard(l10n, detail),
            const SizedBox(height: 12),
            _buildFailureCard(l10n, detail.issue),
            const SizedBox(height: 12),
            _buildInterventionCard(l10n, detail.issue),
            if (detail.maintenanceRecords.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildMaintenanceCard(l10n, detail.maintenanceRecords),
            ],
            const SizedBox(height: 12),
            _buildTimelineCard(l10n, detail.auditLog),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── Carte En-tête ──────────────────────────────────────────────────────────

  Widget _buildHeaderCard(AppLocalizations l10n, IssueDetail detail) {
    final issue = detail.issue;
    return _SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IssueStatusBadge(status: issue.status.displayName),
          const SizedBox(width: 8),
          UrgencyBadge(urgency: issue.urgency),
        ]),
        const SizedBox(height: 16),
        _InfoRow(label: l10n.issueDetailReporter,   value: issue.reporter),
        if (issue.reporterEmail != null && issue.reporterEmail!.isNotEmpty)
          _InfoRow(label: l10n.commonEmail,           value: issue.reporterEmail!),
        _InfoRow(label: l10n.issueDetailReportDate,  value: issue.createdAt),
        if (detail.updatedAt != null && detail.updatedAt!.isNotEmpty)
          _InfoRow(label: l10n.issueDetailUpdatedAt, value: detail.updatedAt!),
      ]),
    );
  }

  // ── Carte Contexte ─────────────────────────────────────────────────────────

  Widget _buildContextCard(AppLocalizations l10n, IssueDetail detail) {
    final issue     = detail.issue;
    final equipment = detail.equipment;
    final locText   = detail.locationText;

    return _SectionCard(
      title: l10n.issueDetailSectionContext,
      icon: Icons.info_outline,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Équipement lié avec bouton de navigation
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 160,
              child: Text(l10n.issuesEquipment,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
            Expanded(
              child: issue.equipmentId != null
                  ? InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EquipmentDetailScreen(
                            equipmentId: issue.equipmentId!,
                          ),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                          child: Text(
                            issue.equipmentName ?? issue.equipmentId!,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.open_in_new, size: 14, color: AppColors.primary),
                      ]),
                    )
                  : Text(
                      issue.locationId ?? locText ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
            ),
          ]),
        ),
        if (issue.issueCategory != null)
          _InfoRow(label: l10n.issueDetailCategory, value: issue.issueCategory!),
        if (issue.assignedGroup != null)
          _InfoRow(label: l10n.issueDetailGroup,    value: issue.assignedGroup!),
        _InfoRow(label: l10n.commonDepartment,       value: issue.department),
        if (equipment != null && equipment['location'] != null)
          _InfoRow(label: l10n.issueDetailLocation,
              value: equipment['location'] as String),
      ]),
    );
  }

  // ── Carte Panne ────────────────────────────────────────────────────────────

  Widget _buildFailureCard(AppLocalizations l10n, Issue issue) {
    return _SectionCard(
      title: l10n.issueDetailSectionFailure,
      icon: Icons.warning_amber_rounded,
      iconColor: AppColors.error,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _InfoRow(label: l10n.issueDetailTypeLabel, value: issue.type),
        const SizedBox(height: 8),
        Text(l10n.issuesDescription,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            issue.description,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
      ]),
    );
  }

  // ── Carte Intervention ─────────────────────────────────────────────────────

  Widget _buildInterventionCard(AppLocalizations l10n, Issue issue) {
    final hasTech    = issue.assignedTechnician != null && issue.assignedTechnician!.isNotEmpty;
    final hasDiag    = issue.diagnosis    != null && issue.diagnosis!.isNotEmpty;
    final hasActions = issue.actions      != null && issue.actions!.isNotEmpty;
    final hasParts   = issue.partsReplaced != null && issue.partsReplaced!.isNotEmpty;
    final hasAny     = hasTech || hasDiag || hasActions || hasParts;

    return _SectionCard(
      title: l10n.issueDetailSectionIntervention,
      icon: Icons.build_outlined,
      iconColor: AppColors.warning,
      child: hasAny
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (hasTech)   _InfoRow(label: l10n.issueDetailAssignedTech, value: issue.assignedTechnician!),
              if (hasDiag) ...[
                _LargeInfoBlock(label: l10n.issueDetailRootCause, value: issue.diagnosis!),
                const SizedBox(height: 8),
              ],
              if (hasActions) ...[
                _LargeInfoBlock(label: l10n.issueDetailCorrectiveActions, value: issue.actions!),
                const SizedBox(height: 8),
              ],
              if (hasParts)   _InfoRow(label: l10n.issueDetailPartsUsed, value: issue.partsReplaced!),
            ])
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                const Icon(Icons.hourglass_empty, color: AppColors.textMuted, size: 18),
                const SizedBox(width: 8),
                Text(l10n.issueDetailNoIntervention,
                    style: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
              ]),
            ),
    );
  }

  // ── Carte Maintenance récente ──────────────────────────────────────────────

  Widget _buildMaintenanceCard(
      AppLocalizations l10n, List<MaintenanceRecord> records) {
    final past = records.where((r) => !r.isFuture).toList();
    if (past.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: l10n.issueDetailMaintenanceHistory,
      icon: Icons.history,
      iconColor: AppColors.primary,
      child: Column(
        children: past
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.intervention,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('${r.date} — ${r.technician}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  // ── Carte Timeline / Historique ────────────────────────────────────────────

  Widget _buildTimelineCard(AppLocalizations l10n, List<IssueAuditEntry> log) {
    return _SectionCard(
      title: l10n.issueDetailSectionHistory,
      icon: Icons.timeline,
      iconColor: AppColors.primary,
      child: log.isEmpty
          ? Row(children: [
              const Icon(Icons.history_toggle_off,
                  color: AppColors.textMuted, size: 18),
              const SizedBox(width: 8),
              Text(l10n.issueDetailNoHistory,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
            ])
          : Column(
              children: List.generate(log.length, (i) {
                final entry = log[i];
                final isLast = i == log.length - 1;
                return _TimelineEntry(
                  entry:  entry,
                  isLast: isLast,
                );
              }),
            ),
    );
  }

  // ── Barre de bas de page ───────────────────────────────────────────────────

  Widget _buildBottomBar(AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              if (widget.onNavigate != null) {
                Navigator.pop(context);
                widget.onNavigate!(4, issueId: widget.issueId);
              } else {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.build, size: 18),
            label: Text(l10n.issueDetailUpdateButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets internes réutilisables ─────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final IconData? icon;
  final Color? iconColor;

  const _SectionCard({
    required this.child,
    this.title,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[
            Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
                const SizedBox(width: 8),
              ],
              Text(
                title!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ]),
            const Divider(height: 20),
          ],
          child,
        ]),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 160,
          child: Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ),
      ]),
    );
  }
}

class _LargeInfoBlock extends StatelessWidget {
  final String label;
  final String value;

  const _LargeInfoBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(value, style: const TextStyle(fontSize: 13, height: 1.5)),
      ),
    ]);
  }
}

class _TimelineEntry extends StatelessWidget {
  final IssueAuditEntry entry;
  final bool isLast;

  const _TimelineEntry({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(entry.action);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 24,
          child: Column(children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 2,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                entry.actionLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${entry.userName} · ${entry.userRole}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                entry.timestamp,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
              ),
              if (entry.parsedDetails != null &&
                  (entry.parsedDetails!['new_status'] != null ||
                      entry.parsedDetails!['new_group'] != null)) ...[
                const SizedBox(height: 4),
                _buildDetailChips(entry.parsedDetails!),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildDetailChips(Map<String, dynamic> d) {
    final items = <Widget>[];
    final oldStatus = d['old_status'] as String?;
    final newStatus = d['new_status'] as String?;
    if (oldStatus != null && newStatus != null) {
      items.add(_chip('$oldStatus → $newStatus', AppColors.warning));
    }
    final oldGroup = d['old_group'] as String?;
    final newGroup = d['new_group'] as String?;
    if (oldGroup != null && newGroup != null) {
      items.add(_chip('$oldGroup → $newGroup', AppColors.primary));
    }
    return Wrap(spacing: 6, runSpacing: 4, children: items);
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Color _actionColor(String action) {
    if (action == 'create_issue') { return AppColors.error; }
    if (action.contains('status_completed') ||
        action.contains('status_verified') ||
        action.contains('status_closed')) { return AppColors.success; }
    if (action.contains('status_in_progress') ||
        action.contains('status_assigned')) { return AppColors.warning; }
    if (action == 'reassign_issue') { return AppColors.primary; }
    return AppColors.textSecondary;
  }
}

