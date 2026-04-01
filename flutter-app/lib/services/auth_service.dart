import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../data/mock_data.dart';
import 'auth_api_service.dart';
import 'data_service.dart';

/// Service d'authentification — utilise l'API réelle en priorité,
/// avec fallback sur les données mock si le serveur est inaccessible.
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? _currentUser;
  bool _isLoading = false;
  String? _lastError;
  String? _sessionExpiredMessage;

  User?   get currentUser          => _currentUser;
  bool    get isLoggedIn           => _currentUser != null;
  bool    get isLoading            => _isLoading;
  String? get lastError            => _lastError;
  String? get sessionExpiredMessage => _sessionExpiredMessage;

  void clearSessionExpiredMessage() {
    _sessionExpiredMessage = null;
  }

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

  /// Changer d'utilisateur (debug uniquement, protégé par assert).
  void switchUser(User user) {
    assert(kDebugMode, 'switchUser ne doit pas être appelé en production');
    _currentUser = user;
    notifyListeners();
  }

  // ── Restauration de session (auto-login) ──────────────────────────────────

  /// Tente de restaurer la session depuis un token stocké.
  /// Appelle /api/auth/me et restaure l'utilisateur si le token est valide.
  Future<bool> restoreSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userData = await AuthApiService.instance.getMe();
      if (userData != null) {
        _currentUser = _userFromApiResponse(userData);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Appelé quand la session JWT expire (refresh token invalide).
  void handleSessionExpired() {
    _sessionExpiredMessage = 'Votre session a expiré. Veuillez vous reconnecter.';
    _currentUser = null;
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
  Future<bool> updateProfile({String? firstName, String? lastName, String? email, String? phone, String? department}) async {
    if (_currentUser == null) return false;
    final newFirst = firstName ?? _currentUser!.firstName;
    final newLast  = lastName  ?? _currentUser!.lastName;
    final newName  = '$newFirst $newLast'.trim();
    _currentUser = _currentUser!.copyWith(
      firstName:  newFirst,
      lastName:   newLast,
      name:       newName,
      email:      email      ?? _currentUser!.email,
      phone:      phone      ?? _currentUser!.phone,
      department: department ?? _currentUser!.department,
    );
    notifyListeners();
    try {
      final data = <String, dynamic>{};
      if (firstName != null)  data['first_name']  = firstName;
      if (lastName != null)   data['last_name']   = lastName;
      if (firstName != null || lastName != null) data['name'] = newName;
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

  bool hasPermission(Permission permission) {
    final user = _currentUser;
    if (user == null) return false;
    // L'admin a toujours accès à tout, sans exception
    if (user.role == UserRole.admin) return true;
    final dynamicPerms = DataService().permissionsForRole(user.role.name);
    if (dynamicPerms != null && dynamicPerms.isNotEmpty) {
      return dynamicPerms.contains(permission.name);
    }
    return user.hasPermission(permission);
  }
  bool hasAllPermissions(List<Permission> permissions) => permissions.every(hasPermission);
  bool hasAnyPermission(List<Permission> permissions)  => permissions.any(hasPermission);

  bool get canViewEquipment    => hasPermission(Permission.viewEquipment);
  bool get canManageEquipment  => hasPermission(Permission.manageEquipment);
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
    final roleStr   = data['role'] as String? ?? 'hospitalStaff';
    final role      = _parseRole(roleStr);
    final name      = data['name']       as String? ?? '';
    final firstName = data['first_name'] as String? ?? '';
    final lastName  = data['last_name']  as String? ?? '';

    return User(
      id:          data['id']         as String? ?? '',
      name:        name,
      firstName:   firstName.isNotEmpty ? firstName : (name.split(' ').first),
      lastName:    lastName.isNotEmpty  ? lastName  : (name.split(' ').skip(1).join(' ')),
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
