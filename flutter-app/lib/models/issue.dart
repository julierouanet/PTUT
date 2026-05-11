/// Issue urgency enumeration (3 levels)
enum IssueUrgency {
  faible,
  moyen,
  urgent;

  /// Valeur canonique (FR) — utilisée pour stockage/API (cf. VALID_URGENCIES côté db-service).
  String get displayName {
    switch (this) {
      case IssueUrgency.faible:
        return 'Faible';
      case IssueUrgency.moyen:
        return 'Moyen';
      case IssueUrgency.urgent:
        return 'Urgent';
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
      default:
        return IssueUrgency.moyen;
    }
  }
}

/// Issue status enumeration
enum IssueStatus {
  open,
  approved,
  inProgress,
  resolved;

  /// Canonical English name (used for storage/API)
  String get displayName {
    switch (this) {
      case IssueStatus.open:
        return 'Open';
      case IssueStatus.approved:
        return 'Approved';
      case IssueStatus.inProgress:
        return 'In Progress';
      case IssueStatus.resolved:
        return 'Resolved';
    }
  }

  /// Localized display name — use this in the UI
  String localizedName(dynamic l10n) {
    switch (this) {
      case IssueStatus.open:
        return l10n.issueStatusOpen as String;
      case IssueStatus.approved:
        return l10n.issueStatusApproved as String;
      case IssueStatus.inProgress:
        return l10n.issueStatusInProgress as String;
      case IssueStatus.resolved:
        return l10n.issueStatusResolved as String;
    }
  }

  static IssueStatus fromString(String value) {
    switch (value) {
      case 'Open':
      case 'Ouvert':
        return IssueStatus.open;
      case 'Approved':
      case 'Approuvé':
        return IssueStatus.approved;
      case 'In Progress':
      case 'En cours':
        return IssueStatus.inProgress;
      case 'Resolved':
      case 'Résolu':
        return IssueStatus.resolved;
      default:
        return IssueStatus.open;
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
  final String createdAt;
  final IssueStatus status;
  final IssueUrgency urgency;
  final String? assignedTechnician;
  final String? diagnosis;
  final String? actions;
  final String? partsReplaced;

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
    required this.createdAt,
    required this.status,
    this.urgency = IssueUrgency.moyen,
    this.assignedTechnician,
    this.diagnosis,
    this.actions,
    this.partsReplaced,
  });

  /// Meilleur libellé disponible pour cet incident (équipement, lieu, ou département).
  String get displayName => equipmentName ?? locationId ?? department;

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
      createdAt:          json['created_at']           as String? ?? '',
      status:             IssueStatus.fromString(json['status'] as String? ?? ''),
      urgency:            IssueUrgency.fromString(json['urgency'] as String?),
      assignedTechnician: json['assigned_technician']  as String?,
      diagnosis:          json['diagnosis']            as String?,
      actions:            json['actions']              as String?,
      partsReplaced:      json['parts_replaced']       as String?,
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
    String? createdAt,
    IssueStatus? status,
    IssueUrgency? urgency,
    String? assignedTechnician,
    String? diagnosis,
    String? actions,
    String? partsReplaced,
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
      createdAt:          createdAt         ?? this.createdAt,
      status:             status            ?? this.status,
      urgency:            urgency           ?? this.urgency,
      assignedTechnician: assignedTechnician ?? this.assignedTechnician,
      diagnosis:          diagnosis         ?? this.diagnosis,
      actions:            actions           ?? this.actions,
      partsReplaced:      partsReplaced     ?? this.partsReplaced,
    );
  }
}
