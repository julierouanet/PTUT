import 'user_role.dart';

/// User model for authentication and authorization
class User {
  final String id;
  final String name;
  final String firstName;
  final String lastName;
  final String email;
  final String department;
  final List<UserRole> roles;
  final List<Permission> permissions;
  final bool isActive;
  final bool isEmailVerified;
  final String? phone;
  final String createdAt;

  /// Nom complet calcule a partir de firstName + lastName
  String get fullName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : name;
  }

  factory User.fromApiJson(Map<String, dynamic> json) {
    final roles = _rolesFromJson(json['roles']);
    final name = json['name'] as String? ?? '';
    final firstName = json['first_name'] as String? ?? '';
    final lastName = json['last_name'] as String? ?? '';
    return User(
      id:          json['id']          as String? ?? '',
      name:        name,
      firstName:   firstName.isNotEmpty ? firstName : (name.split(' ').first),
      lastName:    lastName.isNotEmpty ? lastName : (name.split(' ').skip(1).join(' ')),
      email:       json['email']       as String? ?? '',
      department:  json['department']  as String? ?? '',
      roles:       roles,
      permissions: getPermissionsForRoles(roles),
      isActive:        (json['is_active'] as int? ?? 1) == 1,
      isEmailVerified: (json['email_verified'] as bool?) ?? true,
      phone:           json['phone'] as String?,
      createdAt:   json['created_at']  as String? ?? '',
    );
  }

  static List<UserRole> _rolesFromJson(dynamic raw) {
    if (raw is List) {
      return raw
          .map((r) => UserRole.fromApiName(r as String? ?? ''))
          .whereType<UserRole>()
          .toList();
    }
    return const [];
  }

  const User({
    required this.id,
    required this.name,
    this.firstName = '',
    this.lastName = '',
    required this.email,
    required this.department,
    required this.roles,
    required this.permissions,
    this.isActive = true,
    this.isEmailVerified = true,
    this.phone,
    required this.createdAt,
  });

  /// Check if user has a specific permission
  bool hasPermission(Permission permission) {
    return permissions.contains(permission);
  }

  /// True si l'utilisateur possède le rôle donné.
  bool hasRole(UserRole role) => roles.contains(role);

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
    String? firstName,
    String? lastName,
    String? email,
    String? department,
    List<UserRole>? roles,
    List<Permission>? permissions,
    bool? isActive,
    bool? isEmailVerified,
    String? phone,
    String? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      department: department ?? this.department,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
