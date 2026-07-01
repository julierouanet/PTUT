double? _toDouble(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

/// KPI consolidés du rapport final équipement (GET /api/equipment/:id/final-report).
class EquipmentFinalReportSummary {
  final int totalInterventions;
  final double? mttrHoursAvg;
  final double? reopenedRatePct;
  final double downtimeHoursTotal;

  const EquipmentFinalReportSummary({
    required this.totalInterventions,
    this.mttrHoursAvg,
    this.reopenedRatePct,
    required this.downtimeHoursTotal,
  });

  factory EquipmentFinalReportSummary.fromApiJson(Map<String, dynamic> json) =>
      EquipmentFinalReportSummary(
        totalInterventions: json['total_interventions'] as int? ?? 0,
        mttrHoursAvg:       _toDouble(json['mttr_hours_avg']),
        reopenedRatePct:    _toDouble(json['reopened_rate_pct']),
        downtimeHoursTotal: _toDouble(json['downtime_hours_total']) ?? 0,
      );
}

/// Une ligne de l'historique d'interventions du rapport final équipement.
class EquipmentFinalReportIntervention {
  final String issueId;
  final String resolvedAt;
  final String? technicianName;
  final double? durationHours;
  final String? rootCause;
  final String? summary;
  final bool reopened;

  const EquipmentFinalReportIntervention({
    required this.issueId,
    required this.resolvedAt,
    this.technicianName,
    this.durationHours,
    this.rootCause,
    this.summary,
    required this.reopened,
  });

  factory EquipmentFinalReportIntervention.fromApiJson(Map<String, dynamic> json) =>
      EquipmentFinalReportIntervention(
        issueId:        json['issue_id'] as String? ?? '',
        resolvedAt:     json['resolved_at'] as String? ?? '',
        technicianName: json['technician_name'] as String?,
        durationHours:  _toDouble(json['duration_hours']),
        rootCause:      json['root_cause'] as String?,
        summary:        json['summary'] as String?,
        reopened:       json['reopened'] as bool? ?? false,
      );
}

/// Rapport final équipement : résumé consolidé (KPI) + historique complet des
/// interventions résolues. Modèle immuable (pattern CLAUDE.md), fidèle au
/// contrat JSON de GET /api/equipment/:id/final-report.
class EquipmentFinalReport {
  final String equipmentId;
  final String equipmentName;
  final EquipmentFinalReportSummary summary;
  final List<EquipmentFinalReportIntervention> interventions;

  const EquipmentFinalReport({
    required this.equipmentId,
    required this.equipmentName,
    required this.summary,
    required this.interventions,
  });

  factory EquipmentFinalReport.fromApiJson(Map<String, dynamic> json) =>
      EquipmentFinalReport(
        equipmentId:   json['equipment_id'] as String? ?? '',
        equipmentName: json['equipment_name'] as String? ?? '',
        summary: EquipmentFinalReportSummary.fromApiJson(
            json['summary'] as Map<String, dynamic>? ?? const {}),
        interventions: (json['interventions'] as List<dynamic>? ?? const [])
            .map((e) => EquipmentFinalReportIntervention.fromApiJson(e as Map<String, dynamic>))
            .toList(),
      );
}
