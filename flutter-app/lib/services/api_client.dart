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

    var response = await http.get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _authHeaders();
        response = await http.get(Uri.parse(url), headers: newHeaders)
            .timeout(const Duration(seconds: 30));
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
    ).timeout(const Duration(seconds: 30));
  }

  /// POST avec authentification.
  static Future<http.Response> post(String url, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    var response = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _authHeaders();
        response = await http.post(Uri.parse(url), headers: newHeaders, body: jsonEncode(body))
            .timeout(const Duration(seconds: 30));
      }
    }
    return response;
  }

  /// PUT avec authentification.
  static Future<http.Response> put(String url, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    var response = await http.put(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _authHeaders();
        response = await http.put(Uri.parse(url), headers: newHeaders, body: jsonEncode(body))
            .timeout(const Duration(seconds: 30));
      }
    }
    return response;
  }

  /// PATCH avec authentification.
  static Future<http.Response> patch(String url, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    var response = await http.patch(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _authHeaders();
        response = await http.patch(Uri.parse(url), headers: newHeaders, body: jsonEncode(body))
            .timeout(const Duration(seconds: 30));
      }
    }
    return response;
  }

  /// DELETE avec authentification + retry sur token expiré.
  static Future<http.Response> delete(String url) async {
    final headers = await _authHeaders();
    var response = await http.delete(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _authHeaders();
        response = await http.delete(Uri.parse(url), headers: newHeaders)
            .timeout(const Duration(seconds: 30));
      }
    }
    return response;
  }

  /// Upload multipart avec authentification — retry sur 401 comme les autres méthodes.
  ///
  /// [url]      : URL complète de l'endpoint.
  /// [fileBytes]: contenu binaire du fichier.
  /// [fileName] : nom original du fichier (champ "file").
  /// [mimeType] : type MIME (ex. "image/jpeg", "application/pdf").
  /// [fields]   : champs de formulaire additionnels (ex. {"type": "technical"}).
  /// [fileField]: nom du champ fichier (défaut "file").
  ///
  /// Retourne le JSON décodé ou lève une [Exception] avec le message d'erreur.
  static Future<Map<String, dynamic>> postMultipart(
    String url,
    Uint8List fileBytes,
    String fileName,
    String mimeType,
    Map<String, String> fields, {
    String fileField = 'file',
  }) async {
    final result = await _sendMultipart(url, fileBytes, fileName, mimeType, fields, fileField);
    if (result.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retried = await _sendMultipart(url, fileBytes, fileName, mimeType, fields, fileField);
        return _parseMultipartResponse(retried);
      }
    }
    return _parseMultipartResponse(result);
  }

  /// Upload de plusieurs fichiers (champ multi-values "photos").
  static Future<Map<String, dynamic>> postMultipartFiles(
    String url,
    List<({Uint8List bytes, String name, String mimeType})> files,
  ) async {
    final result = await _sendMultipartFiles(url, files);
    if (result.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retried = await _sendMultipartFiles(url, files);
        return _parseMultipartResponse(retried);
      }
    }
    return _parseMultipartResponse(result);
  }

  static Future<http.StreamedResponse> _sendMultipart(
    String url,
    Uint8List fileBytes,
    String fileName,
    String mimeType,
    Map<String, String> fields,
    String fileField,
  ) async {
    final token = await getAccessToken();
    final request = http.MultipartRequest('POST', Uri.parse(url));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    fields.forEach((k, v) => request.fields[k] = v);
    request.files.add(http.MultipartFile.fromBytes(
      fileField, fileBytes,
      filename: fileName,
      contentType: _mediaType(mimeType),
    ));
    return request.send().timeout(const Duration(seconds: 60));
  }

  static Future<http.StreamedResponse> _sendMultipartFiles(
    String url,
    List<({Uint8List bytes, String name, String mimeType})> files,
  ) async {
    final token = await getAccessToken();
    final request = http.MultipartRequest('POST', Uri.parse(url));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    for (final f in files) {
      request.files.add(http.MultipartFile.fromBytes(
        'photos', f.bytes,
        filename: f.name,
        contentType: _mediaType(f.mimeType),
      ));
    }
    return request.send().timeout(const Duration(seconds: 60));
  }

  static Future<Map<String, dynamic>> _parseMultipartResponse(http.StreamedResponse response) async {
    final body = await response.stream.bytesToString();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    String message = 'Erreur ${response.statusCode}';
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      message = decoded['error'] as String? ?? message;
    } catch (_) {}
    throw Exception(message);
  }

  static http.MediaType _mediaType(String mimeType) {
    final parts = mimeType.split('/');
    return http.MediaType(parts[0], parts.length > 1 ? parts[1] : '*');
  }

  // ── Refresh token via Keycloak (rotation stricte) ────────────────────────

  static Future<bool> _tryRefresh() async {
    final refreshToken = await getRefreshToken();
    // Pas de refresh token = jamais connecté ou déjà déconnecté → pas d'alerte
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.kcTokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type':    'refresh_token',
          'client_id':     ApiConfig.kcClientId,
          'refresh_token': refreshToken,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccess  = data['access_token']  as String?;
        final newRefresh = data['refresh_token'] as String?;
        // Les deux tokens sont obligatoires (rotation stricte Keycloak)
        if (newAccess != null && newRefresh != null) {
          await saveTokens(newAccess, newRefresh);
          return true;
        }
        // Réponse incomplète = session considérée expirée
        onSessionExpired?.call();
        return false;
      }
    } catch (_) {}

    // Refresh token rejeté par Keycloak → session expirée
    onSessionExpired?.call();
    return false;
  }
}
