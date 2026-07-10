// ── Modèle : souscription push (vue admin diagnostic) ────────────────────────

class PushSubscriptionAdmin {
  final int id;
  final String userId;
  final String? userName;
  final String? userRoles;
  final String? platform;
  final String createdAt;
  final String? lastSentAt;
  final String? lastSuccessAt;
  final String? lastDeliveredAt;
  final String? lastError;

  const PushSubscriptionAdmin({
    required this.id,
    required this.userId,
    this.userName,
    this.userRoles,
    this.platform,
    required this.createdAt,
    this.lastSentAt,
    this.lastSuccessAt,
    this.lastDeliveredAt,
    this.lastError,
  });

  factory PushSubscriptionAdmin.fromApiJson(Map<String, dynamic> json) => PushSubscriptionAdmin(
        id: json['id'] as int,
        userId: json['user_id'] as String,
        userName: json['user_name'] as String?,
        userRoles: json['user_roles'] as String?,
        platform: json['platform'] as String?,
        createdAt: json['created_at'] as String,
        lastSentAt: json['last_sent_at'] as String?,
        lastSuccessAt: json['last_success_at'] as String?,
        lastDeliveredAt: json['last_delivered_at'] as String?,
        lastError: json['last_error'] as String?,
      );

  /// Le service de push (Apple/Google/Mozilla) a accepté l'envoi.
  /// Ne prouve PAS la réception sur l'appareil — voir [deviceConfirmed].
  bool get serverAccepted => lastSuccessAt != null && lastError == null;

  /// Le service worker de l'appareil a effectivement traité le push
  /// (accusé de réception via POST /delivery-ack) — signal fort de réception réelle.
  bool get deviceConfirmed => lastDeliveredAt != null;

  bool get neverSent => lastSentAt == null;
}
