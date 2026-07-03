class IssuePhoto {
  final int id;
  final String originalName;
  final String mimeType;
  final int fileSizeKb;
  final String uploadedAt;
  final String? uploaderName;

  const IssuePhoto({
    required this.id,
    required this.originalName,
    required this.mimeType,
    required this.fileSizeKb,
    required this.uploadedAt,
    this.uploaderName,
  });

  factory IssuePhoto.fromJson(Map<String, dynamic> j) => IssuePhoto(
    id:           j['id'] as int,
    originalName: j['original_name'] as String,
    mimeType:     j['mime_type'] as String,
    fileSizeKb:   j['file_size_kb'] as int,
    uploadedAt:   j['uploaded_at'] as String,
    uploaderName: j['uploader_name'] as String?,
  );

  /// Nom du technicien pour affichage — photos historiques (uploadées avant
  /// le suivi de l'uploadeur) ont `uploaderName` null.
  String get uploaderDisplay => uploaderName ?? '—';

  String get displaySize => fileSizeKb < 1024
      ? '$fileSizeKb Ko'
      : '${(fileSizeKb / 1024).toStringAsFixed(1)} Mo';
}
