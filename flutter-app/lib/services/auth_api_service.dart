import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'api_config.dart';

/// Résultat d'une tentative de connexion.
class LoginResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? user;

  const LoginResult({required this.success, this.error, this.user});
}

/// Service d'authentification — communique avec auth-service.
class AuthApiService {
  AuthApiService._();
  static final AuthApiService instance = AuthApiService._();

  /// Connexion via Keycloak — Direct Grant (formulaire natif, pas de redirection).
  Future<LoginResult> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.kcTokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'password',
          'client_id':  ApiConfig.kcClientId,
          'username':   email,
          'password':   password,
          'scope':      'openid profile email',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await ApiClient.saveTokens(
          data['access_token']  as String,
          data['refresh_token'] as String,
        );
        // Profil complet depuis auth-service (rôles + permissions SQLite)
        final userData = await getMe();
        if (userData != null) {
          return LoginResult(success: true, user: userData);
        }
        return const LoginResult(
          success: false,
          error: 'Impossible de récupérer le profil utilisateur',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final code        = body['error']             as String?;
      final description = body['error_description'] as String?;
      // Compte non activé : email non vérifié ou mot de passe temporaire
      if (code == 'invalid_grant' &&
          description != null &&
          description.contains('not fully set up')) {
        return const LoginResult(
          success: false,
          error: 'Votre compte n\'est pas encore activé. '
              'Vérifiez votre email ou contactez votre administrateur.',
        );
      }
      return LoginResult(
        success: false,
        error: description ?? code ?? 'Erreur inconnue',
      );
    } catch (e) {
      return LoginResult(success: false, error: 'Impossible de joindre le serveur: $e');
    }
  }

  /// Déconnexion — supprime les tokens localement.
  /// Keycloak access tokens expirent rapidement (15 min) ; pas d'appel serveur nécessaire.
  Future<void> logout() async {
    await ApiClient.clearTokens();
  }

  /// Vérifie si un token d'accès est présent en stockage local.
  Future<bool> isAuthenticated() async {
    return ApiClient.hasStoredTokens();
  }

  /// Récupère le profil de l'utilisateur connecté.
  Future<Map<String, dynamic>?> getMe() async {
    try {
      final response = await ApiClient.get(ApiConfig.meUrl);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ── Gestion des utilisateurs (admin) ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await ApiClient.get(ApiConfig.usersUrl);
    if (response.statusCode >= 400) {
      throw Exception('Erreur ${response.statusCode}: ${response.body}');
    }
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final response = await ApiClient.post(ApiConfig.usersUrl, data);
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur création utilisateur');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateUser(String id, Map<String, dynamic> data) async {
    final url = '${ApiConfig.usersUrl}/$id';
    final response = await ApiClient.put(url, data);
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur mise à jour utilisateur');
    }
  }

  Future<bool> toggleUserStatus(String id) async {
    final url = '${ApiConfig.usersUrl}/$id/toggle';
    final response = await ApiClient.patch(url, {});
    if (response.statusCode >= 400) {
      throw Exception('Erreur toggle statut utilisateur');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['is_active'] as int) == 1;
  }

  /// Demande à Keycloak de renvoyer l'email de vérification pour l'utilisateur [id].
  Future<void> sendVerificationEmail(String id) async {
    final url = '${ApiConfig.usersUrl}/$id/send-verify-email';
    final response = await ApiClient.post(url, {});
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur envoi email de vérification');
    }
  }

  Future<void> deleteUser(String id, {String? reason}) async {
    var url = '${ApiConfig.usersUrl}/$id';
    if (reason != null && reason.isNotEmpty) url += '?reason=${Uri.encodeComponent(reason)}';
    final response = await ApiClient.delete(url);
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur suppression utilisateur');
    }
  }

  // ── Demandes de changement de département ─────────────────────────────────

  /// Change directement le département (si permission changeDepartment accordée).
  Future<void> changeDepartmentDirect(String department) async {
    final response = await ApiClient.put(
      '${ApiConfig.usersUrl}/me/department',
      {'department': department},
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur lors du changement');
    }
  }

  /// Envoie une demande de changement de département (utilisateur connecté).
  Future<void> requestDepartmentChange(String requestedDepartment) async {
    final response = await ApiClient.post(
      '${ApiConfig.usersUrl}/department-request',
      {'requested_department': requestedDepartment},
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur lors de la demande');
    }
  }

  /// Récupère toutes les demandes (admin seulement). [status] = pending | approved | rejected
  Future<List<Map<String, dynamic>>> getDepartmentRequests({String? status}) async {
    var url = ApiConfig.deptRequestsUrl;
    if (status != null) url += '?status=${Uri.encodeComponent(status)}';
    final response = await ApiClient.get(url);
    if (response.statusCode >= 400) {
      throw Exception('Erreur ${response.statusCode}');
    }
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  /// Approuve ou rejette une demande (admin seulement).
  Future<void> resolveDepartmentRequest(
    String requestId, {
    required String status,
    String? adminNote,
  }) async {
    final url = '${ApiConfig.deptRequestsUrl}/$requestId';
    final response = await ApiClient.put(url, {
      'status': status,
      if (adminNote != null && adminNote.isNotEmpty) 'admin_note': adminNote,
    });
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur résolution demande');
    }
  }

  // ── Gestion des rôles ─────────────────────────────────────────────────────

  /// Récupère tous les rôles avec leurs permissions.
  Future<List<Map<String, dynamic>>> getRoles() async {
    final response = await ApiClient.get(ApiConfig.rolesUrl);
    if (response.statusCode >= 400) {
      throw Exception('Erreur ${response.statusCode}: ${response.body}');
    }
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  /// Crée un rôle personnalisé (admin seulement).
  Future<Map<String, dynamic>> createRole(Map<String, dynamic> data) async {
    final response = await ApiClient.post(ApiConfig.rolesUrl, data);
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur création rôle');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Met à jour les permissions d'un rôle (admin seulement).
  Future<void> updateRolePermissions(String roleName, List<String> permissions) async {
    final url = '${ApiConfig.rolesUrl}/$roleName/permissions';
    final response = await ApiClient.put(url, {'permissions': permissions});
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur mise à jour permissions');
    }
  }

  /// Supprime un rôle personnalisé (admin seulement).
  Future<void> deleteRole(String roleName) async {
    final url = '${ApiConfig.rolesUrl}/$roleName';
    final response = await ApiClient.delete(url);
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur suppression rôle');
    }
  }

  // ── Inscription ───────────────────────────────────────────────────────────────

  /// Crée un nouveau compte via l'Admin API Keycloak (endpoint public).
  /// Assigne automatiquement le rôle hospitalStaff et envoie un email de vérification.
  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String department,
    String? phone,
  }) async {
    final response = await ApiClient.postPublic(ApiConfig.registerUrl, {
      'first_name': firstName,
      'last_name':  lastName,
      'email':      email,
      'password':   password,
      'department': department,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur lors de la création du compte');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Mot de passe oublié ────────────────────────────────────────────────────────

  /// Déclenche l'envoi d'un email de réinitialisation via Keycloak.
  /// Répond toujours sans erreur (anti-énumération côté serveur).
  Future<void> forgotPassword(String email) async {
    final response = await ApiClient.postPublic(
      ApiConfig.forgotPasswordUrl,
      {'email': email},
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur');
    }
  }

  // ── Demandes de rôle ──────────────────────────────────────────────────────────

  /// Soumet une demande de rôle supplémentaire (utilisateur connecté).
  Future<void> requestRole(String requestedRole) async {
    final response = await ApiClient.post(
      '${ApiConfig.usersUrl}/role-request',
      {'requested_role': requestedRole},
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur lors de la demande de rôle');
    }
  }

  /// Récupère les demandes de rôle (admin seulement). [status] = pending | approved | rejected
  Future<List<Map<String, dynamic>>> getRoleRequests({String? status}) async {
    var url = ApiConfig.roleRequestsUrl;
    if (status != null) url += '?status=${Uri.encodeComponent(status)}';
    final response = await ApiClient.get(url);
    if (response.statusCode >= 400) {
      throw Exception('Erreur ${response.statusCode}');
    }
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  /// Approuve ou rejette une demande de rôle (admin seulement).
  Future<void> resolveRoleRequest(
    String requestId, {
    required String status,
    String? adminNote,
  }) async {
    final url = '${ApiConfig.roleRequestsUrl}/$requestId';
    final response = await ApiClient.put(url, {
      'status': status,
      if (adminNote != null && adminNote.isNotEmpty) 'admin_note': adminNote,
    });
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Erreur résolution demande');
    }
  }
}
