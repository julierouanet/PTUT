import 'dart:convert';
import 'issue.dart';

/// Entrée de la timeline d'audit pour un incident.
class IssueAuditEntry {
  final int id;
  final String timestamp;
  final String userName;
  final String userRole;
  final String action;
  final Map<String, dynamic>? parsedDetails;

  const IssueAuditEntry({
    required this.id,
    required this.timestamp,
    required this.userName,
    required this.userRole,
    required this.action,
    this.parsedDetails,
  });

  factory IssueAuditEntry.fromApiJson(Map<String, dynamic> json) {
    Map<String, dynamic>? details;
    final raw = json['details'];
    if (raw is String && raw.isNotEmpty) {
      try {
        details = jsonDecode(raw) as Map<String, dynamic>?;
      } catch (_) {
        details = null;
      }
    } else if (raw is Map) {
      details = Map<String, dynamic>.from(raw);
    }
    return IssueAuditEntry(
      id:            (json['id'] as num).toInt(),
      timestamp:     json['timestamp']  as String? ?? '',
      userName:      json['user_name']  as String? ?? '',
      userRole:      json['user_role']  as String? ?? '',
      action:        json['action']     as String? ?? '',
      parsedDetails: details,
    );
  }

  /// Retourne le libellé lisible de l'action pour la timeline.
  String get actionLabel {
    switch (action) {
      case 'create_issue':
        return 'Incident signalé';
      default:
        if (action.startsWith('issue_status_')) {
          final status = action.replaceFirst('issue_status_', '').replaceAll('_', ' ');
          return 'Statut → ${_capitalise(status)}';
        }
        if (action == 'update_issue') {
          final newStatus = parsedDetails?['new_status'] as String?;
          if (newStatus != null) return 'Statut → $newStatus';
          return 'Mise à jour';
        }
        if (action == 'reassign_issue') return 'Réassigné';
        return action.replaceAll('_', ' ');
    }
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Enregistrement de maintenance lié à l'équipement d'un incident.
class MaintenanceRecord {
  final int id;
  final String equipmentId;
  final String date;
  final String intervention;
  final String technician;
  final bool isFuture;

  const MaintenanceRecord({
    required this.id,
    required this.equipmentId,
    required this.date,
    required this.intervention,
    required this.technician,
    required this.isFuture,
  });

  factory MaintenanceRecord.fromApiJson(Map<String, dynamic> json) {
    return MaintenanceRecord(
      id:           (json['id'] as num).toInt(),
      equipmentId:  json['equipment_id']  as String? ?? '',
      date:         json['date']          as String? ?? '',
      intervention: json['intervention']  as String? ?? '',
      technician:   json['technician']    as String? ?? '',
      isFuture:     (json['is_future'] as num? ?? 0) != 0,
    );
  }
}

/// Détail complet d'un incident (enrichi par le backend avec jointures).
class IssueDetail {
  final Issue issue;
  final Map<String, dynamic>? equipment;
  final List<IssueAuditEntry> auditLog;
  final List<MaintenanceRecord> maintenanceRecords;
  /// Champ `updated_at` non présent dans le modèle Issue de base.
  final String? updatedAt;
  /// Champ `location_text` (localisation libre infrastructure) non présent dans Issue.
  final String? locationText;

  const IssueDetail({
    required this.issue,
    this.equipment,
    required this.auditLog,
    required this.maintenanceRecords,
    this.updatedAt,
    this.locationText,
  });

  factory IssueDetail.fromApiJson(Map<String, dynamic> json) {
    final auditRaw = json['audit_log'];
    final auditLog = (auditRaw is List)
        ? auditRaw
            .whereType<Map<String, dynamic>>()
            .map(IssueAuditEntry.fromApiJson)
            .toList()
        : <IssueAuditEntry>[];

    final maintRaw = json['maintenance_records'];
    final maintenanceRecords = (maintRaw is List)
        ? maintRaw
            .whereType<Map<String, dynamic>>()
            .map(MaintenanceRecord.fromApiJson)
            .toList()
        : <MaintenanceRecord>[];

    final equipRaw = json['equipment'];
    final equipment =
        equipRaw is Map ? Map<String, dynamic>.from(equipRaw) : null;

    return IssueDetail(
      issue:              Issue.fromApiJson(json),
      equipment:          equipment,
      auditLog:           auditLog,
      maintenanceRecords: maintenanceRecords,
      updatedAt:          json['updated_at']    as String?,
      locationText:       json['location_text'] as String?,
    );
  }
}
