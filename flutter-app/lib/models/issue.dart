/// Issue urgency enumeration (4 levels)
enum IssueUrgency {
  faible,
  moyen,
  urgent,
  critique;

  /// Valeur canonique (FR) — utilisée pour stockage/API (cf. VALID_URGENCIES côté db-service).
  String get displayName {
    switch (this) {
      case IssueUrgency.faible:
        return 'Faible';
      case IssueUrgency.moyen:
        return 'Moyen';
      case IssueUrgency.urgent:
        return 'Urgent';
      case IssueUrgency.critique:
        return 'Critique';
    }
  }

  /// Localized display name — use this in the UI
  String localizedName(dynamic l10n) {
    switch (this) {
      case IssueUrgency.faible:
        return l10n.urgencyLow as String;
      case IssueUrgency.moyen:
        return l10n.urgencyMedium as String;
      case IssueUrgency.urgent:
        return l10n.urgencyHigh as String;
      case IssueUrgency.critique:
        return l10n.urgencyCritical as String;
    }
  }

  static IssueUrgency fromString(String? value) {
    switch (value) {
      case 'Faible':
      case 'Low':
        return IssueUrgency.faible;
      case 'Urgent':
      case 'High':
        return IssueUrgency.urgent;
      case 'Critique':
      case 'Critical':
        return IssueUrgency.critique;
      default:
        return IssueUrgency.moyen;
    }
  }
}

/// Issue status enumeration
enum IssueStatus {
  reported,
  acknowledged,
  assigned,
  inProgress,
  waitingMaterials,
  completed,
  verified,
  closed,
  redirected,
  rejected;

  /// Canonical English name (used for storage/API)
  String get displayName {
    switch (this) {
      case IssueStatus.reported:
        return 'Reported';
      case IssueStatus.acknowledged:
        return 'Acknowledged';
      case IssueStatus.assigned:
        return 'Assigned';
      case IssueStatus.inProgress:
        return 'In Progress';
      case IssueStatus.waitingMaterials:
        return 'Waiting Materials';
      case IssueStatus.completed:
        return 'Completed';
      case IssueStatus.verified:
        return 'Verified';
      case IssueStatus.closed:
        return 'Closed';
      case IssueStatus.redirected:
        return 'Redirected';
      case IssueStatus.rejected:
        return 'Rejected';
    }
  }

  /// Localized display name — use this in the UI
  String localizedName(dynamic l10n) {
    switch (this) {
      case IssueStatus.reported:
        return l10n.issueStatusReported as String;
      case IssueStatus.acknowledged:
        return l10n.issueStatusAcknowledged as String;
      case IssueStatus.assigned:
        return l10n.issueStatusAssigned as String;
      case IssueStatus.inProgress:
        return l10n.issueStatusInProgress as String;
      case IssueStatus.waitingMaterials:
        return l10n.issueStatusWaitingMaterials as String;
      case IssueStatus.completed:
        return l10n.issueStatusCompleted as String;
      case IssueStatus.verified:
        return l10n.issueStatusVerified as String;
      case IssueStatus.closed:
        return l10n.issueStatusClosed as String;
      case IssueStatus.redirected:
        return l10n.issueStatusRedirected as String;
      case IssueStatus.rejected:
        return l10n.issueStatusRejected as String;
    }
  }

  static IssueStatus fromString(String value) {
    switch (value) {
      case 'Reported':
      case 'Ouvert':
        return IssueStatus.reported;
      case 'Acknowledged':
      case 'Approuvé':
        return IssueStatus.acknowledged;
      case 'Assigned':
        return IssueStatus.assigned;
      case 'In Progress':
      case 'En cours':
        return IssueStatus.inProgress;
      case 'Waiting Materials':
        return IssueStatus.waitingMaterials;
      case 'Completed':
      case 'Résolu':
        return IssueStatus.completed;
      case 'Verified':
        return IssueStatus.verified;
      case 'Closed':
      case 'Annulé':
        return IssueStatus.closed;
      case 'Redirected':
        return IssueStatus.redirected;
      case 'Rejected':
      case 'Rejeté':
        return IssueStatus.rejected;
      default:
        return IssueStatus.reported;
    }
  }
}

/// Issue model for equipment problem reporting
class Issue {
  final String id;
  final String? equipmentId;
  final String? equipmentName;
  final String? locationId;
  final String? issueCategory;
  final String? assignedGroup;
  final String department;
  final String type;
  final String description;
  final String reporter;
  final String? reporterId;
  final String? reporterEmail;
  final String? reporterPhone;
  final String createdAt;
  final String? resolvedAt;
  final IssueStatus status;
  final IssueUrgency urgency;
  final String? assignedTechnician;
  final String? takenAt;
  final String? diagnosis;
  final String? actions;
  final String? partsReplaced;
  // Données du rapport d'intervention finalisé (LEFT JOIN serveur — KPIs).
  final double? reportDurationHours;
  final double? reportEstimatedCost;

  const Issue({
    required this.id,
    this.equipmentId,
    this.equipmentName,
    this.locationId,
    this.issueCategory,
    this.assignedGroup,
    required this.department,
    required this.type,
    required this.description,
    required this.reporter,
    this.reporterId,
    this.reporterEmail,
    this.reporterPhone,
    required this.createdAt,
    this.resolvedAt,
    required this.status,
    this.urgency = IssueUrgency.moyen,
    this.assignedTechnician,
    this.takenAt,
    this.diagnosis,
    this.actions,
    this.partsReplaced,
    this.reportDurationHours,
    this.reportEstimatedCost,
  });

  /// Meilleur libellé disponible pour cet incident (équipement, lieu, ou département).
  String get displayName => equipmentName ?? locationId ?? department;

  /// Vrai si l'incident est pris en charge : un technicien est assigné OU le
  /// statut a dépassé le simple signalement.
  bool get isHandled =>
      (assignedTechnician?.isNotEmpty ?? false) ||
      status == IssueStatus.inProgress ||
      status == IssueStatus.assigned ||
      status == IssueStatus.waitingMaterials ||
      status == IssueStatus.completed ||
      status == IssueStatus.verified ||
      status == IssueStatus.closed;

  factory Issue.fromApiJson(Map<String, dynamic> json) {
    return Issue(
      id:                 json['id']                   as String? ?? '',
      equipmentId:        json['equipment_id']         as String?,
      equipmentName:      json['equipment_name']       as String?,
      locationId:         json['location_id']          as String?,
      issueCategory:      json['issue_category']       as String?,
      assignedGroup:      json['assigned_group']       as String?,
      department:         json['department']           as String? ?? '',
      type:               json['type']                 as String? ?? '',
      description:        json['description']          as String? ?? '',
      reporter:           json['reporter']             as String? ?? '',
      reporterId:         json['reporter_id']          as String?,
      reporterEmail:      json['reporter_email']       as String?,
      reporterPhone:      json['reporter_phone']       as String?,
      createdAt:          json['created_at']           as String? ?? '',
      resolvedAt:         json['resolved_at']          as String?,
      status:             IssueStatus.fromString(json['status'] as String? ?? ''),
      urgency:            IssueUrgency.fromString(json['urgency'] as String?),
      assignedTechnician: json['assigned_technician']  as String?,
      takenAt:            json['taken_at']             as String?,
      diagnosis:          json['diagnosis']            as String?,
      actions:            json['actions']              as String?,
      partsReplaced:      json['parts_replaced']       as String?,
      reportDurationHours: (json['report_duration_hours'] as num?)?.toDouble(),
      reportEstimatedCost: (json['report_estimated_cost'] as num?)?.toDouble(),
    );
  }

  Issue copyWith({
    String? id,
    String? equipmentId,
    String? equipmentName,
    String? locationId,
    String? issueCategory,
    String? assignedGroup,
    String? department,
    String? type,
    String? description,
    String? reporter,
    String? reporterId,
    String? reporterEmail,
    String? reporterPhone,
    String? createdAt,
    String? resolvedAt,
    IssueStatus? status,
    IssueUrgency? urgency,
    String? assignedTechnician,
    String? takenAt,
    String? diagnosis,
    String? actions,
    String? partsReplaced,
    double? reportDurationHours,
    double? reportEstimatedCost,
  }) {
    return Issue(
      id:                 id                ?? this.id,
      equipmentId:        equipmentId       ?? this.equipmentId,
      equipmentName:      equipmentName     ?? this.equipmentName,
      locationId:         locationId        ?? this.locationId,
      issueCategory:      issueCategory     ?? this.issueCategory,
      assignedGroup:      assignedGroup     ?? this.assignedGroup,
      department:         department        ?? this.department,
      type:               type              ?? this.type,
      description:        description       ?? this.description,
      reporter:           reporter          ?? this.reporter,
      reporterId:         reporterId        ?? this.reporterId,
      reporterEmail:      reporterEmail     ?? this.reporterEmail,
      reporterPhone:      reporterPhone     ?? this.reporterPhone,
      createdAt:          createdAt         ?? this.createdAt,
      resolvedAt:         resolvedAt        ?? this.resolvedAt,
      status:             status            ?? this.status,
      urgency:            urgency           ?? this.urgency,
      assignedTechnician: assignedTechnician ?? this.assignedTechnician,
      takenAt:            takenAt           ?? this.takenAt,
      diagnosis:          diagnosis         ?? this.diagnosis,
      actions:            actions           ?? this.actions,
      partsReplaced:      partsReplaced     ?? this.partsReplaced,
      reportDurationHours: reportDurationHours ?? this.reportDurationHours,
      reportEstimatedCost: reportEstimatedCost ?? this.reportEstimatedCost,
    );
  }
}
