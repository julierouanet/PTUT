import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuration des URLs des microservices.
///
/// Résolution automatique selon le contexte d'accès — aucun recompilation
/// nécessaire pour switcher entre local et en ligne :
///
///   ┌─────────────────────────┬───────────────────────────────────────────┐
///   │ Accès depuis…           │ Backend utilisé                           │
///   ├─────────────────────────┼───────────────────────────────────────────┤
///   │ localhost / 127.0.0.1   │ http://localhost:3001 / :3002 (local dev) │
///   │ IP publique (nginx)     │ https://IP/auth  /  https://IP/db         │
///   │ Domaine (Jenkins prod)  │ --dart-define AUTH_URL / DB_URL           │
///   └─────────────────────────┴───────────────────────────────────────────┘
///
/// Priorité : --dart-define explicite > détection automatique via Uri.base
///
/// Surcharge manuelle possible :
///   flutter run --dart-define=AUTH_URL=http://localhost:3001
///               --dart-define=DB_URL=http://localhost:3002
///               --dart-define=KC_TOKEN_URL=http://localhost:8080/realms/...
class ApiConfig {
  ApiConfig._();

  // ── Valeurs compilées via --dart-define (Jenkins / build_and_push.sh) ────────
  // Vides si non fournis → détection automatique au runtime via Uri.base.
  static const String _definedAuthUrl = String.fromEnvironment('AUTH_URL');
  static const String _definedDbUrl   = String.fromEnvironment('DB_URL');
  static const String _definedKcUrl   = String.fromEnvironment('KC_TOKEN_URL');

  // Identifiant du client public Flutter dans Keycloak
  static const String kcClientId = String.fromEnvironment(
    'KC_CLIENT_ID',
    defaultValue: 'flutter-app',
  );

  // Version injectée par Jenkins via --dart-define=APP_VERSION=x.y.z
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0-dev',
  );

  // ── URLs résolues au runtime ──────────────────────────────────────────────────

  /// URL de base du auth-service.
  /// dart-define prioritaire ; sinon détection automatique depuis l'URL du navigateur.
  static String get authBaseUrl =>
      _definedAuthUrl.isNotEmpty ? _definedAuthUrl : _resolveAuthUrl();

  /// URL de base du db-service.
  static String get dbBaseUrl =>
      _definedDbUrl.isNotEmpty ? _definedDbUrl : _resolveDbUrl();

  /// Token endpoint Keycloak (Direct Grant + refresh).
  static String get kcTokenUrl =>
      _definedKcUrl.isNotEmpty ? _definedKcUrl : _resolveKcTokenUrl();

  // ── Résolution automatique ────────────────────────────────────────────────────

  /// Vrai en dev local (ou hors web). Public : aussi utilisé par le
  /// LoginScreen pour masquer le lien /setup/ qui n'existe qu'en déploiement.
  static bool get isLocalhost {
    if (!kIsWeb) return true; // mobile/desktop → toujours localhost
    final host = Uri.base.host;
    return host == 'localhost' || host == '127.0.0.1';
  }

  static String get _webSchemeHost {
    final uri = Uri.base;
    // Inclure le port seulement s'il est non-standard
    final port = uri.port;
    final isDefaultPort = (uri.scheme == 'https' && port == 443) ||
        (uri.scheme == 'http' && port == 80);
    return isDefaultPort
        ? '${uri.scheme}://${uri.host}'
        : '${uri.scheme}://${uri.host}:$port';
  }

  static String _resolveAuthUrl() {
    if (isLocalhost) return 'http://localhost:3001';
    // IP ou domaine → Nginx route /auth/ vers auth-service:3001
    return '$_webSchemeHost/auth';
  }

  static String _resolveDbUrl() {
    if (isLocalhost) return 'http://localhost:3002';
    // IP ou domaine → Nginx route /db/ vers db-service:3002
    return '$_webSchemeHost/db';
  }

  static String _resolveKcTokenUrl() {
    if (isLocalhost) {
      return 'http://localhost:8080/realms/kabutare-hospital/protocol/openid-connect/token';
    }
    // IP ou domaine → Nginx route /keycloak/ vers keycloak:8080
    return '$_webSchemeHost/keycloak/realms/kabutare-hospital/protocol/openid-connect/token';
  }

  // ── Vérification sécurité (appelée au démarrage) ──────────────────────────────

  /// Vérifie que les URLs de production utilisent HTTPS.
  static void assertSecureUrls() {
    assert(
      authBaseUrl.startsWith('https://') || authBaseUrl.startsWith('http://localhost'),
      'AUTH_URL doit utiliser HTTPS en production (valeur actuelle: $authBaseUrl)',
    );
    assert(
      dbBaseUrl.startsWith('https://') || dbBaseUrl.startsWith('http://localhost'),
      'DB_URL doit utiliser HTTPS en production (valeur actuelle: $dbBaseUrl)',
    );
  }

  // ── Auth endpoints ────────────────────────────────────────────────────────────
  static String get meUrl                  => '$authBaseUrl/api/auth/me';
  static String get usersUrl               => '$authBaseUrl/api/users';
  static String get deptRequestsUrl        => '$authBaseUrl/api/users/department-requests';
  static String get rolesUrl               => '$authBaseUrl/api/roles';
  static String get registerUrl            => '$authBaseUrl/api/auth/register';
  static String get forgotPasswordUrl      => '$authBaseUrl/api/auth/forgot-password';
  static String get accessRequestUrl       => '$authBaseUrl/api/auth/access-request';
  static String get roleRequestsUrl        => '$authBaseUrl/api/users/role-requests';
  static String get notificationPrefsUrl   => '$authBaseUrl/api/users/me/notifications';
  static String get debugModeVerifyUrl     => '$authBaseUrl/api/auth/debug-mode/verify';

  // ── DB endpoints ──────────────────────────────────────────────────────────────
  static String get locationsUrl  => '$dbBaseUrl/api/locations';
  static String get equipmentUrl  => '$dbBaseUrl/api/equipment';
  static String get issuesUrl     => '$dbBaseUrl/api/issues';
  static String get inventoryUrl  => '$dbBaseUrl/api/inventory';
  static String get logsUrl       => '$dbBaseUrl/api/logs';
  static String get sidebarUrl    => '$dbBaseUrl/api/sidebar/config';
  static String get sidebarAllUrl => '$dbBaseUrl/api/sidebar/config/all';
  static String get analyticsUrl  => '$dbBaseUrl/api/analytics';
  static String get featuresUrl   => '$authBaseUrl/api/feature-flags';
  static String get backupsUrl    => '$dbBaseUrl/api/admin/backups';
  static String get interventionDocumentsUrl => '$dbBaseUrl/api/documents/interventions';

  // ── Départements (db-service) ─────────────────────────────────────────────────
  static String get departmentsUrl => '$dbBaseUrl/api/departments';
  static String departmentStatsUrl(int id) => '$dbBaseUrl/api/departments/$id/stats';
  static String departmentDetailUrl(int id) => '$dbBaseUrl/api/departments/$id/detail';
  static String departmentCheckDepsUrl(int id) => '$dbBaseUrl/api/departments/$id/check-dependencies';

  // ── Catégories (db-service) ───────────────────────────────────────────────────
  static String get categoriesMacroUrl => '$dbBaseUrl/api/categories/macro';
  static String get categoriesSubUrl => '$dbBaseUrl/api/categories/sub';
  static String categoriesSubByMacroUrl(int macroId) => '$dbBaseUrl/api/categories/sub?macro_category_id=$macroId';
  static String categoriesSubItemUrl(int id) => '$dbBaseUrl/api/categories/sub/$id';
  static String categoriesSubLifespanUrl(int id) => '$dbBaseUrl/api/categories/sub/$id/lifespan';
  static String categoryDetailUrl(String name) =>
      '$dbBaseUrl/api/categories/detail?name=${Uri.encodeComponent(name)}';

  // ── Catalogue Fabricant → Modèle (db-service) ─────────────────────────────────
  static String get brandsUrl => '$dbBaseUrl/api/brands';
  static String brandsBySubUrl(int subcategoryId) => '$dbBaseUrl/api/brands?subcategory_id=$subcategoryId';
  static String brandItemUrl(int id) => '$dbBaseUrl/api/brands/$id';
  static String brandItemBySubUrl(int id, int subcategoryId) =>
      '$dbBaseUrl/api/brands/$id?subcategory_id=$subcategoryId';

  static String get modelsUrl => '$dbBaseUrl/api/models';
  static String modelsFilteredUrl({int? subcategoryId, int? brandId}) {
    final params = <String>[];
    if (subcategoryId != null) params.add('subcategory_id=$subcategoryId');
    if (brandId != null) params.add('brand_id=$brandId');
    return params.isEmpty ? '$dbBaseUrl/api/models' : '$dbBaseUrl/api/models?${params.join('&')}';
  }
  static String modelItemUrl(int id) => '$dbBaseUrl/api/models/$id';
  static String modelDocumentsUrl(int id) => '$dbBaseUrl/api/models/$id/documents';
  static String modelDocumentItemUrl(int id, int docId) => '$dbBaseUrl/api/models/$id/documents/$docId';
  static String modelDocumentDownloadUrl(int id, int docId) =>
      '$dbBaseUrl/api/models/$id/documents/$docId/download';
  static String modelProtocolUrl(int id, int protocolId) => '$dbBaseUrl/api/models/$id/protocols/$protocolId';

  // ── Plan de remplacement biomédical (RA3 S5) ──────────────────────────────────
  static String get replacementPlanUrl => '$dbBaseUrl/api/equipment/replacement-plan';

  static String equipmentByTagUrl(String tag) =>
      '$dbBaseUrl/api/equipment/by-tag/${Uri.encodeComponent(tag)}';

  static String equipmentPmPlanUrl(String id) =>
      '$dbBaseUrl/api/equipment/${Uri.encodeComponent(id)}/pm-plan';

  static String equipmentValidatePmUrl(String id) =>
      '$dbBaseUrl/api/equipment/${Uri.encodeComponent(id)}/maintenance/validate';

  // ── Protocoles PM par sous-catégorie ──────────────────────────────────────────
  static String pmProtocolsUrl({int? subcategoryId}) => subcategoryId != null
      ? '$dbBaseUrl/api/pm-protocols?subcategory_id=$subcategoryId'
      : '$dbBaseUrl/api/pm-protocols';
  static String pmProtocolItemUrl(int id) => '$dbBaseUrl/api/pm-protocols/$id';

  // ── Détail d'un rôle (auth-service) ──────────────────────────────────────────
  static String roleHierarchyUrl(String n)   => '$rolesUrl/${Uri.encodeComponent(n)}/hierarchy';
  static String rolePermissionsUrl(String n) => '$rolesUrl/${Uri.encodeComponent(n)}/permissions';
  static String roleUsersUrl(String n)       => '$rolesUrl/${Uri.encodeComponent(n)}/users';

  // ── Paramètres application (auth-service) ────────────────────────────────────
  static String get appSettingsUrl          => '$authBaseUrl/api/app-settings';
  static String get appSettingsPublicUrl    => '$authBaseUrl/api/app-settings/public';
  static String get appSettingsTestEmailUrl => '$authBaseUrl/api/app-settings/test-email';

  // ── Health endpoints (publics, sans authentification) ────────────────────────
  static String get healthAuthUrl => '$authBaseUrl/health';
  static String get healthDbUrl   => '$dbBaseUrl/health';

  // ── Web Push endpoints ────────────────────────────────────────────────────────
  static String get vapidKeyUrl        => '$dbBaseUrl/api/notifications/vapid-key';
  static String get pushSubscribeUrl   => '$dbBaseUrl/api/notifications/subscribe';
  static String get pushUnsubscribeUrl => '$dbBaseUrl/api/notifications/unsubscribe';
}
