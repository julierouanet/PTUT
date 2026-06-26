class EquipmentDocument {
  final int id;
  final String documentType;
  final String originalName;
  final String mimeType;
  final int fileSizeKb;
  final String uploaderName;
  final String uploadedAt;
  final String? issueId;
  final String? issueStatus;
  final String? issueCreatedAt;

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
  });

  factory EquipmentDocument.fromJson(Map<String, dynamic> j) => EquipmentDocument(
    id:             j['id'] as int,
    documentType:   j['document_type'] as String,
    originalName:   j['original_name'] as String,
    mimeType:       j['mime_type'] as String,
    fileSizeKb:     j['file_size_kb'] as int,
    uploaderName:   j['uploader_name'] as String,
    uploadedAt:     j['uploaded_at'] as String,
    issueId:        j['issue_id'] as String?,
    issueStatus:    j['issue_status'] as String?,
    issueCreatedAt: j['issue_created_at'] as String?,
  );

  String get displaySize => fileSizeKb < 1024
      ? '$fileSizeKb Ko'
      : '${(fileSizeKb / 1024).toStringAsFixed(1)} Mo';

  bool get isPdf   => mimeType == 'application/pdf';
  bool get isImage => mimeType.startsWith('image/');
}
