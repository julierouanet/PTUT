import 'package:flutter/foundation.dart' show debugPrint;

/// Façade pour les notifications OS (Web + Android).
///
/// Sur Web : les notifications navigateur sont gérées par [PushNotificationWebService].
/// Sur Android natif : intégrer flutter_local_notifications si nécessaire.
/// Ce service est un point d'extension — il ne bloque jamais l'UX en cas d'erreur.
class OsNotificationService {
  static bool _initialized = false;

  /// Initialiser le service — appeler une fois dans main() avant runApp.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    // Aucune initialisation requise pour l'implémentation actuelle (stub).
    // Pour Android natif, initialiser flutter_local_notifications ici.
  }

  /// Affiche une notification OS si les permissions sont accordées.
  /// Ne lève jamais d'exception — erreur silencieuse + debugPrint.
  static Future<void> showIfPermitted({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    try {
      // Sur Web : le push navigateur (service worker) gère les notifications OS.
      // Sur Android natif : implémenter via flutter_local_notifications.
      debugPrint('[OsNotificationService] Notification prête : $title — $body');
    } catch (e) {
      debugPrint('[OsNotificationService] Erreur notification OS: $e');
    }
  }
}
