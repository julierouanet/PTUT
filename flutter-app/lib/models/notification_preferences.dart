// ── Préférences de notifications email de l'utilisateur ──────────────────────

/// Modèle immuable représentant les préférences de notification email.
/// [preferencesSet] = false indique une première connexion (modal à afficher).
class NotificationPreferences {
  final bool notifyNewIssue;
  final bool notifyIssueAssigned;
  final bool notifyIssueResolved;
  final bool notifyIssueStatusUpdate;
  final bool notifyPmDue;
  final bool preferencesSet;

  const NotificationPreferences({
    required this.notifyNewIssue,
    required this.notifyIssueAssigned,
    required this.notifyIssueResolved,
    required this.notifyIssueStatusUpdate,
    required this.notifyPmDue,
    required this.preferencesSet,
  });

  /// Préférences par défaut — tout activé, non encore confirmées par l'utilisateur.
  static const NotificationPreferences defaults = NotificationPreferences(
    notifyNewIssue:          true,
    notifyIssueAssigned:     true,
    notifyIssueResolved:     true,
    notifyIssueStatusUpdate: true,
    notifyPmDue:             true,
    preferencesSet:          false,
  );

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      notifyNewIssue:          (json['notify_new_issue']           as bool?) ?? true,
      notifyIssueAssigned:     (json['notify_issue_assigned']      as bool?) ?? true,
      notifyIssueResolved:     (json['notify_issue_resolved']      as bool?) ?? true,
      notifyIssueStatusUpdate: (json['notify_issue_status_update'] as bool?) ?? true,
      notifyPmDue:             (json['notify_pm_due']              as bool?) ?? true,
      preferencesSet:          (json['preferences_set']            as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'notify_new_issue':           notifyNewIssue,
    'notify_issue_assigned':      notifyIssueAssigned,
    'notify_issue_resolved':      notifyIssueResolved,
    'notify_issue_status_update': notifyIssueStatusUpdate,
    'notify_pm_due':              notifyPmDue,
  };

  NotificationPreferences copyWith({
    bool? notifyNewIssue,
    bool? notifyIssueAssigned,
    bool? notifyIssueResolved,
    bool? notifyIssueStatusUpdate,
    bool? notifyPmDue,
    bool? preferencesSet,
  }) {
    return NotificationPreferences(
      notifyNewIssue:          notifyNewIssue          ?? this.notifyNewIssue,
      notifyIssueAssigned:     notifyIssueAssigned     ?? this.notifyIssueAssigned,
      notifyIssueResolved:     notifyIssueResolved     ?? this.notifyIssueResolved,
      notifyIssueStatusUpdate: notifyIssueStatusUpdate ?? this.notifyIssueStatusUpdate,
      notifyPmDue:             notifyPmDue             ?? this.notifyPmDue,
      preferencesSet:          preferencesSet          ?? this.preferencesSet,
    );
  }
}
