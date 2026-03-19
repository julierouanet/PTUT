/// Issue status enumeration
enum IssueStatus {
  open,
  inProgress,
  resolved;

  String get displayName {
    switch (this) {
      case IssueStatus.open:
        return 'Ouvert';
      case IssueStatus.inProgress:
        return 'En cours';
      case IssueStatus.resolved:
        return 'Résolu';
    }
  }

  static IssueStatus fromString(String value) {
    switch (value) {
      case 'Open':
      case 'Ouvert':
        return IssueStatus.open;
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
  final String equipmentId;
  final String equipmentName;
  final String department;
  final String type;
  final String description;
  final String reporter;
  final String createdAt;
  final IssueStatus status;
  final String? assignedTechnician;
  final String? diagnosis;
  final String? actions;
  final String? partsReplaced;

  const Issue({
    required this.id,
    required this.equipmentId,
    required this.equipmentName,
    required this.department,
    required this.type,
    required this.description,
    required this.reporter,
    required this.createdAt,
    required this.status,
    this.assignedTechnician,
    this.diagnosis,
    this.actions,
    this.partsReplaced,
  });

  factory Issue.fromApiJson(Map<String, dynamic> json) {
    return Issue(
      id:                 json['id']                   as String? ?? '',
      equipmentId:        json['equipment_id']         as String? ?? '',
      equipmentName:      json['equipment_name']       as String? ?? '',
      department:         json['department']           as String? ?? '',
      type:               json['type']                 as String? ?? '',
      description:        json['description']          as String? ?? '',
      reporter:           json['reporter']             as String? ?? '',
      createdAt:          json['created_at']           as String? ?? '',
      status:             IssueStatus.fromString(json['status'] as String? ?? ''),
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
    String? department,
    String? type,
    String? description,
    String? reporter,
    String? createdAt,
    IssueStatus? status,
    String? assignedTechnician,
    String? diagnosis,
    String? actions,
    String? partsReplaced,
  }) {
    return Issue(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentName: equipmentName ?? this.equipmentName,
      department: department ?? this.department,
      type: type ?? this.type,
      description: description ?? this.description,
      reporter: reporter ?? this.reporter,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      assignedTechnician: assignedTechnician ?? this.assignedTechnician,
      diagnosis: diagnosis ?? this.diagnosis,
      actions: actions ?? this.actions,
      partsReplaced: partsReplaced ?? this.partsReplaced,
    );
  }
}
