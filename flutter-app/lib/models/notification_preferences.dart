// ── Préférences de notifications email ──────────────────────────────────────

import 'issue.dart';

/// Modèle immuable représentant les préférences de notification email.
///
///   - [notifyNewIssue] + [minUrgencyNewIssue] : Techniciens — nouvel incident
///     signalé, à partir du seuil d'urgence configuré (Faible/Moyen/Urgent/Critique)
///   - [notifyCriticalAcknowledged]: Superviseurs — technicien a pris en charge
///   - [notifyCriticalDiagnosed]   : Superviseurs — diagnostic posé
///   - [notifyCriticalResolved]    : Superviseurs — incident résolu (avec KPIs)
///   - [notifyPmDue]               : Techniciens/Admins — maintenance préventive à planifier
///
/// [preferencesSet] = false → première connexion, modal de configuration à afficher.
class NotificationPreferences {
  final bool notifyNewIssue;
  final IssueUrgency minUrgencyNewIssue;
  final bool notifyCriticalAcknowledged;
  final bool notifyCriticalDiagnosed;
  final bool notifyCriticalResolved;
  final bool notifyPmDue;
  final bool preferencesSet;

  const NotificationPreferences({
    required this.notifyNewIssue,
    required this.minUrgencyNewIssue,
    required this.notifyCriticalAcknowledged,
    required this.notifyCriticalDiagnosed,
    required this.notifyCriticalResolved,
    required this.notifyPmDue,
    required this.preferencesSet,
  });

  /// Préférences par défaut — tout activé, seuil Critique, non encore confirmées.
  static const NotificationPreferences defaults = NotificationPreferences(
    notifyNewIssue:             true,
    minUrgencyNewIssue:         IssueUrgency.critique,
    notifyCriticalAcknowledged: true,
    notifyCriticalDiagnosed:    true,
    notifyCriticalResolved:     true,
    notifyPmDue:                true,
    preferencesSet:             false,
  );

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      notifyNewIssue:             (json['notify_new_issue']             as bool?) ?? true,
      minUrgencyNewIssue:         IssueUrgency.fromString(json['min_urgency_new_issue'] as String?),
      notifyCriticalAcknowledged:(json['notify_critical_acknowledged'] as bool?) ?? true,
      notifyCriticalDiagnosed:   (json['notify_critical_diagnosed']    as bool?) ?? true,
      notifyCriticalResolved:    (json['notify_critical_resolved']     as bool?) ?? true,
      notifyPmDue:               (json['notify_pm_due']                as bool?) ?? true,
      preferencesSet:            (json['preferences_set']              as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'notify_new_issue':             notifyNewIssue,
    'min_urgency_new_issue':        minUrgencyNewIssue.displayName,
    'notify_critical_acknowledged': notifyCriticalAcknowledged,
    'notify_critical_diagnosed':    notifyCriticalDiagnosed,
    'notify_critical_resolved':     notifyCriticalResolved,
    'notify_pm_due':                notifyPmDue,
  };

  NotificationPreferences copyWith({
    bool? notifyNewIssue,
    IssueUrgency? minUrgencyNewIssue,
    bool? notifyCriticalAcknowledged,
    bool? notifyCriticalDiagnosed,
    bool? notifyCriticalResolved,
    bool? notifyPmDue,
    bool? preferencesSet,
  }) {
    return NotificationPreferences(
      notifyNewIssue:             notifyNewIssue             ?? this.notifyNewIssue,
      minUrgencyNewIssue:         minUrgencyNewIssue         ?? this.minUrgencyNewIssue,
      notifyCriticalAcknowledged:notifyCriticalAcknowledged?? this.notifyCriticalAcknowledged,
      notifyCriticalDiagnosed:   notifyCriticalDiagnosed   ?? this.notifyCriticalDiagnosed,
      notifyCriticalResolved:    notifyCriticalResolved     ?? this.notifyCriticalResolved,
      notifyPmDue:               notifyPmDue               ?? this.notifyPmDue,
      preferencesSet:            preferencesSet            ?? this.preferencesSet,
    );
  }
}
