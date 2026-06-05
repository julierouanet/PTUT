class IssuePhoto {
  final int id;
  final String originalName;
  final String mimeType;
  final int fileSizeKb;
  final String uploadedAt;

  const IssuePhoto({
    required this.id,
    required this.originalName,
    required this.mimeType,
    required this.fileSizeKb,
    required this.uploadedAt,
  });

  factory IssuePhoto.fromJson(Map<String, dynamic> j) => IssuePhoto(
    id:           j['id'] as int,
    originalName: j['original_name'] as String,
    mimeType:     j['mime_type'] as String,
    fileSizeKb:   j['file_size_kb'] as int,
    uploadedAt:   j['uploaded_at'] as String,
  );

  String get displaySize => fileSizeKb < 1024
      ? '$fileSizeKb Ko'
      : '${(fileSizeKb / 1024).toStringAsFixed(1)} Mo';
}
