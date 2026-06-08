/// Données de détail d'un rôle — distinct de l'enum UserRole qui reste inchangé.
/// Contient la hiérarchie, les permissions SQLite et la configuration sidebar.
class RoleDetailConfig {
  final String name;
  final String? displayName;
  final String? parentRole;
  final List<String> childRoles;
  final List<String> permissions;
  final List<String> sidebarOrder;
  final String? inheritedFrom;

  const RoleDetailConfig({
    required this.name,
    this.displayName,
    this.parentRole,
    this.childRoles    = const [],
    this.permissions   = const [],
    this.sidebarOrder  = const [],
    this.inheritedFrom,
  });

  RoleDetailConfig copyWith({
    List<String>? permissions,
    List<String>? sidebarOrder,
  }) =>
      RoleDetailConfig(
        name:          name,
        displayName:   displayName,
        parentRole:    parentRole,
        childRoles:    childRoles,
        permissions:   permissions   ?? this.permissions,
        sidebarOrder:  sidebarOrder  ?? this.sidebarOrder,
        inheritedFrom: inheritedFrom,
      );
}

/// Résumé d'un utilisateur dans l'onglet Utilisateurs.
class RoleUserSummary {
  final String id;
  final String name;
  final String email;
  final String username;

  const RoleUserSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
  });

  factory RoleUserSummary.fromJson(Map<String, dynamic> j) => RoleUserSummary(
        id:       j['id']       as String? ?? '',
        name:     j['name']     as String? ?? '',
        email:    j['email']    as String? ?? '',
        username: j['username'] as String? ?? '',
      );
}
