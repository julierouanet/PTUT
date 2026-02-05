import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../data/mock_data.dart';

/// Authentication service for managing current user and permissions
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? _currentUser;

  /// Get current logged in user
  User? get currentUser => _currentUser;

  /// Check if a user is logged in
  bool get isLoggedIn => _currentUser != null;

  /// Get current user's role
  UserRole? get currentRole => _currentUser?.role;

  /// Initialize with default admin user for demo
  void initDemo() {
    if (_currentUser == null) {
      _currentUser = mockUsers.firstWhere((u) => u.role == UserRole.admin);
      notifyListeners();
    }
  }

  /// Switch to a different user (for demo purposes)
  void switchUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Log in user by email (simplified for demo)
  bool login(String email) {
    final user = mockUsers.where((u) => u.email == email).firstOrNull;
    if (user != null) {
      _currentUser = user;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Log out current user
  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  /// Check if current user has a specific permission
  bool hasPermission(Permission permission) {
    return _currentUser?.hasPermission(permission) ?? false;
  }

  /// Check multiple permissions (all required)
  bool hasAllPermissions(List<Permission> permissions) {
    return permissions.every((p) => hasPermission(p));
  }

  /// Check multiple permissions (any required)
  bool hasAnyPermission(List<Permission> permissions) {
    return permissions.any((p) => hasPermission(p));
  }

  /// Convenience permission checks
  bool get canViewEquipment => hasPermission(Permission.viewEquipment);
  bool get canReportIssue => hasPermission(Permission.reportIssue);
  bool get canTrackIssues => hasPermission(Permission.trackIssues);
  bool get canApproveRequests => hasPermission(Permission.approveRequests);
  bool get canAssignTasks => hasPermission(Permission.assignTasks);
  bool get canUpdateRepairs => hasPermission(Permission.updateRepairs);
  bool get canManageUsers => hasPermission(Permission.manageUsers);
  bool get canGenerateReports => hasPermission(Permission.generateReports);
  bool get canViewInventory => hasPermission(Permission.viewInventory);
}
