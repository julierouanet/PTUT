/// User role enumeration
enum UserRole {
  hospitalStaff,
  supervisor,
  technician,
  admin;

  String get displayName {
    switch (this) {
      case UserRole.hospitalStaff:
        return 'Personnel hospitalier';
      case UserRole.supervisor:
        return 'Superviseur';
      case UserRole.technician:
        return 'Technicien';
      case UserRole.admin:
        return 'Administrateur ICT';
    }
  }

  /// Localized display name — use this in the UI
  String localizedName(dynamic l10n) {
    switch (this) {
      case UserRole.hospitalStaff:
        return l10n.roleHospitalStaff as String;
      case UserRole.supervisor:
        return l10n.roleSupervisor as String;
      case UserRole.technician:
        return l10n.roleTechnician as String;
      case UserRole.admin:
        return l10n.roleAdmin as String;
    }
  }

  String get description {
    switch (this) {
      case UserRole.hospitalStaff:
        return 'Médecins, infirmiers, techniciens de laboratoire';
      case UserRole.supervisor:
        return 'Responsables de département';
      case UserRole.technician:
        return 'Équipe technique de maintenance';
      case UserRole.admin:
        return 'Service informatique';
    }
  }
}

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
  
  // Admin only
  manageEquipment,
  manageUsers,
  manageDepartments,
  manageCategories,
  generateReports,
  viewInventory,
  changeDepartment;

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
      case Permission.manageEquipment:   return l10n.permManageEquipment as String;
      case Permission.manageUsers:       return l10n.permManageUsers as String;
      case Permission.manageDepartments: return l10n.permManageDepartments as String;
      case Permission.manageCategories:  return l10n.permManageCategories as String;
      case Permission.generateReports:   return l10n.permGenerateReports as String;
      case Permission.viewInventory:     return l10n.permViewInventory as String;
      case Permission.changeDepartment:  return l10n.permChangeDepartment as String;
    }
  }
}

/// Get default permissions for a role
List<Permission> getPermissionsForRole(UserRole role) {
  switch (role) {
    case UserRole.hospitalStaff:
      return [
        Permission.viewEquipment,
        Permission.reportIssue,
        Permission.trackIssues,
      ];
    case UserRole.supervisor:
      return [
        Permission.viewEquipment,
        Permission.reportIssue,
        Permission.trackIssues,
        Permission.approveRequests,
        Permission.assignTasks,
      ];
    case UserRole.technician:
      return [
        Permission.viewEquipment,
        Permission.reportIssue,
        Permission.trackIssues,
        Permission.updateRepairs,
        Permission.registerParts,
      ];
    case UserRole.admin:
      return Permission.values; // All permissions
  }
}
