import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// Client HTTP de base — gère le token JWT et le refresh automatique.
class ApiClient {
  static const _accessTokenKey  = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  // ── Token storage ──────────────────────────────────────────────────────────

  static Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey,  access);
    await prefs.setString(_refreshTokenKey, refresh);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  // ── Requêtes HTTP ──────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET avec authentification — rafraîchit le token si expiré (403).
  static Future<http.Response> get(String url, {Map<String, String>? extra}) async {
    final headers = await _authHeaders();
    if (extra != null) headers.addAll(extra);

    var response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 403) {
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

    if (response.statusCode == 403) {
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

    if (response.statusCode == 403) {
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

    if (response.statusCode == 403) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _authHeaders();
        response = await http.patch(Uri.parse(url), headers: newHeaders, body: jsonEncode(body));
      }
    }
    return response;
  }

  /// DELETE avec authentification.
  static Future<http.Response> delete(String url) async {
    final headers = await _authHeaders();
    return http.delete(Uri.parse(url), headers: headers);
  }

  // ── Refresh token ─────────────────────────────────────────────────────────

  static Future<bool> _tryRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.refreshUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accessTokenKey, data['accessToken'] as String);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
