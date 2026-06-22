import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import 'api_client.dart';
import 'api_config.dart';

/// Service Paramètres Application — Singleton ChangeNotifier.
class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  AppSettings? _settings;
  bool _isLoading = false;
  String? _lastError;

  AppSettings? get settings  => _settings;
  bool         get isLoading => _isLoading;
  String?      get lastError => _lastError;

  // ── Chargement admin ──────────────────────────────────────────────────────

  Future<void> loadAdmin() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await ApiClient.get(ApiConfig.appSettingsUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        _settings = AppSettings.fromAdminJson(data);
      } else {
        _lastError = 'Erreur ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('AppSettingsService: erreur chargement ($e)');
      _lastError = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Sauvegarde ────────────────────────────────────────────────────────────

  Future<bool> save(Map<String, String> updates) async {
    try {
      final response = await ApiClient.put(
        ApiConfig.appSettingsUrl,
        {'settings': updates},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        _settings = AppSettings.fromAdminJson(data);
        _lastError = null;
        notifyListeners();
        return true;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _lastError = (body['error'] as String?) ?? 'Erreur ${response.statusCode}';
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Email de test ─────────────────────────────────────────────────────────

  Future<({bool sent, String? error})> sendTestEmail(String toEmail) async {
    try {
      final response = await ApiClient.post(
        ApiConfig.appSettingsTestEmailUrl,
        {'to_email': toEmail},
      );
      if (response.statusCode == 200) {
        return (sent: true, error: null);
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = (body['error'] as String?) ?? 'Erreur ${response.statusCode}';
      return (sent: false, error: msg);
    } catch (e) {
      return (sent: false, error: e.toString());
    }
  }

  // ── Réinitialisation (déconnexion) ────────────────────────────────────────

  void clear() {
    _settings  = null;
    _lastError = null;
    notifyListeners();
  }
}
