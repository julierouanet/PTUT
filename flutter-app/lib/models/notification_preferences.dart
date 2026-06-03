// ── Préférences de notifications email — incidents critiques uniquement ────────

/// Modèle immuable représentant les préférences de notification email.
///
/// Toutes les notifications sont centrées sur les incidents CRITIQUES :
///   - [notifyCriticalNewIssue]    : Techniciens — nouvel incident critique signalé
///   - [notifyCriticalAcknowledged]: Superviseurs — technicien a pris en charge
///   - [notifyCriticalDiagnosed]   : Superviseurs — diagnostic posé
///   - [notifyCriticalResolved]    : Superviseurs — incident résolu (avec KPIs)
///   - [notifyPmDue]               : Techniciens/Admins — maintenance préventive à planifier
///
/// [preferencesSet] = false → première connexion, modal de configuration à afficher.
class NotificationPreferences {
  final bool notifyCriticalNewIssue;
  final bool notifyCriticalAcknowledged;
  final bool notifyCriticalDiagnosed;
  final bool notifyCriticalResolved;
  final bool notifyPmDue;
  final bool preferencesSet;

  const NotificationPreferences({
    required this.notifyCriticalNewIssue,
    required this.notifyCriticalAcknowledged,
    required this.notifyCriticalDiagnosed,
    required this.notifyCriticalResolved,
    required this.notifyPmDue,
    required this.preferencesSet,
  });

  /// Préférences par défaut — tout activé, non encore confirmées.
  static const NotificationPreferences defaults = NotificationPreferences(
    notifyCriticalNewIssue:    true,
    notifyCriticalAcknowledged: true,
    notifyCriticalDiagnosed:   true,
    notifyCriticalResolved:    true,
    notifyPmDue:               true,
    preferencesSet:            false,
  );

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      notifyCriticalNewIssue:    (json['notify_critical_new_issue']    as bool?) ?? true,
      notifyCriticalAcknowledged:(json['notify_critical_acknowledged'] as bool?) ?? true,
      notifyCriticalDiagnosed:   (json['notify_critical_diagnosed']    as bool?) ?? true,
      notifyCriticalResolved:    (json['notify_critical_resolved']     as bool?) ?? true,
      notifyPmDue:               (json['notify_pm_due']                as bool?) ?? true,
      preferencesSet:            (json['preferences_set']              as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'notify_critical_new_issue':    notifyCriticalNewIssue,
    'notify_critical_acknowledged': notifyCriticalAcknowledged,
    'notify_critical_diagnosed':    notifyCriticalDiagnosed,
    'notify_critical_resolved':     notifyCriticalResolved,
    'notify_pm_due':                notifyPmDue,
  };

  NotificationPreferences copyWith({
    bool? notifyCriticalNewIssue,
    bool? notifyCriticalAcknowledged,
    bool? notifyCriticalDiagnosed,
    bool? notifyCriticalResolved,
    bool? notifyPmDue,
    bool? preferencesSet,
  }) {
    return NotificationPreferences(
      notifyCriticalNewIssue:    notifyCriticalNewIssue    ?? this.notifyCriticalNewIssue,
      notifyCriticalAcknowledged:notifyCriticalAcknowledged?? this.notifyCriticalAcknowledged,
      notifyCriticalDiagnosed:   notifyCriticalDiagnosed   ?? this.notifyCriticalDiagnosed,
      notifyCriticalResolved:    notifyCriticalResolved     ?? this.notifyCriticalResolved,
      notifyPmDue:               notifyPmDue               ?? this.notifyPmDue,
      preferencesSet:            preferencesSet            ?? this.preferencesSet,
    );
  }
}
