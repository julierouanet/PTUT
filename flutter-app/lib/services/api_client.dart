import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'secure_token_storage.dart';

/// Client HTTP de base — gère le token JWT et le refresh automatique.
///
/// Le stockage des tokens est délégué à [SecureTokenStorage] qui utilise
/// SharedPreferences sur web et FlutterSecureStorage sur natif.
class ApiClient {
  static const _accessTokenKey  = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  /// Callback appelé quand la session expire (refresh token invalide).
  static VoidCallback? onSessionExpired;

  // ── Token storage ─────────────────────────────────────────────────────────

  static Future<void> saveTokens(String access, String refresh) async {
    await SecureTokenStorage.write(_accessTokenKey, access);
    await SecureTokenStorage.write(_refreshTokenKey, refresh);
  }

  static Future<String?> getAccessToken() async {
    return SecureTokenStorage.read(_accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return SecureTokenStorage.read(_refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    await SecureTokenStorage.deleteAll([_accessTokenKey, _refreshTokenKey]);
  }

  /// Vérifie si des tokens sont stockés (pour l'auto-login).
  static Future<bool> hasStoredTokens() async {
    final token = await getAccessToken();
    return token != null;
  }

  // ── Requêtes HTTP ──────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET avec authentification — rafraîchit le token si expiré (401).
  static Future<http.Response> get(String url, {Map<String, String>? extra}) async {
    final headers = await _authHeaders();
    if (extra != null) headers.addAll(extra);

    var response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _authHeaders();
        response = await http.get(Uri.parse(url), headers: newHeaders);
      }
    }
    return response;
  }

  /// POST sans authentification (ex. login).
  static Future<http.Response> postPublic(String url, Map<String, dynamic> body) async {
    return http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  /// POST avec authentification.
  static Future<http.Response> post(String url, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    var response = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body));

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _authHeaders();
        response = await http.post(Uri.parse(url), headers: newHeaders, body: jsonEncode(body));
      }
    }
    return response;
  }

  /// PUT avec authentification.
  static Future<http.Response> put(String url, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    var response = await http.put(Uri.parse(url), headers: headers, body: jsonEncode(body));

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _authHeaders();
        response = await http.put(Uri.parse(url), headers: newHeaders, body: jsonEncode(body));
      }
    }
    return response;
  }

  /// PATCH avec authentification.
  static Future<http.Response> patch(String url, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    var response = await http.patch(Uri.parse(url), headers: headers, body: jsonEncode(body));

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _authHeaders();
        response = await http.patch(Uri.parse(url), headers: newHeaders, body: jsonEncode(body));
      }
    }
    return response;
  }

  /// DELETE avec authentification + retry sur token expiré.
  static Future<http.Response> delete(String url) async {
    final headers = await _authHeaders();
    var response = await http.delete(Uri.parse(url), headers: headers);

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _authHeaders();
        response = await http.delete(Uri.parse(url), headers: newHeaders);
      }
    }
    return response;
  }

  // ── Refresh token (avec rotation — sauvegarde aussi le nouveau refresh) ────

  static Future<bool> _tryRefresh() async {
    final refreshToken = await getRefreshToken();
    // Pas de refresh token = jamais connecté ou déjà déconnecté → pas d'alerte
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.refreshUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccess = data['accessToken'] as String;
        final newRefresh = data['refreshToken'] as String?;
        if (newRefresh != null) {
          await saveTokens(newAccess, newRefresh);
        } else {
          await SecureTokenStorage.write(_accessTokenKey, newAccess);
        }
        return true;
      }
    } catch (_) {}

    // Refresh token existait mais le serveur l'a rejeté → session expirée
    onSessionExpired?.call();
    return false;
  }
}
