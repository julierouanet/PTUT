import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../l10n/app_localizations.dart';
import '../../models/issue_intervention_session.dart';
import '../../services/auth_service.dart';
import '../../services/db_api_service.dart';
import '../../services/pdf_report_service.dart';
import '../../theme/app_theme.dart';

/// Section « Suivi des interventions » — liste les boucles d'une intervention.
///
/// Chaque ligne fermée est cliquable pour générer et afficher le PDF de boucle.
/// Affichée uniquement sur [IssueDetailScreen], jamais sur [IssueStaffDetailScreen].
class InterventionSessionsTimeline extends StatefulWidget {
  final String issueId;
  final String equipmentName;
  final String? equipmentTag;

  const InterventionSessionsTimeline({
    super.key,
    required this.issueId,
    required this.equipmentName,
    this.equipmentTag,
  });

  @override
  State<InterventionSessionsTimeline> createState() =>
      _InterventionSessionsTimelineState();
}

class _InterventionSessionsTimelineState
    extends State<InterventionSessionsTimeline> {
  List<IssueInterventionSession>? _sessions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await DbApiService.instance.getInterventionSessions(widget.issueId);
      if (!mounted) return;
      setState(() {
        _sessions = raw
            .map((e) => IssueInterventionSession.fromApiJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
      );
    }

    final sessions = _sessions ?? [];
    if (sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          l10n.interventionSessionEmpty,
          style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic),
        ),
      );
    }

    final total = sessions
        .where((s) => s.durationHours != null)
        .fold(0.0, (a, s) => a + s.durationHours!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.interventionSessionsTotalTime(total.toStringAsFixed(1)),
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
        ...sessions.map((s) => _buildSessionTile(context, l10n, s)),
      ],
    );
  }

  Widget _buildSessionTile(
      BuildContext context, AppLocalizations l10n, IssueInterventionSession s) {
    final date = (s.closedAt ?? s.startedAt).split('T').first;
    final tech = s.technicianName ?? '—';

    Widget badge;
    if (!s.isClosed) {
      badge = _badge(l10n.interventionSessionBadgeInProgress, AppColors.primary);
    } else if (s.resolved) {
      badge = _badge(l10n.interventionSessionBadgeResolved, AppColors.success);
    } else {
      badge = _badge(l10n.interventionSessionBadgeNotResolved, AppColors.warning);
    }

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: AppColors.primaryLight,
        child: Text('${s.loopNumber}',
            style: const TextStyle(fontSize: 11, color: AppColors.primary,
                fontWeight: FontWeight.w700)),
      ),
      title: Text(
        l10n.interventionSessionLoop(s.loopNumber, date, tech),
        style: const TextStyle(fontSize: 13),
      ),
      trailing: badge,
      onTap: s.isClosed ? () => _openSessionPdf(context, l10n, s) : null,
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      );

  Future<void> _openSessionPdf(
      BuildContext context, AppLocalizations l10n, IssueInterventionSession s) async {
    try {
      final user = AuthService().currentUser;
      final bytes = await PdfReportService.generateInterventionSessionReport(
        session: s,
        issueId: widget.issueId,
        equipmentName: widget.equipmentName,
        equipmentTag: widget.equipmentTag,
        generatedByName: user?.name ?? '—',
        generatedByRole: user?.roles.isNotEmpty == true
            ? user!.roles.first.displayName
            : '—',
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.interventionSessionPdfError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}
