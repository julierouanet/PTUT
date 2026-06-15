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
  String get loadingData => 'Chargement des données...';

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
  String get navSettings => 'Admin';

  @override
  String get navLogs => 'Journaux';

  @override
  String get navLogsShort => 'Logs';

  @override
  String get navDashboardShort => 'Accueil';

  @override
  String get navEquipmentShort => 'Equip.';

  @override
  String get navIssueTrackingShort => 'Incidents';

  @override
  String get navReportIssueShort => 'Signaler';

  @override
  String get navTechnicianShort => 'Technicien';

  @override
  String get navInventoryShort => 'Inventaire';

  @override
  String get navReportsShort => 'Rapports';

  @override
  String get navUsersShort => 'Usagers';

  @override
  String get navSettingsShort => 'Admin';

  @override
  String get tooltipBack => 'Retour';

  @override
  String get tooltipMenu => 'Menu';

  @override
  String get tooltipAccountSettings => 'Parametres du compte';

  @override
  String get tooltipNotifications => 'Notifications';

  @override
  String get logout => 'Se deconnecter';

  @override
  String get logoutConfirmTitle => 'Deconnexion';

  @override
  String get logoutConfirmMessage =>
      'Etes-vous sur de vouloir vous deconnecter ?';

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
  String get commonDetails => 'Détails';

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
  String get commonConfirm => 'Confirmer';

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
  String get dashboardOperational => 'Operationnels';

  @override
  String get dashboardMaintenance => 'Maintenance';

  @override
  String get dashboardOutOfService => 'Hors Service';

  @override
  String get dashboardEquipmentStatus => 'Statut des equipements';

  @override
  String get dashboardOperationalStatus => 'Operationnel';

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
  String get issuesApproved => 'En cours';

  @override
  String get issuesTitle => 'Suivi des incidents';

  @override
  String get issuesSubtitle => 'Gerer et suivre les incidents des equipements';

  @override
  String get issuesOpen => 'Signalés';

  @override
  String get issuesInProgress => 'En attente';

  @override
  String get issuesResolved => 'Terminés';

  @override
  String get issuesReport => 'Signaler un incident';

  @override
  String get issuesFilterByStatus => 'Filtrer par statut: ';

  @override
  String issuesCount(int count) {
    return '$count incident(s)';
  }

  @override
  String get issuesMyIssues => 'Mes incidents';

  @override
  String get issuesMyIssuesSubtitle => 'Incidents que vous avez soumis';

  @override
  String get issuesNoMyIssues => 'Vous n\'avez pas encore signale d\'incident';

  @override
  String get issuesDeptIssues => 'Incidents de mon departement';

  @override
  String issuesDeptIssuesSubtitle(String dept) {
    return 'Departement: $dept';
  }

  @override
  String get issuesNoDeptIssues =>
      'Aucun incident signale dans votre departement';

  @override
  String issuesAndMore(int count) {
    return '... et $count autre(s)';
  }

  @override
  String get issuesAllIssues => 'Tous les incidents';

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
  String get issueFormLeaveTitle => 'Quitter le formulaire ?';

  @override
  String get issueFormLeaveMessage =>
      'Des informations ont ete saisies. Si vous quittez maintenant, elles seront perdues.';

  @override
  String get issueFormLeaveConfirm => 'Quitter';

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
  String get reportsOperational => 'Operationnel';

  @override
  String get reportsInMaintenance => 'En maintenance';

  @override
  String get reportsOutOfService => 'Hors service';

  @override
  String get reportsByDepartment => 'Equipements par departement';

  @override
  String get reportsByCategory => 'Equipements par categorie';

  @override
  String get seeMore => 'Voir plus';

  @override
  String get seeLess => 'Voir moins';

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

  @override
  String get settingsAccountSection => 'Parametres du compte';

  @override
  String get settingsAccountSubtitle =>
      'Gerez vos informations personnelles et preferences';

  @override
  String get settingsPersonalInfo => 'Informations personnelles';

  @override
  String get settingsPersonalInfoSubtitle =>
      'Modifier votre nom, email et telephone';

  @override
  String get settingsChangePassword => 'Changer le mot de passe';

  @override
  String get settingsChangePasswordSubtitle =>
      'Modifier votre mot de passe de connexion';

  @override
  String get settingsNewPassword => 'Nouveau mot de passe';

  @override
  String get settingsConfirmPassword => 'Confirmer le nouveau mot de passe';

  @override
  String get settingsPasswordMismatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get settingsPasswordMinLength => 'Minimum 6 caracteres requis';

  @override
  String get settingsPasswordChanged => 'Mot de passe modifie avec succes';

  @override
  String get settingsProfileUpdated => 'Profil mis a jour';

  @override
  String get settingsAdminSection => 'Administration';

  @override
  String get settingsAdminSubtitle =>
      'Gerer les departements et categories d\'equipements';

  @override
  String get settingsFullName => 'Nom complet';

  @override
  String get settingsFullNameHint => 'Ex: Dr. Martin';

  @override
  String get settingsPhoneLabel => 'Telephone';

  @override
  String get settingsPhoneHint => 'Ex: +250 788 123 456';

  @override
  String get settingsDepartmentHint => 'Ex: Cardiologie';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifMarkAllRead => 'Tout marquer comme lu';

  @override
  String get notifEmpty => 'Aucune notification';

  @override
  String get notifNewIssue => 'Nouvel incident signale';

  @override
  String notifNewIssueBody(String equipment, String dept) {
    return 'Incident sur $equipment ($dept)';
  }

  @override
  String get notifInProgress => 'Votre incident est pris en charge';

  @override
  String notifInProgressBody(String equipment) {
    return 'L\'incident sur $equipment est en cours de traitement';
  }

  @override
  String get notifResolved => 'Votre incident a ete resolu';

  @override
  String notifResolvedBody(String equipment) {
    return 'L\'incident sur $equipment est marque comme resolu';
  }

  @override
  String get notifTimeJustNow => 'A l\'instant';

  @override
  String notifTimeMinutes(int n) {
    return 'Il y a $n min';
  }

  @override
  String notifTimeHours(int n) {
    return 'Il y a $n h';
  }

  @override
  String notifTimeDays(int n) {
    return 'Il y a $n j';
  }

  @override
  String get hubSelectModule => 'Selectionnez un module';

  @override
  String get hubSelectModuleSubtitle =>
      'Choisissez le module auquel vous souhaitez acceder';

  @override
  String hubOpenModule(String title) {
    return 'Ouvrir $title';
  }

  @override
  String get issueTrackingTab => 'Suivi des incidents';

  @override
  String get issueValidationTab => 'A valider';

  @override
  String get issueValidationTitle => 'Incidents a valider';

  @override
  String get issueValidationSubtitleAll =>
      'Tous les incidents ouverts en attente de validation';

  @override
  String issueValidationSubtitleDept(String dept) {
    return 'Incidents ouverts du departement \"$dept\" en attente de validation';
  }

  @override
  String issueValidationOpenCount(int count) {
    return '$count incident(s) ouvert(s)';
  }

  @override
  String get issueValidationNone => 'Aucun incident ouvert a valider';

  @override
  String get issueValidationDetails => 'Details';

  @override
  String get issueValidationValidate => 'Valider';

  @override
  String get issueValidationConfirmTitle => 'Valider l\'incident';

  @override
  String get issueValidationConfirmContent =>
      'Confirmer la validation de l\'incident sur :';

  @override
  String get issueValidationUrgencyLabel => 'Niveau d\'urgence :';

  @override
  String get issueValidationConfirmMessage =>
      'L\'incident passera au statut \"Approuve\" et sera assigne a l\'equipe technique.';

  @override
  String issueValidationSuccess(String equipment) {
    return 'Incident sur \"$equipment\" valide avec succes.';
  }

  @override
  String issueValidationError(String error) {
    return 'Erreur lors de la validation : $error';
  }

  @override
  String issueValidationSignaledBy(String reporter, String date) {
    return 'Signale par $reporter • $date';
  }

  @override
  String get issueUrgencyLabel => 'Niveau d\'urgence';

  @override
  String get issueValidationGroupLabel => 'Equipe technique assignee :';

  @override
  String get issueValidationGroupBiomedical => 'Biomedical';

  @override
  String get issueValidationGroupIT => 'IT';

  @override
  String get issueValidationGroupInfrastructure => 'Infrastructure';

  @override
  String get issueValidationGroupNoChange => 'Garder l\'equipe actuelle';

  @override
  String get issueValidationRedirectLabel => 'Rediriger vers une autre equipe';

  @override
  String get settingsMenuOrder => 'Ordre du menu';

  @override
  String get settingsMenuOrderRole => 'Configurer pour le role :';

  @override
  String get settingsMenuOrderHint =>
      'Faites glisser les elements pour changer leur ordre dans la barre de navigation.';

  @override
  String get settingsMenuOrderReset => 'Reinitialiser';

  @override
  String get settingsMenuOrderResetDone =>
      'Ordre par defaut restaure (non encore sauvegarde)';

  @override
  String get settingsMenuOrderSave => 'Sauvegarder';

  @override
  String get settingsMenuOrderSaved => 'Ordre du menu sauvegarde';

  @override
  String get backToModules => '← Modules';

  @override
  String get backToModulesLabel => 'Retour aux modules';

  @override
  String get equipmentRevisionColumn => 'Revision';

  @override
  String get accountDepartmentChange => 'Changer de departement';

  @override
  String get accountDepartmentChangeTitle => 'Demande de changement';

  @override
  String get accountDepartmentChangeSubtitle =>
      'Votre demande sera soumise a un administrateur pour validation.';

  @override
  String get accountDepartmentCurrent => 'Actuel : ';

  @override
  String get accountDepartmentNew => 'Nouveau departement';

  @override
  String get accountDepartmentRequestSent =>
      'Demande envoyee - en attente de validation admin';

  @override
  String get accountDepartmentRequestSend => 'Envoyer la demande';

  @override
  String get commonApiError => 'Une erreur est survenue. Veuillez reessayer.';

  @override
  String get commonNetworkError =>
      'Impossible de se connecter au serveur. Verifiez votre connexion.';

  @override
  String get commonDeleteError =>
      'Impossible de supprimer cet element. Veuillez reessayer.';

  @override
  String get commonSaveError =>
      'Impossible d\'enregistrer. Veuillez reessayer.';

  @override
  String get greetingMorning => 'Bonjour';

  @override
  String get greetingAfternoon => 'Bon après-midi';

  @override
  String get greetingEvening => 'Bonsoir';

  @override
  String get hubEquipmentTitle => 'Équipement';

  @override
  String get hubEquipmentDesc =>
      'Gérez les équipements médicaux, suivez les incidents et planifiez les interventions.';

  @override
  String get hubSettingsTitle => 'Paramètres';

  @override
  String get hubSettingsDesc =>
      'Administrez les utilisateurs, configurez le système et consultez les journaux.';

  @override
  String get hubInventoryTitle => 'Inventaire';

  @override
  String get hubInventoryDesc =>
      'Consultez et gérez les stocks de fournitures médicales et consommables.';

  @override
  String get hubKpiTitle => 'Tableau de bord global';

  @override
  String get hubKpiSubtitle => 'Indicateurs clés en temps réel';

  @override
  String get hubKpiCriticalUrgentLabel => 'Incidents critiques / urgents';

  @override
  String get hubKpiOpenIssues => 'incidents ouverts';

  @override
  String get hubKpiStockAlertsLabel => 'Alertes de stock';

  @override
  String get hubKpiStockAlertsSubtitle => 'ruptures ou niveaux faibles';

  @override
  String get hubKpiOutOfServiceLabel => 'Hors service';

  @override
  String get hubKpiOutOfServiceSubtitle => 'équipements hors service';

  @override
  String get hubKpiNoAlert => 'Aucune alerte';

  @override
  String get hubReportUrgentButton => 'Signaler un incident';

  @override
  String get hubReportUrgentTooltip => 'Signaler un incident immédiatement';

  @override
  String get hubQuickAccessTitle => 'Accès rapide aux modules';

  @override
  String get equipStatusOperational => 'Opérationnel';

  @override
  String get equipStatusInMaintenance => 'En maintenance';

  @override
  String get equipStatusOutOfService => 'Hors service';

  @override
  String get equipStatusToBeDisposal => 'À éliminer';

  @override
  String get equipStatusDisposed => 'Éliminé';

  @override
  String get equipmentManufacturer => 'Fabricant';

  @override
  String get equipmentManufacturerHint => 'Ex : Philips Healthcare';

  @override
  String get equipmentModel => 'Modèle';

  @override
  String get equipmentModelHint => 'Ex : IntelliVue MX450';

  @override
  String get equipmentManufYear => 'Année de fabrication';

  @override
  String get equipmentManufYearHint => 'Ex : 2023';

  @override
  String get equipmentInstallDate => 'Date d\'installation';

  @override
  String get equipmentInstallDateHint => 'Sélectionner une date (optionnel)';

  @override
  String get equipmentTags => 'Étiquettes (tags)';

  @override
  String get equipmentNoTags => 'Aucune étiquette';

  @override
  String get equipmentInternalId => 'Identifiant interne';

  @override
  String get equipmentCreatedAt => 'Créé le';

  @override
  String get equipmentUpdatedAt => 'Modifié le';

  @override
  String get equipmentNextRevision => 'Prochaine révision';

  @override
  String get equipmentFutureMaintenance => 'Maintenance planifiée';

  @override
  String get lastPreventiveDate => 'Dernière maintenance préventive';

  @override
  String get nextPreventiveDate => 'Prochaine maintenance préventive';

  @override
  String get preventiveAlert => 'Maintenance préventive à prévoir';

  @override
  String get preventiveAlertOverdue => 'Maintenance préventive en retard';

  @override
  String get preventiveAlertSoon => 'Maintenance préventive sous 7 jours';

  @override
  String get preventiveSection => 'Maintenance préventive';

  @override
  String get equipmentSystemInfoSection => 'Informations système';

  @override
  String get equipmentInventorySection => 'Inventaire';

  @override
  String get equipmentGeneralSection => 'Informations générales';

  @override
  String get issueStatusReported => 'Signalé';

  @override
  String get issueStatusAcknowledged => 'Pris en compte';

  @override
  String get issueStatusAssigned => 'Assigné';

  @override
  String get issueStatusInProgress => 'En cours';

  @override
  String get issueStatusWaitingMaterials => 'En attente de matériel';

  @override
  String get issueStatusCompleted => 'Terminé';

  @override
  String get issueStatusVerified => 'Vérifié';

  @override
  String get issueStatusClosed => 'Clôturé';

  @override
  String get issueStatusRedirected => 'Redirigé';

  @override
  String get urgencyLow => 'Faible';

  @override
  String get urgencyMedium => 'Moyen';

  @override
  String get urgencyHigh => 'Urgent';

  @override
  String get urgencyCritical => 'Critique';

  @override
  String get deptAdministration => 'Administration';

  @override
  String get deptOpd => 'OPD (Consultations externes)';

  @override
  String get deptInternalMedicine => 'Médecine interne';

  @override
  String get deptPediatrics => 'Pédiatrie';

  @override
  String get deptEmergency => 'Urgences';

  @override
  String get deptLaboratory => 'Laboratoire';

  @override
  String get deptStomatology => 'Stomatologie';

  @override
  String get deptPhysiotherapy => 'Kinésithérapie';

  @override
  String get deptNeonatology => 'Néonatologie';

  @override
  String get deptMaternity => 'Maternité';

  @override
  String get deptSurgery => 'Chirurgie';

  @override
  String get deptOperatingTheater => 'Bloc opératoire';

  @override
  String get deptOphthalmology => 'Ophtalmologie';

  @override
  String get deptTbMr => 'TB-MR (Tuberculose)';

  @override
  String get deptGbv => 'GBV (Violences basées sur le genre)';

  @override
  String get deptMentalHealth => 'Santé mentale';

  @override
  String get deptArv => 'ARV (Traitement VIH/SIDA)';

  @override
  String get deptPharmacy => 'Pharmacie';

  @override
  String get catIct => 'Équipement ICT';

  @override
  String get catHygiene => 'Matériel d\'hygiène';

  @override
  String get catBiomedical => 'Équipement biomédical';

  @override
  String get catElectrical => 'Équipement électrique';

  @override
  String get catSterilization => 'Stérilisation et buanderie';

  @override
  String get catPharmacy => 'Pharmacie';

  @override
  String get techAvailableTab => 'Incidents disponibles';

  @override
  String get techMyInterventionsTab => 'Mes interventions';

  @override
  String get techScheduleTab => 'Agenda';

  @override
  String get techAvailableTitle => 'Incidents disponibles';

  @override
  String get techScheduleTitle => 'Agenda';

  @override
  String get techAvailableSubtitle =>
      'Incidents approuvés en attente d\'un technicien — prenez en charge ceux que vous souhaitez traiter.';

  @override
  String get techNoAvailableIncidents => 'Aucun incident approuvé disponible.';

  @override
  String get techTakeCharge => 'Prendre en charge';

  @override
  String get techSheet => 'Fiche';

  @override
  String get techTakeChargeTitle => 'Prendre en charge l\'incident';

  @override
  String get techTakeChargeContent =>
      'Vous allez prendre en charge l\'incident sur :';

  @override
  String get techTakeChargeMessage =>
      'L\'incident passera au statut \"En cours\" et vous sera assigné.';

  @override
  String techTakeChargeSuccess(String equipment) {
    return 'Vous avez pris en charge l\'incident sur \"$equipment\".';
  }

  @override
  String get techNoInterventions => 'Aucune intervention enregistrée';

  @override
  String get techNoInterventionsHint =>
      'Les incidents que vous prendrez en charge apparaîtront ici.';

  @override
  String get techNoCurrentInterventions => 'Aucune intervention en cours';

  @override
  String get techFindIncidentsHint =>
      'Pour trouver des incidents à traiter, consultez l\'onglet \"Incidents disponibles\".';

  @override
  String get techSearchHint => 'Rechercher une intervention…';

  @override
  String get techNoResults => 'Aucun résultat';

  @override
  String get techScheduleSubtitle =>
      'Votre calendrier d\'interventions et de maintenances planifiées.';

  @override
  String get techLegendInProgress => 'En cours';

  @override
  String get techLegendResolved => 'Terminé';

  @override
  String get techLegendPastMaintenance => 'Maintenance passée';

  @override
  String get techLegendPlanned => 'Planifiée';

  @override
  String get techFullHistory => 'Historique complet';

  @override
  String get techNoEventsToday => 'Aucun événement ce jour.';

  @override
  String techEventsOn(String date) {
    return 'Événements du $date';
  }

  @override
  String techEventCount(int count) {
    return '$count événement(s)';
  }

  @override
  String get techEventStatusCompleted => 'Effectuée';

  @override
  String get monthJanuary => 'Janvier';

  @override
  String get monthFebruary => 'Février';

  @override
  String get monthMarch => 'Mars';

  @override
  String get monthApril => 'Avril';

  @override
  String get monthMay => 'Mai';

  @override
  String get monthJune => 'Juin';

  @override
  String get monthJuly => 'Juillet';

  @override
  String get monthAugust => 'Août';

  @override
  String get monthSeptember => 'Septembre';

  @override
  String get monthOctober => 'Octobre';

  @override
  String get monthNovember => 'Novembre';

  @override
  String get monthDecember => 'Décembre';

  @override
  String get logsTitle => 'Journaux d\'activité';

  @override
  String get logsRefresh => 'Actualiser';

  @override
  String get logsColAction => 'Action';

  @override
  String get logsColUser => 'Utilisateur';

  @override
  String get logsColResource => 'Ressource';

  @override
  String get logsColIpDevice => 'IP / Appareil';

  @override
  String get logsColTimestamp => 'Horodatage';

  @override
  String get logsSearchHint => 'Rechercher (utilisateur, ressource…)';

  @override
  String get logsFilterAll => 'Tout';

  @override
  String get logsFilterAuth => 'Auth';

  @override
  String get logsFilterEquipment => 'Équipements';

  @override
  String get logsFilterIncidents => 'Incidents';

  @override
  String get logsFilterInventory => 'Inventaire';

  @override
  String get logsFilterUsers => 'Utilisateurs';

  @override
  String get logsNewIp => 'Nouvelle IP';

  @override
  String get logsNewIpTooltip => 'Première connexion depuis cette adresse IP';

  @override
  String get logsNoLogs => 'Aucun log trouvé';

  @override
  String get logsNoLogsSubtitle =>
      'Les actions des utilisateurs apparaîtront ici.';

  @override
  String get logsLoadError => 'Erreur de chargement';

  @override
  String get logsRetry => 'Réessayer';

  @override
  String get logsMetadata => 'Métadonnées';

  @override
  String get logsViewProfile => 'Voir profil';

  @override
  String get logsViewDetails => 'Voir détails';

  @override
  String get logsRestoring => 'Restauration…';

  @override
  String get logsAlreadyRestored => 'Cette action a déjà été restaurée.';

  @override
  String get logsUserProfileTitle => 'Profil utilisateur';

  @override
  String get logsEquipmentTitle => 'Équipement';

  @override
  String get logsEquipmentNotFound => 'Équipement supprimé ou introuvable.';

  @override
  String get logsDeviceMobile => 'Mobile';

  @override
  String get logsDevicePc => 'PC / Navigateur';

  @override
  String get logsDeviceUnknown => 'Inconnu';

  @override
  String get logsTargetEquipment => 'Équipement';

  @override
  String get logsTargetUser => 'Utilisateur concerné';

  @override
  String get logsTargetIncident => 'Incident';

  @override
  String get logsTargetInventory => 'Article d\'inventaire';

  @override
  String get logsTargetAuth => 'Authentification';

  @override
  String get logsTargetResource => 'Ressource';

  @override
  String get logsUserLabel => 'Utilisateur';

  @override
  String get logsActionLogin => 'Connexion';

  @override
  String get logsActionLoginFailed => 'Échec connexion';

  @override
  String get logsActionLogout => 'Déconnexion';

  @override
  String get logsActionCreateEquipment => 'Créer équipement';

  @override
  String get logsActionUpdateEquipment => 'Modif. équipement';

  @override
  String get logsActionDeleteEquipment => 'Suppr. équipement';

  @override
  String get logsActionRestoreEquipment => 'Restaur. équipement';

  @override
  String get logsActionAddMaintenance => 'Maintenance';

  @override
  String get logsActionScheduleMaintenance => 'Planif. maint.';

  @override
  String get logsActionCreateIssue => 'Signaler incident';

  @override
  String get logsActionUpdateIssue => 'Modif. incident';

  @override
  String get logsActionDeleteIssue => 'Suppr. incident';

  @override
  String get logsActionCreateInventory => 'Créer article';

  @override
  String get logsActionUpdateInventory => 'Modif. stock';

  @override
  String get logsActionRestockInventory => 'Réappro. stock';

  @override
  String get logsActionDeleteInventory => 'Suppr. article';

  @override
  String get logsActionCreateUser => 'Créer compte';

  @override
  String get logsActionUpdateUser => 'Modif. compte';

  @override
  String get logsActionDeleteUser => 'Suppr. compte';

  @override
  String get logsActionRestoreUser => 'Restaur. compte';

  @override
  String get logsActionChangePassword => 'Modif. mot de passe';

  @override
  String get logsActionChangeName => 'Modif. nom';

  @override
  String get logsActionChangeEmail => 'Modif. email';

  @override
  String get logsActionChangePhone => 'Modif. téléphone';

  @override
  String get logsActionActivateUser => 'Compte activé';

  @override
  String get logsActionSuspendUser => 'Compte suspendu';

  @override
  String get logsRestoreGeneric => 'Restaurer';

  @override
  String get logsRestoreEquipmentLabel => 'Restaurer l\'équipement';

  @override
  String get logsRestorePreviousState => 'Restaurer l\'état précédent';

  @override
  String get logsRestoreUserAccount => 'Restaurer le compte';

  @override
  String get logsReactivateUserAccount => 'Réactiver le compte';

  @override
  String get logsRestoreOldName => 'Restaurer l\'ancien nom';

  @override
  String get logsRestoreOldEmail => 'Restaurer l\'ancien email';

  @override
  String get logsRestoreOldPhone => 'Restaurer l\'ancien numéro';

  @override
  String get logsRestorePreviousValues => 'Restaurer les valeurs précédentes';

  @override
  String get logsConfirmRestoreTitle => 'Confirmer la restauration';

  @override
  String logsConfirmRestoreShort(String label) {
    return '$label ?';
  }

  @override
  String logsConfirmRestoreLong(String label) {
    return 'Voulez-vous vraiment $label ?';
  }

  @override
  String get logsRestoreButton => 'Restaurer';

  @override
  String get logsEquipmentRestored => 'Équipement restauré avec succès.';

  @override
  String get logsEquipmentRestoredState =>
      'Équipement restauré à son état précédent.';

  @override
  String logsUserAccountRestored(String pwd) {
    return 'Compte restauré.\nMot de passe temporaire : $pwd';
  }

  @override
  String get logsUserAccountReactivated => 'Compte réactivé.';

  @override
  String logsNameRestored(String old) {
    return 'Nom restauré : $old';
  }

  @override
  String logsEmailRestored(String old) {
    return 'Email restauré : $old';
  }

  @override
  String logsPhoneRestored(String old) {
    return 'Téléphone restauré : $old';
  }

  @override
  String get logsPreviousValuesRestored => 'Valeurs précédentes restaurées.';

  @override
  String logsRestoreErrorPrefix(String message) {
    return 'Erreur : $message';
  }

  @override
  String get logsErrSnapshotMissing => 'Données de snapshot manquantes';

  @override
  String get logsErrInsufficientData => 'Données insuffisantes';

  @override
  String get logsErrUserIdMissing => 'ID utilisateur manquant';

  @override
  String get logsErrOldValueMissing => 'Ancienne valeur introuvable';

  @override
  String get logsErrNothingToRestore => 'Aucune valeur à restaurer';

  @override
  String get logsErrNotRestorable => 'Action non restaurable';

  @override
  String get logsDetailsBefore => 'Avant';

  @override
  String get logsDetailsAfter => 'Après';

  @override
  String get logsDetailsSnapshotAvailable => 'Snapshot disponible';

  @override
  String get logsDetailsPreviousAvailable => 'État précédent disponible';

  @override
  String get logsSectionDetails => 'Détails';

  @override
  String get logsSectionDeleteSnapshot => 'Données au moment de la suppression';

  @override
  String get logsSectionStateBeforeChange => 'État avant modification';

  @override
  String get logsSectionUserStatus => 'Statut';

  @override
  String get logsFieldId => 'ID';

  @override
  String get logsFieldRole => 'Rôle';

  @override
  String get logsFieldPhone => 'Téléphone';

  @override
  String get logsFieldStatus => 'Statut';

  @override
  String get logsFieldSerial => 'N° série';

  @override
  String get logsFieldSupplier => 'Fournisseur';

  @override
  String get logsFieldLocation => 'Emplacement';

  @override
  String get logsFieldActive => 'Actif';

  @override
  String get logsFieldNewStatus => 'Nouveau statut';

  @override
  String get logsFieldReason => 'Raison';

  @override
  String get logsFieldDeviceLabel => 'Appareil';

  @override
  String get logsFieldIp => 'IP';

  @override
  String get logsFieldIpUnknown => 'Inconnue';

  @override
  String get logsFieldUserAgent => 'User-Agent';

  @override
  String get logsFieldTimestamp => 'Horodatage';

  @override
  String get logsFieldType => 'Type';

  @override
  String get logsAlertNewIpFull =>
      'Première connexion depuis cette adresse IP pour ce compte.';

  @override
  String get logsUserStatusActive => 'Actif';

  @override
  String get logsUserStatusSuspended => 'Suspendu';

  @override
  String logsErrorLoading(String error) {
    return 'Erreur : $error';
  }

  @override
  String get logsTimeJustNow => 'À l\'instant';

  @override
  String logsTimeWithMinutes(String time, int n) {
    return '$time (il y a $n min)';
  }

  @override
  String logsTimeWithHours(String time, int n) {
    return '$time (il y a $n h)';
  }

  @override
  String logsEntriesCount(int count) {
    return '$count entrée(s)';
  }

  @override
  String get settingsRolesTab => 'Gestion des rôles';

  @override
  String get settingsRolesTitle => 'Rôles et permissions';

  @override
  String get settingsRolesSubtitle =>
      'Modifier les permissions ou créer un rôle personnalisé';

  @override
  String get settingsNewRole => 'Nouveau rôle';

  @override
  String get settingsAdminLockedInfo =>
      'Les permissions de l\'Administrateur sont verrouillées — il a toujours accès à tout. Les rôles personnalisés peuvent être supprimés.';

  @override
  String get settingsNoRoles => 'Aucun rôle chargé.';

  @override
  String get settingsCustomBadge => 'Personnalisé';

  @override
  String get settingsAdminAlwaysAll =>
      'L\'administrateur a toujours toutes les permissions';

  @override
  String get settingsLocked => 'Verrouillé';

  @override
  String get settingsRoleActive => 'Permissions actives :';

  @override
  String get settingsNoPermissions => 'Aucune permission';

  @override
  String get settingsNewRoleTitle => 'Nouveau rôle personnalisé';

  @override
  String get settingsRoleIdLabel => 'Identifiant (ex: nurse)';

  @override
  String get settingsRoleIdHint => 'Lettres, chiffres, underscores';

  @override
  String get settingsRoleDisplayLabel => 'Nom affiché (ex: Infirmier)';

  @override
  String get settingsRoleDescLabel => 'Description (optionnel)';

  @override
  String get settingsPermissionsLabel => 'Permissions';

  @override
  String get settingsSelectAll => 'Tout sélectionner';

  @override
  String get settingsDeselectAll => 'Tout désélectionner';

  @override
  String get settingsCreateRole => 'Créer';

  @override
  String settingsEditPermissionsTitle(String role) {
    return 'Permissions — $role';
  }

  @override
  String get settingsBuiltinRole => 'Rôle intégré';

  @override
  String get settingsAccessByRole => 'Accès aux pages par rôle';

  @override
  String get settingsAccessDesc =>
      'Cochez les pages et fonctions accessibles pour le rôle sélectionné.';

  @override
  String get settingsRoleLabel => 'Rôle';

  @override
  String get settingsAdminAllAccess =>
      'L\'administrateur a accès à toutes les pages et fonctions sans restriction.';

  @override
  String get settingsNoSpecificFunction => 'Aucune fonction spécifique';

  @override
  String get settingsResetToDefault => 'Réinitialisé aux valeurs par défaut';

  @override
  String get settingsReset => 'Réinitialiser';

  @override
  String get settingsDeleteRole => 'Supprimer le rôle';

  @override
  String get settingsRoleCreated => 'Rôle créé';

  @override
  String get settingsRoleCreateError => 'Erreur lors de la création';

  @override
  String get settingsRoleSaveError => 'Erreur lors de la sauvegarde';

  @override
  String get settingsRoleDeleteError => 'Erreur lors de la suppression';

  @override
  String settingsRoleDeletedToast(String role) {
    return 'Rôle \"$role\" supprimé';
  }

  @override
  String settingsRoleDeleteConfirm(String role) {
    return 'Supprimer \"$role\" ? Cette action est irréversible.';
  }

  @override
  String settingsRolePermissionsUpdated(String role) {
    return 'Permissions de $role mises à jour';
  }

  @override
  String get settingsRoleConfigSaved => 'Configuration sauvegardée';

  @override
  String get settingsRoleConfigSaveError => 'Erreur lors de la sauvegarde';

  @override
  String get settingsResetDone => 'Réinitialisé aux valeurs par défaut';

  @override
  String get roleHospitalStaff => 'Personnel hospitalier';

  @override
  String get roleSupervisor => 'Superviseur';

  @override
  String get roleTechnician => 'Technicien';

  @override
  String get roleTechnicianBiomedical => 'Tech. biomédical';

  @override
  String get roleTechnicianIt => 'Tech. IT';

  @override
  String get roleTechnicianInfra => 'Tech. infrastructure';

  @override
  String get roleAdmin => 'Administrateur ICT';

  @override
  String get permViewEquipment => 'Consulter les équipements';

  @override
  String get permReportIssue => 'Signaler un problème';

  @override
  String get permTrackIssues => 'Suivre les demandes';

  @override
  String get permApproveRequests => 'Approuver les demandes';

  @override
  String get permAssignTasks => 'Assigner les tâches';

  @override
  String get permUpdateRepairs => 'Mettre à jour les réparations';

  @override
  String get permRegisterParts => 'Enregistrer les pièces';

  @override
  String get permManageEquipment => 'Gérer les équipements';

  @override
  String get permManageUsers => 'Gérer les utilisateurs';

  @override
  String get permManageDepartments => 'Gérer les départements';

  @override
  String get permManageCategories => 'Gérer les catégories';

  @override
  String get permGenerateReports => 'Générer des rapports';

  @override
  String get permViewInventory => 'Consulter l\'inventaire';

  @override
  String get permChangeDepartment => 'Changer son département directement';

  @override
  String get permManageFeatures => 'Gérer les feature flags';

  @override
  String get accountFirstName => 'Prénom';

  @override
  String get accountLastName => 'Nom';

  @override
  String get accountDirectChange => 'Direct';

  @override
  String get accountDirectChangeSubtitle =>
      'Votre département sera modifié immédiatement.';

  @override
  String get accountConfirm => 'Confirmer';

  @override
  String get accountCancelLabel => 'Annuler';

  @override
  String get equipmentSelectDate => 'Sélectionner une date (optionnel)';

  @override
  String get equipmentRemoveDate => 'Supprimer la date';

  @override
  String get equipmentDeleteReason => 'Raison de la suppression (optionnel)';

  @override
  String get equipmentDeleteReasonHint => 'Ex : Hors service, remplacé…';

  @override
  String widgetHistoryTitle(String name) {
    return 'Historique — $name';
  }

  @override
  String widgetMaintenanceEvent(String intervention) {
    return 'Maintenance — $intervention';
  }

  @override
  String widgetPlannedMaintenance(String intervention) {
    return 'Maintenance planifiée — $intervention';
  }

  @override
  String get widgetNoHistory => 'Aucun historique pour cet équipement.';

  @override
  String widgetSerialNumber(String serial) {
    return 'N° $serial';
  }

  @override
  String widgetEventCount(int count) {
    return '$count événement(s)';
  }

  @override
  String get usersDeptRequests => 'Demandes de changement de département';

  @override
  String get usersNoPendingRequests => 'Aucune demande en attente.';

  @override
  String get usersApproveTooltip => 'Approuver';

  @override
  String get usersRejectTooltip => 'Rejeter';

  @override
  String get usersApproveTitle => 'Approuver la demande';

  @override
  String get usersRejectTitle => 'Rejeter la demande';

  @override
  String get usersFirstName => 'Prénom';

  @override
  String get usersLastName => 'Nom';

  @override
  String get usersDeleteReason => 'Raison de la suppression (optionnel)';

  @override
  String get usersDeleteReasonHint =>
      'Ex : Départ de l\'établissement, doublon…';

  @override
  String get usersRolesInfo =>
      'Pour modifier les permissions, rendez-vous dans l\'onglet Rôles.';

  @override
  String get issueFormSourceLabel => 'Type de signalement';

  @override
  String get issueFormSourceEquipment => 'Équipement médical';

  @override
  String get issueFormSourceLocation => 'Infrastructure / Lieu';

  @override
  String get issueFormSelectLocation => 'Sélectionnez un lieu';

  @override
  String get issueFormLocationRequired => 'Veuillez sélectionner un lieu';

  @override
  String get techReassignButton => 'Transférer vers un autre groupe';

  @override
  String get techReassignTitle => 'Transférer l\'incident';

  @override
  String get techReassignSubtitle =>
      'Choisissez le groupe qui doit traiter cet incident.';

  @override
  String get techReassignGroupHint => 'Sélectionnez un groupe';

  @override
  String get techReassignGroupRequired => 'Le groupe est obligatoire';

  @override
  String get techReassignReasonLabel => 'Motif du transfert';

  @override
  String get techReassignReasonHint =>
      'Expliquez pourquoi vous transférez cet incident…';

  @override
  String get techReassignReasonMinLength =>
      'Le motif doit contenir au moins 10 caractères';

  @override
  String techReassignSuccess(String group) {
    return 'Incident transféré au groupe $group';
  }

  @override
  String get equipDetailCurrentIssues => 'Incidents en cours';

  @override
  String get equipDetailPastIssues => 'Historique des incidents';

  @override
  String get equipDetailNoCurrentIssues =>
      'Aucun incident en cours pour cet équipement';

  @override
  String get equipDetailNoPastIssues =>
      'Aucun incident résolu pour cet équipement';

  @override
  String get equipDetailIssuesSection => 'Incidents';

  @override
  String get equipDetailLoadingError => 'Erreur lors du chargement des détails';

  @override
  String get issueCategorySelectorTitle =>
      'Quel type de problème rencontrez-vous ?';

  @override
  String get issueCategoryBiomedical => 'Équipements Biomédicaux';

  @override
  String get issueCategoryBiomedicalDesc =>
      'Scanner, IRM, échographe, analyseurs, moniteurs, pompes à perfusion, ventilateurs…';

  @override
  String get issueCategoryInfrastructure => 'Infrastructure & Électricité';

  @override
  String get issueCategoryInfrastructureDesc =>
      'Lits, tables d\'examen, fauteuils roulants, éclairage, prises électriques, plomberie…';

  @override
  String get issueCategoryIT => 'Informatique (IT)';

  @override
  String get issueCategoryITDesc =>
      'Ordinateurs, imprimantes, réseau, serveurs, logiciels, systèmes d\'information…';

  @override
  String get issueCategoryOther => 'Autre / Je ne sais pas';

  @override
  String get issueCategoryOtherDesc =>
      'Problème non classé ou dont vous ne connaissez pas la catégorie — tous les équipements restent disponibles.';

  @override
  String get issueFormNoEquipmentInCategory =>
      'Aucun équipement de ce type trouvé dans votre département.';

  @override
  String get issueFormTagNumber => 'Numéro de Tag IT';

  @override
  String get issueFormTagNumberHint => 'Ex: TG-0042';

  @override
  String get issueFormTagSearching => 'Recherche en cours...';

  @override
  String get issueFormTagNotFound => 'Aucun équipement trouvé pour ce tag';

  @override
  String get issueFormTagFound => 'Équipement trouvé';

  @override
  String get issueFormBuilding => 'Bâtiment';

  @override
  String get issueFormSelectBuilding => 'Sélectionnez un bâtiment';

  @override
  String get issueFormSelectDepartment => 'Sélectionnez un département';

  @override
  String get issueFormProblemCategory => 'Catégorie de problème *';

  @override
  String get issueFormSelectProblemCategory => 'Sélectionnez une catégorie';

  @override
  String get issueFormProblemSubcategory => 'Sous-catégorie *';

  @override
  String get issueFormSelectProblemSubcategory =>
      'Sélectionnez une sous-catégorie';

  @override
  String get issueFormAutoFilled =>
      'Informations auto-remplies depuis l\'équipement';

  @override
  String get issueFormSearchEquipmentByTag => 'Rechercher par numéro de tag';

  @override
  String get issueFormEquipmentRequired =>
      'Veuillez sélectionner un équipement';

  @override
  String get issueFormDepartmentRequired =>
      'Veuillez sélectionner un département';

  @override
  String get issueFormBuildingHint => 'Ex: Bloc A, Bâtiment Principal...';

  @override
  String get issueFormLocationHint => 'Ex: Salle 12, Couloir Nord...';

  @override
  String get issueFormInfraTagNumber => 'Numéro de tag (optionnel)';

  @override
  String get issueFormInfraTagHint => 'Ex: TG-0042';

  @override
  String get issueFormBuildingRequired => 'Veuillez saisir le nom du bâtiment';

  @override
  String get issueFormLocationRequired2 => 'Veuillez saisir la localisation';

  @override
  String get issueFormCategoryRequired => 'Veuillez sélectionner une catégorie';

  @override
  String get issueFormSubcategoryRequired =>
      'Veuillez sélectionner une sous-catégorie';

  @override
  String get issueFormTagRequired =>
      'Veuillez saisir un numéro de tag et rechercher l\'équipement';

  @override
  String get issueFormQuickSearch => 'Recherche rapide';

  @override
  String get issueFormQuickSearchHint =>
      'Tapez un mot-clé pour trouver un problème...';

  @override
  String get issueFormSpecificIssue => 'Problème spécifique *';

  @override
  String get issueFormSelectSpecificIssue => 'Sélectionnez le problème';

  @override
  String get issueFormIssueRequired => 'Veuillez sélectionner le problème';

  @override
  String get registerTitle => 'Inscription';

  @override
  String get registerFirstName => 'Prénom';

  @override
  String get registerLastName => 'Nom';

  @override
  String get registerDepartment => 'Département';

  @override
  String get registerPhone => 'Téléphone (optionnel)';

  @override
  String get registerPasswordConfirm => 'Confirmer le mot de passe';

  @override
  String get registerPasswordMinLength => 'Minimum 8 caractères';

  @override
  String get registerPasswordMismatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get registerSubmit => 'Créer mon compte';

  @override
  String get registerSuccess =>
      'Compte créé ! Vérifiez votre email pour l\'activer. Une fois connecté, vous pourrez demander un rôle supplémentaire depuis votre profil.';

  @override
  String get registerHaveAccount => 'Déjà un compte ? Se connecter';

  @override
  String get registerNoAccount => 'Pas encore de compte ? S\'inscrire';

  @override
  String get forgotPasswordTitle => 'Mot de passe oublié';

  @override
  String get forgotPasswordSubmit => 'Envoyer le lien';

  @override
  String get forgotPasswordSuccess =>
      'Si cet email existe, vous recevrez un lien de réinitialisation. Vérifiez également vos spams.';

  @override
  String get forgotPasswordLink => 'Mot de passe oublié ?';

  @override
  String get loginEmailNotVerified =>
      'Votre compte n\'est pas encore activé. Vérifiez votre email ou contactez votre administrateur.';

  @override
  String get roleRequestTitle => 'Demander un rôle supplémentaire';

  @override
  String get roleRequestLabel => 'Rôle demandé';

  @override
  String get roleRequestSubmit => 'Envoyer la demande';

  @override
  String get roleRequestSuccess =>
      'Demande envoyée, en attente de validation administrateur';

  @override
  String get navAnalytics => 'Analytiques';

  @override
  String get navAnalyticsShort => 'Stats';

  @override
  String get healthAuth => 'Auth';

  @override
  String get healthDb => 'BD';

  @override
  String get healthIam => 'IAM';

  @override
  String get healthMail => 'Mail';

  @override
  String get analyticsTitle => 'Analytiques';

  @override
  String get analyticsPeriod => 'Période :';

  @override
  String get analyticsToday => 'Aujourd\'hui';

  @override
  String get analyticsWeek => '7 jours';

  @override
  String get analyticsMonth => '30 jours';

  @override
  String get analyticsLogins => 'Connexions';

  @override
  String get analyticsFailedLogins => 'Échecs connexion';

  @override
  String get analyticsActiveUsers => 'Utilisateurs actifs';

  @override
  String get analyticsIssuesCreated => 'Incidents créés';

  @override
  String get analyticsIssuesResolved => 'Incidents résolus';

  @override
  String get analyticsEquipmentTotal => 'Équipements';

  @override
  String get analyticsEquipmentByStatus => 'État des équipements';

  @override
  String get analyticsTopActions => 'Activité par action';

  @override
  String get analyticsNoData => 'Aucune donnée pour cette période.';

  @override
  String get accountAlertEmailNotVerifiedTitle => 'Email non vérifié';

  @override
  String get accountAlertEmailNotVerifiedSubtitle =>
      'Vérifiez votre boîte mail et cliquez sur le lien de confirmation envoyé à l\'inscription.';

  @override
  String get accountAlertPhoneMissingTitle => 'Numéro de téléphone manquant';

  @override
  String get accountAlertPhoneMissingSubtitle =>
      'Ajoutez votre numéro dans vos informations personnelles pour être joignable en cas d\'incident.';

  @override
  String appVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get navFeatureManagement => 'Feature Flags';

  @override
  String get navFeatureManagementShort => 'Flags';

  @override
  String get featureMgmtTitle => 'Gestion des Feature Flags';

  @override
  String get featureMgmtSubtitle =>
      'Activez ou désactivez les modules de l\'application globalement ou par rôle';

  @override
  String get featureMgmtGlobalStatusLabel => 'Actif globalement';

  @override
  String get featureMgmtRoleOverridesBtn => 'Exceptions par rôle';

  @override
  String get featureMgmtSaveSuccess => 'Feature mise à jour avec succès';

  @override
  String featureMgmtSaveError(String error) {
    return 'Erreur lors de la mise à jour : $error';
  }

  @override
  String get featureMgmtNoFeatures => 'Aucune feature disponible';

  @override
  String featureMgmtRoleDialogTitle(String name) {
    return 'Exceptions par rôle — $name';
  }

  @override
  String get featureMgmtRoleDialogHint =>
      'Sans exception, la feature suit son statut global.';

  @override
  String get featureMgmtRoleNoOverride => 'Aucune exception (statut global)';

  @override
  String get featureMgmtRoleForceActive => 'Forcé actif';

  @override
  String get featureMgmtRoleForceInactive => 'Forcé inactif';

  @override
  String get featureMgmtLoading => 'Chargement des features...';

  @override
  String get featureMgmtGlobalActive => 'Activé globalement';

  @override
  String get featureMgmtGlobalInactive => 'Désactivé globalement';

  @override
  String get navBackupManagement => 'Sauvegardes';

  @override
  String get navBackupManagementShort => 'Backup';

  @override
  String get permManageBackups => 'Gérer les sauvegardes';

  @override
  String get settingsTabDepartments => 'Départements';

  @override
  String get settingsTabCategories => 'Catégories';

  @override
  String get settingsTabRoles => 'Rôles & Permissions';

  @override
  String get settingsTabActivity => 'Journal d\'activité';

  @override
  String get settingsDeptDescription => 'Description (optionnel)';

  @override
  String get settingsDeptDescriptionHint => 'Ex: Soins intensifs pédiatriques';

  @override
  String settingsDeptConfirmDelete(String name) {
    return 'Confirmer la suppression de « $name » ?';
  }

  @override
  String get settingsDeptDeleteDisabledTooltip =>
      'Suppression impossible : des équipements sont liés à ce département';

  @override
  String settingsDeptDeleteBlocked(int count) {
    return 'Ce département a $count équipement(s) associé(s)';
  }

  @override
  String settingsDeptStatsOt(int count) {
    return '$count OT ouvertes';
  }

  @override
  String settingsDeptStatsAssets(int count) {
    return '$count actifs';
  }

  @override
  String get settingsCatBiomedical => 'Biomédical';

  @override
  String get settingsCatInfrastructure => 'Infrastructure';

  @override
  String get settingsCatIt => 'Informatique';

  @override
  String get settingsCatAddSub => 'Ajouter une sous-catégorie';

  @override
  String get settingsCatSelectMacro => 'Macro-catégorie';

  @override
  String get settingsEmptyList => 'Aucun élément à afficher';

  @override
  String get settingsLoadMore => 'Charger plus';

  @override
  String get settingsActivityFilter => 'Filtrer par action';

  @override
  String get backupTitle => 'Gestion des Sauvegardes';

  @override
  String get backupSubtitle =>
      'Sauvegardez, planifiez et téléchargez les données de l\'hôpital';

  @override
  String get backupLoading => 'Chargement...';

  @override
  String get backupLoadError => 'Erreur lors du chargement des données';

  @override
  String get backupRetry => 'Réessayer';

  @override
  String get backupLastStatus => 'Statut de la dernière sauvegarde';

  @override
  String get backupNoLastBackup => 'Aucune sauvegarde effectuée';

  @override
  String get backupDate => 'Date';

  @override
  String get backupSize => 'Taille';

  @override
  String get backupStatusLabel => 'Statut';

  @override
  String get backupStatusSuccess => 'Succès';

  @override
  String get backupStatusError => 'Échec';

  @override
  String get backupTypeManual => 'Manuelle';

  @override
  String get backupTypeAutomated => 'Automatique';

  @override
  String get backupTrigger => 'Exécuter une sauvegarde immédiate';

  @override
  String get backupTriggering => 'Sauvegarde en cours...';

  @override
  String get backupTriggerSuccess => 'Sauvegarde réussie';

  @override
  String backupTriggerError(String error) {
    return 'Erreur lors de la sauvegarde : $error';
  }

  @override
  String get backupAutomationSection => 'Automatisation';

  @override
  String get backupEnableAuto => 'Activer la sauvegarde automatique';

  @override
  String get backupScheduleLabel => 'Récurrence';

  @override
  String get backupScheduleDaily => 'Tous les jours à minuit';

  @override
  String get backupScheduleWeekly => 'Chaque semaine (dimanche à minuit)';

  @override
  String get backupSettingsSaved => 'Paramètres de sauvegarde enregistrés';

  @override
  String backupSettingsSaveError(String error) {
    return 'Erreur lors de la mise à jour : $error';
  }

  @override
  String get backupAlertTitle => 'Rappel Critique';

  @override
  String get backupAlertMessage =>
      'Pour des raisons de sécurité (incendie, panne matérielle majeure), veuillez régulièrement télécharger une sauvegarde et la stocker sur un support physique hors du serveur de l\'hôpital.';

  @override
  String get backupHistorySection => 'Historique des sauvegardes';

  @override
  String get backupNoHistory => 'Aucune sauvegarde enregistrée';

  @override
  String get backupDownload => 'Télécharger';

  @override
  String get backupDownloadSuccess => 'Téléchargement démarré';

  @override
  String backupDownloadError(String error) {
    return 'Erreur lors du téléchargement : $error';
  }

  @override
  String get backupColDate => 'Date';

  @override
  String get backupColType => 'Type';

  @override
  String get backupColSize => 'Taille';

  @override
  String get backupColStatus => 'Statut';

  @override
  String get backupColAction => 'Action';

  @override
  String get backupAccessDeniedTitle => 'Accès Refusé — Espace Système';

  @override
  String get backupAccessDeniedMessage =>
      'Cet espace est réservé aux administrateurs ICT du système.';

  @override
  String get backupAccessDeniedSub =>
      'Contactez le service informatique si vous pensez que c\'est une erreur.';

  @override
  String get backupAutoDisableWarning =>
      'Attention : La base de données de l\'hôpital n\'est plus protégée par les sauvegardes automatiques. Réactivez cette option dès que possible.';

  @override
  String get backupRestoreButton => 'Restaurer';

  @override
  String get backupRestoreDialogTitle => 'Confirmer la restauration';

  @override
  String backupRestoreDialogWarning(String date) {
    return 'Cette opération va écraser toutes les données de production actuelles et les remplacer par la sauvegarde du $date. Cette action est irréversible.';
  }

  @override
  String get backupRestoreTypeInstruction =>
      'Pour confirmer, tapez RESTAURER dans le champ ci-dessous :';

  @override
  String get backupRestoreConfirmWord => 'RESTAURER';

  @override
  String get backupRestoreConfirmButton => 'Confirmer la restauration';

  @override
  String get backupRestoreSuccess => 'Restauration effectuée avec succès';

  @override
  String backupRestoreError(String error) {
    return 'Erreur lors de la restauration : $error';
  }

  @override
  String get backupRestoring => 'Restauration en cours...';

  @override
  String get issueDetailTitle => 'Détail de l\'Incident';

  @override
  String get issueDetailSectionContext => 'Contexte';

  @override
  String get issueDetailSectionFailure => 'Panne';

  @override
  String get issueDetailSectionIntervention => 'Suivi d\'intervention';

  @override
  String get issueDetailSectionResources => 'Ressources';

  @override
  String get issueDetailSectionHistory => 'Historique';

  @override
  String get issueDetailEquipmentLink => 'Voir l\'équipement';

  @override
  String get issueDetailRootCause => 'Cause racine (diagnostic)';

  @override
  String get issueDetailCorrectiveActions => 'Actions correctives';

  @override
  String get issueDetailPartsUsed => 'Pièces remplacées';

  @override
  String get issueDetailMaintenanceHistory => 'Maintenance récente';

  @override
  String get issueDetailNoHistory => 'Aucun événement enregistré';

  @override
  String get issueDetailLoading => 'Chargement des détails...';

  @override
  String get issueDetailCategory => 'Catégorie d\'incident';

  @override
  String get issueDetailGroup => 'Groupe technique';

  @override
  String get issueDetailLocation => 'Localisation';

  @override
  String get issueDetailUpdatedAt => 'Dernière mise à jour';

  @override
  String get issueDetailUpdateButton => 'Mettre à jour l\'incident';

  @override
  String get issueDetailTypeLabel => 'Type de défaillance';

  @override
  String get issueDetailReporter => 'Signalé par';

  @override
  String get issueDetailReportDate => 'Date de signalement';

  @override
  String get issueDetailAssignedTech => 'Technicien assigné';

  @override
  String get issueDetailNoIntervention => 'Aucune intervention enregistrée';

  @override
  String get issueDetailNoMaintenance => 'Aucune maintenance enregistrée';

  @override
  String get issueDetailTimelineCreated => 'Incident signalé';

  @override
  String get issueDetailLoadError =>
      'Impossible de charger les détails de l\'incident.';

  @override
  String get macroCategoryLabel => 'Macro-catégorie';

  @override
  String get macroCategoryBiomedical => 'Biomédical';

  @override
  String get macroCategoryInfrastructure => 'Infrastructure';

  @override
  String get macroCategoryIT => 'Informatique (IT)';

  @override
  String get subcategoryLabel => 'Sous-catégorie';

  @override
  String get subcategorySelectHint => 'Sélectionnez une sous-catégorie';

  @override
  String get criticalityLabel => 'Criticité (Matrice ABC)';

  @override
  String get criticalityA => 'A — Critique';

  @override
  String get criticalityB => 'B — Important';

  @override
  String get criticalityC => 'C — Courant';

  @override
  String get criticalityTooltipA =>
      'Panne = arrêt immédiat des soins. Priorité absolue.';

  @override
  String get criticalityTooltipB =>
      'Impact significatif mais solution de repli possible.';

  @override
  String get criticalityTooltipC =>
      'Peu d\'impact sur la continuité des soins.';

  @override
  String get warrantyEndDate => 'Fin de garantie';

  @override
  String get warrantyEndDateHint =>
      'Sélectionner la date de fin de garantie (optionnel)';

  @override
  String get warrantyExpired => 'Garantie expirée';

  @override
  String get warrantyExpiringSoon => 'Garantie expirée dans 30 jours';

  @override
  String get warrantyValid => 'Sous garantie';

  @override
  String get pmProtocolsTitle => 'Protocoles de Maintenance Préventive';

  @override
  String get pmProtocolsSubtitle =>
      'Checklists et fréquences par type d\'équipement';

  @override
  String get pmProtocolFrequency => 'Fréquence';

  @override
  String pmProtocolFrequencyMonths(int n) {
    return '$n mois';
  }

  @override
  String get pmProtocolDuration => 'Durée estimée';

  @override
  String pmProtocolDurationHours(String h) {
    return '$h h';
  }

  @override
  String get pmProtocolChecklist => 'Checklist';

  @override
  String get pmProtocolChecklistEmpty => 'Aucune tâche définie';

  @override
  String get pmProtocolAdd => 'Ajouter un protocole';

  @override
  String get pmProtocolEdit => 'Modifier le protocole';

  @override
  String get pmProtocolDelete => 'Supprimer le protocole';

  @override
  String pmProtocolDeleteConfirm(String name) {
    return 'Supprimer le protocole \"$name\" ?';
  }

  @override
  String get pmProtocolSaved => 'Protocole enregistré';

  @override
  String get pmProtocolDeleted => 'Protocole supprimé';

  @override
  String get pmProtocolNameLabel => 'Nom du protocole *';

  @override
  String get pmProtocolFrequencyLabel => 'Fréquence (mois) *';

  @override
  String get pmProtocolDurationLabel => 'Durée estimée (heures)';

  @override
  String get pmProtocolChecklistLabel => 'Tâches de la checklist';

  @override
  String get pmProtocolAddTask => 'Ajouter une tâche';

  @override
  String get pmProtocolTaskHint => 'Ex : Vérifier la tension secteur';

  @override
  String get pmProtocolNoProtocols =>
      'Aucun protocole PM pour ce type d\'équipement';

  @override
  String get equipmentSubcategorySection => 'Classification GMAO';

  @override
  String get equipmentWarrantySection => 'Garantie & Criticité';

  @override
  String get equipmentPmSection => 'Protocoles PM applicables';

  @override
  String get systemStatusOperational => 'Statut système : Opérationnel';

  @override
  String get systemStatusDegraded => 'Statut système : Dégradé';

  @override
  String get systemStatusChecking => 'Vérification en cours…';

  @override
  String systemStatusLastCheck(String time) {
    return 'Dernière vérif. à $time';
  }

  @override
  String get systemAlertBannerAuth =>
      'Service d\'authentification indisponible. Veuillez contacter l\'administrateur IT.';

  @override
  String get systemAlertBannerGeneral =>
      'Service(s) système indisponible(s) — fonctionnalités limitées.';

  @override
  String get loginRecentSessionsTitle =>
      'Comptes récemment utilisés sur ce poste';

  @override
  String get loginBackToLogin => 'Retour à la connexion';

  @override
  String get forgotPasswordHint =>
      'Entrez votre adresse email. Vous recevrez un lien pour réinitialiser votre mot de passe.';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonBack => 'Retour';

  @override
  String get dashboardRefreshedJustNow => 'À l\'instant';

  @override
  String dashboardRefreshedAgo(int n) {
    return 'Il y a $n min';
  }

  @override
  String dashboardRefreshedAt(String time) {
    return 'Actualisé à $time';
  }

  @override
  String get dashboardRefreshTooltip => 'Actualiser';

  @override
  String get dashboardPmOverdue => 'PM en retard';

  @override
  String get dashboardPriorityIssues => 'Incidents prioritaires';

  @override
  String get dashboardCriticalIssue24h => 'Incident critique (24h)';

  @override
  String get dashboardTechSection => 'Tableau technicien';

  @override
  String get dashboardTechBacklogLabel => 'File d\'attente';

  @override
  String get dashboardTechCriticalOos => 'Hors service critiques';

  @override
  String get dashboardSidePanelTitle => 'Hors service critiques';

  @override
  String get dashboardSidePanelSubtitle =>
      'Équipements hors service avec criticité A';

  @override
  String get dashboardSidePanelEmpty =>
      'Aucun équipement critique hors service';

  @override
  String get dashboardWeatherTitle => 'Météo de l\'hôpital';

  @override
  String get dashboardWeatherAllGood =>
      'Tout est opérationnel — aucune alerte en cours';

  @override
  String dashboardWeatherCriticalCount(int count) {
    return '$count incident(s) critique(s) ou urgent(s) en cours';
  }

  @override
  String dashboardWeatherOosCount(int count) {
    return '$count équipement(s) hors service';
  }

  @override
  String get dashboardWeatherReportBtn => 'Signaler un incident';

  @override
  String get dashboardMyTasksTitle => 'Mes tâches du jour';

  @override
  String get dashboardMyTasksNoTasks => 'Aucune tâche en cours';

  @override
  String get dashboardMyTasksPmDue => 'PM à faire / imminentes';

  @override
  String get dashboardMyTasksViewIssues => 'Voir mes interventions';

  @override
  String dashboardScopedTo(String scope) {
    return 'Périmètre : $scope';
  }

  @override
  String get equipmentExportCsv => 'Exporter CSV';

  @override
  String get equipmentExportCsvTooltip => 'Télécharger la liste filtrée en CSV';

  @override
  String get equipmentSchedulePm => 'Planifier PM';

  @override
  String get equipmentSchedulePmSuccess => 'Maintenance préventive planifiée';

  @override
  String get equipmentFilterPmOverdueChip => 'PM en retard';

  @override
  String get equipmentFilterPmSoonChip => 'PM imminente (<7j)';

  @override
  String get equipmentFormStep1 => 'Infos essentielles';

  @override
  String get equipmentFormStep2 => 'Infos techniques';

  @override
  String get equipmentFormStep3 => 'GMAO & Maintenance';

  @override
  String get equipmentFormStep1Subtitle =>
      'Nom, catégorie, département, statut';

  @override
  String get equipmentFormStep2Subtitle =>
      'Fabricant, numéro de série, localisation';

  @override
  String get equipmentFormStep3Subtitle =>
      'Maintenance préventive, criticité, révision';

  @override
  String get equipmentReportBreakdown => 'Signaler une panne';

  @override
  String get equipmentColumnInstallDate => 'Date install.';

  @override
  String get equipmentCsvWebOnly =>
      'Export CSV disponible sur navigateur web uniquement';

  @override
  String get equipmentSortBy => 'Trier par';

  @override
  String get equipDetailTabInfo => 'Informations';

  @override
  String get equipDetailTabMaintenance => 'Maintenance';

  @override
  String get equipDetailTabIncidents => 'Incidents';

  @override
  String get equipDetailTabDocuments => 'Documents';

  @override
  String get equipDetailCriticalBanner =>
      'ALERTE — Équipement critique hors service. Contactez immédiatement l\'équipe technique.';

  @override
  String get equipDetailQrCode => 'QR Code';

  @override
  String get equipDetailQrCodeTitle => 'Identifiant de l\'équipement';

  @override
  String get equipDetailQrCodeSubtitle =>
      'Copiez ou partagez l\'ID pour lier cet équipement à un incident';

  @override
  String get equipDetailQrCodeCopy => 'Copier l\'ID';

  @override
  String get equipDetailQrCodeCopied => 'ID copié !';

  @override
  String get equipDetailKpiSection => 'Indicateurs de performance';

  @override
  String get equipDetailMttr => 'MTTR (Temps Moyen de Réparation)';

  @override
  String equipDetailMttrValue(int n) {
    return '$n jour(s)';
  }

  @override
  String get equipDetailMttrNoData => 'Données insuffisantes';

  @override
  String get equipDetailTotalRepairs => 'Réparations enregistrées';

  @override
  String get equipDetailCreatePm => 'Créer une intervention PM';

  @override
  String get equipDetailStaffReportButton => 'Signaler une panne';

  @override
  String get equipDetailStaffContactSection => 'Contact équipe technique';

  @override
  String get equipDetailStaffContactBiomedical => 'Équipe biomédicale';

  @override
  String get equipDetailStaffContactIt => 'Service IT';

  @override
  String get equipDetailStaffContactInfra => 'Équipe infrastructure';

  @override
  String get equipDetailStaffContactGeneric => 'Service technique';

  @override
  String get equipDetailStaffActiveIssues =>
      'Incidents en cours sur cet équipement';

  @override
  String get equipDetailStaffNoActiveIssues => 'Aucun incident en cours';

  @override
  String get equipDetailNoDocuments => 'Aucun document disponible';

  @override
  String get equipDetailDocumentsHint =>
      'Les manuels d\'utilisation, fiches techniques et procédures PM seront affichés ici.';

  @override
  String get equipDetailDeleteConfirmTitle => 'Supprimer l\'équipement';

  @override
  String get equipDetailDeleteConfirmBody =>
      'Cette action est irréversible. Tapez le nom exact de l\'équipement pour confirmer :';

  @override
  String get equipDetailDeleteConfirmLabel => 'Nom de l\'équipement';

  @override
  String equipDetailDeleteConfirmHint(String name) {
    return 'Tapez exactement : $name';
  }

  @override
  String get equipDetailDeleteConfirmMismatch => 'Le nom ne correspond pas';

  @override
  String get equipDetailDeleteConfirmButton => 'Supprimer définitivement';

  @override
  String get equipDetailDeleteReasonLabel => 'Raison (optionnel)';

  @override
  String get equipDetailDeleteReasonHint =>
      'Ex : Hors service définitif, remplacé…';

  @override
  String get decommissionButton => 'Réformer / Mettre au rebut';

  @override
  String get decommissionDialogTitle => 'Réformer l\'équipement';

  @override
  String get decommissionDialogBody =>
      'L\'équipement sortira des listes actives mais conservera tout son historique pour l\'audit.';

  @override
  String get decommissionReasonLabel => 'Motif de réforme';

  @override
  String get decommissionMethodLabel => 'Méthode d\'élimination';

  @override
  String get decommissionReplacementLabel => 'Équipement remplaçant';

  @override
  String get decommissionReplacementHint => 'Sélectionner l\'équipement neuf';

  @override
  String get decommissionReplacementRequired =>
      'Un remplaçant est requis pour le motif « Remplacé »';

  @override
  String get decommissionNotesLabel => 'Notes (optionnel)';

  @override
  String get decommissionConfirmButton => 'Réformer';

  @override
  String get decommissionSuccess => 'Équipement réformé';

  @override
  String get decommissionBadge => 'Réformé';

  @override
  String get decommissionReplacedBy => 'Remplacé par';

  @override
  String get decommissionReplaces => 'Remplace';

  @override
  String get decommissionInfoTitle => 'Réforme';

  @override
  String get decommissionReasonValueIrreparable => 'Irréparable';

  @override
  String get decommissionReasonValueObsolete => 'Obsolète';

  @override
  String get decommissionReasonValueReplaced => 'Remplacé';

  @override
  String get decommissionReasonValueLost => 'Perdu / Volé';

  @override
  String get decommissionReasonValueDonatedOut => 'Donné (sortie)';

  @override
  String get decommissionMethodValueDestroyed => 'Détruit';

  @override
  String get decommissionMethodValueSold => 'Vendu';

  @override
  String get decommissionMethodValueDonated => 'Donné';

  @override
  String get decommissionMethodValueReturned => 'Retourné au fournisseur';

  @override
  String get decommissionMethodValueCannibalized => 'Pièces récupérées';

  @override
  String get decommissionDeleteBlockedTitle => 'Suppression impossible';

  @override
  String get decommissionDeleteBlockedBody =>
      'Cet équipement possède un historique (incidents, maintenances). Réformez-le plutôt que de le supprimer pour conserver la traçabilité.';

  @override
  String get decommissionForceDeleteButton =>
      'Supprimer définitivement (admin)';

  @override
  String get decommissionForceDeleteWarning =>
      'Ceci détruit aussi tout l\'historique (incidents, maintenances, tags, documents). Action irréversible.';

  @override
  String get equipmentFilterShowDisposed => 'Afficher les réformés';

  @override
  String equipDetailMaintenanceCount(int count) {
    return '$count intervention(s)';
  }

  @override
  String get issueFormSwitchTabTitle => 'Changer de catégorie ?';

  @override
  String get issueFormSwitchTabMessage =>
      'Les données saisies (description, photos) seront effacées si vous changez d\'onglet. Continuer ?';

  @override
  String get issueFormSwitchTabConfirm => 'Changer';

  @override
  String get issueFormScanQrTooltip => 'Scanner le QR code de l\'équipement';

  @override
  String get issueFormScanQrTitle => 'Scanner le QR code';

  @override
  String get issueFormScanQrFallbackTitle => 'Saisir l\'identifiant';

  @override
  String get issueFormScanQrFallbackHint =>
      'ID ou numéro de série de l\'équipement';

  @override
  String get issueFormScanQrFallbackConfirm => 'Valider';

  @override
  String get issueFormScanQrNotFound =>
      'Aucun équipement trouvé pour cet identifiant';

  @override
  String get issueFormEquipmentAvailableLabel =>
      'Disponible pour intervention immédiate';

  @override
  String get issueFormEquipmentAvailableHint =>
      'L\'équipement peut être mis hors tension pour la réparation';

  @override
  String get issueFormSuccessTitle => 'Signalement soumis avec succès';

  @override
  String issueFormSuccessTicketId(String id) {
    return 'N° de ticket : $id';
  }

  @override
  String get issueFormSuccessSlaLabel => 'Délai cible (SLA)';

  @override
  String get issueFormSla2h => '2 heures — urgence critique';

  @override
  String get issueFormSla12h => '12 heures — urgent';

  @override
  String get issueFormSla48h => '48 heures — priorité moyenne';

  @override
  String get issueFormSla1week => '1 semaine — faible priorité';

  @override
  String get issueFormSuccessClose => 'Fermer';

  @override
  String get issuesSearchHint => 'Rechercher incident, équipement, déclarant…';

  @override
  String get issuesFilterPeriod => 'Période';

  @override
  String get issuesFilterPeriodAll => 'Tous';

  @override
  String get issuesFilterPeriodLast7 => '7 derniers jours';

  @override
  String get issuesFilterPeriodLast30 => '30 derniers jours';

  @override
  String get issuesFilterUrgency => 'Urgence';

  @override
  String get issuesFilterGroup => 'Groupe';

  @override
  String get issuesFilterGroupBiomedical => 'Biomédical';

  @override
  String get issuesFilterGroupIT => 'IT';

  @override
  String get issuesFilterGroupInfra => 'Infrastructure';

  @override
  String get issuesViewSeeAll => 'Voir tout';

  @override
  String get issuesClearFilter => 'Effacer le filtre';

  @override
  String get issuesViewList => 'Liste';

  @override
  String get issuesViewKanban => 'Kanban';

  @override
  String get issuesExportCsv => 'Exporter CSV';

  @override
  String get issuesCsvWebOnly =>
      'Export CSV disponible sur navigateur web uniquement';

  @override
  String get issuesKanbanColTodo => 'À faire';

  @override
  String get issuesKanbanColInProgress => 'En cours';

  @override
  String get issuesKanbanColWaiting => 'En attente';

  @override
  String get issuesKanbanColDone => 'Terminé';

  @override
  String get issuesKanbanEmpty => 'Aucun incident';

  @override
  String get issuesActiveFilterMyIssues => 'Mes incidents uniquement';

  @override
  String get issuesActiveFilterDeptIssues => 'Mon département uniquement';

  @override
  String get issuesActiveFilterLabel => 'Filtre actif :';

  @override
  String issueDetailHandledBy(String technician, String date) {
    return 'Pris en charge par $technician le $date';
  }

  @override
  String get issueDetailNotHandledYet =>
      'En attente d\'attribution à un technicien';

  @override
  String get issueDetailReassignButton => 'Réassigner';

  @override
  String get issueDetailReassignTitle => 'Réassigner l\'incident';

  @override
  String get issueDetailReassignGroupLabel => 'Groupe technique';

  @override
  String get issueDetailReassignReasonLabel => 'Motif (obligatoire)';

  @override
  String get issueDetailReassignReasonHint =>
      'Expliquez la raison de la réassignation…';

  @override
  String get issueDetailReassignReasonMinLength =>
      'Le motif doit contenir au moins 5 caractères';

  @override
  String get issueDetailReassignSuccess => 'Incident réassigné avec succès';

  @override
  String issueDetailReassignError(String error) {
    return 'Erreur lors de la réassignation : $error';
  }

  @override
  String get issueDetailAddCommentButton => 'Ajouter un commentaire';

  @override
  String get issueDetailCommentTitle => 'Ajouter un commentaire';

  @override
  String get issueDetailCommentHint => 'Saisissez votre commentaire…';

  @override
  String get issueDetailCommentMinLength =>
      'Le commentaire doit contenir au moins 5 caractères';

  @override
  String get issueDetailCommentSubmit => 'Envoyer';

  @override
  String get issueDetailCommentSuccess => 'Commentaire ajouté à l\'historique';

  @override
  String issueDetailCommentError(String error) {
    return 'Erreur : $error';
  }

  @override
  String get issueDetailSectionDocuments => 'Documents & Pièces jointes';

  @override
  String get issueDetailAddDocument => 'Ajouter un fichier';

  @override
  String get issueDetailNoDocuments => 'Aucun document attaché à cet incident';

  @override
  String get issueDetailDocumentsHint =>
      'Rapports PDF, bons de commande, photos supplémentaires…';

  @override
  String get issueDetailPanelNoSelection =>
      'Sélectionnez un incident dans la liste pour voir ses détails';

  @override
  String get issueDetailClosePanel => 'Fermer le panneau';

  @override
  String get techMarkResolvedTooltip =>
      'Sélectionnez d\'abord le statut « Réparé » pour clore l\'incident';

  @override
  String get techPartsFromInventory => 'Pièces remplacées (inventaire)';

  @override
  String get techPartsSearchHint => 'Rechercher un article d\'inventaire...';

  @override
  String get techPartsNoResults => 'Aucun article trouvé';

  @override
  String techPartsStockLabel(int n, String unit) {
    return 'Stock : $n $unit';
  }

  @override
  String get techPartsNoneSelected => 'Aucune pièce sélectionnée';

  @override
  String get techPartsOutOfStock => 'Rupture de stock';

  @override
  String techTakenAtLabel(String date) {
    return 'Prise en charge le $date';
  }

  @override
  String get techAvailableGroupedSubtitle =>
      'Regroupés par département / localisation';

  @override
  String techAvailableDeptCount(int count) {
    return '$count incident(s)';
  }

  @override
  String get techDestockConfirmTitle => 'Confirmer le déstockage';

  @override
  String get techDestockConfirmSubtitle =>
      'Vous avez déclaré les pièces suivantes :';

  @override
  String techDestockItemLine(
    String name,
    int quantity,
    String unit,
    int stock,
  ) {
    return '$name × $quantity $unit  (stock actuel : $stock)';
  }

  @override
  String techDestockStockAfter(int after, String unit) {
    return 'Stock restant estimé : $after $unit';
  }

  @override
  String get techDestockLowWarning => '⚠ Stock faible après cette opération';

  @override
  String get techDestockConfirm => 'Confirmer et déstockerter';

  @override
  String get techEscalateButton => 'Escalader / Suspendre';

  @override
  String get techEscalateTitle => 'Escalader l\'incident';

  @override
  String get techEscalateSubtitle =>
      'Suspendez l\'incident si vous manquez de matériel ou de compétences spécifiques. Cela le rend visible aux superviseurs.';

  @override
  String get techEscalateStatusLabel => 'Type d\'escalade';

  @override
  String get techEscalateWaitingMaterials => 'Attente de matériaux / pièces';

  @override
  String get techEscalateRedirected => 'Rediriger vers un spécialiste';

  @override
  String get techEscalateStatusRequired =>
      'Le type d\'escalade est obligatoire';

  @override
  String get techEscalateCommentLabel => 'Commentaire obligatoire';

  @override
  String get techEscalateCommentHint =>
      'Expliquez le problème (pièces manquantes, expertise externe requise…)';

  @override
  String get techEscalateCommentMinLength =>
      'Le commentaire doit contenir au moins 10 caractères';

  @override
  String techEscalateSuccess(String status) {
    return 'Incident escaladé — statut : $status';
  }

  @override
  String get techWorkOrderTitle => 'Bon de Travail — Clôture formelle';

  @override
  String get techWorkOrderSafetyCheck =>
      'J\'atteste que toutes les vérifications de sécurité ont été effectuées et que l\'équipement est en état de fonctionnement.';

  @override
  String get techWorkOrderSafetyRequired =>
      'Vous devez valider les vérifications de sécurité avant de clore l\'incident.';

  @override
  String get techWorkOrderClosingNotes => 'Notes de clôture';

  @override
  String get techWorkOrderClosingNotesHint =>
      'Informations complémentaires pour le superviseur ou les futurs intervenants…';

  @override
  String get techWorkOrderConfirm => 'Confirmer la clôture';

  @override
  String get reportsPeriodLabel => 'Période d\'analyse';

  @override
  String get reportsPeriodLast7 => '7 jours';

  @override
  String get reportsPeriodLast30 => '30 jours';

  @override
  String get reportsPeriodLast90 => '90 jours';

  @override
  String get reportsPeriodYearToDate => 'Année en cours';

  @override
  String get reportsPeriodCustom => 'Personnalisée';

  @override
  String get reportsKpiSectionTitle => 'Indicateurs GMAO (KPIs)';

  @override
  String get reportsMttr => 'Délai moyen d\'intervention';

  @override
  String get reportsMttrNoData => 'Données insuffisantes';

  @override
  String get reportsMttrHint =>
      'Temps moyen entre signalement et prise en charge (incidents clôturés)';

  @override
  String reportsMttrDays(String n) {
    return '$n jour(s)';
  }

  @override
  String get reportsPmCompliance => 'Conformité PM';

  @override
  String get reportsPmComplianceHint =>
      '% des équipements dont la PM n\'est pas en retard';

  @override
  String reportsPmTotal(int n) {
    return '$n équipement(s) avec PM planifiée';
  }

  @override
  String get reportsPmNoData => 'Aucun plan PM configuré';

  @override
  String get reportsTopDepts => 'Départements les plus impactés';

  @override
  String get reportsTopDeptsHint => 'Par nombre d\'incidents sur la période';

  @override
  String get reportsTopDeptsEmpty =>
      'Aucun incident sur la période sélectionnée';

  @override
  String get reportsExportCsv => 'Export CSV';

  @override
  String get reportsExportCsvSuccess => 'Fichier CSV téléchargé';

  @override
  String get reportsExportCsvWebOnly =>
      'Export CSV disponible sur navigateur web uniquement';

  @override
  String get reportsIssuesInPeriod => 'Incidents (période)';

  @override
  String get reportsResolutionRate => 'Taux de résolution';

  @override
  String get analyticsIssueKpiSection => 'Métriques incidents';

  @override
  String get analyticsEquipmentSection => 'État des équipements';

  @override
  String get analyticsChartsSection => 'Graphiques de tendance';

  @override
  String get analyticsChartsPeriodNote =>
      'Fenêtre glissante — 13 semaines (indépendant du filtre)';

  @override
  String get analyticsIncidentTrend => 'Signalements vs Résolus — 13 semaines';

  @override
  String get analyticsCreatedSeries => 'Signalés';

  @override
  String get analyticsResolvedSeries => 'Résolus';

  @override
  String get analyticsResolutionRateLabel => 'Taux de résolution';

  @override
  String get analyticsOpenIssuesLabel => 'Incidents ouverts';

  @override
  String get analyticsGroupBarTitle => 'Incidents par groupe technique';

  @override
  String get analyticsGroupBiomedical => 'Biomédical';

  @override
  String get analyticsGroupIT => 'IT';

  @override
  String get analyticsGroupInfra => 'Infrastructure';

  @override
  String get analyticsGroupOther => 'Autre';

  @override
  String get analyticsRetry => 'Réessayer';

  @override
  String get analyticsNoChartData =>
      'Impossible de charger les données pour les graphiques';

  @override
  String get healthStatusOk => 'Opérationnel';

  @override
  String get healthStatusKo => 'Indisponible';

  @override
  String get healthTooltipTitle => 'État des services';

  @override
  String healthTooltipLastCheck(String time) {
    return 'Dernière vérif. : $time';
  }

  @override
  String get healthTooltipNoCheck => 'Vérification en cours…';

  @override
  String get accessRequestLink => 'Demander un accès';

  @override
  String get accessRequestTitle => 'Demande d\'accès au système';

  @override
  String get accessRequestSubtitle =>
      'Créez votre compte en quelques secondes. Vous serez connecté automatiquement avec le rôle Personnel hospitalier.';

  @override
  String get accessRequestFirstName => 'Prénom *';

  @override
  String get accessRequestLastName => 'Nom *';

  @override
  String get accessRequestEmail => 'Email professionnel *';

  @override
  String get accessRequestDepartment => 'Département (optionnel)';

  @override
  String get accessRequestPassword => 'Mot de passe *';

  @override
  String get accessRequestPasswordConfirm => 'Confirmer le mot de passe *';

  @override
  String get accessRequestPasswordTooShort => 'Minimum 8 caractères';

  @override
  String get accessRequestPasswordMismatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get accessRequestAccountExists =>
      'Cet email est déjà associé à un compte';

  @override
  String get accessRequestSubmit => 'Créer mon compte';

  @override
  String get accessRequestSuccess => 'Compte créé ! Connexion en cours…';

  @override
  String get accessRequestError =>
      'Erreur lors de la création. Réessayez ou contactez directement l\'administrateur IT.';

  @override
  String get accessRequestOtherOption => 'Autre / Non listé';

  @override
  String get emergencyContactTitle => 'Urgence ou compte bloqué ?';

  @override
  String get emergencyContactInfo =>
      'Admin IT : nzephmd@gmail.com  •  +250 788 823 228';

  @override
  String get hubStaffTitle => 'Que souhaitez-vous faire ?';

  @override
  String get hubStaffReportButton => 'Signaler une panne';

  @override
  String get hubStaffActiveIssuesButton => 'Mes incidents actifs';

  @override
  String hubStaffActiveIssuesCount(int count) {
    return '$count incident(s) en cours';
  }

  @override
  String get hubStaffNoActiveIssues => 'Aucun incident actif pour le moment';

  @override
  String get hubTechWorkplanTitle => 'Mon plan de travail du jour';

  @override
  String get hubTechWorkplanSubtitle =>
      'Tâches planifiées et interventions assignées';

  @override
  String get hubTechPmSection => 'Maintenances préventives (PM)';

  @override
  String get hubTechAssignedSection => 'Mes interventions assignées';

  @override
  String get hubTechPendingPartsSection => 'En attente de pièces';

  @override
  String get hubTechNoPm => 'Aucune PM en retard ou imminente';

  @override
  String get hubTechNoAssigned => 'Aucune intervention assignée en cours';

  @override
  String get hubTechNoPendingParts => 'Aucune pièce en attente';

  @override
  String get hubTechViewAll => 'Voir tout';

  @override
  String get hubTechPmOverdueLabel => 'PM en retard';

  @override
  String get hubTechPmSoonLabel => 'PM imminente (< 7 j)';

  @override
  String get hubKpiLastRefreshLabel => 'Données actualisées';

  @override
  String get equipmentViewGrid => 'Vue grille';

  @override
  String get equipmentViewList => 'Vue liste';

  @override
  String get equipmentColumnLastPm => 'Dernière PM / Intervention';

  @override
  String get equipmentFilterMyUnit => 'Mon unité / Ma salle';

  @override
  String get equipmentFilterUnit => 'Unité / Salle';

  @override
  String get equipmentScanQrTooltip => 'Rechercher par QR code';

  @override
  String get equipmentScanQrTitle => 'Rechercher par QR';

  @override
  String get equipmentScanQrManualTitle => 'Saisir l\'identifiant manuellement';

  @override
  String get equipmentScanQrManualHint =>
      'ID ou numéro de série de l\'équipement';

  @override
  String get equipmentScanQrNotFound =>
      'Aucun équipement trouvé pour cet identifiant';

  @override
  String get equipmentCsvShared => 'Fichier CSV prêt à partager';

  @override
  String get equipmentCsvShareError => 'Erreur lors du partage du CSV';

  @override
  String get issueFormStep1Label => 'Étape 1 / 2 — Catégorie & Équipement';

  @override
  String get issueFormStep2Label => 'Étape 2 / 2 — Description & Photos';

  @override
  String get issueFormScanBlock => 'Signaler par QR Code';

  @override
  String get issueFormScanBlockTooltip =>
      'Mode ultra-rapide : scanner → urgence Critique → 2 champs à remplir';

  @override
  String get issueFormScanBlockUrgencySet =>
      'Urgence mise à Critique — complétez la description';

  @override
  String get issueFormUnlistedEquipment => 'Équipement non répertorié';

  @override
  String get issueFormUnlistedEquipmentNameLabel => 'Nom de l\'équipement';

  @override
  String get issueFormUnlistedEquipmentHint =>
      'Ex : Respirateur salle 3, Moniteur lit 12...';

  @override
  String get issueFormUnlistedEquipmentRequired =>
      'Veuillez saisir le nom de l\'équipement';

  @override
  String get issueFormUnlistedWarning =>
      'Le technicien devra identifier cet équipement sur site.';

  @override
  String get issueFormPhotoGuide =>
      'Conseil : photographiez l\'écran d\'erreur, l\'étiquette de l\'équipement ou la zone défaillante.';

  @override
  String get notifPrefsTitle => 'Alertes emails — Incidents critiques';

  @override
  String get notifPrefsSubtitle =>
      'Toutes les notifications portent sur les incidents de niveau Critique uniquement.';

  @override
  String get notifPrefsScope => 'Incidents de niveau Critique seulement';

  @override
  String get notifPrefsFirstSetupSubtitle =>
      'Bienvenue ! Configurez vos alertes email.';

  @override
  String get notifPrefsSkip => 'Ignorer';

  @override
  String get notifPrefsUpdated => 'Préférences d\'alerte mises à jour';

  @override
  String get notifPrefsAllEnabled => 'Toutes les alertes activées';

  @override
  String get notifPrefsSomeEnabled => 'Alertes partiellement activées';

  @override
  String get notifPrefsAllDisabled => 'Toutes les alertes désactivées';

  @override
  String get notifPrefsSectionTechnician => 'Alertes technicien';

  @override
  String get notifPrefsSectionSupervisor => 'Alertes superviseur';

  @override
  String get notifPrefsCriticalNewIssue => 'Nouvel incident critique signalé';

  @override
  String get notifPrefsCriticalNewIssueDesc =>
      'Email dès qu\'un incident CRITIQUE est signalé dans votre groupe technique.';

  @override
  String get notifPrefsCriticalAcknowledged =>
      'Incident critique pris en charge';

  @override
  String get notifPrefsCriticalAcknowledgedDesc =>
      'Email quand un technicien prend en charge un incident critique.';

  @override
  String get notifPrefsCriticalDiagnosed =>
      'Diagnostic posé sur un incident critique';

  @override
  String get notifPrefsCriticalDiagnosedDesc =>
      'Email dès qu\'un technicien renseigne le diagnostic d\'un incident critique.';

  @override
  String get notifPrefsCriticalResolved =>
      'Incident critique résolu (avec KPIs)';

  @override
  String get notifPrefsCriticalResolvedDesc =>
      'Email de clôture avec délai de résolution, diagnostic, actions et pièces remplacées.';

  @override
  String get notifPrefsPmDue => 'Maintenance préventive à planifier';

  @override
  String get notifPrefsPmDueDesc =>
      'Email quand une maintenance préventive est en retard ou imminente.';

  @override
  String get reportsPdfExportTooltip => 'Générer et télécharger le rapport PDF';

  @override
  String get reportsPdfSuccess =>
      'Rapport PDF prêt — enregistrez-le depuis la boîte de dialogue';

  @override
  String get reportsPdfError => 'Erreur lors de la génération du PDF';

  @override
  String get navDebugTest => 'Debug & Test';

  @override
  String get navDebugTestShort => 'Debug';

  @override
  String get debugTitle => 'Module Debug & Test';

  @override
  String get debugSubtitle =>
      'Réservé aux administrateurs — actions irréversibles sur les données';

  @override
  String get debugDbSection => 'Gestion de la Base de Données';

  @override
  String get debugClearIssuesLabel =>
      'Nettoyer tous les signalements d\'incidents';

  @override
  String get debugClearIssuesDesc =>
      'Supprime définitivement tous les incidents de la base de données. Cette action est irréversible.';

  @override
  String get debugClearIssuesButton => 'Nettoyer tous les signalements';

  @override
  String get debugClearIssuesLoading => 'Nettoyage en cours...';

  @override
  String get debugClearIssuesTitle => 'Confirmer le nettoyage';

  @override
  String get debugClearIssuesMessage =>
      'Cette action va supprimer TOUS les incidents de la base de données. Cette opération est irréversible et ne peut pas être annulée.';

  @override
  String get debugClearIssuesConfirm => 'Tout supprimer';

  @override
  String debugClearIssuesSuccess(int count) {
    return '$count incident(s) supprimé(s) avec succès';
  }

  @override
  String debugClearIssuesError(String error) {
    return 'Erreur lors du nettoyage : $error';
  }

  @override
  String get reportsArchivesSectionTitle => 'Archives & Rapports Historiques';

  @override
  String get reportsArchivesTypeMonthly => 'Mensuel';

  @override
  String get reportsArchivesTypeAnnual => 'Annuel';

  @override
  String get reportsArchivesDownload => 'Télécharger le rapport PDF';

  @override
  String get reportsArchivesDownloading => 'Génération en cours…';

  @override
  String get reportsArchivesHint =>
      'Sélectionnez une période pour télécharger un rapport historique au format PDF.';

  @override
  String get pmProtocols => 'Protocoles de maintenance';

  @override
  String get pmChecklist => 'Checklist de maintenance';

  @override
  String pmStepsProgress(int done, int total) {
    return '$done / $total étapes validées';
  }

  @override
  String get pmNoProtocolAvailable =>
      'Aucun protocole défini pour ce type d\'équipement';

  @override
  String get pmFrequencyLabel => 'Fréquence de maintenance';

  @override
  String pmFrequencyValue(int months) {
    return 'Tous les $months mois';
  }

  @override
  String pmDurationEstimated(int min) {
    return 'Durée estimée : $min min';
  }

  @override
  String pmDurationActual(int min) {
    return 'Durée réelle : $min min';
  }

  @override
  String get pmValidateButton => 'Valider la maintenance préventive';

  @override
  String get pmValidateConfirmTitle => 'Confirmer la validation';

  @override
  String pmValidateConfirmBody(int unchecked) {
    return '$unchecked étape(s) non cochée(s). Valider quand même ?';
  }

  @override
  String get pmValidateSuccess => 'Maintenance enregistrée';

  @override
  String pmNextDate(String date) {
    return 'Prochaine maintenance : $date';
  }

  @override
  String get pmPrintLabel => 'Imprimer l\'étiquette';

  @override
  String get pmEditLabel => 'Étiquette de maintenance';

  @override
  String get pmHistoryTitle => 'Historique des maintenances préventives';

  @override
  String pmComplianceRate(int rate) {
    return 'Conformité : $rate%';
  }

  @override
  String get pmPartsUsed => 'Pièces utilisées';

  @override
  String get pmSeeAll => 'Voir tout';

  @override
  String get pmFrequencySaved => 'Fréquence de maintenance mise à jour';

  @override
  String get pmFrequencySelectLabel => 'Définir la fréquence PM';

  @override
  String get docTabTitle => 'Documents';

  @override
  String get docTechnicalSection => 'Documents techniques';

  @override
  String get docInterventionSection => 'Documents d\'intervention';

  @override
  String get docCertificationSection => 'Certificats & Conformité';

  @override
  String get docAddButton => 'Ajouter un document';

  @override
  String get docTypeLabel => 'Type de document';

  @override
  String get docTypeTechnical => 'Manuel / Fiche technique';

  @override
  String get docTypeIntervention => 'Rapport / Facture';

  @override
  String get docTypeCertification => 'Certificat / Conformité';

  @override
  String get docUploadSuccess => 'Document ajouté avec succès';

  @override
  String docUploadError(String error) {
    return 'Échec de l\'upload : $error';
  }

  @override
  String get docDeleteConfirmTitle => 'Supprimer ce document ?';

  @override
  String get docDeleteConfirmBody => 'Cette action est irréversible.';

  @override
  String get docDeleteSuccess => 'Document supprimé';

  @override
  String get docDownloadError => 'Impossible d\'ouvrir le document';

  @override
  String get docNoDocuments => 'Aucun document dans cette section';

  @override
  String get docRestrictedAccess =>
      'Accès réservé aux techniciens et superviseurs';

  @override
  String get issuePhotosSection => 'Photos de l\'incident';

  @override
  String get issuePhotoLimitReached => 'Limite de 5 photos atteinte';

  @override
  String get issuePhotoCompressing => 'Compression en cours…';

  @override
  String get issuePhotosUploading => 'Envoi des photos…';

  @override
  String get issuePhotosNoPhotos => 'Aucune photo jointe';

  @override
  String get showMore => 'Afficher plus';

  @override
  String get allEquipmentDisplayed => 'Tous les équipements sont affichés';

  @override
  String get issueStaffDetailTitle => 'Suivi de mon signalement';

  @override
  String get issueTimelineReported => 'Signalé';

  @override
  String get issueTimelineAcknowledged => 'Pris en charge';

  @override
  String get issueTimelineInProgress => 'En cours de réparation';

  @override
  String get issueTimelineResolved => 'Résolu';

  @override
  String get sidebarTitleEquipment => 'Gestion des équipements';

  @override
  String get sidebarTitleSettings => 'Configuration';

  @override
  String get sidebarTitleInventory => 'Inventaire';

  @override
  String get sidebarTitleReports => 'Rapports';

  @override
  String get see => 'Voir';

  @override
  String get exportingPdf => 'Génération du PDF…';

  @override
  String get exportError => 'Erreur lors de l\'export. Réessayez.';

  @override
  String get pushBannerTitle => 'Notifications désactivées';

  @override
  String get pushBannerBody =>
      'Activez les notifications pour recevoir les alertes critiques en temps réel.';

  @override
  String get pushBannerActivate => 'Activer';

  @override
  String get debugNotifySection => 'Tests de Notifications';

  @override
  String debugNotifyWarning(String interval) {
    return 'Scheduling actif ($interval). Sera réinitialisé au prochain redémarrage du serveur.';
  }

  @override
  String get debugNotifyNow => 'Notification immédiate';

  @override
  String get debugNotifyMinute => 'Notif auto (toutes les minutes)';

  @override
  String get debugNotifyHour => 'Notif auto (toutes les heures)';

  @override
  String get debugNotifyStop => 'Stopper les notifs auto';

  @override
  String debugNotifySent(String email) {
    return 'Notification envoyée à $email';
  }

  @override
  String debugNotifyStarted(String interval) {
    return 'Notifications auto activées ($interval)';
  }

  @override
  String get debugNotifyStopped => 'Notifications auto arrêtées';

  @override
  String get debugNotifyAlreadyStopped => 'Aucune notification auto en cours';

  @override
  String get notificationsBell => 'Notifications';

  @override
  String notificationsUnread(int count) {
    return '$count non lue(s)';
  }

  @override
  String get notificationsMarkAllRead => 'Tout marquer comme lu';

  @override
  String get notificationsEmpty => 'Aucune notification';

  @override
  String get notificationsOsPermissionDenied =>
      'Notifications système désactivées. Activez-les dans les paramètres.';

  @override
  String get notificationsTitleNewIssue => 'Nouvel incident signalé';

  @override
  String get notificationsTitleCritical => 'Incident critique';

  @override
  String get roleDetailOpenButton => 'Détails';

  @override
  String get roleDetailTabHierarchy => 'Hiérarchie';

  @override
  String get roleDetailTabFeatures => 'Fonctionnalités';

  @override
  String get roleDetailTabMenu => 'Menu';

  @override
  String get roleDetailTabUsers => 'Utilisateurs';

  @override
  String get roleDetailParentRole => 'Rôle parent';

  @override
  String get roleDetailNoParent => 'Rôle racine (aucun parent)';

  @override
  String get roleDetailChildRoles => 'Rôles enfants';

  @override
  String get roleDetailNoChildren => 'Aucun rôle enfant';

  @override
  String get roleDetailNoUsers => 'Aucun utilisateur avec ce rôle';

  @override
  String roleDetailUsersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utilisateurs',
      one: '1 utilisateur',
      zero: 'Aucun utilisateur',
    );
    return '$_temp0';
  }

  @override
  String get roleDetailSavedSuccess => 'Configuration sauvegardée';

  @override
  String get roleDetailSaveError => 'Erreur lors de la sauvegarde';

  @override
  String get roleDetailOffline => 'Mode hors ligne — modifications désactivées';

  @override
  String roleDetailInheritedFrom(String role) {
    return 'Hérité de $role';
  }

  @override
  String get roleDetailAdminLocked =>
      'Les permissions de l\'Administrateur sont verrouillées.';

  @override
  String get roleDetailMenuVisible =>
      'Éléments visibles (ordre par glisser-déposer)';

  @override
  String get roleDetailMenuHidden => 'Éléments masqués';

  @override
  String get replacementStatusDue => 'À remplacer';

  @override
  String get replacementStatusSoon => 'Bientôt à remplacer';

  @override
  String get replacementStatusUnknown => 'Donnée manquante';

  @override
  String replacementTooltipDue(
    Object age,
    Object lifespan,
    String criticality,
  ) {
    return 'À remplacer — $age ans / réf. $lifespan ans (Crit. $criticality)';
  }

  @override
  String replacementTooltipSoon(
    Object age,
    Object lifespan,
    String criticality,
  ) {
    return 'Bientôt — $age ans / réf. $lifespan ans (Crit. $criticality)';
  }

  @override
  String get replacementTooltipUnknown =>
      'Durée de vie de référence non définie pour cette sous-catégorie';

  @override
  String get replacementHorizonThisYear => 'Cette année';

  @override
  String get replacementHorizon12Years => '1–2 ans';

  @override
  String get replacementHorizonLater => 'Plus tard';

  @override
  String get replacementHorizonUnknown => 'Non planifiable';

  @override
  String get subcategoryLifespanLabel => 'Durée de vie de réf. (ans)';

  @override
  String get subcategoryLifespanHint => 'Années';

  @override
  String get subcategoryLifespanUndefinedTooltip =>
      'Durée de vie de référence non définie';

  @override
  String get subcategoryLifespanSaved => 'Durée de vie enregistrée';

  @override
  String get subcategoryLifespanInvalid => 'Saisir un entier positif';

  @override
  String get subcategoryDetailTitle => 'Détail de la sous-catégorie';

  @override
  String get subcategoryDetailLifespanSection => 'Durée de vie de référence';

  @override
  String get subcategoryDetailAlertsSection => 'Notifications';

  @override
  String get subcategoryDetailNoAlerts => 'Aucune alerte';

  @override
  String subcategoryDetailEquipmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count équipements',
      one: '1 équipement',
      zero: 'Aucun équipement',
    );
    return '$_temp0';
  }

  @override
  String get equipmentDetailAlertsTitle => 'Notifications';

  @override
  String get equipmentDetailNoAlerts => 'Aucune alerte';

  @override
  String get replacementPlanReportButton => 'Plan de remplacement';

  @override
  String get replacementPlanReportTooltip =>
      'Exporter le plan de remplacement des équipements biomédicaux (PDF)';

  @override
  String get replacementPlanReportProgress => 'Génération…';

  @override
  String get replacementPlanReportError =>
      'Erreur lors de la génération du plan de remplacement';

  @override
  String get replacementPlanReportEmpty =>
      'Aucun équipement biomédical à planifier';

  @override
  String get commonOpen => 'Ouvrir';

  @override
  String get docOpenNativeUnsupported =>
      'ouverture PDF non supportée sur cette plateforme';

  @override
  String get equipmentTabList => 'Liste';

  @override
  String get equipmentTabCategories => 'Catégories';

  @override
  String get subcategoryEquipmentSection => 'Équipements';

  @override
  String get subcategoryBrandsSection => 'Fabricants';

  @override
  String get subcategoryNoBrands => 'Aucun fabricant pour cette sous-catégorie';

  @override
  String get brandDetailTitle => 'Détail du fabricant';

  @override
  String get brandModelsSection => 'Modèles';

  @override
  String get brandNoModels => 'Aucun modèle pour ce fabricant';

  @override
  String get categoryDetailTitle => 'Détail de la catégorie';

  @override
  String get departmentDetailTitle => 'Détail du département';

  @override
  String get departmentOpenIssuesSection => 'Incidents ouverts';

  @override
  String get modelDetailTitle => 'Fiche du modèle';

  @override
  String get modelEquipmentSection => 'Équipements';

  @override
  String get modelDocumentsSection => 'Documents';

  @override
  String get modelProtocolsSection => 'Protocoles PM';

  @override
  String get modelNoProtocols => 'Aucun protocole lié';

  @override
  String catalogBrandCounts(int models, int equipment) {
    return '$models modèle(s) · $equipment équipement(s)';
  }

  @override
  String catalogProtocolFrequency(int months) {
    return 'Tous les $months mois';
  }

  @override
  String get catalogAddBrand => 'Ajouter un fabricant';

  @override
  String get catalogRenameBrand => 'Renommer le fabricant';

  @override
  String get catalogBrandName => 'Nom du fabricant';

  @override
  String get catalogBrandRenamed => 'Fabricant renommé';

  @override
  String get catalogAddModel => 'Ajouter un modèle';

  @override
  String get catalogRenameModel => 'Renommer le modèle';

  @override
  String get catalogModelName => 'Nom du modèle';

  @override
  String get catalogModelAdded => 'Modèle ajouté';

  @override
  String get catalogModelRenamed => 'Modèle renommé';

  @override
  String get catalogDeleteModel => 'Supprimer le modèle';

  @override
  String get catalogModelDeleted => 'Modèle supprimé';

  @override
  String get catalogDeleteBlockedTooltip =>
      'Suppression impossible : des équipements sont rattachés';

  @override
  String get catalogLinkProtocol => 'Lier un protocole';

  @override
  String get catalogUnlinkProtocol => 'Délier le protocole';

  @override
  String get catalogProtocolLinked => 'Protocole lié';

  @override
  String get catalogProtocolUnlinked => 'Protocole délié';

  @override
  String get catalogNoProtocolToLink => 'Aucun protocole disponible à lier';

  @override
  String get interventionReportSection => 'Rapport d\'intervention';

  @override
  String get interventionReportDraftBadge => 'Brouillon';

  @override
  String get interventionReportFinalizedBadge => 'Finalisé';

  @override
  String get interventionReportLoadError =>
      'Erreur lors du chargement du rapport';

  @override
  String get interventionReportPrefillTitle =>
      'Données de l\'incident (lecture seule)';

  @override
  String get interventionReportSummaryLabel => 'Résumé de l\'intervention';

  @override
  String get interventionReportSummaryHint =>
      'Décrivez ce qui a été réalisé sur l\'équipement';

  @override
  String get interventionReportRootCauseLabel => 'Cause racine';

  @override
  String get interventionReportRootCauseHint => 'Origine du problème';

  @override
  String get interventionReportRecommendationsLabel => 'Recommandations';

  @override
  String get interventionReportRecommendationsHint =>
      'Mesures préventives, pièces à prévoir…';

  @override
  String get interventionReportDurationLabel => 'Durée (heures)';

  @override
  String get interventionReportReturnedAtLabel => 'Remise en service le';

  @override
  String get interventionReportCostLabel => 'Coût estimé (RWF)';

  @override
  String get interventionReportFinalStatusLabel =>
      'État final de l\'équipement';

  @override
  String get interventionReportAuthorLabel => 'Rédigé par';

  @override
  String get interventionReportValidatedByLabel => 'Validé par';

  @override
  String get interventionReportSaveButton => 'Enregistrer';

  @override
  String get interventionReportSaved => 'Rapport enregistré';

  @override
  String get interventionReportSaveError => 'Erreur lors de l\'enregistrement';

  @override
  String get interventionReportFinalizeButton => 'Finaliser';

  @override
  String get interventionReportFinalized => 'Rapport finalisé et archivé';

  @override
  String get interventionReportFinalizeError =>
      'Finalisation impossible (incident non résolu ?)';

  @override
  String get interventionReportReopenButton => 'Rouvrir';

  @override
  String get interventionReportReopened => 'Rapport rouvert';

  @override
  String get interventionReportReopenError => 'Réouverture impossible';

  @override
  String get interventionReportExportButton => 'Exporter PDF';

  @override
  String get interventionReportExportError =>
      'Erreur lors de la génération du PDF';

  @override
  String get interventionReportArchived =>
      'PDF archivé dans la fiche équipement';

  @override
  String get interventionReportLockedHint =>
      'Rapport finalisé : modification réservée aux administrateurs';

  @override
  String get interventionReportEmptyReadonly =>
      'Aucun rapport d\'intervention n\'a encore été rédigé';

  @override
  String get reportsMaintenanceCost => 'Coût de maintenance';

  @override
  String get reportsMaintenanceCostHint =>
      'Somme des rapports finalisés (période)';
}
