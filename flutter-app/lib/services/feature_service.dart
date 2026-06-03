import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/feature_flag.dart';
import 'api_client.dart';
import 'api_config.dart';

/// Service Feature Flags — Singleton ChangeNotifier.
///
/// Charge la liste des features depuis le backend (admin seulement).
/// Les non-admins reçoivent un 403 → la liste reste vide sans erreur.
class FeatureService extends ChangeNotifier {
  static final FeatureService _instance = FeatureService._internal();
  factory FeatureService() => _instance;
  FeatureService._internal();

  List<FeatureFlag> _features = [];
  bool _isLoading = false;
  String? _lastError;

  List<FeatureFlag> get features  => _features;
  bool              get isLoading => _isLoading;
  String?           get lastError => _lastError;

  // ── Chargement ────────────────────────────────────────────────────────────

  Future<void> loadFeatures() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await ApiClient.get(ApiConfig.featuresUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        _features = data
            .map((e) => FeatureFlag.fromApiJson(e as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 403) {
        // Non-admin : features vides, pas d'erreur affichée
        _features = [];
      } else {
        _lastError = 'Erreur ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('FeatureService: erreur chargement ($e)');
      _lastError = e.toString();
      _features = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Mise à jour d'une feature ─────────────────────────────────────────────

  /// Met à jour le statut global et les overrides par rôle d'une feature.
  /// Retourne true si l'opération réussit.
  Future<bool> updateFeature(
    String id, {
    required bool isGlobalActive,
    required Map<String, bool> roleOverrides,
  }) async {
    try {
      final response = await ApiClient.put(
        '${ApiConfig.featuresUrl}/$id',
        {
          'is_global_active': isGlobalActive,
          'role_overrides':   roleOverrides,
        },
      );
      if (response.statusCode == 200) {
        // Recharge depuis l'API pour avoir l'état canonique
        await loadFeatures();
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
    }
  }

  // ── Évaluation d'un flag pour un rôle donné ────────────────────────────────

  /// Retourne true si le module [flagId] est actif pour le rôle [roleApiName].
  ///
  /// Logique :
  ///   - Flag inconnu → true par défaut (module actif)
  ///   - global désactivé → false (kill switch, aucune exception)
  ///   - Override présent pour le rôle → valeur de l'override
  ///   - Sinon → état global
  bool isModuleEnabled(String flagId, [String? roleApiName]) {
    final flag = _features.where((f) => f.id == flagId).firstOrNull;
    if (flag == null) return true;
    if (!flag.isGlobalActive) return false;
    if (roleApiName != null && flag.roleOverrides.containsKey(roleApiName)) {
      return flag.roleOverrides[roleApiName]!;
    }
    return flag.isGlobalActive;
  }

  // ── Réinitialisation (déconnexion) ────────────────────────────────────────

  void clear() {
    _features  = [];
    _lastError = null;
    notifyListeners();
  }
}
