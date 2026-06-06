// ── Stub Web Push (plateformes non-web : VM, tests) ──────────────────────────
// Ce fichier est utilisé par la Dart VM (flutter test, mobile, desktop).
// Il n'importe aucune bibliothèque web-only et ne fait rien.

class PushNotificationWebService {
  static final PushNotificationWebService _instance =
      PushNotificationWebService._internal();
  factory PushNotificationWebService() => _instance;
  PushNotificationWebService._internal();

  /// No-op sur les plateformes non-web.
  Future<void> requestAndSubscribe() async {}

  /// No-op sur les plateformes non-web.
  Future<void> unsubscribe() async {}

  /// Toujours actif sur les plateformes non-web (pas de bannière).
  Future<bool> isPushActive() async => true;
}
