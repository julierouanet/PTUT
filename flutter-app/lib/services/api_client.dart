import 'dart:async';
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

  /// Marge de sécurité avant l'expiration de l'access token pour déclencher
  /// un refresh proactif — évite de dépendre uniquement du 401 réactif si le
  /// réseau est lent au moment exact de l'expiration.
  static const _proactiveRefreshMargin = Duration(minutes: 2);

  /// Délai plancher avant un refresh proactif. Absorbe un décalage d'horloge
  /// locale (clock skew navigateur/OS) sans déclencher une rafale de refresh
  /// rapprochés vers Keycloak si l'horloge du client est significativement en
  /// avance sur celle du serveur (l'`exp` du token paraîtrait alors toujours
  /// "presque expiré").
  static const _proactiveRefreshFloor = Duration(seconds: 30);

  static Timer? _proactiveRefreshTimer;

  /// Future du refresh Keycloak en cours, s'il y en a un. Garantit qu'un seul
  /// appel de refresh est en vol à la fois : les 401 concurrents (ex. plusieurs
  /// requêtes du dashboard lancées en parallèle) attendent ce même Future au
  /// lieu de déclencher chacun un refresh distinct. Sans ce verrou, la rotation
  /// stricte de Keycloak (`revokeRefreshToken: true`) rejette les appels de
  /// refresh suivants (refresh token déjà consommé par le premier) et
  /// provoque une déconnexion forcée alors que la session est valide.
  static Future<bool>? _refreshInFlight;

  // ── Token storage ─────────────────────────────────────────────────────────

  static Future<void> saveTokens(String access, String refresh) async {
    await SecureTokenStorage.write(_accessTokenKey, access);
    await SecureTokenStorage.write(_refreshTokenKey, refresh);
    // Réarme le timer proactif à chaque sauvegarde de tokens (login, refresh
    // réactif sur 401, ou restauration explicite). Un réarmement redondant
    // (ex. un refresh réactif suivi de près par le timer proactif encore en
    // vol au moment du 401) est sans effet indésirable : `_scheduleProactiveRefresh`
    // annule systématiquement le timer précédent avant d'en poser un nouveau.
    _scheduleProactiveRefresh(access);
  }

  static Future<String?> getAccessToken() async {
    return SecureTokenStorage.read(_accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return SecureTokenStorage.read(_refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    _proactiveRefreshTimer?.cancel();
    _proactiveRefreshTimer = null;
    await SecureTokenStorage.deleteAll([_accessTokenKey, _refreshTokenKey]);
  }

  /// Vérifie si des tokens sont stockés (pour l'auto-login).
  static Future<bool> hasStoredTokens() async {
    final token = await getAccessToken();
    return token != null;
  }

  /// À appeler après un `restoreSession()` réussi (auto-login au démarrage,
  /// `main.dart`) : réarme le timer de refresh proactif depuis le token déjà
  /// stocké, qui n'est pas repassé par [saveTokens] lors d'une simple
  /// restauration de session (seul un login ou un refresh y repasse).
  static Future<void> armProactiveRefreshFromStorage() async {
    final token = await getAccessToken();
    if (token != null) _scheduleProactiveRefresh(token);
  }

  // ── Requêtes HTTP ──────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Cache conditionnel ETag/304 ───────────────────────────────────────────
  // ApiClient reste un client HTTP générique : c'est l'appelant (db_api_service)
  // qui décide, via `conditional: true` sur [get], qu'une URL donnée est un GET
  // lourd et stable (équipement léger, lieux) éligible — PAS sur les endpoints
  // volatils (ex. /api/issues). Un 304 ne renvoie aucun corps : on persiste donc
  // {etag, body} pour reconstruire une réponse 200 localement.
  static const _etagCachePrefix = 'etag_cache:';

  static String _etagCacheKey(String url) => '$_etagCachePrefix$url';

  static Future<Map<String, dynamic>?> _readEtagCache(String url) async {
    try {
      final raw = await SecureTokenStorage.read(_etagCacheKey(url));
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['etag'] is! String || decoded['body'] is! String) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeEtagCache(String url, String etag, String body) async {
    try {
      await SecureTokenStorage.write(_etagCacheKey(url), jsonEncode({'etag': etag, 'body': body}));
    } catch (_) {
      // Quota de stockage dépassé (localStorage web) ou autre erreur d'écriture :
      // on vide cette entrée plutôt que de planter — la requête reste utilisable,
      // simplement sans bénéfice de cache à la prochaine visite.
      await _clearEtagCache(url);
    }
  }

  static Future<void> _clearEtagCache(String url) async {
    try {
      await SecureTokenStorage.delete(_etagCacheKey(url));
    } catch (_) {}
  }

  /// Invalide le cache conditionnel de la liste équipement (légère, login).
  /// À appeler après toute mutation POST/PUT/DELETE sur /api/equipment.
  static Future<void> invalidateEquipmentCache() async {
    await _clearEtagCache('${ApiConfig.equipmentUrl}?light=true');
  }

  /// GET avec authentification — rafraîchit le token si expiré (401).
  /// [conditional] : à activer par l'appelant pour les GET lourds et stables
  /// (ex. équipement léger, lieux) — envoie `If-None-Match` si un ETag est en
  /// cache et reconstruit une réponse 200 depuis le corps caché en cas de 304.
  static Future<http.Response> get(String url, {Map<String, String>? extra, bool conditional = false}) async {
    final headers = await _authHeaders();
    if (extra != null) headers.addAll(extra);

    final cached = conditional ? await _readEtagCache(url) : null;
    if (cached != null) headers['If-None-Match'] = cached['etag'] as String;

    var response = await http.get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _authHeaders();
        if (cached != null) newHeaders['If-None-Match'] = cached['etag'] as String;
        response = await http.get(Uri.parse(url), headers: newHeaders)
            .timeout(const Duration(seconds: 30));
      }
    }

    if (conditional) {
      if (response.statusCode == 304 && cached != null) {
        return http.Response(cached['body'] as String, 200, headers: response.headers);
      }
      if (response.statusCode == 200) {
        final etag = response.headers['etag'];
        if (etag != null) await _writeEtagCache(url, etag, response.body);
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
  /// Retourne le JSON décodé (Map ou List selon l'endpoint) ou lève une [Exception].
  static Future<dynamic> postMultipart(
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

  /// Upload de plusieurs fichiers (champ multi-values, ex. "photos" ou "files").
  /// Retourne la liste des documents insérés telle que renvoyée par le serveur.
  static Future<List<dynamic>> postMultipartFiles(
    String url,
    List<({Uint8List bytes, String name, String mimeType})> files, {
    required String fileField,
    Map<String, String> fields = const {},
  }) async {
    var toProcess = await _sendMultipartFiles(url, files, fileField, fields);
    if (toProcess.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) toProcess = await _sendMultipartFiles(url, files, fileField, fields);
    }
    final decoded = await _parseMultipartResponse(toProcess);
    return _extractFileList(decoded);
  }

  /// Le serveur renvoie tantôt un tableau nu (ex. POST /documents), tantôt un
  /// objet enveloppant la liste sous une clé (ex. POST /photos → {message, photos}).
  /// Accepter les deux formes évite un TypeError qui masquerait un upload
  /// pourtant réussi côté serveur (voir POST /api/issues/:id/photos).
  /// Si l'objet contient zéro ou plusieurs valeurs de type List, on échoue
  /// explicitement plutôt que de deviner laquelle est la bonne (pas de
  /// résolution silencieuse d'un cas ambigu).
  static List<dynamic> _extractFileList(dynamic decoded) {
    if (decoded is List<dynamic>) return decoded;
    if (decoded is Map<String, dynamic>) {
      final listValues = decoded.values.whereType<List<dynamic>>().toList();
      if (listValues.length == 1) return listValues.single;
    }
    throw Exception('Réponse serveur inattendue (liste de fichiers introuvable ou ambiguë)');
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
    String fileField,
    Map<String, String> fields,
  ) async {
    final token = await getAccessToken();
    final request = http.MultipartRequest('POST', Uri.parse(url));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    fields.forEach((k, v) => request.fields[k] = v);
    for (final f in files) {
      request.files.add(http.MultipartFile.fromBytes(
        fileField, f.bytes,
        filename: f.name,
        contentType: _mediaType(f.mimeType),
      ));
    }
    return request.send().timeout(const Duration(seconds: 60));
  }

  // Retourne dynamic car les endpoints renvoient tantôt un objet, tantôt un tableau.
  static Future<dynamic> _parseMultipartResponse(http.StreamedResponse response) async {
    final body = await response.stream.bytesToString();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(body);
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

  // ── Refresh proactif (avant expiration) ──────────────────────────────────

  /// Décode le claim `exp` (secondes epoch UTC, `num` — Keycloak encode
  /// habituellement un entier mais un `double` JSON reste accepté par
  /// robustesse) du payload JWT, sans vérifier la signature — la validation
  /// cryptographique de l'access token reste faite par le backend via JWKS
  /// (`auth-service/src/middleware/auth.js`). Ce décodage local sert
  /// uniquement à planifier le timer de refresh proactif ; un token malformé
  /// ou un `exp` absent/de type inattendu retourne `null` (le refresh
  /// proactif est alors simplement désactivé, le fallback réactif sur 401
  /// reste actif).
  @visibleForTesting
  static DateTime? decodeExpiry(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      payload += '=' * ((4 - payload.length % 4) % 4);
      final decoded = jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
      final exp = decoded['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch((exp * 1000).round(), isUtc: true);
    } catch (_) {
      return null;
    }
  }

  static void _scheduleProactiveRefresh(String accessToken) {
    _proactiveRefreshTimer?.cancel();
    final expiry = decodeExpiry(accessToken);
    if (expiry == null) return;
    var delay = expiry.difference(DateTime.now().toUtc()) - _proactiveRefreshMargin;
    if (delay < _proactiveRefreshFloor) delay = _proactiveRefreshFloor;
    _proactiveRefreshTimer = Timer(delay, () {
      _tryRefresh();
    });
  }

  // ── Refresh token via Keycloak (rotation stricte) ────────────────────────

  /// Point d'entrée public — garantit qu'un seul refresh Keycloak est en vol
  /// à la fois (voir [_refreshInFlight]). Volontairement NON `async` :
  /// `_tryRefresh` elle-même ne contient aucun `await`, donc son corps
  /// s'exécute intégralement de façon synchrone (test de `_refreshInFlight`
  /// PUIS affectation, sans point de suspension entre les deux) avant de
  /// rendre la main à l'appelant. C'est cette absence d'`await` DANS
  /// `_tryRefresh` elle-même qui élimine la race condition — PAS le fait que
  /// `_doRefresh` (appelée à l'intérieur) contiendrait elle-même des `await` :
  /// `_doRefresh()` peut suspendre autant qu'elle veut une fois sa Future
  /// créée et stockée dans `_refreshInFlight`, cela n'affecte plus la section
  /// critique. Ne JAMAIS ajouter `async` à `_tryRefresh` elle-même, même si
  /// une revue de style le suggère — ce serait réintroduire la race condition.
  static Future<bool> _tryRefresh() =>
      _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);

  static Future<bool> _doRefresh() async {
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
