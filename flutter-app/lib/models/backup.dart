/// Paramètres de planification des sauvegardes automatiques.
class BackupSettings {
  final String cronSchedule;
  final bool isAutomated;
  final String? updatedAt;

  const BackupSettings({
    required this.cronSchedule,
    required this.isAutomated,
    this.updatedAt,
  });

  factory BackupSettings.fromApiJson(Map<String, dynamic> json) => BackupSettings(
    cronSchedule: json['cron_schedule'] as String? ?? '0 0 * * *',
    isAutomated:  json['is_automated']  as bool?   ?? false,
    updatedAt:    json['updated_at']    as String?,
  );

  BackupSettings copyWith({String? cronSchedule, bool? isAutomated}) => BackupSettings(
    cronSchedule: cronSchedule ?? this.cronSchedule,
    isAutomated:  isAutomated  ?? this.isAutomated,
    updatedAt:    updatedAt,
  );
}

/// Une entrée dans l'historique des sauvegardes.
class BackupRecord {
  final int id;
  final String filename;
  final String backupType;
  final String status;
  final String? fileSize;
  final String createdAt;

  const BackupRecord({
    required this.id,
    required this.filename,
    required this.backupType,
    required this.status,
    this.fileSize,
    required this.createdAt,
  });

  factory BackupRecord.fromApiJson(Map<String, dynamic> json) => BackupRecord(
    id:         json['id']          as int,
    filename:   json['filename']    as String,
    backupType: json['backup_type'] as String? ?? 'manual',
    status:     json['status']      as String? ?? 'success',
    fileSize:   json['file_size']   as String?,
    createdAt:  json['created_at']  as String,
  );

  bool get isSuccess => status == 'success';
  bool get isManual  => backupType == 'manual';
}
