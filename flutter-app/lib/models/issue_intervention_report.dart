/// Statut d'un rapport d'intervention.
enum InterventionReportStatus {
  draft,
  finalized;

  bool get isFinalized => this == InterventionReportStatus.finalized;

  /// Conversion depuis l'API avec défaut sûr (`draft`).
  static InterventionReportStatus fromString(String? value) =>
      switch ((value ?? '').toLowerCase()) {
        'finalized' => InterventionReportStatus.finalized,
        _           => InterventionReportStatus.draft,
      };

  String get apiValue => switch (this) {
        InterventionReportStatus.draft     => 'draft',
        InterventionReportStatus.finalized => 'finalized',
      };
}

/// Rapport d'intervention 1:1 avec un incident.
///
/// Modèle immuable (pattern CLAUDE.md). Les champs `diagnosis`/`actions`/
/// `partsReplaced` sont des champs de pré-remplissage lus EN DIRECT depuis
/// l'incident côté serveur — ils ne sont jamais dupliqués en base.
class IssueInterventionReport {
  final String issueId;
  final String? summary;
  final String? rootCause;
  final String? recommendations;
  final double? durationHours;
  final String? returnedToServiceAt;
  final double? estimatedCost;
  final String? finalEquipmentStatus;
  final String? authorId;
  final String? authorName;
  final String? validatedById;
  final String? validatedByName;
  final String? validatedAt;
  final InterventionReportStatus reportStatus;

  // Champs live de l'incident (lecture seule, pré-remplissage)
  final String? diagnosis;
  final String? actions;
  final String? partsReplaced;
  final String? equipmentId;
  final String? equipmentName;
  final String? issueStatus;

  const IssueInterventionReport({
    required this.issueId,
    this.summary,
    this.rootCause,
    this.recommendations,
    this.durationHours,
    this.returnedToServiceAt,
    this.estimatedCost,
    this.finalEquipmentStatus,
    this.authorId,
    this.authorName,
    this.validatedById,
    this.validatedByName,
    this.validatedAt,
    this.reportStatus = InterventionReportStatus.draft,
    this.diagnosis,
    this.actions,
    this.partsReplaced,
    this.equipmentId,
    this.equipmentName,
    this.issueStatus,
  });

  bool get isFinalized => reportStatus.isFinalized;

  static double? _toDouble(dynamic v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

  factory IssueInterventionReport.fromApiJson(Map<String, dynamic> json) =>
      IssueInterventionReport(
        issueId:              json['issue_id'] as String? ?? '',
        summary:              json['summary'] as String?,
        rootCause:            json['root_cause'] as String?,
        recommendations:      json['recommendations'] as String?,
        durationHours:        _toDouble(json['duration_hours']),
        returnedToServiceAt:  json['returned_to_service_at'] as String?,
        estimatedCost:        _toDouble(json['estimated_cost']),
        finalEquipmentStatus: json['final_equipment_status'] as String?,
        authorId:             json['author_id'] as String?,
        authorName:           json['author_name'] as String?,
        validatedById:        json['validated_by_id'] as String?,
        validatedByName:      json['validated_by_name'] as String?,
        validatedAt:          json['validated_at'] as String?,
        reportStatus:         InterventionReportStatus.fromString(json['report_status'] as String?),
        diagnosis:            json['diagnosis'] as String?,
        actions:              json['actions'] as String?,
        partsReplaced:        json['parts_replaced'] as String?,
        equipmentId:          json['equipment_id'] as String?,
        equipmentName:        json['equipment_name'] as String?,
        issueStatus:          json['issue_status'] as String?,
      );

  /// Payload pour PUT /api/issues/:id/report (champs éditables uniquement).
  Map<String, dynamic> toUpdateJson() => {
        'summary':                 summary,
        'root_cause':              rootCause,
        'recommendations':         recommendations,
        'duration_hours':          durationHours,
        'returned_to_service_at':  returnedToServiceAt,
        'estimated_cost':          estimatedCost,
        'final_equipment_status':  finalEquipmentStatus,
      };

  /// Map complète pour la génération du PDF : champs éditables + champs live de
  /// l'incident + métadonnées de validation.
  Map<String, dynamic> toReportPdfJson() => {
        ...toUpdateJson(),
        'issue_status':      issueStatus,
        'report_status':     reportStatus.apiValue,
        'equipment_id':      equipmentId,
        'equipment_name':    equipmentName,
        'diagnosis':         diagnosis,
        'actions':           actions,
        'parts_replaced':    partsReplaced,
        'author_name':       authorName,
        'validated_by_name': validatedByName,
        'validated_at':      validatedAt,
      };

  IssueInterventionReport copyWith({
    String? summary,
    String? rootCause,
    String? recommendations,
    double? durationHours,
    String? returnedToServiceAt,
    double? estimatedCost,
    String? finalEquipmentStatus,
    InterventionReportStatus? reportStatus,
  }) =>
      IssueInterventionReport(
        issueId:              issueId,
        summary:              summary ?? this.summary,
        rootCause:            rootCause ?? this.rootCause,
        recommendations:      recommendations ?? this.recommendations,
        durationHours:        durationHours ?? this.durationHours,
        returnedToServiceAt:  returnedToServiceAt ?? this.returnedToServiceAt,
        estimatedCost:        estimatedCost ?? this.estimatedCost,
        finalEquipmentStatus: finalEquipmentStatus ?? this.finalEquipmentStatus,
        authorId:             authorId,
        authorName:           authorName,
        validatedById:        validatedById,
        validatedByName:      validatedByName,
        validatedAt:          validatedAt,
        reportStatus:         reportStatus ?? this.reportStatus,
        diagnosis:            diagnosis,
        actions:              actions,
        partsReplaced:        partsReplaced,
        equipmentId:          equipmentId,
        equipmentName:        equipmentName,
        issueStatus:          issueStatus,
      );
}
