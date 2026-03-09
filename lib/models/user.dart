import 'user_role.dart';

/// User model for authentication and authorization
class User {
  final String id;
  final String name;
  final String email;
  final String department;
  final UserRole role;
  final List<Permission> permissions;
  final bool isActive;
  final String? phone;
  final String createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.role,
    required this.permissions,
    this.isActive = true,
    this.phone,
    required this.createdAt,
  });

  /// Check if user has a specific permission
  bool hasPermission(Permission permission) {
    return permissions.contains(permission);
  }

  /// Check if user can access a feature
  bool canViewEquipment() => hasPermission(Permission.viewEquipment);
  bool canReportIssue() => hasPermission(Permission.reportIssue);
  bool canTrackIssues() => hasPermission(Permission.trackIssues);
  bool canApproveRequests() => hasPermission(Permission.approveRequests);
  bool canAssignTasks() => hasPermission(Permission.assignTasks);
  bool canUpdateRepairs() => hasPermission(Permission.updateRepairs);
  bool canManageUsers() => hasPermission(Permission.manageUsers);
  bool canGenerateReports() => hasPermission(Permission.generateReports);
  bool canViewInventory() => hasPermission(Permission.viewInventory);

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? department,
    UserRole? role,
    List<Permission>? permissions,
    bool? isActive,
    String? phone,
    String? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      department: department ?? this.department,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
