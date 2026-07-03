import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/issue_intervention_session.dart';
import '../../services/db_api_service.dart';
import '../../theme/app_theme.dart';

/// Résumé « Follow up » d'un incident : diagnostics successifs, dernière action
/// prise, dernier résultat et prochaine action planifiée, calculés à partir des
/// boucles réelles (`issue_intervention_sessions`) plutôt que des champs figés
/// hérités (`issues.diagnosis`/`issues.actions`).
class IssueFollowUpCard extends StatefulWidget {
  final String issueId;

  const IssueFollowUpCard({super.key, required this.issueId});

  @override
  State<IssueFollowUpCard> createState() => _IssueFollowUpCardState();
}

class _IssueFollowUpCardState extends State<IssueFollowUpCard> {
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

  static String _fmtDateTime(String raw) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
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
        child: Row(children: [
          const Icon(Icons.hourglass_empty, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 8),
          Text(l10n.issueDetailNoIntervention,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
        ]),
      );
    }

    // Diagnostics successifs — ordre chronologique (sessions déjà triées par
    // loop_number ASC côté serveur).
    final diagnosisEntries =
        sessions.where((s) => (s.diagnosis ?? '').isNotEmpty).toList();

    // Dernière action prise : session au loopNumber le plus élevé (ouverte ou fermée)
    final lastAction = sessions.last.actionTaken;

    // Dernier résultat : outcome de la dernière session FERMÉE avec un outcome renseigné
    String? lastOutcome;
    for (final s in sessions.reversed) {
      if (s.isClosed && (s.outcome ?? '').isNotEmpty) {
        lastOutcome = s.outcome;
        break;
      }
    }

    // Prochaine action : dernière session fermée non résolue avec nextActions renseigné
    IssueInterventionSession? nextActionSession;
    for (final s in sessions.reversed) {
      if (s.isClosed && !s.resolved && (s.nextActions ?? '').isNotEmpty) {
        nextActionSession = s;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (diagnosisEntries.isNotEmpty) ...[
          Text(l10n.issueFollowUpDiagnosisTitle,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          ...diagnosisEntries.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.issueFollowUpLoopDiagnosis(s.loopNumber, s.diagnosis!),
                      style: const TextStyle(fontSize: 13),
                    ),
                    if ((s.diagnosisAddendum ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          s.diagnosisAddendum!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],
        if ((lastAction ?? '').isNotEmpty) ...[
          _FollowUpBlock(label: l10n.issueFollowUpLastAction, value: lastAction!),
          const SizedBox(height: 8),
        ],
        if (lastOutcome != null) ...[
          _FollowUpBlock(label: l10n.issueFollowUpLastOutcome, value: lastOutcome),
          const SizedBox(height: 8),
        ],
        if (nextActionSession != null)
          _FollowUpBlock(
            label: l10n.issueFollowUpNextAction,
            value: nextActionSession.nextActionDueAt != null
                ? '${nextActionSession.nextActions!}\n\n'
                    '${l10n.issueFollowUpNextActionDue(_fmtDateTime(nextActionSession.nextActionDueAt!))}'
                : nextActionSession.nextActions!,
          ),
      ],
    );
  }
}

class _FollowUpBlock extends StatelessWidget {
  final String label;
  final String value;

  const _FollowUpBlock({required this.label, required this.value});

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
