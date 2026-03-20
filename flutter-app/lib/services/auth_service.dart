import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../data/mock_data.dart';
import 'auth_api_service.dart';

/// Service d'authentification — utilise l'API réelle en priorité,
/// avec fallback sur les données mock si le serveur est inaccessible.
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? _currentUser;
  bool _isLoading = false;
  String? _lastError;

  User?   get currentUser => _currentUser;
  bool    get isLoggedIn  => _currentUser != null;
  bool    get isLoading   => _isLoading;
  String? get lastError   => _lastError;

  UserRole? get currentRole => _currentUser?.role;

  // ── Initialisation (tests uniquement) ──────────────────────────────────────

  /// Démarre avec l'admin en mode démo (données mock).
  /// Réservé aux tests — n'utilise pas de vrai token JWT.
  @visibleForTesting
  void initDemo() {
    assert(kDebugMode, 'initDemo ne doit pas être appelé en production');
    if (_currentUser == null) {
      _currentUser = mockUsers.firstWhere((u) => u.role == UserRole.admin);
      notifyListeners();
    }
  }

  // ── Connexion ──────────────────────────────────────────────────────────────

  /// Connexion via l'API réelle.
  /// Retourne true si réussi, false sinon (consulter [lastError]).
  Future<bool> loginWithApi(String email, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = await AuthApiService.instance.login(email, password);

      if (result.success && result.user != null) {
        _currentUser = _userFromApiResponse(result.user!);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _lastError = result.error;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = 'Erreur réseau: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Connexion simplifiée par email (données mock — tests uniquement).
  /// Ne crée PAS de session JWT — aucune requête API ne fonctionnera.
  @visibleForTesting
  bool login(String email) {
    assert(kDebugMode, 'login(email) mock ne doit pas être appelé en production');
    final user = mockUsers.where((u) => u.email == email).firstOrNull;
    if (user != null) {
      _currentUser = user;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Changer d'utilisateur (tests uniquement).
  @visibleForTesting
  void switchUser(User user) {
    assert(kDebugMode, 'switchUser ne doit pas être appelé en production');
    _currentUser = user;
    notifyListeners();
  }

  // ── Déconnexion ────────────────────────────────────────────────────────────

  Future<void> logoutApi() async {
    await AuthApiService.instance.logout();
    _currentUser = null;
    notifyListeners();
  }

  /// Déconnexion simple (mock).
  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // ── Profil utilisateur ─────────────────────────────────────────────────────

  /// Met à jour le profil de l'utilisateur connecté localement + via API.
  Future<bool> updateProfile({String? name, String? email, String? phone, String? department}) async {
    if (_currentUser == null) return false;
    _currentUser = _currentUser!.copyWith(
      name:       name       ?? _currentUser!.name,
      email:      email      ?? _currentUser!.email,
      phone:      phone      ?? _currentUser!.phone,
      department: department ?? _currentUser!.department,
    );
    notifyListeners();
    try {
      final data = <String, dynamic>{};
      if (name != null)       data['name']       = name;
      if (email != null)      data['email']      = email;
      if (phone != null)      data['phone']      = phone;
      if (department != null) data['department'] = department;
      await AuthApiService.instance.updateUser(_currentUser!.id, data);
    } catch (_) {}
    return true;
  }

  /// Change le mot de passe de l'utilisateur connecté via API.
  Future<bool> changePassword(String newPassword) async {
    if (_currentUser == null) return false;
    try {
      await AuthApiService.instance.updateUser(_currentUser!.id, {'password': newPassword});
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  bool hasPermission(Permission permission)            => _currentUser?.hasPermission(permission) ?? false;
  bool hasAllPermissions(List<Permission> permissions) => permissions.every(hasPermission);
  bool hasAnyPermission(List<Permission> permissions)  => permissions.any(hasPermission);

  bool get canViewEquipment   => hasPermission(Permission.viewEquipment);
  bool get canReportIssue     => hasPermission(Permission.reportIssue);
  bool get canTrackIssues     => hasPermission(Permission.trackIssues);
  bool get canApproveRequests => hasPermission(Permission.approveRequests);
  bool get canAssignTasks     => hasPermission(Permission.assignTasks);
  bool get canUpdateRepairs   => hasPermission(Permission.updateRepairs);
  bool get canManageUsers     => hasPermission(Permission.manageUsers);
  bool get canGenerateReports => hasPermission(Permission.generateReports);
  bool get canViewInventory   => hasPermission(Permission.viewInventory);

  // ── Conversion API → modèle ────────────────────────────────────────────────

  User _userFromApiResponse(Map<String, dynamic> data) {
    final roleStr = data['role'] as String? ?? 'hospitalStaff';
    final role    = _parseRole(roleStr);

    return User(
      id:          data['id']         as String? ?? '',
      name:        data['name']       as String? ?? '',
      email:       data['email']      as String? ?? '',
      department:  data['department'] as String? ?? '',
      role:        role,
      permissions: getPermissionsForRole(role),
      phone:       data['phone']      as String?,
      createdAt:   data['created_at'] as String? ?? '',
    );
  }

  UserRole _parseRole(String role) {
    switch (role) {
      case 'admin':      return UserRole.admin;
      case 'supervisor': return UserRole.supervisor;
      case 'technician': return UserRole.technician;
      default:           return UserRole.hospitalStaff;
    }
  }
}
