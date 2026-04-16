import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction de stockage sécurisé cross-platform :
/// - Web  → SharedPreferences (localStorage) : flutter_secure_storage n'est
///          pas disponible dans le runtime web Flutter compilé.
/// - Natif → FlutterSecureStorage (Keychain / Keystore) pour un vrai stockage
///           chiffré sur mobile/desktop.
class SecureTokenStorage {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Écrire ──────────────────────────────────────────────────────────────────

  static Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  // ── Lire ────────────────────────────────────────────────────────────────────

  static Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return await _secureStorage.read(key: key);
    }
  }

  // ── Supprimer ───────────────────────────────────────────────────────────────

  static Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _secureStorage.delete(key: key);
    }
  }

  // ── Tout supprimer ───────────────────────────────────────────────────────────

  static Future<void> deleteAll(List<String> keys) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } else {
      for (final key in keys) {
        await _secureStorage.delete(key: key);
      }
    }
  }
}
