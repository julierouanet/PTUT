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
}
