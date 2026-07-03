class EquipmentDocument {
  final int id;
  final String documentType;
  final String originalName;
  final String mimeType;
  final int fileSizeKb;
  final String? uploaderName;
  final String uploadedAt;
  final String? issueId;
  final String? issueStatus;
  final String? issueCreatedAt;
  final String? equipmentId;
  final String? equipmentName;
  final String? uploadedBy;
  final int? annexNumber;
  final int? annexTypeIndex;
  final String kind;

  const EquipmentDocument({
    required this.id,
    required this.documentType,
    required this.originalName,
    required this.mimeType,
    required this.fileSizeKb,
    required this.uploaderName,
    required this.uploadedAt,
    this.issueId,
    this.issueStatus,
    this.issueCreatedAt,
    this.equipmentId,
    this.equipmentName,
    this.uploadedBy,
    this.annexNumber,
    this.annexTypeIndex,
    this.kind = 'document',
  });

  factory EquipmentDocument.fromJson(Map<String, dynamic> j) => EquipmentDocument(
    id:             j['id'] as int,
    documentType:   j['document_type'] as String,
    originalName:   j['original_name'] as String,
    mimeType:       j['mime_type'] as String,
    fileSizeKb:     j['file_size_kb'] as int,
    uploaderName:   j['uploader_name'] as String?,
    uploadedAt:     j['uploaded_at'] as String,
    issueId:        j['issue_id'] as String?,
    issueStatus:    j['issue_status'] as String?,
    issueCreatedAt: j['issue_created_at'] as String?,
    equipmentId:    j['equipment_id'] as String?,
    equipmentName:  j['equipment_name'] as String?,
    uploadedBy:     j['uploaded_by'] as String?,
    annexNumber:    j['annex_number'] as int?,
    annexTypeIndex: j['annex_type_index'] as int?,
    kind:           j['kind'] as String? ?? 'document',
  );

  String get displaySize => fileSizeKb < 1024
      ? '$fileSizeKb Ko'
      : '${(fileSizeKb / 1024).toStringAsFixed(1)} Mo';

  /// Nom du technicien pour affichage — repli pour les documents hérités
  /// uploadés avant le suivi de l'uploadeur (`uploaderName` null).
  String get uploaderDisplay => uploaderName ?? '—';

  bool get isPdf   => mimeType == 'application/pdf';
  bool get isImage => mimeType.startsWith('image/');
  bool get isPhoto => kind == 'photo';
}
