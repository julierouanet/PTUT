import 'dart:convert';
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

  /// Connexion avec email + mot de passe.
  Future<LoginResult> login(String email, String password) async {
    try {
      final response = await ApiClient.postPublic(
        ApiConfig.loginUrl,
        {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await ApiClient.saveTokens(
          data['accessToken']  as String,
          data['refreshToken'] as String,
        );
        return LoginResult(success: true, user: data['user'] as Map<String, dynamic>);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return LoginResult(success: false, error: body['error'] as String? ?? 'Erreur inconnue');
    } catch (e) {
      return LoginResult(success: false, error: 'Impossible de joindre le serveur: $e');
    }
  }

  /// Déconnexion — supprime les tokens.
  Future<void> logout() async {
    final refreshToken = await ApiClient.getRefreshToken();
    if (refreshToken != null) {
      try {
        await ApiClient.postPublic(ApiConfig.logoutUrl, {'refreshToken': refreshToken});
      } catch (_) {}
    }
    await ApiClient.clearTokens();
  }

  /// Vérifie si le token courant est valide.
  Future<bool> isAuthenticated() async {
    final token = await ApiClient.getAccessToken();
    if (token == null) return false;

    try {
      final response = await ApiClient.get(ApiConfig.verifyUrl);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
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
}
