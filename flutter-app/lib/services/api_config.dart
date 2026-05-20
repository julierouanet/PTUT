/// Configuration des URLs des microservices.
///
/// Les URLs sont injectées à la compilation via --dart-define :
///   flutter build web --dart-define=AUTH_URL=https://auth.lucaslopvet.fr
///                     --dart-define=DB_URL=https://DB.lucaslopvet.fr
///
/// En local (flutter run), pointe vers les services de production par défaut.
/// Vous pouvez surcharger localement :
///   flutter run --dart-define=AUTH_URL=http://localhost:3001
///               --dart-define=DB_URL=http://localhost:3002
class ApiConfig {
  ApiConfig._();

  static const String authBaseUrl = String.fromEnvironment(
    'AUTH_URL',
    defaultValue: 'https://auth.lucaslopvet.fr',
  );

  static const String dbBaseUrl = String.fromEnvironment(
    'DB_URL',
    defaultValue: 'https://DB.lucaslopvet.fr',
  );

  // Keycloak — token endpoint (Direct Grant + refresh)
  static const String kcTokenUrl = String.fromEnvironment(
    'KC_TOKEN_URL',
    defaultValue: 'https://keycloak.lucaslopvet.fr/realms/kabutare-hospital/protocol/openid-connect/token',
  );

  // Identifiant du client public Flutter dans Keycloak
  static const String kcClientId = String.fromEnvironment(
    'KC_CLIENT_ID',
    defaultValue: 'flutter-app',
  );

  /// Vérifie que les URLs de production utilisent HTTPS.
  /// Appelé au démarrage de l'application.
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

  // Auth endpoints
  static String get meUrl         => '$authBaseUrl/api/auth/me';

  // Auth user management endpoint
  static String get usersUrl      => '$authBaseUrl/api/users';

  // DB endpoints
  static String get locationsUrl  => '$dbBaseUrl/api/locations';
  static String get equipmentUrl  => '$dbBaseUrl/api/equipment';
  static String get issuesUrl     => '$dbBaseUrl/api/issues';
  static String get inventoryUrl  => '$dbBaseUrl/api/inventory';
  static String get logsUrl       => '$dbBaseUrl/api/logs';
  static String get sidebarUrl    => '$dbBaseUrl/api/sidebar/config';

  static String equipmentByTagUrl(String tag) =>
      '$dbBaseUrl/api/equipment/by-tag/${Uri.encodeComponent(tag)}';

  // Auth extra endpoints
  static String get deptRequestsUrl   => '$authBaseUrl/api/users/department-requests';
  static String get rolesUrl          => '$authBaseUrl/api/roles';
  static String get registerUrl       => '$authBaseUrl/api/auth/register';
  static String get forgotPasswordUrl => '$authBaseUrl/api/auth/forgot-password';
  static String get roleRequestsUrl   => '$authBaseUrl/api/users/role-requests';

  // Web Push endpoints (db-service)
  static String get vapidKeyUrl        => '$dbBaseUrl/api/notifications/vapid-key';
  static String get pushSubscribeUrl   => '$dbBaseUrl/api/notifications/subscribe';
  static String get pushUnsubscribeUrl => '$dbBaseUrl/api/notifications/unsubscribe';
}
