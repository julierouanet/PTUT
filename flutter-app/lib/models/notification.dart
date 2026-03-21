/// Types de notifications in-app
enum NotificationType { newIssue, issueInProgress, issueResolved }

/// Modèle d'une notification in-app
class AppNotification {
  final String id;
  final NotificationType type;
  /// Nom de l'équipement concerné (utilisé pour construire le texte affiché)
  final String equipmentName;
  /// Département de l'équipement (utilisé pour le type newIssue)
  final String department;
  final bool read;
  final DateTime createdAt;
  final String? linkedIssueId;

  const AppNotification({
    required this.id,
    required this.type,
    required this.equipmentName,
    required this.department,
    this.read = false,
    required this.createdAt,
    this.linkedIssueId,
  });

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? equipmentName,
    String? department,
    bool? read,
    DateTime? createdAt,
    String? linkedIssueId,
  }) {
    return AppNotification(
      id:            id            ?? this.id,
      type:          type          ?? this.type,
      equipmentName: equipmentName ?? this.equipmentName,
      department:    department    ?? this.department,
      read:          read          ?? this.read,
      createdAt:     createdAt     ?? this.createdAt,
      linkedIssueId: linkedIssueId ?? this.linkedIssueId,
    );
  }
}
