/// User role enumeration.
///
/// Le rôle `technician` générique est conservé pour la rétro-compat de lecture
/// (anciens JWT et logs) mais n'est plus assignable : les trois rôles spécialisés
/// `technicianBiomedical` / `technicianIt` / `technicianInfra` le remplacent.
enum UserRole {
  hospitalStaff,
  supervisor,
  technician,
  technicianBiomedical,
  technicianIt,
  technicianInfra,
  admin;

  /// Nom utilisé côté API (snake_case, identique à `roles.name` en base).
  String get apiName {
    switch (this) {
      case UserRole.hospitalStaff:        return 'hospitalStaff';
      case UserRole.supervisor:           return 'supervisor';
      case UserRole.technician:           return 'technician';
      case UserRole.technicianBiomedical: return 'technician_biomedical';
      case UserRole.technicianIt:         return 'technician_it';
      case UserRole.technicianInfra:      return 'technician_infra';
      case UserRole.admin:                return 'admin';
    }
  }

  /// Construit un UserRole à partir du nom renvoyé par l'API.
  /// Retourne null si la valeur n'est pas reconnue.
  static UserRole? fromApiName(String name) {
    switch (name) {
      case 'hospitalStaff':         return UserRole.hospitalStaff;
      case 'supervisor':            return UserRole.supervisor;
      case 'technician':            return UserRole.technician;
      case 'technician_biomedical': return UserRole.technicianBiomedical;
      case 'technician_it':         return UserRole.technicianIt;
      case 'technician_infra':      return UserRole.technicianInfra;
      case 'admin':                 return UserRole.admin;
      default:                      return null;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.hospitalStaff:        return 'Personnel hospitalier';
      case UserRole.supervisor:           return 'Superviseur';
      case UserRole.technician:           return 'Technicien';
      case UserRole.technicianBiomedical: return 'Tech. biomédical';
      case UserRole.technicianIt:         return 'Tech. IT';
      case UserRole.technicianInfra:      return 'Tech. infrastructure';
      case UserRole.admin:                return 'Administrateur ICT';
    }
  }

  /// Localized display name — use this in the UI
  String localizedName(dynamic l10n) {
    switch (this) {
      case UserRole.hospitalStaff:        return l10n.roleHospitalStaff as String;
      case UserRole.supervisor:           return l10n.roleSupervisor as String;
      case UserRole.technician:           return l10n.roleTechnician as String;
      case UserRole.technicianBiomedical: return l10n.roleTechnicianBiomedical as String;
      case UserRole.technicianIt:         return l10n.roleTechnicianIt as String;
      case UserRole.technicianInfra:      return l10n.roleTechnicianInfra as String;
      case UserRole.admin:                return l10n.roleAdmin as String;
    }
  }

  String get description {
    switch (this) {
      case UserRole.hospitalStaff:        return 'Médecins, infirmiers, techniciens de laboratoire';
      case UserRole.supervisor:           return 'Responsables de département';
      case UserRole.technician:           return 'Rôle générique déprécié (utiliser les rôles spécialisés)';
      case UserRole.technicianBiomedical: return 'Maintenance des équipements biomédicaux';
      case UserRole.technicianIt:         return 'Maintenance informatique et réseau';
      case UserRole.technicianInfra:      return 'Maintenance bâtiment et infrastructure';
      case UserRole.admin:                return 'Service informatique';
    }
  }
}

/// Rôles directement assignables via l'interface (le `technician` générique est exclu).
const List<UserRole> kAssignableRoles = [
  UserRole.hospitalStaff,
  UserRole.supervisor,
  UserRole.technicianBiomedical,
  UserRole.technicianIt,
  UserRole.technicianInfra,
  UserRole.admin,
];

/// Permission enumeration
enum Permission {
  // All users
  viewEquipment,
  reportIssue,
  trackIssues,

  // Supervisor
  approveRequests,
  assignTasks,

  // Technician
  updateRepairs,
  registerParts,
  viewInterventionDocuments,

  // Admin only
  manageEquipment,
  manageUsers,
  manageDepartments,
  manageCategories,
  generateReports,
  viewInventory,
  changeDepartment,
  manageFeatures,
  manageBackups;

  String get displayName {
    switch (this) {
      case Permission.viewEquipment:
        return 'Consulter les équipements';
      case Permission.reportIssue:
        return 'Signaler un problème';
      case Permission.trackIssues:
        return 'Suivre les demandes';
      case Permission.approveRequests:
        return 'Approuver les demandes';
      case Permission.assignTasks:
        return 'Assigner les tâches';
      case Permission.updateRepairs:
        return 'Mettre à jour les réparations';
      case Permission.registerParts:
        return 'Enregistrer les pièces';
      case Permission.viewInterventionDocuments:
        return 'Consulter les documents d\'intervention';
      case Permission.manageEquipment:
        return 'Gérer les équipements';
      case Permission.manageUsers:
        return 'Gérer les utilisateurs';
      case Permission.manageDepartments:
        return 'Gérer les départements';
      case Permission.manageCategories:
        return 'Gérer les catégories';
      case Permission.generateReports:
        return 'Générer des rapports';
      case Permission.viewInventory:
        return 'Consulter l\'inventaire';
      case Permission.changeDepartment:
        return 'Changer son département directement';
      case Permission.manageFeatures:
        return 'Gérer les feature flags';
      case Permission.manageBackups:
        return 'Gérer les sauvegardes';
    }
  }

  /// Localized display name — use this in the UI
  String localizedName(dynamic l10n) {
    switch (this) {
      case Permission.viewEquipment:     return l10n.permViewEquipment as String;
      case Permission.reportIssue:       return l10n.permReportIssue as String;
      case Permission.trackIssues:       return l10n.permTrackIssues as String;
      case Permission.approveRequests:   return l10n.permApproveRequests as String;
      case Permission.assignTasks:       return l10n.permAssignTasks as String;
      case Permission.updateRepairs:     return l10n.permUpdateRepairs as String;
      case Permission.registerParts:     return l10n.permRegisterParts as String;
      case Permission.viewInterventionDocuments: return l10n.permViewInterventionDocuments as String;
      case Permission.manageEquipment:   return l10n.permManageEquipment as String;
      case Permission.manageUsers:       return l10n.permManageUsers as String;
      case Permission.manageDepartments: return l10n.permManageDepartments as String;
      case Permission.manageCategories:  return l10n.permManageCategories as String;
      case Permission.generateReports:   return l10n.permGenerateReports as String;
      case Permission.viewInventory:     return l10n.permViewInventory as String;
      case Permission.changeDepartment:  return l10n.permChangeDepartment as String;
      case Permission.manageFeatures:    return l10n.permManageFeatures as String;
      case Permission.manageBackups:     return l10n.permManageBackups  as String;
    }
  }
}

/// Permissions par défaut pour un rôle donné.
List<Permission> getPermissionsForRole(UserRole role) {
  const techPerms = [
    Permission.viewEquipment,
    Permission.reportIssue,
    Permission.trackIssues,
    Permission.updateRepairs,
    Permission.registerParts,
    Permission.approveRequests,
    Permission.viewInterventionDocuments,
  ];
  switch (role) {
    case UserRole.hospitalStaff:
      return const [
        Permission.viewEquipment,
        Permission.reportIssue,
        Permission.trackIssues,
      ];
    case UserRole.supervisor:
      return const [
        Permission.viewEquipment,
        Permission.reportIssue,
        Permission.trackIssues,
        Permission.approveRequests,
        Permission.assignTasks,
        Permission.viewInterventionDocuments,
      ];
    case UserRole.technician:
    case UserRole.technicianBiomedical:
    case UserRole.technicianIt:
    case UserRole.technicianInfra:
      return techPerms;
    case UserRole.admin:
      return Permission.values; // All permissions
  }
}

/// Union des permissions de plusieurs rôles (sans doublons).
List<Permission> getPermissionsForRoles(Iterable<UserRole> roles) {
  final set = <Permission>{};
  for (final r in roles) {
    set.addAll(getPermissionsForRole(r));
  }
  return set.toList();
}
