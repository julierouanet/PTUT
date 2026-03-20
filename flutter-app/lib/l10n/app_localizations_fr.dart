// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Gestion des Equipements - Kabutare Hospital';

  @override
  String get hospitalName => 'Kabutare Hospital';

  @override
  String get hospitalSubtitle => 'Gestion Equipements';

  @override
  String get hospitalSubtitleLong => 'Gestion des Equipements';

  @override
  String get loadingData => 'Chargement des donnees...';

  @override
  String get navDashboard => 'Tableau de bord';

  @override
  String get navEquipment => 'Equipements';

  @override
  String get navIssueTracking => 'Suivi incidents';

  @override
  String get navReportIssue => 'Signaler';

  @override
  String get navTechnician => 'Technicien';

  @override
  String get navInventory => 'Inventaire';

  @override
  String get navReports => 'Rapports';

  @override
  String get navUsers => 'Utilisateurs';

  @override
  String get navSettings => 'Parametres';

  @override
  String get logout => 'Se deconnecter';

  @override
  String get accessDenied => 'Acces refuse';

  @override
  String get accessDeniedMessage =>
      'Vous n\'avez pas les permissions necessaires pour acceder a cette page.';

  @override
  String accessDeniedNav(String target) {
    return 'Acces refuse: vous n\'avez pas la permission d\'acceder a \"$target\"';
  }

  @override
  String get backToDashboard => 'Retour au tableau de bord';

  @override
  String get user => 'Utilisateur';

  @override
  String get commonAll => 'Tous';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonSearch => 'Rechercher...';

  @override
  String get commonError => 'Erreur';

  @override
  String get commonDetails => 'Details';

  @override
  String get commonReport => 'Signaler';

  @override
  String get commonActions => 'Actions';

  @override
  String get commonStatus => 'Statut';

  @override
  String get commonCategory => 'Categorie';

  @override
  String get commonDepartment => 'Departement';

  @override
  String get commonName => 'Nom';

  @override
  String get commonEmail => 'Email';

  @override
  String get commonRole => 'Role';

  @override
  String get commonDefault => 'Par defaut';

  @override
  String get commonAbbreviation => 'Abreviation';

  @override
  String get commonFillRequiredFields =>
      'Veuillez remplir les champs obligatoires';

  @override
  String get commonFillAllFields => 'Veuillez remplir tous les champs';

  @override
  String get commonIrreversible => 'Cette action est irreversible.';

  @override
  String get commonCreate => 'Creer';

  @override
  String get loginTitle => 'Connexion';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginEmailRequired => 'Email requis';

  @override
  String get loginPassword => 'Mot de passe';

  @override
  String get loginPasswordRequired => 'Mot de passe requis';

  @override
  String get loginSubmit => 'Se connecter';

  @override
  String get loginInvalidCredentials => 'Identifiants incorrects';

  @override
  String get dashboardTitle => 'Tableau de bord';

  @override
  String get dashboardSubtitle =>
      'Vue d\'ensemble de la gestion des equipements';

  @override
  String get dashboardViewEquipment => 'Voir les equipements';

  @override
  String get dashboardReportProblem => 'Signaler un probleme';

  @override
  String get dashboardViewIssues => 'Voir les incidents';

  @override
  String get dashboardTotal => 'Total';

  @override
  String get dashboardAvailable => 'Disponibles';

  @override
  String get dashboardMaintenance => 'Maintenance';

  @override
  String get dashboardOutOfService => 'Hors Service';

  @override
  String get dashboardEquipmentStatus => 'Statut des equipements';

  @override
  String get dashboardAvailableStatus => 'Disponible';

  @override
  String get dashboardInUse => 'En usage';

  @override
  String get dashboardInMaintenance => 'En maintenance';

  @override
  String get dashboardOutOfServiceStatus => 'Hors service';

  @override
  String get dashboardRecentIssues => 'Derniers incidents signales';

  @override
  String get dashboardNoIssues => 'Aucun incident en cours';

  @override
  String get dashboardViewAllIssues => 'Voir tous les incidents';

  @override
  String get dashboardUrgentAlerts => 'Alertes urgentes';

  @override
  String get dashboardNoAlerts => 'Aucune alerte urgente';

  @override
  String get dashboardCriticalFailure => 'Panne critique';

  @override
  String get dashboardOpenIssue => 'Incident ouvert';

  @override
  String get equipmentTitle => 'Liste des equipements';

  @override
  String get equipmentSubtitle => 'Gestion et suivi de tous les equipements';

  @override
  String get equipmentNew => 'Nouvel equipement';

  @override
  String get equipmentName => 'Nom de l\'equipement';

  @override
  String get equipmentSerialNumber => 'Numero de serie';

  @override
  String equipmentFound(int count) {
    return '$count equipement(s) trouve(s)';
  }

  @override
  String get equipmentEditTitle => 'Modifier l\'equipement';

  @override
  String get equipmentNewTitle => 'Nouvel equipement';

  @override
  String get equipmentNameLabel => 'Nom de l\'equipement *';

  @override
  String get equipmentNameHint => 'Ex: Scanner IRM Siemens';

  @override
  String get equipmentSerialLabel => 'Numero de serie *';

  @override
  String get equipmentSerialHint => 'Ex: SN-2023-001';

  @override
  String get equipmentDepartmentLabel => 'Departement *';

  @override
  String get equipmentCategoryLabel => 'Categorie *';

  @override
  String get equipmentSupplier => 'Fournisseur';

  @override
  String get equipmentSupplierHint => 'Ex: Siemens Healthineers';

  @override
  String get equipmentLocation => 'Localisation';

  @override
  String get equipmentLocationHint => 'Ex: Batiment A, Salle 101';

  @override
  String get equipmentModified => 'Equipement modifie';

  @override
  String get equipmentAdded => 'Equipement ajoute';

  @override
  String get equipmentSaveChanges => 'Enregistrer les modifications';

  @override
  String get equipmentAddButton => 'Ajouter l\'equipement';

  @override
  String get equipmentDeleteTitle => 'Supprimer l\'equipement';

  @override
  String equipmentDeleteConfirm(String name) {
    return 'Confirmer la suppression de \"$name\" ? Cette action est irreversible.';
  }

  @override
  String get equipmentDeleted => 'Equipement supprime';

  @override
  String get equipmentMaintenanceHistory => 'Historique de maintenance';

  @override
  String get equipmentReportProblem => 'Signaler un probleme';

  @override
  String get issuesTitle => 'Suivi des incidents';

  @override
  String get issuesSubtitle => 'Gerer et suivre les incidents des equipements';

  @override
  String get issuesOpen => 'Ouverts';

  @override
  String get issuesInProgress => 'En cours';

  @override
  String get issuesResolved => 'Resolus';

  @override
  String get issuesReport => 'Signaler un incident';

  @override
  String get issuesFilterByStatus => 'Filtrer par statut: ';

  @override
  String issuesCount(int count) {
    return '$count incident(s)';
  }

  @override
  String issuesIncidentId(String id) {
    return 'Incident #$id';
  }

  @override
  String get issuesEquipment => 'Equipement';

  @override
  String get issuesType => 'Type';

  @override
  String get issuesDescription => 'Description';

  @override
  String get issuesReportedBy => 'Signale par';

  @override
  String get issuesReportDate => 'Date de signalement';

  @override
  String get issuesAssignedTech => 'Technicien assigne';

  @override
  String get issuesDiagnosis => 'Diagnostic';

  @override
  String get issuesUpdate => 'Mettre a jour';

  @override
  String issuesReportedByDate(String reporter, String date) {
    return 'Signale par $reporter • $date';
  }

  @override
  String get issueFormTitle => 'Signaler un probleme';

  @override
  String get issueFormSubtitle =>
      'Remplissez le formulaire pour signaler un probleme d\'equipement';

  @override
  String get issueFormEquipment => 'Equipement concerne *';

  @override
  String get issueFormSelectEquipment => 'Selectionnez un equipement';

  @override
  String get issueFormProblemType => 'Type de probleme *';

  @override
  String get issueFormBreakdown => 'Panne';

  @override
  String get issueFormMalfunction => 'Dysfonctionnement';

  @override
  String get issueFormWear => 'Usure';

  @override
  String get issueFormAbnormalNoise => 'Bruit anormal';

  @override
  String get issueFormLeak => 'Fuite';

  @override
  String get issueFormOther => 'Autre';

  @override
  String get issueFormDescription => 'Description du probleme *';

  @override
  String get issueFormDescriptionHint => 'Decrivez le probleme en detail...';

  @override
  String get issueFormDescriptionRequired => 'La description est obligatoire';

  @override
  String get issueFormDescriptionMinLength =>
      'La description doit contenir au moins 10 caracteres';

  @override
  String get issueFormPhotos => 'Photos (optionnel)';

  @override
  String issueFormPhotosHint(int max) {
    return 'Ajoutez jusqu\'a $max photos pour illustrer le probleme';
  }

  @override
  String get issueFormAddPhoto => 'Ajouter';

  @override
  String issueFormMaxPhotos(int max) {
    return 'Maximum $max photos autorisees';
  }

  @override
  String get issueFormYourName => 'Votre nom *';

  @override
  String get issueFormYourNameHint => 'Ex: Dr. Martin';

  @override
  String get issueFormYourNameRequired => 'Votre nom est obligatoire';

  @override
  String get issueFormSubmit => 'Soumettre le signalement';

  @override
  String issueFormSubmitWithPhotos(int count) {
    return 'Soumettre le signalement ($count photo(s))';
  }

  @override
  String get issueFormSuccess => 'Signalement envoye !';

  @override
  String issueFormSuccessWithPhotos(int count) {
    return 'Signalement envoye ! ($count photo(s))';
  }

  @override
  String issueFormError(String error) {
    return 'Erreur lors de l\'envoi: $error';
  }

  @override
  String get techTitle => 'Mise a jour technicien';

  @override
  String get techSubtitle => 'Mettre a jour le statut de reparation';

  @override
  String get techNoIssues => 'Aucun incident en cours';

  @override
  String get techAllResolved => 'Tous les incidents ont ete resolus';

  @override
  String get techSelectIssue => 'Incident a mettre a jour';

  @override
  String get techSelectIssueHint => 'Selectionnez un incident';

  @override
  String techReportedByDate(String reporter, String date) {
    return 'Signale par $reporter le $date';
  }

  @override
  String get techRepairStatus => 'Statut de reparation';

  @override
  String get techDiagnosisInProgress => 'Diagnostic en cours';

  @override
  String get techPartsOrdered => 'Pieces commandees';

  @override
  String get techRepairInProgress => 'Reparation en cours';

  @override
  String get techTestInProgress => 'Test en cours';

  @override
  String get techRepaired => 'Repare';

  @override
  String get techDiagnosis => 'Diagnostic';

  @override
  String get techDiagnosisHint => 'Decrivez le diagnostic...';

  @override
  String get techActionsTaken => 'Actions effectuees';

  @override
  String get techActionsHint => 'Decrivez les actions effectuees...';

  @override
  String get techPartsReplaced => 'Pieces remplacees';

  @override
  String get techPartsHint => 'Ex: Capteur O2, Pompe a vide...';

  @override
  String get techSave => 'Sauvegarder';

  @override
  String get techMarkResolved => 'Marquer resolu';

  @override
  String get techProgressSaved => 'Progression sauvegardee';

  @override
  String get techIssueResolved => 'Incident marque comme resolu !';

  @override
  String get inventoryTitle => 'Inventaire';

  @override
  String get inventorySubtitle => 'Gestion des stocks de consommables';

  @override
  String get inventoryNewItem => 'Nouvel article';

  @override
  String get inventoryCriticalStock => 'Attention: Stock critique';

  @override
  String inventoryOutOfStockCount(int count) {
    return '$count article(s) en rupture';
  }

  @override
  String inventoryLowStockCount(int count) {
    return '$count article(s) en stock bas';
  }

  @override
  String get inventoryFilter => 'Filtrer: ';

  @override
  String get inventoryMedicalConsumable => 'Consommable medical';

  @override
  String get inventoryHygiene => 'Hygiene';

  @override
  String get inventoryOffice => 'Bureautique';

  @override
  String inventoryItemCount(int count) {
    return '$count articles';
  }

  @override
  String get inventoryItem => 'Article';

  @override
  String get inventoryCurrentStock => 'Stock actuel';

  @override
  String get inventoryMinStock => 'Stock min';

  @override
  String get inventoryUnit => 'Unite';

  @override
  String get inventoryLastRestocked => 'Dernier reappro';

  @override
  String get inventoryEditItem => 'Modifier l\'article';

  @override
  String get inventoryNewItemTitle => 'Nouvel article';

  @override
  String get inventoryNameLabel => 'Nom *';

  @override
  String get inventoryCategoryLabel => 'Categorie *';

  @override
  String get inventoryCurrentStockLabel => 'Stock actuel *';

  @override
  String get inventoryMinStockLabel => 'Stock minimum *';

  @override
  String get inventoryUnitLabel => 'Unite (ex: boites) *';

  @override
  String get inventoryItemModified => 'Article modifie';

  @override
  String get inventoryItemAdded => 'Article ajoute';

  @override
  String get inventoryDeleteItem => 'Supprimer l\'article';

  @override
  String inventoryDeleteConfirm(String name) {
    return 'Supprimer \"$name\" de l\'inventaire ?';
  }

  @override
  String get inventoryItemDeleted => 'Article supprime';

  @override
  String get reportsTitle => 'Rapports et Analyses';

  @override
  String get reportsSubtitle => 'Vue d\'ensemble des statistiques';

  @override
  String get reportsExport => 'Exporter';

  @override
  String get reportsTotalEquipment => 'Total equipements';

  @override
  String get reportsAvailabilityRate => 'Taux disponibilite';

  @override
  String get reportsTotalIssues => 'Total incidents';

  @override
  String get reportsResolvedIssues => 'Incidents resolus';

  @override
  String get reportsStatusBreakdown => 'Repartition par statut';

  @override
  String get reportsAvailable => 'Disponible';

  @override
  String get reportsInUse => 'En usage';

  @override
  String get reportsInMaintenance => 'En maintenance';

  @override
  String get reportsOutOfService => 'Hors service';

  @override
  String get reportsByDepartment => 'Equipements par departement';

  @override
  String get reportsByCategory => 'Equipements par categorie';

  @override
  String get reportsIssueStats => 'Statistiques des incidents';

  @override
  String get reportsExportData => 'Exporter les donnees';

  @override
  String get reportsExportExcel => 'Exporter en Excel';

  @override
  String get reportsExportPDF => 'Exporter en PDF';

  @override
  String get reportsExportExcelProgress => 'Export Excel en cours...';

  @override
  String get reportsExportPDFProgress => 'Export PDF en cours...';

  @override
  String get reportsOpenIssues => 'Ouverts';

  @override
  String get reportsInProgressIssues => 'En cours';

  @override
  String get reportsResolvedIssuesLabel => 'Resolus';

  @override
  String get usersTitle => 'Gestion des utilisateurs';

  @override
  String get usersSubtitle => 'Gerer les comptes et les roles des utilisateurs';

  @override
  String get usersNew => 'Nouvel utilisateur';

  @override
  String get usersTotal => 'Total';

  @override
  String get usersAdmins => 'Admins';

  @override
  String get usersSupervisors => 'Superviseurs';

  @override
  String get usersTechnicians => 'Techniciens';

  @override
  String get usersStaff => 'Personnel';

  @override
  String get usersSearchHint => 'Rechercher par nom ou email...';

  @override
  String get usersFilterByRole => 'Filtrer par role';

  @override
  String get usersUser => 'Utilisateur';

  @override
  String get usersPermissions => 'Permissions';

  @override
  String get usersEditTitle => 'Modifier utilisateur';

  @override
  String get usersNewTitle => 'Nouvel utilisateur';

  @override
  String get usersFullName => 'Nom complet *';

  @override
  String get usersEmailLabel => 'Email *';

  @override
  String get usersNewPassword =>
      'Nouveau mot de passe (laisser vide = inchange)';

  @override
  String get usersPasswordLabel => 'Mot de passe *';

  @override
  String get usersPhone => 'Telephone';

  @override
  String get usersModified => 'Utilisateur modifie';

  @override
  String get usersCreated => 'Utilisateur cree';

  @override
  String usersPermissionsTitle(String name) {
    return 'Permissions — $name';
  }

  @override
  String get usersActivePermissions => 'Permissions actives:';

  @override
  String get usersAccountActivated => 'Compte active';

  @override
  String get usersAccountDeactivated => 'Compte desactive';

  @override
  String get usersDeleteTitle => 'Supprimer l\'utilisateur';

  @override
  String usersDeleteConfirm(String name) {
    return 'Supprimer le compte de \"$name\" ? Cette action est irreversible.';
  }

  @override
  String get usersDeleted => 'Utilisateur supprime';

  @override
  String get usersActive => 'Actif';

  @override
  String get usersInactive => 'Inactif';

  @override
  String get usersDisable => 'Desactiver';

  @override
  String get usersEnable => 'Activer';

  @override
  String get settingsTitle => 'Parametres';

  @override
  String get settingsSubtitle =>
      'Gerer les departements et categories d\'equipements';

  @override
  String settingsDepartmentsTab(int count) {
    return 'Departements ($count)';
  }

  @override
  String settingsCategoriesTab(int count) {
    return 'Categories ($count)';
  }

  @override
  String get settingsNewDepartment => 'Nouveau departement';

  @override
  String get settingsEditDepartment => 'Modifier departement';

  @override
  String get settingsDepartmentName => 'Nom du departement';

  @override
  String get settingsDepartmentNameHint => 'Ex: Cardiologie';

  @override
  String get settingsShortName => 'Nom abrege';

  @override
  String get settingsShortNameHint => 'Ex: Cardio';

  @override
  String get settingsDepartmentModified => 'Departement modifie';

  @override
  String get settingsDepartmentAdded => 'Departement ajoute';

  @override
  String get settingsNewCategory => 'Nouvelle categorie';

  @override
  String get settingsEditCategory => 'Modifier categorie';

  @override
  String get settingsCategoryName => 'Nom de la categorie';

  @override
  String get settingsCategoryNameHint => 'Ex: Equipement radiologique';

  @override
  String get settingsCategoryShortHint => 'Ex: Radio';

  @override
  String get settingsCategoryModified => 'Categorie modifiee';

  @override
  String get settingsCategoryAdded => 'Categorie ajoutee';

  @override
  String get settingsDeleteDepartment => 'Supprimer departement';

  @override
  String get settingsDeleteCategory => 'Supprimer categorie';

  @override
  String settingsDeleteConfirm(String name) {
    return 'Etes-vous sur de vouloir supprimer \"$name\" ?\n\nCette action est irreversible.';
  }

  @override
  String settingsDeleted(String type) {
    return '$type supprime';
  }

  @override
  String settingsDeletedFeminine(String type) {
    return '$type supprimee';
  }

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSubtitle => 'Changer la langue de l\'application';

  @override
  String get settingsFrench => 'Francais';

  @override
  String get settingsEnglish => 'English';
}
