import 'package:flutter/material.dart';
import '../models/equipment.dart';
import '../models/issue.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';
import 'urgency_badge.dart';

/// Événement de la timeline (incident ou maintenance)
class _HistoryEvent {
  final DateTime date;
  final bool isIssue;          // true = incident, false = maintenance
  final bool isFuture;         // vrai si maintenance planifiée
  final String title;
  final String subtitle;
  final String? detail;
  final IssueStatus? issueStatus;
  final IssueUrgency? urgency;

  const _HistoryEvent({
    required this.date,
    required this.isIssue,
    this.isFuture = false,
    required this.title,
    required this.subtitle,
    this.detail,
    this.issueStatus,
    this.urgency,
  });
}

/// Dialog d'historique d'un équipement — incidents + maintenances sur une timeline.
class EquipmentHistoryDialog extends StatefulWidget {
  final Equipment equipment;

  const EquipmentHistoryDialog({super.key, required this.equipment});

  static void show(BuildContext context, Equipment equipment) {
    showDialog(
      context: context,
      builder: (_) => EquipmentHistoryDialog(equipment: equipment),
    );
  }

  @override
  State<EquipmentHistoryDialog> createState() => _EquipmentHistoryDialogState();
}

class _EquipmentHistoryDialogState extends State<EquipmentHistoryDialog> {
  List<_HistoryEvent> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final issuesRaw = await DbApiService.instance.getIssues(
        equipmentId: widget.equipment.id,
      );

      final events = <_HistoryEvent>[];

      // Incidents
      for (final raw in issuesRaw) {
        final issue = Issue.fromApiJson(raw);
        DateTime? date;
        try { date = DateTime.parse(issue.createdAt.substring(0, 10)); } catch (_) {}
        if (date == null) continue;
        events.add(_HistoryEvent(
          date: date,
          isIssue: true,
          title: '${issue.type} — ${issue.displayName}',
          subtitle: issue.reporter,
          detail: issue.description,
          issueStatus: issue.status,
          urgency: issue.urgency,
        ));
      }

      // Maintenance passée
      for (final m in widget.equipment.maintenanceHistory) {
        DateTime? date;
        try { date = DateTime.parse(m.date.substring(0, 10)); } catch (_) {}
        if (date == null) continue;
        events.add(_HistoryEvent(
          date: date,
          isIssue: false,
          isFuture: false,
          title: 'Maintenance — ${m.intervention}',
          subtitle: m.technician,
        ));
      }

      // Maintenance planifiée
      for (final m in widget.equipment.futureMaintenance) {
        DateTime? date;
        try { date = DateTime.parse(m.date.substring(0, 10)); } catch (_) {}
        if (date == null) continue;
        events.add(_HistoryEvent(
          date: date,
          isIssue: false,
          isFuture: true,
          title: 'Maintenance planifiée — ${m.intervention}',
          subtitle: m.technician,
        ));
      }

      // Trier par date décroissante (plus récent en haut)
      events.sort((a, b) => b.date.compareTo(a.date));

      setState(() { _events = events; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── En-tête ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(children: [
                const Icon(Icons.history, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      'Historique — ${widget.equipment.name}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      widget.equipment.serialNumber.isNotEmpty
                          ? 'N° ${widget.equipment.serialNumber}'
                          : widget.equipment.department,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ]),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ]),
            ),

            // ── Contenu ──────────────────────────────────────────────────────
            Flexible(
              child: _loading
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ))
                  : _error != null
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Erreur : $_error', style: const TextStyle(color: AppColors.error)),
                        ))
                      : _events.isEmpty
                          ? Center(child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.history_toggle_off, size: 48, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                const Text('Aucun historique pour cet équipement.', style: TextStyle(color: AppColors.textSecondary)),
                              ]),
                            ))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _events.length,
                              itemBuilder: (_, i) => _buildEvent(_events[i], i),
                            ),
            ),

            // ── Pied ─────────────────────────────────────────────────────────
            if (!_loading && _events.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  '${_events.length} événement${_events.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvent(_HistoryEvent ev, int index) {
    final isLast = index == _events.length - 1;

    Color dotColor;
    IconData dotIcon;
    if (ev.isIssue) {
      dotColor = _issueStatusColor(ev.issueStatus);
      dotIcon  = Icons.warning_amber_rounded;
    } else if (ev.isFuture) {
      dotColor = AppColors.primary;
      dotIcon  = Icons.event_available;
    } else {
      dotColor = AppColors.success;
      dotIcon  = Icons.build;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ligne verticale + point ─────────────────────────────────────
          SizedBox(
            width: 48,
            child: Column(children: [
              const SizedBox(height: 12),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 1.5),
                ),
                child: Icon(dotIcon, size: 14, color: dotColor),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: AppColors.border)),
            ]),
          ),

          // ── Contenu ─────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      ev.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (ev.issueStatus != null)
                    IssueStatusBadge(status: ev.issueStatus!.displayName),
                  if (ev.urgency != null) ...[
                    const SizedBox(width: 4),
                    UrgencyBadge(urgency: ev.urgency!, isCompact: true),
                  ],
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.person_outline, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Text(ev.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  Icon(Icons.calendar_today, size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(_fmtDate(ev.date), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ]),
                if (ev.detail != null && ev.detail!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    ev.detail!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Color _issueStatusColor(IssueStatus? s) {
    switch (s) {
      case IssueStatus.reported:         return AppColors.error;
      case IssueStatus.acknowledged:     return AppColors.primary;
      case IssueStatus.assigned:         return AppColors.primary;
      case IssueStatus.inProgress:       return AppColors.warning;
      case IssueStatus.waitingMaterials: return AppColors.warning;
      case IssueStatus.completed:        return AppColors.success;
      case IssueStatus.verified:         return AppColors.success;
      case IssueStatus.closed:           return AppColors.textSecondary;
      case IssueStatus.redirected:       return AppColors.primary;
      default:                           return AppColors.textSecondary;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
