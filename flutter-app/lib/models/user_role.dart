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
