// ── Implémentation Web Push (web uniquement — dart:js_interop) ───────────────
// Ce fichier n'est chargé que sur la plateforme web grâce à l'export conditionnel
// dans push_notification_web_service.dart.

import 'dart:js_interop';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'api_config.dart';

// ── Déclarations externes JS (top-level, requis par dart:js_interop) ─────────

@JS('requestPushPermission')
external JSPromise<JSString> _jsRequestPermission();

@JS('getPushPermission')
external JSString _jsGetPermission();

/// Retourne le JSON de la souscription push, ou null si refusé/indisponible.
@JS('subscribeToPush')
external JSPromise<JSString?> _jsSubscribe(JSString vapidKey);

@JS('unsubscribeFromPush')
external JSPromise<JSAny?> _jsUnsubscribe();

@JS('getPushEnvironment')
external JSString _jsGetPushEnvironment();

// ── Modèles ──────────────────────────────────────────────────────────────────

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

/// Résultat structuré d'un auto-test push — laisse l'appelant construire le
/// message localisé via AppLocalizations plutôt que de figer du texte ici.
class PushTestResult {
  final int attempted;
  final int sent;
  final int expired;
  final bool networkError;

  const PushTestResult({
    this.attempted = 0,
    this.sent = 0,
    this.expired = 0,
    this.networkError = false,
  });
}

// ── Service ──────────────────────────────────────────────────────────────────

class PushNotificationWebService {
  static final PushNotificationWebService _instance =
      PushNotificationWebService._internal();
  factory PushNotificationWebService() => _instance;
  PushNotificationWebService._internal();

  // ── API publique ────────────────────────────────────────────────────────────

  /// Demande la permission au navigateur puis envoie la souscription au backend.
  /// Retourne true seulement si le POST /subscribe backend a réussi.
  Future<bool> requestAndSubscribe() async {
    if (!kIsWeb) return false;
    try {
      final permJs = await _jsRequestPermission().toDart;
      if (permJs.toDart != 'granted') return false;

      final vapidKey = await _fetchVapidKey();
      if (vapidKey == null) return false;

      final subJs = await _jsSubscribe(vapidKey.toJS).toDart;
      if (subJs == null) return false;
      final subJson = subJs.toDart;

      final sub = jsonDecode(subJson) as Map<String, dynamic>;
      final endpoint = sub['endpoint'] as String?;
      final keys = sub['keys'] as Map<String, dynamic>?;

      if (endpoint == null || keys == null) return false;

      final env = await getEnvironment();
      final platformLabel = '${env.isIos ? "iOS" : "Desktop/Android"} · ${env.isStandalone ? "PWA installée" : "Navigateur"}';

      final resp = await ApiClient.post(ApiConfig.pushSubscribeUrl, {
        'endpoint': endpoint,
        'keys': {
          'p256dh': keys['p256dh'],
          'auth': keys['auth'],
        },
        'platform': platformLabel,
      });
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      // Erreur réseau/JS — les push notifications restent optionnelles,
      // mais l'appelant sait maintenant que ça a échoué (retour false).
      return false;
    }
  }

  /// Envoie une notification de test à l'utilisateur connecté (auto-diagnostic).
  /// Retourne un résultat structuré — distingue succès / absence de souscription / expiration
  /// via le corps JSON (attempted/sent/expired), jamais via le status code seul
  /// (POST /test-push répond toujours 200, voir contrat backend). L'appelant construit
  /// le message affiché via AppLocalizations (aucun texte figé ici).
  Future<PushTestResult> sendTestPush() async {
    try {
      final resp = await ApiClient.post(ApiConfig.pushTestUrl, {});
      if (resp.statusCode != 200) return const PushTestResult(networkError: true);
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return PushTestResult(
        attempted: body['attempted'] as int? ?? 0,
        sent: body['sent'] as int? ?? 0,
        expired: body['expired'] as int? ?? 0,
      );
    } catch (_) {
      return const PushTestResult(networkError: true);
    }
  }

  /// Retourne true si les notifications push sont accordées par le navigateur.
  Future<bool> isPushActive() async {
    if (!kIsWeb) return true;
    try {
      return _jsGetPermission().toDart == 'granted';
    } catch (_) {
      return true;
    }
  }

  /// Supprime la souscription côté backend et côté navigateur.
  Future<void> unsubscribe() async {
    if (!kIsWeb) return;
    try {
      await ApiClient.post(ApiConfig.pushUnsubscribeUrl, {});
      await _jsUnsubscribe().toDart;
    } catch (_) {}
  }

  /// Détecte l'environnement Push du navigateur (iOS, standalone, support, permission).
  /// En cas d'erreur, retourne des valeurs par défaut reproduisant le comportement
  /// actuel (branche "Activer" classique) — ne bloque jamais le Hub.
  Future<PushEnvironment> getEnvironment() async {
    if (!kIsWeb) {
      return const PushEnvironment(
        isIos: false, isStandalone: true, pushSupported: true, permissionState: 'default',
      );
    }
    try {
      final json = jsonDecode(_jsGetPushEnvironment().toDart) as Map<String, dynamic>;
      return PushEnvironment(
        isIos: json['isIos'] as bool,
        isStandalone: json['isStandalone'] as bool,
        pushSupported: json['pushSupported'] as bool,
        permissionState: json['permissionState'] as String,
      );
    } catch (_) {
      return const PushEnvironment(
        isIos: false, isStandalone: true, pushSupported: true, permissionState: 'default',
      );
    }
  }

  // ── Helpers privés ──────────────────────────────────────────────────────────

  Future<String?> _fetchVapidKey() async {
    try {
      final resp = await ApiClient.get(ApiConfig.vapidKeyUrl);
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['publicKey'] as String?;
    } catch (_) {
      return null;
    }
  }
}
