// ── Stub Web Push (plateformes non-web : VM, tests) ──────────────────────────
// Ce fichier est utilisé par la Dart VM (flutter test, mobile, desktop).
// Il n'importe aucune bibliothèque web-only et ne fait rien.

/// Variante de bannière à afficher selon l'environnement Push détecté.
enum PushBannerVariant { iosInstallGuide, unsupported, permissionDenied, promptActivate }

/// Environnement Push détecté côté navigateur (iOS, mode standalone, support, permission).
class PushEnvironment {
  final bool isIos;
  final bool isStandalone;
  final bool pushSupported;
  final String permissionState; // 'granted' | 'denied' | 'default' | 'unsupported'

  const PushEnvironment({
    required this.isIos,
    required this.isStandalone,
    required this.pushSupported,
    required this.permissionState,
  });

  /// Variante de bannière à afficher, par ordre de précédence strict :
  /// installation iOS requise > push non supporté > permission refusée > normal.
  PushBannerVariant get variant {
    if (isIos && !isStandalone) return PushBannerVariant.iosInstallGuide;
    if (!pushSupported) return PushBannerVariant.unsupported;
    if (permissionState == 'denied') return PushBannerVariant.permissionDenied;
    return PushBannerVariant.promptActivate;
  }
}

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

  /// Non-web : jamais concerné, valeurs par défaut équivalentes à "supporté".
  Future<PushEnvironment> getEnvironment() async => const PushEnvironment(
        isIos: false, isStandalone: true, pushSupported: true, permissionState: 'default',
      );
}
