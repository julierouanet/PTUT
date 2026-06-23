class IssueInterventionSession {
  final int id;
  final String issueId;
  final int loopNumber;
  final String? diagnosis;
  final String? diagnosisAddendum;
  final String? actionTaken;
  final String? outcome;
  final String? nextActions;
  final bool resolved;
  final String? technicianName;
  final String startedAt;
  final String? closedAt;
  final double? durationHours;

  const IssueInterventionSession({
    required this.id,
    required this.issueId,
    required this.loopNumber,
    this.diagnosis,
    this.diagnosisAddendum,
    this.actionTaken,
    this.outcome,
    this.nextActions,
    this.resolved = false,
    this.technicianName,
    required this.startedAt,
    this.closedAt,
    this.durationHours,
  });

  bool get isClosed => closedAt != null;

  factory IssueInterventionSession.fromApiJson(Map<String, dynamic> json) =>
      IssueInterventionSession(
        id:                json['id']                 as int,
        issueId:           json['issue_id']           as String,
        loopNumber:        json['loop_number']        as int,
        diagnosis:         json['diagnosis']          as String?,
        diagnosisAddendum: json['diagnosis_addendum'] as String?,
        actionTaken:       json['action_taken']       as String?,
        outcome:           json['outcome']             as String?,
        nextActions:       json['next_actions']       as String?,
        resolved:          (json['resolved'] as int? ?? 0) == 1,
        technicianName:    json['technician_name']    as String?,
        startedAt:         json['started_at']         as String? ?? '',
        closedAt:          json['closed_at']           as String?,
        durationHours:     (json['duration_hours'] as num?)?.toDouble(),
      );
}
