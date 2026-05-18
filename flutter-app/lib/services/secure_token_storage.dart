import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// local_auth importé conditionnellement pour rester compatible web
import 'package:local_auth/local_auth.dart';

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

  // ── Biométrie (natif uniquement — non disponible sur web) ────────────────────
  // Stocke un refresh token "maître" dans le Keychain/Keystore pour permettre
  // un re-login biométrique sans resaisir le mot de passe.

  static const _bioTokenKey = 'bio_refresh_token';
  static final _localAuth   = LocalAuthentication();

  /// Persiste le refresh token en tant que token biométrique.
  /// Aucune action sur web (LocalAuthentication n'est pas disponible).
  static Future<void> saveBioToken(String refreshToken) async {
    if (kIsWeb) return;
    await _secureStorage.write(key: _bioTokenKey, value: refreshToken);
  }

  /// Récupère le refresh token biométrique stocké, ou null.
  static Future<String?> readBioToken() async {
    if (kIsWeb) return null;
    return _secureStorage.read(key: _bioTokenKey);
  }

  /// Supprime le token biométrique (ex. lors du logout).
  static Future<void> deleteBioToken() async {
    if (kIsWeb) return;
    await _secureStorage.delete(key: _bioTokenKey);
  }

  /// Vérifie si la biométrie est disponible ET si un token maître est enregistré.
  static Future<bool> canUseBiometrics() async {
    if (kIsWeb) return false;
    try {
      final canCheck    = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      final storedToken = await readBioToken();
      return storedToken != null;
    } catch (_) {
      return false;
    }
  }

  /// Lance l'authentification biométrique.
  /// Retourne true si l'utilisateur s'est authentifié avec succès.
  /// Retourne false sur web ou si la biométrie échoue/est annulée.
  static Future<bool> authenticateWithBiometrics({
    String localizedReason = 'Confirmez votre identité pour vous reconnecter',
  }) async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
