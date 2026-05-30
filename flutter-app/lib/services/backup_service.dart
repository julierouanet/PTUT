import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/backup.dart';
import 'api_client.dart';
import 'api_config.dart';
// Import conditionnel : web_download_web.dart sur navigateur, stub sur VM/mobile.
import '../utils/web_download.dart';

/// Service de gestion des sauvegardes — Singleton ChangeNotifier.
class BackupService extends ChangeNotifier {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  BackupSettings? _settings;
  List<BackupRecord> _history = [];
  bool _isLoading = false;
  bool _isTriggering = false;
  bool _isSavingSettings = false;
  bool _isRestoring = false;
  String? _lastError;

  BackupSettings? get settings        => _settings;
  List<BackupRecord> get history      => _history;
  bool get isLoading                  => _isLoading;
  bool get isTriggering               => _isTriggering;
  bool get isSavingSettings          => _isSavingSettings;
  bool get isRestoring                => _isRestoring;
  String? get lastError               => _lastError;

  // ── Chargement ────────────────────────────────────────────────────────────

  Future<void> loadBackupInfos() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await ApiClient.get(ApiConfig.backupsUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _settings = BackupSettings.fromApiJson(
            data['settings'] as Map<String, dynamic>);
        _history = (data['history'] as List<dynamic>)
            .map((e) => BackupRecord.fromApiJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _lastError = 'Erreur ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('BackupService: erreur chargement ($e)');
      _lastError = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Déclenchement manuel ──────────────────────────────────────────────────

  /// Déclenche une sauvegarde manuelle. Retourne true si succès.
  Future<bool> triggerManualBackup() async {
    _isTriggering = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await ApiClient.post(
        '${ApiConfig.backupsUrl}/trigger',
        {},
      );
      if (response.statusCode == 200) {
        // Recharge l'historique pour afficher la nouvelle entrée
        await loadBackupInfos();
        return true;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _lastError = body['error'] as String? ?? 'Erreur ${response.statusCode}';
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isTriggering = false;
      notifyListeners();
    }
  }

  // ── Mise à jour des paramètres ────────────────────────────────────────────

  /// Met à jour la planification cron et l'activation. Retourne true si succès.
  Future<bool> updateBackupSettings({
    required String cronSchedule,
    required bool isAutomated,
  }) async {
    _isSavingSettings = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await ApiClient.post(
        '${ApiConfig.backupsUrl}/settings',
        {'cron_schedule': cronSchedule, 'is_automated': isAutomated},
      );
      if (response.statusCode == 200) {
        await loadBackupInfos();
        return true;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _lastError = body['error'] as String? ?? 'Erreur ${response.statusCode}';
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isSavingSettings = false;
      notifyListeners();
    }
  }

  // ── Téléchargement ────────────────────────────────────────────────────────

  /// Télécharge le fichier .db et déclenche le téléchargement navigateur (web).
  Future<bool> downloadBackup(BackupRecord record) async {
    _lastError = null;

    try {
      final response = await ApiClient.get(
        '${ApiConfig.backupsUrl}/download/${record.id}',
      );
      if (response.statusCode == 200) {
        // Téléchargement navigateur via la façade conditionnelle (web uniquement)
        if (kIsWeb) {
          await triggerWebDownload(
            response.bodyBytes.toList(),
            record.filename,
          );
        }
        return true;
      }
      _lastError = 'Erreur ${response.statusCode}';
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Restauration ──────────────────────────────────────────────────────────

  /// Restaure la base de données depuis une sauvegarde. Retourne true si succès.
  Future<bool> restoreBackup(BackupRecord record) async {
    _isRestoring = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await ApiClient.post(
        '${ApiConfig.backupsUrl}/restore/${record.id}',
        {},
      );
      if (response.statusCode == 200) {
        await loadBackupInfos();
        return true;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _lastError = body['error'] as String? ?? 'Erreur ${response.statusCode}';
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('BackupService: erreur restauration ($e)');
      _lastError = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  // ── Réinitialisation (déconnexion) ────────────────────────────────────────

  void clear() {
    _settings   = null;
    _history    = [];
    _lastError  = null;
    notifyListeners();
  }
}
