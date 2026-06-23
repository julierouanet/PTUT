import 'nav_item.dart';

/// Types de notifications in-app
enum NotificationType {
  newIssue,
  issueInProgress,
  issueResolved,
  deptRequest,
  roleRequest;

  /// Conversion depuis le type string retourné par l'API backend
  static NotificationType fromApiString(String value) => switch (value) {
    'critical_new_issue' => NotificationType.newIssue,
    'new_issue'          => NotificationType.newIssue,
    'issue_in_progress'  => NotificationType.issueInProgress,
    'issue_resolved'     => NotificationType.issueResolved,
    'dept_request'       => NotificationType.deptRequest,
    'role_request'       => NotificationType.roleRequest,
    _                    => NotificationType.newIssue, // défaut sécurisé
  };

  /// Écran cible lors du tap sur la notification (null = pas de navigation directe)
  ScreenType? get targetScreen => switch (this) {
    NotificationType.deptRequest => ScreenType.users,
    NotificationType.roleRequest => ScreenType.users,
    _                            => null,
  };
}

/// Modèle d'une notification in-app
class AppNotification {
  final String id;
  final NotificationType type;
  /// Nom de l'équipement concerné (utilisé pour construire le texte affiché)
  final String equipmentName;
  /// Département de l'équipement (utilisé pour le type newIssue)
  final String department;
  /// Nom de l'utilisateur (utilisé pour le type deptRequest)
  final String? userName;
  final bool read;
  final DateTime createdAt;
  final String? linkedIssueId;
  // Champs API : titre et corps directs depuis la DB
  final String? title;
  final String? body;
  final String? targetId;
  final String? targetType;

  /// Accesseur isRead — alias de read pour la compatibilité API
  bool get isRead => read;

  const AppNotification({
    required this.id,
    required this.type,
    required this.equipmentName,
    required this.department,
    this.userName,
    this.read = false,
    required this.createdAt,
    this.linkedIssueId,
    this.title,
    this.body,
    this.targetId,
    this.targetType,
  });

  /// Construit une AppNotification depuis la réponse JSON de l'API backend
  factory AppNotification.fromApiJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id    = rawId?.toString() ?? '';
    final type  = NotificationType.fromApiString(json['type'] as String? ?? '');
    final t     = json['title'] as String? ?? '';
    final b     = json['body']  as String? ?? '';
    final tId   = json['target_id']   as String?;
    final tType = json['target_type'] as String?;

    DateTime createdAt;
    try {
      createdAt = DateTime.parse(json['created_at'] as String? ?? '');
    } catch (_) {
      createdAt = DateTime.now();
    }

    return AppNotification(
      id:            'api-$id',
      type:          type,
      // On utilise le titre comme equipmentName pour l'affichage local
      equipmentName: t,
      department:    '',
      read:          (json['is_read'] as int? ?? 0) == 1,
      createdAt:     createdAt,
      linkedIssueId: tType == 'issue' ? tId : null,
      title:         t,
      body:          b,
      targetId:      tId,
      targetType:    tType,
    );
  }

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? equipmentName,
    String? department,
    String? userName,
    bool? read,
    DateTime? createdAt,
    String? linkedIssueId,
    String? title,
    String? body,
    String? targetId,
    String? targetType,
  }) {
    return AppNotification(
      id:            id            ?? this.id,
      type:          type          ?? this.type,
      equipmentName: equipmentName ?? this.equipmentName,
      department:    department    ?? this.department,
      userName:      userName      ?? this.userName,
      read:          read          ?? this.read,
      createdAt:     createdAt     ?? this.createdAt,
      linkedIssueId: linkedIssueId ?? this.linkedIssueId,
      title:         title         ?? this.title,
      body:          body          ?? this.body,
      targetId:      targetId      ?? this.targetId,
      targetType:    targetType    ?? this.targetType,
    );
  }
}
