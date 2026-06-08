import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Equipements - Kabutare Hospital'**
  String get appTitle;

  /// No description provided for @hospitalName.
  ///
  /// In fr, this message translates to:
  /// **'Kabutare Hospital'**
  String get hospitalName;

  /// No description provided for @hospitalSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gestion Equipements'**
  String get hospitalSubtitle;

  /// No description provided for @hospitalSubtitleLong.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Equipements'**
  String get hospitalSubtitleLong;

  /// No description provided for @loadingData.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des données...'**
  String get loadingData;

  /// No description provided for @navDashboard.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get navDashboard;

  /// No description provided for @navEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Equipements'**
  String get navEquipment;

  /// No description provided for @navIssueTracking.
  ///
  /// In fr, this message translates to:
  /// **'Suivi incidents'**
  String get navIssueTracking;

  /// No description provided for @navReportIssue.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get navReportIssue;

  /// No description provided for @navTechnician.
  ///
  /// In fr, this message translates to:
  /// **'Technicien'**
  String get navTechnician;

  /// No description provided for @navInventory.
  ///
  /// In fr, this message translates to:
  /// **'Inventaire'**
  String get navInventory;

  /// No description provided for @navReports.
  ///
  /// In fr, this message translates to:
  /// **'Rapports'**
  String get navReports;

  /// No description provided for @navUsers.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs'**
  String get navUsers;

  /// No description provided for @navSettings.
  ///
  /// In fr, this message translates to:
  /// **'Admin'**
  String get navSettings;

  /// No description provided for @navLogs.
  ///
  /// In fr, this message translates to:
  /// **'Journaux'**
  String get navLogs;

  /// No description provided for @navLogsShort.
  ///
  /// In fr, this message translates to:
  /// **'Logs'**
  String get navLogsShort;

  /// No description provided for @navDashboardShort.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navDashboardShort;

  /// No description provided for @navEquipmentShort.
  ///
  /// In fr, this message translates to:
  /// **'Equip.'**
  String get navEquipmentShort;

  /// No description provided for @navIssueTrackingShort.
  ///
  /// In fr, this message translates to:
  /// **'Incidents'**
  String get navIssueTrackingShort;

  /// No description provided for @navReportIssueShort.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get navReportIssueShort;

  /// No description provided for @navTechnicianShort.
  ///
  /// In fr, this message translates to:
  /// **'Technicien'**
  String get navTechnicianShort;

  /// No description provided for @navInventoryShort.
  ///
  /// In fr, this message translates to:
  /// **'Inventaire'**
  String get navInventoryShort;

  /// No description provided for @navReportsShort.
  ///
  /// In fr, this message translates to:
  /// **'Rapports'**
  String get navReportsShort;

  /// No description provided for @navUsersShort.
  ///
  /// In fr, this message translates to:
  /// **'Usagers'**
  String get navUsersShort;

  /// No description provided for @navSettingsShort.
  ///
  /// In fr, this message translates to:
  /// **'Admin'**
  String get navSettingsShort;

  /// No description provided for @tooltipBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get tooltipBack;

  /// No description provided for @tooltipMenu.
  ///
  /// In fr, this message translates to:
  /// **'Menu'**
  String get tooltipMenu;

  /// No description provided for @tooltipAccountSettings.
  ///
  /// In fr, this message translates to:
  /// **'Parametres du compte'**
  String get tooltipAccountSettings;

  /// No description provided for @tooltipNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get tooltipNotifications;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Se deconnecter'**
  String get logout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Deconnexion'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Etes-vous sur de vouloir vous deconnecter ?'**
  String get logoutConfirmMessage;

  /// No description provided for @accessDenied.
  ///
  /// In fr, this message translates to:
  /// **'Acces refuse'**
  String get accessDenied;

  /// No description provided for @accessDeniedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas les permissions necessaires pour acceder a cette page.'**
  String get accessDeniedMessage;

  /// No description provided for @accessDeniedNav.
  ///
  /// In fr, this message translates to:
  /// **'Acces refuse: vous n\'avez pas la permission d\'acceder a \"{target}\"'**
  String accessDeniedNav(String target);

  /// No description provided for @backToDashboard.
  ///
  /// In fr, this message translates to:
  /// **'Retour au tableau de bord'**
  String get backToDashboard;

  /// No description provided for @user.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get user;

  /// No description provided for @commonAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get commonAll;

  /// No description provided for @commonCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get commonSave;

  /// No description provided for @commonAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get commonAdd;

  /// No description provided for @commonDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get commonClose;

  /// No description provided for @commonSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher...'**
  String get commonSearch;

  /// No description provided for @commonError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get commonError;

  /// No description provided for @commonDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails'**
  String get commonDetails;

  /// No description provided for @commonReport.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get commonReport;

  /// No description provided for @commonActions.
  ///
  /// In fr, this message translates to:
  /// **'Actions'**
  String get commonActions;

  /// No description provided for @commonStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get commonStatus;

  /// No description provided for @commonCategory.
  ///
  /// In fr, this message translates to:
  /// **'Categorie'**
  String get commonCategory;

  /// No description provided for @commonDepartment.
  ///
  /// In fr, this message translates to:
  /// **'Departement'**
  String get commonDepartment;

  /// No description provided for @commonName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get commonName;

  /// No description provided for @commonEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get commonEmail;

  /// No description provided for @commonRole.
  ///
  /// In fr, this message translates to:
  /// **'Role'**
  String get commonRole;

  /// No description provided for @commonDefault.
  ///
  /// In fr, this message translates to:
  /// **'Par defaut'**
  String get commonDefault;

  /// No description provided for @commonAbbreviation.
  ///
  /// In fr, this message translates to:
  /// **'Abreviation'**
  String get commonAbbreviation;

  /// No description provided for @commonFillRequiredFields.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez remplir les champs obligatoires'**
  String get commonFillRequiredFields;

  /// No description provided for @commonFillAllFields.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez remplir tous les champs'**
  String get commonFillAllFields;

  /// No description provided for @commonIrreversible.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irreversible.'**
  String get commonIrreversible;

  /// No description provided for @commonCreate.
  ///
  /// In fr, this message translates to:
  /// **'Creer'**
  String get commonCreate;

  /// No description provided for @commonConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get commonConfirm;

  /// No description provided for @loginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get loginTitle;

  /// No description provided for @loginEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginEmailRequired.
  ///
  /// In fr, this message translates to:
  /// **'Email requis'**
  String get loginEmailRequired;

  /// No description provided for @loginPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get loginPassword;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe requis'**
  String get loginPasswordRequired;

  /// No description provided for @loginSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get loginSubmit;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Identifiants incorrects'**
  String get loginInvalidCredentials;

  /// No description provided for @dashboardTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get dashboardTitle;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vue d\'ensemble de la gestion des equipements'**
  String get dashboardSubtitle;

  /// No description provided for @dashboardViewEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Voir les equipements'**
  String get dashboardViewEquipment;

  /// No description provided for @dashboardReportProblem.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un probleme'**
  String get dashboardReportProblem;

  /// No description provided for @dashboardViewIssues.
  ///
  /// In fr, this message translates to:
  /// **'Voir les incidents'**
  String get dashboardViewIssues;

  /// No description provided for @dashboardTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get dashboardTotal;

  /// No description provided for @dashboardOperational.
  ///
  /// In fr, this message translates to:
  /// **'Operationnels'**
  String get dashboardOperational;

  /// No description provided for @dashboardMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance'**
  String get dashboardMaintenance;

  /// No description provided for @dashboardOutOfService.
  ///
  /// In fr, this message translates to:
  /// **'Hors Service'**
  String get dashboardOutOfService;

  /// No description provided for @dashboardEquipmentStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut des equipements'**
  String get dashboardEquipmentStatus;

  /// No description provided for @dashboardOperationalStatus.
  ///
  /// In fr, this message translates to:
  /// **'Operationnel'**
  String get dashboardOperationalStatus;

  /// No description provided for @dashboardInMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'En maintenance'**
  String get dashboardInMaintenance;

  /// No description provided for @dashboardOutOfServiceStatus.
  ///
  /// In fr, this message translates to:
  /// **'Hors service'**
  String get dashboardOutOfServiceStatus;

  /// No description provided for @dashboardRecentIssues.
  ///
  /// In fr, this message translates to:
  /// **'Derniers incidents signales'**
  String get dashboardRecentIssues;

  /// No description provided for @dashboardNoIssues.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident en cours'**
  String get dashboardNoIssues;

  /// No description provided for @dashboardViewAllIssues.
  ///
  /// In fr, this message translates to:
  /// **'Voir tous les incidents'**
  String get dashboardViewAllIssues;

  /// No description provided for @dashboardUrgentAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Alertes urgentes'**
  String get dashboardUrgentAlerts;

  /// No description provided for @dashboardNoAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Aucune alerte urgente'**
  String get dashboardNoAlerts;

  /// No description provided for @dashboardCriticalFailure.
  ///
  /// In fr, this message translates to:
  /// **'Panne critique'**
  String get dashboardCriticalFailure;

  /// No description provided for @dashboardOpenIssue.
  ///
  /// In fr, this message translates to:
  /// **'Incident ouvert'**
  String get dashboardOpenIssue;

  /// No description provided for @equipmentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Liste des equipements'**
  String get equipmentTitle;

  /// No description provided for @equipmentSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gestion et suivi de tous les equipements'**
  String get equipmentSubtitle;

  /// No description provided for @equipmentNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel equipement'**
  String get equipmentNew;

  /// No description provided for @equipmentName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'equipement'**
  String get equipmentName;

  /// No description provided for @equipmentSerialNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numero de serie'**
  String get equipmentSerialNumber;

  /// No description provided for @equipmentFound.
  ///
  /// In fr, this message translates to:
  /// **'{count} equipement(s) trouve(s)'**
  String equipmentFound(int count);

  /// No description provided for @equipmentEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'equipement'**
  String get equipmentEditTitle;

  /// No description provided for @equipmentNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel equipement'**
  String get equipmentNewTitle;

  /// No description provided for @equipmentNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'equipement *'**
  String get equipmentNameLabel;

  /// No description provided for @equipmentNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Scanner IRM Siemens'**
  String get equipmentNameHint;

  /// No description provided for @equipmentSerialLabel.
  ///
  /// In fr, this message translates to:
  /// **'Numero de serie *'**
  String get equipmentSerialLabel;

  /// No description provided for @equipmentSerialHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: SN-2023-001'**
  String get equipmentSerialHint;

  /// No description provided for @equipmentDepartmentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Departement *'**
  String get equipmentDepartmentLabel;

  /// No description provided for @equipmentCategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Categorie *'**
  String get equipmentCategoryLabel;

  /// No description provided for @equipmentSupplier.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur'**
  String get equipmentSupplier;

  /// No description provided for @equipmentSupplierHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Siemens Healthineers'**
  String get equipmentSupplierHint;

  /// No description provided for @equipmentLocation.
  ///
  /// In fr, this message translates to:
  /// **'Localisation'**
  String get equipmentLocation;

  /// No description provided for @equipmentLocationHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Batiment A, Salle 101'**
  String get equipmentLocationHint;

  /// No description provided for @equipmentModified.
  ///
  /// In fr, this message translates to:
  /// **'Equipement modifie'**
  String get equipmentModified;

  /// No description provided for @equipmentAdded.
  ///
  /// In fr, this message translates to:
  /// **'Equipement ajoute'**
  String get equipmentAdded;

  /// No description provided for @equipmentSaveChanges.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les modifications'**
  String get equipmentSaveChanges;

  /// No description provided for @equipmentAddButton.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter l\'equipement'**
  String get equipmentAddButton;

  /// No description provided for @equipmentDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'equipement'**
  String get equipmentDeleteTitle;

  /// No description provided for @equipmentDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la suppression de \"{name}\" ? Cette action est irreversible.'**
  String equipmentDeleteConfirm(String name);

  /// No description provided for @equipmentDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Equipement supprime'**
  String get equipmentDeleted;

  /// No description provided for @equipmentMaintenanceHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique de maintenance'**
  String get equipmentMaintenanceHistory;

  /// No description provided for @equipmentReportProblem.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un probleme'**
  String get equipmentReportProblem;

  /// No description provided for @issuesApproved.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get issuesApproved;

  /// No description provided for @issuesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suivi des incidents'**
  String get issuesTitle;

  /// No description provided for @issuesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gerer et suivre les incidents des equipements'**
  String get issuesSubtitle;

  /// No description provided for @issuesOpen.
  ///
  /// In fr, this message translates to:
  /// **'Signalés'**
  String get issuesOpen;

  /// No description provided for @issuesInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get issuesInProgress;

  /// No description provided for @issuesResolved.
  ///
  /// In fr, this message translates to:
  /// **'Terminés'**
  String get issuesResolved;

  /// No description provided for @issuesReport.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un incident'**
  String get issuesReport;

  /// No description provided for @issuesFilterByStatus.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer par statut: '**
  String get issuesFilterByStatus;

  /// No description provided for @issuesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} incident(s)'**
  String issuesCount(int count);

  /// No description provided for @issuesMyIssues.
  ///
  /// In fr, this message translates to:
  /// **'Mes incidents'**
  String get issuesMyIssues;

  /// No description provided for @issuesMyIssuesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Incidents que vous avez soumis'**
  String get issuesMyIssuesSubtitle;

  /// No description provided for @issuesNoMyIssues.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore signale d\'incident'**
  String get issuesNoMyIssues;

  /// No description provided for @issuesDeptIssues.
  ///
  /// In fr, this message translates to:
  /// **'Incidents de mon departement'**
  String get issuesDeptIssues;

  /// No description provided for @issuesDeptIssuesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Departement: {dept}'**
  String issuesDeptIssuesSubtitle(String dept);

  /// No description provided for @issuesNoDeptIssues.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident signale dans votre departement'**
  String get issuesNoDeptIssues;

  /// No description provided for @issuesAndMore.
  ///
  /// In fr, this message translates to:
  /// **'... et {count} autre(s)'**
  String issuesAndMore(int count);

  /// No description provided for @issuesAllIssues.
  ///
  /// In fr, this message translates to:
  /// **'Tous les incidents'**
  String get issuesAllIssues;

  /// No description provided for @issuesIncidentId.
  ///
  /// In fr, this message translates to:
  /// **'Incident #{id}'**
  String issuesIncidentId(String id);

  /// No description provided for @issuesEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Equipement'**
  String get issuesEquipment;

  /// No description provided for @issuesType.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get issuesType;

  /// No description provided for @issuesDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get issuesDescription;

  /// No description provided for @issuesReportedBy.
  ///
  /// In fr, this message translates to:
  /// **'Signale par'**
  String get issuesReportedBy;

  /// No description provided for @issuesReportDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de signalement'**
  String get issuesReportDate;

  /// No description provided for @issuesAssignedTech.
  ///
  /// In fr, this message translates to:
  /// **'Technicien assigne'**
  String get issuesAssignedTech;

  /// No description provided for @issuesDiagnosis.
  ///
  /// In fr, this message translates to:
  /// **'Diagnostic'**
  String get issuesDiagnosis;

  /// No description provided for @issuesUpdate.
  ///
  /// In fr, this message translates to:
  /// **'Mettre a jour'**
  String get issuesUpdate;

  /// No description provided for @issuesReportedByDate.
  ///
  /// In fr, this message translates to:
  /// **'Signale par {reporter} • {date}'**
  String issuesReportedByDate(String reporter, String date);

  /// No description provided for @issueFormTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un probleme'**
  String get issueFormTitle;

  /// No description provided for @issueFormSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Remplissez le formulaire pour signaler un probleme d\'equipement'**
  String get issueFormSubtitle;

  /// No description provided for @issueFormEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Equipement concerne *'**
  String get issueFormEquipment;

  /// No description provided for @issueFormSelectEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Selectionnez un equipement'**
  String get issueFormSelectEquipment;

  /// No description provided for @issueFormProblemType.
  ///
  /// In fr, this message translates to:
  /// **'Type de probleme *'**
  String get issueFormProblemType;

  /// No description provided for @issueFormBreakdown.
  ///
  /// In fr, this message translates to:
  /// **'Panne'**
  String get issueFormBreakdown;

  /// No description provided for @issueFormMalfunction.
  ///
  /// In fr, this message translates to:
  /// **'Dysfonctionnement'**
  String get issueFormMalfunction;

  /// No description provided for @issueFormWear.
  ///
  /// In fr, this message translates to:
  /// **'Usure'**
  String get issueFormWear;

  /// No description provided for @issueFormAbnormalNoise.
  ///
  /// In fr, this message translates to:
  /// **'Bruit anormal'**
  String get issueFormAbnormalNoise;

  /// No description provided for @issueFormLeak.
  ///
  /// In fr, this message translates to:
  /// **'Fuite'**
  String get issueFormLeak;

  /// No description provided for @issueFormOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get issueFormOther;

  /// No description provided for @issueFormDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description du probleme *'**
  String get issueFormDescription;

  /// No description provided for @issueFormDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Decrivez le probleme en detail...'**
  String get issueFormDescriptionHint;

  /// No description provided for @issueFormDescriptionRequired.
  ///
  /// In fr, this message translates to:
  /// **'La description est obligatoire'**
  String get issueFormDescriptionRequired;

  /// No description provided for @issueFormDescriptionMinLength.
  ///
  /// In fr, this message translates to:
  /// **'La description doit contenir au moins 10 caracteres'**
  String get issueFormDescriptionMinLength;

  /// No description provided for @issueFormPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Photos (optionnel)'**
  String get issueFormPhotos;

  /// No description provided for @issueFormPhotosHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez jusqu\'a {max} photos pour illustrer le probleme'**
  String issueFormPhotosHint(int max);

  /// No description provided for @issueFormAddPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get issueFormAddPhoto;

  /// No description provided for @issueFormMaxPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Maximum {max} photos autorisees'**
  String issueFormMaxPhotos(int max);

  /// No description provided for @issueFormYourName.
  ///
  /// In fr, this message translates to:
  /// **'Votre nom *'**
  String get issueFormYourName;

  /// No description provided for @issueFormYourNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Dr. Martin'**
  String get issueFormYourNameHint;

  /// No description provided for @issueFormYourNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Votre nom est obligatoire'**
  String get issueFormYourNameRequired;

  /// No description provided for @issueFormSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Soumettre le signalement'**
  String get issueFormSubmit;

  /// No description provided for @issueFormSubmitWithPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Soumettre le signalement ({count} photo(s))'**
  String issueFormSubmitWithPhotos(int count);

  /// No description provided for @issueFormLeaveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le formulaire ?'**
  String get issueFormLeaveTitle;

  /// No description provided for @issueFormLeaveMessage.
  ///
  /// In fr, this message translates to:
  /// **'Des informations ont ete saisies. Si vous quittez maintenant, elles seront perdues.'**
  String get issueFormLeaveMessage;

  /// No description provided for @issueFormLeaveConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get issueFormLeaveConfirm;

  /// No description provided for @issueFormSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Signalement envoye !'**
  String get issueFormSuccess;

  /// No description provided for @issueFormSuccessWithPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Signalement envoye ! ({count} photo(s))'**
  String issueFormSuccessWithPhotos(int count);

  /// No description provided for @issueFormError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'envoi: {error}'**
  String issueFormError(String error);

  /// No description provided for @techTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mise a jour technicien'**
  String get techTitle;

  /// No description provided for @techSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Mettre a jour le statut de reparation'**
  String get techSubtitle;

  /// No description provided for @techNoIssues.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident en cours'**
  String get techNoIssues;

  /// No description provided for @techAllResolved.
  ///
  /// In fr, this message translates to:
  /// **'Tous les incidents ont ete resolus'**
  String get techAllResolved;

  /// No description provided for @techSelectIssue.
  ///
  /// In fr, this message translates to:
  /// **'Incident a mettre a jour'**
  String get techSelectIssue;

  /// No description provided for @techSelectIssueHint.
  ///
  /// In fr, this message translates to:
  /// **'Selectionnez un incident'**
  String get techSelectIssueHint;

  /// No description provided for @techReportedByDate.
  ///
  /// In fr, this message translates to:
  /// **'Signale par {reporter} le {date}'**
  String techReportedByDate(String reporter, String date);

  /// No description provided for @techRepairStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut de reparation'**
  String get techRepairStatus;

  /// No description provided for @techDiagnosisInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Diagnostic en cours'**
  String get techDiagnosisInProgress;

  /// No description provided for @techPartsOrdered.
  ///
  /// In fr, this message translates to:
  /// **'Pieces commandees'**
  String get techPartsOrdered;

  /// No description provided for @techRepairInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Reparation en cours'**
  String get techRepairInProgress;

  /// No description provided for @techTestInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Test en cours'**
  String get techTestInProgress;

  /// No description provided for @techRepaired.
  ///
  /// In fr, this message translates to:
  /// **'Repare'**
  String get techRepaired;

  /// No description provided for @techDiagnosis.
  ///
  /// In fr, this message translates to:
  /// **'Diagnostic'**
  String get techDiagnosis;

  /// No description provided for @techDiagnosisHint.
  ///
  /// In fr, this message translates to:
  /// **'Decrivez le diagnostic...'**
  String get techDiagnosisHint;

  /// No description provided for @techActionsTaken.
  ///
  /// In fr, this message translates to:
  /// **'Actions effectuees'**
  String get techActionsTaken;

  /// No description provided for @techActionsHint.
  ///
  /// In fr, this message translates to:
  /// **'Decrivez les actions effectuees...'**
  String get techActionsHint;

  /// No description provided for @techPartsReplaced.
  ///
  /// In fr, this message translates to:
  /// **'Pieces remplacees'**
  String get techPartsReplaced;

  /// No description provided for @techPartsHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Capteur O2, Pompe a vide...'**
  String get techPartsHint;

  /// No description provided for @techSave.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder'**
  String get techSave;

  /// No description provided for @techMarkResolved.
  ///
  /// In fr, this message translates to:
  /// **'Marquer resolu'**
  String get techMarkResolved;

  /// No description provided for @techProgressSaved.
  ///
  /// In fr, this message translates to:
  /// **'Progression sauvegardee'**
  String get techProgressSaved;

  /// No description provided for @techIssueResolved.
  ///
  /// In fr, this message translates to:
  /// **'Incident marque comme resolu !'**
  String get techIssueResolved;

  /// No description provided for @inventoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Inventaire'**
  String get inventoryTitle;

  /// No description provided for @inventorySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des stocks de consommables'**
  String get inventorySubtitle;

  /// No description provided for @inventoryNewItem.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel article'**
  String get inventoryNewItem;

  /// No description provided for @inventoryCriticalStock.
  ///
  /// In fr, this message translates to:
  /// **'Attention: Stock critique'**
  String get inventoryCriticalStock;

  /// No description provided for @inventoryOutOfStockCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} article(s) en rupture'**
  String inventoryOutOfStockCount(int count);

  /// No description provided for @inventoryLowStockCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} article(s) en stock bas'**
  String inventoryLowStockCount(int count);

  /// No description provided for @inventoryFilter.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer: '**
  String get inventoryFilter;

  /// No description provided for @inventoryMedicalConsumable.
  ///
  /// In fr, this message translates to:
  /// **'Consommable medical'**
  String get inventoryMedicalConsumable;

  /// No description provided for @inventoryHygiene.
  ///
  /// In fr, this message translates to:
  /// **'Hygiene'**
  String get inventoryHygiene;

  /// No description provided for @inventoryOffice.
  ///
  /// In fr, this message translates to:
  /// **'Bureautique'**
  String get inventoryOffice;

  /// No description provided for @inventoryItemCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} articles'**
  String inventoryItemCount(int count);

  /// No description provided for @inventoryItem.
  ///
  /// In fr, this message translates to:
  /// **'Article'**
  String get inventoryItem;

  /// No description provided for @inventoryCurrentStock.
  ///
  /// In fr, this message translates to:
  /// **'Stock actuel'**
  String get inventoryCurrentStock;

  /// No description provided for @inventoryMinStock.
  ///
  /// In fr, this message translates to:
  /// **'Stock min'**
  String get inventoryMinStock;

  /// No description provided for @inventoryUnit.
  ///
  /// In fr, this message translates to:
  /// **'Unite'**
  String get inventoryUnit;

  /// No description provided for @inventoryLastRestocked.
  ///
  /// In fr, this message translates to:
  /// **'Dernier reappro'**
  String get inventoryLastRestocked;

  /// No description provided for @inventoryEditItem.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'article'**
  String get inventoryEditItem;

  /// No description provided for @inventoryNewItemTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel article'**
  String get inventoryNewItemTitle;

  /// No description provided for @inventoryNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom *'**
  String get inventoryNameLabel;

  /// No description provided for @inventoryCategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Categorie *'**
  String get inventoryCategoryLabel;

  /// No description provided for @inventoryCurrentStockLabel.
  ///
  /// In fr, this message translates to:
  /// **'Stock actuel *'**
  String get inventoryCurrentStockLabel;

  /// No description provided for @inventoryMinStockLabel.
  ///
  /// In fr, this message translates to:
  /// **'Stock minimum *'**
  String get inventoryMinStockLabel;

  /// No description provided for @inventoryUnitLabel.
  ///
  /// In fr, this message translates to:
  /// **'Unite (ex: boites) *'**
  String get inventoryUnitLabel;

  /// No description provided for @inventoryItemModified.
  ///
  /// In fr, this message translates to:
  /// **'Article modifie'**
  String get inventoryItemModified;

  /// No description provided for @inventoryItemAdded.
  ///
  /// In fr, this message translates to:
  /// **'Article ajoute'**
  String get inventoryItemAdded;

  /// No description provided for @inventoryDeleteItem.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'article'**
  String get inventoryDeleteItem;

  /// No description provided for @inventoryDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer \"{name}\" de l\'inventaire ?'**
  String inventoryDeleteConfirm(String name);

  /// No description provided for @inventoryItemDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Article supprime'**
  String get inventoryItemDeleted;

  /// No description provided for @reportsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rapports et Analyses'**
  String get reportsTitle;

  /// No description provided for @reportsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vue d\'ensemble des statistiques'**
  String get reportsSubtitle;

  /// No description provided for @reportsExport.
  ///
  /// In fr, this message translates to:
  /// **'Exporter'**
  String get reportsExport;

  /// No description provided for @reportsTotalEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Total equipements'**
  String get reportsTotalEquipment;

  /// No description provided for @reportsAvailabilityRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux disponibilite'**
  String get reportsAvailabilityRate;

  /// No description provided for @reportsTotalIssues.
  ///
  /// In fr, this message translates to:
  /// **'Total incidents'**
  String get reportsTotalIssues;

  /// No description provided for @reportsResolvedIssues.
  ///
  /// In fr, this message translates to:
  /// **'Incidents resolus'**
  String get reportsResolvedIssues;

  /// No description provided for @reportsStatusBreakdown.
  ///
  /// In fr, this message translates to:
  /// **'Repartition par statut'**
  String get reportsStatusBreakdown;

  /// No description provided for @reportsOperational.
  ///
  /// In fr, this message translates to:
  /// **'Operationnel'**
  String get reportsOperational;

  /// No description provided for @reportsInMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'En maintenance'**
  String get reportsInMaintenance;

  /// No description provided for @reportsOutOfService.
  ///
  /// In fr, this message translates to:
  /// **'Hors service'**
  String get reportsOutOfService;

  /// No description provided for @reportsByDepartment.
  ///
  /// In fr, this message translates to:
  /// **'Equipements par departement'**
  String get reportsByDepartment;

  /// No description provided for @reportsByCategory.
  ///
  /// In fr, this message translates to:
  /// **'Equipements par categorie'**
  String get reportsByCategory;

  /// No description provided for @seeMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus'**
  String get seeMore;

  /// No description provided for @seeLess.
  ///
  /// In fr, this message translates to:
  /// **'Voir moins'**
  String get seeLess;

  /// No description provided for @reportsIssueStats.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques des incidents'**
  String get reportsIssueStats;

  /// No description provided for @reportsExportData.
  ///
  /// In fr, this message translates to:
  /// **'Exporter les donnees'**
  String get reportsExportData;

  /// No description provided for @reportsExportExcel.
  ///
  /// In fr, this message translates to:
  /// **'Exporter en Excel'**
  String get reportsExportExcel;

  /// No description provided for @reportsExportPDF.
  ///
  /// In fr, this message translates to:
  /// **'Exporter en PDF'**
  String get reportsExportPDF;

  /// No description provided for @reportsExportExcelProgress.
  ///
  /// In fr, this message translates to:
  /// **'Export Excel en cours...'**
  String get reportsExportExcelProgress;

  /// No description provided for @reportsExportPDFProgress.
  ///
  /// In fr, this message translates to:
  /// **'Export PDF en cours...'**
  String get reportsExportPDFProgress;

  /// No description provided for @reportsOpenIssues.
  ///
  /// In fr, this message translates to:
  /// **'Ouverts'**
  String get reportsOpenIssues;

  /// No description provided for @reportsInProgressIssues.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get reportsInProgressIssues;

  /// No description provided for @reportsResolvedIssuesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Resolus'**
  String get reportsResolvedIssuesLabel;

  /// No description provided for @usersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des utilisateurs'**
  String get usersTitle;

  /// No description provided for @usersSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gerer les comptes et les roles des utilisateurs'**
  String get usersSubtitle;

  /// No description provided for @usersNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel utilisateur'**
  String get usersNew;

  /// No description provided for @usersTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get usersTotal;

  /// No description provided for @usersAdmins.
  ///
  /// In fr, this message translates to:
  /// **'Admins'**
  String get usersAdmins;

  /// No description provided for @usersSupervisors.
  ///
  /// In fr, this message translates to:
  /// **'Superviseurs'**
  String get usersSupervisors;

  /// No description provided for @usersTechnicians.
  ///
  /// In fr, this message translates to:
  /// **'Techniciens'**
  String get usersTechnicians;

  /// No description provided for @usersStaff.
  ///
  /// In fr, this message translates to:
  /// **'Personnel'**
  String get usersStaff;

  /// No description provided for @usersSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom ou email...'**
  String get usersSearchHint;

  /// No description provided for @usersFilterByRole.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer par role'**
  String get usersFilterByRole;

  /// No description provided for @usersUser.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get usersUser;

  /// No description provided for @usersPermissions.
  ///
  /// In fr, this message translates to:
  /// **'Permissions'**
  String get usersPermissions;

  /// No description provided for @usersEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier utilisateur'**
  String get usersEditTitle;

  /// No description provided for @usersNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel utilisateur'**
  String get usersNewTitle;

  /// No description provided for @usersFullName.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet *'**
  String get usersFullName;

  /// No description provided for @usersEmailLabel.
  ///
  /// In fr, this message translates to:
  /// **'Email *'**
  String get usersEmailLabel;

  /// No description provided for @usersNewPassword.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe (laisser vide = inchange)'**
  String get usersNewPassword;

  /// No description provided for @usersPasswordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe *'**
  String get usersPasswordLabel;

  /// No description provided for @usersPhone.
  ///
  /// In fr, this message translates to:
  /// **'Telephone'**
  String get usersPhone;

  /// No description provided for @usersModified.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur modifie'**
  String get usersModified;

  /// No description provided for @usersCreated.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur cree'**
  String get usersCreated;

  /// No description provided for @usersPermissionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Permissions — {name}'**
  String usersPermissionsTitle(String name);

  /// No description provided for @usersActivePermissions.
  ///
  /// In fr, this message translates to:
  /// **'Permissions actives:'**
  String get usersActivePermissions;

  /// No description provided for @usersAccountActivated.
  ///
  /// In fr, this message translates to:
  /// **'Compte active'**
  String get usersAccountActivated;

  /// No description provided for @usersAccountDeactivated.
  ///
  /// In fr, this message translates to:
  /// **'Compte desactive'**
  String get usersAccountDeactivated;

  /// No description provided for @usersDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'utilisateur'**
  String get usersDeleteTitle;

  /// No description provided for @usersDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le compte de \"{name}\" ? Cette action est irreversible.'**
  String usersDeleteConfirm(String name);

  /// No description provided for @usersDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur supprime'**
  String get usersDeleted;

  /// No description provided for @usersActive.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get usersActive;

  /// No description provided for @usersInactive.
  ///
  /// In fr, this message translates to:
  /// **'Inactif'**
  String get usersInactive;

  /// No description provided for @usersDisable.
  ///
  /// In fr, this message translates to:
  /// **'Desactiver'**
  String get usersDisable;

  /// No description provided for @usersEnable.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get usersEnable;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Parametres'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gerer les departements et categories d\'equipements'**
  String get settingsSubtitle;

  /// No description provided for @settingsDepartmentsTab.
  ///
  /// In fr, this message translates to:
  /// **'Departements ({count})'**
  String settingsDepartmentsTab(int count);

  /// No description provided for @settingsCategoriesTab.
  ///
  /// In fr, this message translates to:
  /// **'Categories ({count})'**
  String settingsCategoriesTab(int count);

  /// No description provided for @settingsNewDepartment.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau departement'**
  String get settingsNewDepartment;

  /// No description provided for @settingsEditDepartment.
  ///
  /// In fr, this message translates to:
  /// **'Modifier departement'**
  String get settingsEditDepartment;

  /// No description provided for @settingsDepartmentName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du departement'**
  String get settingsDepartmentName;

  /// No description provided for @settingsDepartmentNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Cardiologie'**
  String get settingsDepartmentNameHint;

  /// No description provided for @settingsShortName.
  ///
  /// In fr, this message translates to:
  /// **'Nom abrege'**
  String get settingsShortName;

  /// No description provided for @settingsShortNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Cardio'**
  String get settingsShortNameHint;

  /// No description provided for @settingsDepartmentModified.
  ///
  /// In fr, this message translates to:
  /// **'Departement modifie'**
  String get settingsDepartmentModified;

  /// No description provided for @settingsDepartmentAdded.
  ///
  /// In fr, this message translates to:
  /// **'Departement ajoute'**
  String get settingsDepartmentAdded;

  /// No description provided for @settingsNewCategory.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle categorie'**
  String get settingsNewCategory;

  /// No description provided for @settingsEditCategory.
  ///
  /// In fr, this message translates to:
  /// **'Modifier categorie'**
  String get settingsEditCategory;

  /// No description provided for @settingsCategoryName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la categorie'**
  String get settingsCategoryName;

  /// No description provided for @settingsCategoryNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Equipement radiologique'**
  String get settingsCategoryNameHint;

  /// No description provided for @settingsCategoryShortHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Radio'**
  String get settingsCategoryShortHint;

  /// No description provided for @settingsCategoryModified.
  ///
  /// In fr, this message translates to:
  /// **'Categorie modifiee'**
  String get settingsCategoryModified;

  /// No description provided for @settingsCategoryAdded.
  ///
  /// In fr, this message translates to:
  /// **'Categorie ajoutee'**
  String get settingsCategoryAdded;

  /// No description provided for @settingsDeleteDepartment.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer departement'**
  String get settingsDeleteDepartment;

  /// No description provided for @settingsDeleteCategory.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer categorie'**
  String get settingsDeleteCategory;

  /// No description provided for @settingsDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Etes-vous sur de vouloir supprimer \"{name}\" ?\n\nCette action est irreversible.'**
  String settingsDeleteConfirm(String name);

  /// No description provided for @settingsDeleted.
  ///
  /// In fr, this message translates to:
  /// **'{type} supprime'**
  String settingsDeleted(String type);

  /// No description provided for @settingsDeletedFeminine.
  ///
  /// In fr, this message translates to:
  /// **'{type} supprimee'**
  String settingsDeletedFeminine(String type);

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Changer la langue de l\'application'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsFrench.
  ///
  /// In fr, this message translates to:
  /// **'Francais'**
  String get settingsFrench;

  /// No description provided for @settingsEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get settingsEnglish;

  /// No description provided for @settingsAccountSection.
  ///
  /// In fr, this message translates to:
  /// **'Parametres du compte'**
  String get settingsAccountSection;

  /// No description provided for @settingsAccountSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gerez vos informations personnelles et preferences'**
  String get settingsAccountSubtitle;

  /// No description provided for @settingsPersonalInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations personnelles'**
  String get settingsPersonalInfo;

  /// No description provided for @settingsPersonalInfoSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier votre nom, email et telephone'**
  String get settingsPersonalInfoSubtitle;

  /// No description provided for @settingsChangePassword.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get settingsChangePassword;

  /// No description provided for @settingsChangePasswordSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier votre mot de passe de connexion'**
  String get settingsChangePasswordSubtitle;

  /// No description provided for @settingsNewPassword.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get settingsNewPassword;

  /// No description provided for @settingsConfirmPassword.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le nouveau mot de passe'**
  String get settingsConfirmPassword;

  /// No description provided for @settingsPasswordMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get settingsPasswordMismatch;

  /// No description provided for @settingsPasswordMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Minimum 6 caracteres requis'**
  String get settingsPasswordMinLength;

  /// No description provided for @settingsPasswordChanged.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe modifie avec succes'**
  String get settingsPasswordChanged;

  /// No description provided for @settingsProfileUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Profil mis a jour'**
  String get settingsProfileUpdated;

  /// No description provided for @settingsAdminSection.
  ///
  /// In fr, this message translates to:
  /// **'Administration'**
  String get settingsAdminSection;

  /// No description provided for @settingsAdminSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gerer les departements et categories d\'equipements'**
  String get settingsAdminSubtitle;

  /// No description provided for @settingsFullName.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet'**
  String get settingsFullName;

  /// No description provided for @settingsFullNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Dr. Martin'**
  String get settingsFullNameHint;

  /// No description provided for @settingsPhoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Telephone'**
  String get settingsPhoneLabel;

  /// No description provided for @settingsPhoneHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: +250 788 123 456'**
  String get settingsPhoneHint;

  /// No description provided for @settingsDepartmentHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Cardiologie'**
  String get settingsDepartmentHint;

  /// No description provided for @notifTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @notifMarkAllRead.
  ///
  /// In fr, this message translates to:
  /// **'Tout marquer comme lu'**
  String get notifMarkAllRead;

  /// No description provided for @notifEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification'**
  String get notifEmpty;

  /// No description provided for @notifNewIssue.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel incident signale'**
  String get notifNewIssue;

  /// No description provided for @notifNewIssueBody.
  ///
  /// In fr, this message translates to:
  /// **'Incident sur {equipment} ({dept})'**
  String notifNewIssueBody(String equipment, String dept);

  /// No description provided for @notifInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Votre incident est pris en charge'**
  String get notifInProgress;

  /// No description provided for @notifInProgressBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'incident sur {equipment} est en cours de traitement'**
  String notifInProgressBody(String equipment);

  /// No description provided for @notifResolved.
  ///
  /// In fr, this message translates to:
  /// **'Votre incident a ete resolu'**
  String get notifResolved;

  /// No description provided for @notifResolvedBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'incident sur {equipment} est marque comme resolu'**
  String notifResolvedBody(String equipment);

  /// No description provided for @notifTimeJustNow.
  ///
  /// In fr, this message translates to:
  /// **'A l\'instant'**
  String get notifTimeJustNow;

  /// No description provided for @notifTimeMinutes.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {n} min'**
  String notifTimeMinutes(int n);

  /// No description provided for @notifTimeHours.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {n} h'**
  String notifTimeHours(int n);

  /// No description provided for @notifTimeDays.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {n} j'**
  String notifTimeDays(int n);

  /// No description provided for @hubSelectModule.
  ///
  /// In fr, this message translates to:
  /// **'Selectionnez un module'**
  String get hubSelectModule;

  /// No description provided for @hubSelectModuleSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez le module auquel vous souhaitez acceder'**
  String get hubSelectModuleSubtitle;

  /// No description provided for @hubOpenModule.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir {title}'**
  String hubOpenModule(String title);

  /// No description provided for @issueTrackingTab.
  ///
  /// In fr, this message translates to:
  /// **'Suivi des incidents'**
  String get issueTrackingTab;

  /// No description provided for @issueValidationTab.
  ///
  /// In fr, this message translates to:
  /// **'A valider'**
  String get issueValidationTab;

  /// No description provided for @issueValidationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Incidents a valider'**
  String get issueValidationTitle;

  /// No description provided for @issueValidationSubtitleAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous les incidents ouverts en attente de validation'**
  String get issueValidationSubtitleAll;

  /// No description provided for @issueValidationSubtitleDept.
  ///
  /// In fr, this message translates to:
  /// **'Incidents ouverts du departement \"{dept}\" en attente de validation'**
  String issueValidationSubtitleDept(String dept);

  /// No description provided for @issueValidationOpenCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} incident(s) ouvert(s)'**
  String issueValidationOpenCount(int count);

  /// No description provided for @issueValidationNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident ouvert a valider'**
  String get issueValidationNone;

  /// No description provided for @issueValidationDetails.
  ///
  /// In fr, this message translates to:
  /// **'Details'**
  String get issueValidationDetails;

  /// No description provided for @issueValidationValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get issueValidationValidate;

  /// No description provided for @issueValidationConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Valider l\'incident'**
  String get issueValidationConfirmTitle;

  /// No description provided for @issueValidationConfirmContent.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la validation de l\'incident sur :'**
  String get issueValidationConfirmContent;

  /// No description provided for @issueValidationUrgencyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Niveau d\'urgence :'**
  String get issueValidationUrgencyLabel;

  /// No description provided for @issueValidationConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'incident passera au statut \"Approuve\" et sera assigne a l\'equipe technique.'**
  String get issueValidationConfirmMessage;

  /// No description provided for @issueValidationSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Incident sur \"{equipment}\" valide avec succes.'**
  String issueValidationSuccess(String equipment);

  /// No description provided for @issueValidationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la validation : {error}'**
  String issueValidationError(String error);

  /// No description provided for @issueValidationSignaledBy.
  ///
  /// In fr, this message translates to:
  /// **'Signale par {reporter} • {date}'**
  String issueValidationSignaledBy(String reporter, String date);

  /// No description provided for @issueUrgencyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Niveau d\'urgence'**
  String get issueUrgencyLabel;

  /// No description provided for @issueValidationGroupLabel.
  ///
  /// In fr, this message translates to:
  /// **'Equipe technique assignee :'**
  String get issueValidationGroupLabel;

  /// No description provided for @issueValidationGroupBiomedical.
  ///
  /// In fr, this message translates to:
  /// **'Biomedical'**
  String get issueValidationGroupBiomedical;

  /// No description provided for @issueValidationGroupIT.
  ///
  /// In fr, this message translates to:
  /// **'IT'**
  String get issueValidationGroupIT;

  /// No description provided for @issueValidationGroupInfrastructure.
  ///
  /// In fr, this message translates to:
  /// **'Infrastructure'**
  String get issueValidationGroupInfrastructure;

  /// No description provided for @issueValidationGroupNoChange.
  ///
  /// In fr, this message translates to:
  /// **'Garder l\'equipe actuelle'**
  String get issueValidationGroupNoChange;

  /// No description provided for @issueValidationRedirectLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rediriger vers une autre equipe'**
  String get issueValidationRedirectLabel;

  /// No description provided for @settingsMenuOrder.
  ///
  /// In fr, this message translates to:
  /// **'Ordre du menu'**
  String get settingsMenuOrder;

  /// No description provided for @settingsMenuOrderRole.
  ///
  /// In fr, this message translates to:
  /// **'Configurer pour le role :'**
  String get settingsMenuOrderRole;

  /// No description provided for @settingsMenuOrderHint.
  ///
  /// In fr, this message translates to:
  /// **'Faites glisser les elements pour changer leur ordre dans la barre de navigation.'**
  String get settingsMenuOrderHint;

  /// No description provided for @settingsMenuOrderReset.
  ///
  /// In fr, this message translates to:
  /// **'Reinitialiser'**
  String get settingsMenuOrderReset;

  /// No description provided for @settingsMenuOrderResetDone.
  ///
  /// In fr, this message translates to:
  /// **'Ordre par defaut restaure (non encore sauvegarde)'**
  String get settingsMenuOrderResetDone;

  /// No description provided for @settingsMenuOrderSave.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder'**
  String get settingsMenuOrderSave;

  /// No description provided for @settingsMenuOrderSaved.
  ///
  /// In fr, this message translates to:
  /// **'Ordre du menu sauvegarde'**
  String get settingsMenuOrderSaved;

  /// No description provided for @backToModules.
  ///
  /// In fr, this message translates to:
  /// **'← Modules'**
  String get backToModules;

  /// No description provided for @backToModulesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Retour aux modules'**
  String get backToModulesLabel;

  /// No description provided for @equipmentRevisionColumn.
  ///
  /// In fr, this message translates to:
  /// **'Revision'**
  String get equipmentRevisionColumn;

  /// No description provided for @accountDepartmentChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer de departement'**
  String get accountDepartmentChange;

  /// No description provided for @accountDepartmentChangeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demande de changement'**
  String get accountDepartmentChangeTitle;

  /// No description provided for @accountDepartmentChangeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre demande sera soumise a un administrateur pour validation.'**
  String get accountDepartmentChangeSubtitle;

  /// No description provided for @accountDepartmentCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Actuel : '**
  String get accountDepartmentCurrent;

  /// No description provided for @accountDepartmentNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau departement'**
  String get accountDepartmentNew;

  /// No description provided for @accountDepartmentRequestSent.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyee - en attente de validation admin'**
  String get accountDepartmentRequestSent;

  /// No description provided for @accountDepartmentRequestSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la demande'**
  String get accountDepartmentRequestSend;

  /// No description provided for @commonApiError.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez reessayer.'**
  String get commonApiError;

  /// No description provided for @commonNetworkError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de se connecter au serveur. Verifiez votre connexion.'**
  String get commonNetworkError;

  /// No description provided for @commonDeleteError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de supprimer cet element. Veuillez reessayer.'**
  String get commonDeleteError;

  /// No description provided for @commonSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer. Veuillez reessayer.'**
  String get commonSaveError;

  /// No description provided for @greetingMorning.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In fr, this message translates to:
  /// **'Bon après-midi'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In fr, this message translates to:
  /// **'Bonsoir'**
  String get greetingEvening;

  /// No description provided for @hubEquipmentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Équipement'**
  String get hubEquipmentTitle;

  /// No description provided for @hubEquipmentDesc.
  ///
  /// In fr, this message translates to:
  /// **'Gérez les équipements médicaux, suivez les incidents et planifiez les interventions.'**
  String get hubEquipmentDesc;

  /// No description provided for @hubSettingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get hubSettingsTitle;

  /// No description provided for @hubSettingsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Administrez les utilisateurs, configurez le système et consultez les journaux.'**
  String get hubSettingsDesc;

  /// No description provided for @hubInventoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Inventaire'**
  String get hubInventoryTitle;

  /// No description provided for @hubInventoryDesc.
  ///
  /// In fr, this message translates to:
  /// **'Consultez et gérez les stocks de fournitures médicales et consommables.'**
  String get hubInventoryDesc;

  /// No description provided for @hubKpiTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord global'**
  String get hubKpiTitle;

  /// No description provided for @hubKpiSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Indicateurs clés en temps réel'**
  String get hubKpiSubtitle;

  /// No description provided for @hubKpiCriticalUrgentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Incidents critiques / urgents'**
  String get hubKpiCriticalUrgentLabel;

  /// No description provided for @hubKpiOpenIssues.
  ///
  /// In fr, this message translates to:
  /// **'incidents ouverts'**
  String get hubKpiOpenIssues;

  /// No description provided for @hubKpiStockAlertsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Alertes de stock'**
  String get hubKpiStockAlertsLabel;

  /// No description provided for @hubKpiStockAlertsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'ruptures ou niveaux faibles'**
  String get hubKpiStockAlertsSubtitle;

  /// No description provided for @hubKpiOutOfServiceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Hors service'**
  String get hubKpiOutOfServiceLabel;

  /// No description provided for @hubKpiOutOfServiceSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'équipements hors service'**
  String get hubKpiOutOfServiceSubtitle;

  /// No description provided for @hubKpiNoAlert.
  ///
  /// In fr, this message translates to:
  /// **'Aucune alerte'**
  String get hubKpiNoAlert;

  /// No description provided for @hubReportUrgentButton.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un incident'**
  String get hubReportUrgentButton;

  /// No description provided for @hubReportUrgentTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un incident immédiatement'**
  String get hubReportUrgentTooltip;

  /// No description provided for @hubQuickAccessTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accès rapide aux modules'**
  String get hubQuickAccessTitle;

  /// No description provided for @equipStatusOperational.
  ///
  /// In fr, this message translates to:
  /// **'Opérationnel'**
  String get equipStatusOperational;

  /// No description provided for @equipStatusInMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'En maintenance'**
  String get equipStatusInMaintenance;

  /// No description provided for @equipStatusOutOfService.
  ///
  /// In fr, this message translates to:
  /// **'Hors service'**
  String get equipStatusOutOfService;

  /// No description provided for @equipStatusToBeDisposal.
  ///
  /// In fr, this message translates to:
  /// **'À éliminer'**
  String get equipStatusToBeDisposal;

  /// No description provided for @equipStatusDisposed.
  ///
  /// In fr, this message translates to:
  /// **'Éliminé'**
  String get equipStatusDisposed;

  /// No description provided for @equipmentManufacturer.
  ///
  /// In fr, this message translates to:
  /// **'Fabricant'**
  String get equipmentManufacturer;

  /// No description provided for @equipmentManufacturerHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Philips Healthcare'**
  String get equipmentManufacturerHint;

  /// No description provided for @equipmentModel.
  ///
  /// In fr, this message translates to:
  /// **'Modèle'**
  String get equipmentModel;

  /// No description provided for @equipmentModelHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : IntelliVue MX450'**
  String get equipmentModelHint;

  /// No description provided for @equipmentManufYear.
  ///
  /// In fr, this message translates to:
  /// **'Année de fabrication'**
  String get equipmentManufYear;

  /// No description provided for @equipmentManufYearHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : 2023'**
  String get equipmentManufYearHint;

  /// No description provided for @equipmentInstallDate.
  ///
  /// In fr, this message translates to:
  /// **'Date d\'installation'**
  String get equipmentInstallDate;

  /// No description provided for @equipmentInstallDateHint.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une date (optionnel)'**
  String get equipmentInstallDateHint;

  /// No description provided for @equipmentTags.
  ///
  /// In fr, this message translates to:
  /// **'Étiquettes (tags)'**
  String get equipmentTags;

  /// No description provided for @equipmentNoTags.
  ///
  /// In fr, this message translates to:
  /// **'Aucune étiquette'**
  String get equipmentNoTags;

  /// No description provided for @equipmentInternalId.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant interne'**
  String get equipmentInternalId;

  /// No description provided for @equipmentCreatedAt.
  ///
  /// In fr, this message translates to:
  /// **'Créé le'**
  String get equipmentCreatedAt;

  /// No description provided for @equipmentUpdatedAt.
  ///
  /// In fr, this message translates to:
  /// **'Modifié le'**
  String get equipmentUpdatedAt;

  /// No description provided for @equipmentNextRevision.
  ///
  /// In fr, this message translates to:
  /// **'Prochaine révision'**
  String get equipmentNextRevision;

  /// No description provided for @equipmentFutureMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance planifiée'**
  String get equipmentFutureMaintenance;

  /// No description provided for @lastPreventiveDate.
  ///
  /// In fr, this message translates to:
  /// **'Dernière maintenance préventive'**
  String get lastPreventiveDate;

  /// No description provided for @nextPreventiveDate.
  ///
  /// In fr, this message translates to:
  /// **'Prochaine maintenance préventive'**
  String get nextPreventiveDate;

  /// No description provided for @preventiveAlert.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance préventive à prévoir'**
  String get preventiveAlert;

  /// No description provided for @preventiveAlertOverdue.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance préventive en retard'**
  String get preventiveAlertOverdue;

  /// No description provided for @preventiveAlertSoon.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance préventive sous 7 jours'**
  String get preventiveAlertSoon;

  /// No description provided for @preventiveSection.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance préventive'**
  String get preventiveSection;

  /// No description provided for @equipmentSystemInfoSection.
  ///
  /// In fr, this message translates to:
  /// **'Informations système'**
  String get equipmentSystemInfoSection;

  /// No description provided for @equipmentInventorySection.
  ///
  /// In fr, this message translates to:
  /// **'Inventaire'**
  String get equipmentInventorySection;

  /// No description provided for @equipmentGeneralSection.
  ///
  /// In fr, this message translates to:
  /// **'Informations générales'**
  String get equipmentGeneralSection;

  /// No description provided for @issueStatusReported.
  ///
  /// In fr, this message translates to:
  /// **'Signalé'**
  String get issueStatusReported;

  /// No description provided for @issueStatusAcknowledged.
  ///
  /// In fr, this message translates to:
  /// **'Pris en compte'**
  String get issueStatusAcknowledged;

  /// No description provided for @issueStatusAssigned.
  ///
  /// In fr, this message translates to:
  /// **'Assigné'**
  String get issueStatusAssigned;

  /// No description provided for @issueStatusInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get issueStatusInProgress;

  /// No description provided for @issueStatusWaitingMaterials.
  ///
  /// In fr, this message translates to:
  /// **'En attente de matériel'**
  String get issueStatusWaitingMaterials;

  /// No description provided for @issueStatusCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get issueStatusCompleted;

  /// No description provided for @issueStatusVerified.
  ///
  /// In fr, this message translates to:
  /// **'Vérifié'**
  String get issueStatusVerified;

  /// No description provided for @issueStatusClosed.
  ///
  /// In fr, this message translates to:
  /// **'Clôturé'**
  String get issueStatusClosed;

  /// No description provided for @issueStatusRedirected.
  ///
  /// In fr, this message translates to:
  /// **'Redirigé'**
  String get issueStatusRedirected;

  /// No description provided for @urgencyLow.
  ///
  /// In fr, this message translates to:
  /// **'Faible'**
  String get urgencyLow;

  /// No description provided for @urgencyMedium.
  ///
  /// In fr, this message translates to:
  /// **'Moyen'**
  String get urgencyMedium;

  /// No description provided for @urgencyHigh.
  ///
  /// In fr, this message translates to:
  /// **'Urgent'**
  String get urgencyHigh;

  /// No description provided for @urgencyCritical.
  ///
  /// In fr, this message translates to:
  /// **'Critique'**
  String get urgencyCritical;

  /// No description provided for @deptAdministration.
  ///
  /// In fr, this message translates to:
  /// **'Administration'**
  String get deptAdministration;

  /// No description provided for @deptOpd.
  ///
  /// In fr, this message translates to:
  /// **'OPD (Consultations externes)'**
  String get deptOpd;

  /// No description provided for @deptInternalMedicine.
  ///
  /// In fr, this message translates to:
  /// **'Médecine interne'**
  String get deptInternalMedicine;

  /// No description provided for @deptPediatrics.
  ///
  /// In fr, this message translates to:
  /// **'Pédiatrie'**
  String get deptPediatrics;

  /// No description provided for @deptEmergency.
  ///
  /// In fr, this message translates to:
  /// **'Urgences'**
  String get deptEmergency;

  /// No description provided for @deptLaboratory.
  ///
  /// In fr, this message translates to:
  /// **'Laboratoire'**
  String get deptLaboratory;

  /// No description provided for @deptStomatology.
  ///
  /// In fr, this message translates to:
  /// **'Stomatologie'**
  String get deptStomatology;

  /// No description provided for @deptPhysiotherapy.
  ///
  /// In fr, this message translates to:
  /// **'Kinésithérapie'**
  String get deptPhysiotherapy;

  /// No description provided for @deptNeonatology.
  ///
  /// In fr, this message translates to:
  /// **'Néonatologie'**
  String get deptNeonatology;

  /// No description provided for @deptMaternity.
  ///
  /// In fr, this message translates to:
  /// **'Maternité'**
  String get deptMaternity;

  /// No description provided for @deptSurgery.
  ///
  /// In fr, this message translates to:
  /// **'Chirurgie'**
  String get deptSurgery;

  /// No description provided for @deptOperatingTheater.
  ///
  /// In fr, this message translates to:
  /// **'Bloc opératoire'**
  String get deptOperatingTheater;

  /// No description provided for @deptOphthalmology.
  ///
  /// In fr, this message translates to:
  /// **'Ophtalmologie'**
  String get deptOphthalmology;

  /// No description provided for @deptTbMr.
  ///
  /// In fr, this message translates to:
  /// **'TB-MR (Tuberculose)'**
  String get deptTbMr;

  /// No description provided for @deptGbv.
  ///
  /// In fr, this message translates to:
  /// **'GBV (Violences basées sur le genre)'**
  String get deptGbv;

  /// No description provided for @deptMentalHealth.
  ///
  /// In fr, this message translates to:
  /// **'Santé mentale'**
  String get deptMentalHealth;

  /// No description provided for @deptArv.
  ///
  /// In fr, this message translates to:
  /// **'ARV (Traitement VIH/SIDA)'**
  String get deptArv;

  /// No description provided for @deptPharmacy.
  ///
  /// In fr, this message translates to:
  /// **'Pharmacie'**
  String get deptPharmacy;

  /// No description provided for @catIct.
  ///
  /// In fr, this message translates to:
  /// **'Équipement ICT'**
  String get catIct;

  /// No description provided for @catHygiene.
  ///
  /// In fr, this message translates to:
  /// **'Matériel d\'hygiène'**
  String get catHygiene;

  /// No description provided for @catBiomedical.
  ///
  /// In fr, this message translates to:
  /// **'Équipement biomédical'**
  String get catBiomedical;

  /// No description provided for @catElectrical.
  ///
  /// In fr, this message translates to:
  /// **'Équipement électrique'**
  String get catElectrical;

  /// No description provided for @catSterilization.
  ///
  /// In fr, this message translates to:
  /// **'Stérilisation et buanderie'**
  String get catSterilization;

  /// No description provided for @catPharmacy.
  ///
  /// In fr, this message translates to:
  /// **'Pharmacie'**
  String get catPharmacy;

  /// No description provided for @techAvailableTab.
  ///
  /// In fr, this message translates to:
  /// **'Incidents disponibles'**
  String get techAvailableTab;

  /// No description provided for @techMyInterventionsTab.
  ///
  /// In fr, this message translates to:
  /// **'Mes interventions'**
  String get techMyInterventionsTab;

  /// No description provided for @techScheduleTab.
  ///
  /// In fr, this message translates to:
  /// **'Agenda'**
  String get techScheduleTab;

  /// No description provided for @techAvailableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Incidents disponibles'**
  String get techAvailableTitle;

  /// No description provided for @techScheduleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Agenda'**
  String get techScheduleTitle;

  /// No description provided for @techAvailableSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Incidents approuvés en attente d\'un technicien — prenez en charge ceux que vous souhaitez traiter.'**
  String get techAvailableSubtitle;

  /// No description provided for @techNoAvailableIncidents.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident approuvé disponible.'**
  String get techNoAvailableIncidents;

  /// No description provided for @techTakeCharge.
  ///
  /// In fr, this message translates to:
  /// **'Prendre en charge'**
  String get techTakeCharge;

  /// No description provided for @techSheet.
  ///
  /// In fr, this message translates to:
  /// **'Fiche'**
  String get techSheet;

  /// No description provided for @techTakeChargeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Prendre en charge l\'incident'**
  String get techTakeChargeTitle;

  /// No description provided for @techTakeChargeContent.
  ///
  /// In fr, this message translates to:
  /// **'Vous allez prendre en charge l\'incident sur :'**
  String get techTakeChargeContent;

  /// No description provided for @techTakeChargeMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'incident passera au statut \"En cours\" et vous sera assigné.'**
  String get techTakeChargeMessage;

  /// No description provided for @techTakeChargeSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez pris en charge l\'incident sur \"{equipment}\".'**
  String techTakeChargeSuccess(String equipment);

  /// No description provided for @techNoInterventions.
  ///
  /// In fr, this message translates to:
  /// **'Aucune intervention enregistrée'**
  String get techNoInterventions;

  /// No description provided for @techNoInterventionsHint.
  ///
  /// In fr, this message translates to:
  /// **'Les incidents que vous prendrez en charge apparaîtront ici.'**
  String get techNoInterventionsHint;

  /// No description provided for @techNoCurrentInterventions.
  ///
  /// In fr, this message translates to:
  /// **'Aucune intervention en cours'**
  String get techNoCurrentInterventions;

  /// No description provided for @techFindIncidentsHint.
  ///
  /// In fr, this message translates to:
  /// **'Pour trouver des incidents à traiter, consultez l\'onglet \"Incidents disponibles\".'**
  String get techFindIncidentsHint;

  /// No description provided for @techSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une intervention…'**
  String get techSearchHint;

  /// No description provided for @techNoResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get techNoResults;

  /// No description provided for @techScheduleSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre calendrier d\'interventions et de maintenances planifiées.'**
  String get techScheduleSubtitle;

  /// No description provided for @techLegendInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get techLegendInProgress;

  /// No description provided for @techLegendResolved.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get techLegendResolved;

  /// No description provided for @techLegendPastMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance passée'**
  String get techLegendPastMaintenance;

  /// No description provided for @techLegendPlanned.
  ///
  /// In fr, this message translates to:
  /// **'Planifiée'**
  String get techLegendPlanned;

  /// No description provided for @techFullHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique complet'**
  String get techFullHistory;

  /// No description provided for @techNoEventsToday.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement ce jour.'**
  String get techNoEventsToday;

  /// No description provided for @techEventsOn.
  ///
  /// In fr, this message translates to:
  /// **'Événements du {date}'**
  String techEventsOn(String date);

  /// No description provided for @techEventCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} événement(s)'**
  String techEventCount(int count);

  /// No description provided for @techEventStatusCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Effectuée'**
  String get techEventStatusCompleted;

  /// No description provided for @monthJanuary.
  ///
  /// In fr, this message translates to:
  /// **'Janvier'**
  String get monthJanuary;

  /// No description provided for @monthFebruary.
  ///
  /// In fr, this message translates to:
  /// **'Février'**
  String get monthFebruary;

  /// No description provided for @monthMarch.
  ///
  /// In fr, this message translates to:
  /// **'Mars'**
  String get monthMarch;

  /// No description provided for @monthApril.
  ///
  /// In fr, this message translates to:
  /// **'Avril'**
  String get monthApril;

  /// No description provided for @monthMay.
  ///
  /// In fr, this message translates to:
  /// **'Mai'**
  String get monthMay;

  /// No description provided for @monthJune.
  ///
  /// In fr, this message translates to:
  /// **'Juin'**
  String get monthJune;

  /// No description provided for @monthJuly.
  ///
  /// In fr, this message translates to:
  /// **'Juillet'**
  String get monthJuly;

  /// No description provided for @monthAugust.
  ///
  /// In fr, this message translates to:
  /// **'Août'**
  String get monthAugust;

  /// No description provided for @monthSeptember.
  ///
  /// In fr, this message translates to:
  /// **'Septembre'**
  String get monthSeptember;

  /// No description provided for @monthOctober.
  ///
  /// In fr, this message translates to:
  /// **'Octobre'**
  String get monthOctober;

  /// No description provided for @monthNovember.
  ///
  /// In fr, this message translates to:
  /// **'Novembre'**
  String get monthNovember;

  /// No description provided for @monthDecember.
  ///
  /// In fr, this message translates to:
  /// **'Décembre'**
  String get monthDecember;

  /// No description provided for @logsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Journaux d\'activité'**
  String get logsTitle;

  /// No description provided for @logsRefresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get logsRefresh;

  /// No description provided for @logsColAction.
  ///
  /// In fr, this message translates to:
  /// **'Action'**
  String get logsColAction;

  /// No description provided for @logsColUser.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get logsColUser;

  /// No description provided for @logsColResource.
  ///
  /// In fr, this message translates to:
  /// **'Ressource'**
  String get logsColResource;

  /// No description provided for @logsColIpDevice.
  ///
  /// In fr, this message translates to:
  /// **'IP / Appareil'**
  String get logsColIpDevice;

  /// No description provided for @logsColTimestamp.
  ///
  /// In fr, this message translates to:
  /// **'Horodatage'**
  String get logsColTimestamp;

  /// No description provided for @logsSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher (utilisateur, ressource…)'**
  String get logsSearchHint;

  /// No description provided for @logsFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get logsFilterAll;

  /// No description provided for @logsFilterAuth.
  ///
  /// In fr, this message translates to:
  /// **'Auth'**
  String get logsFilterAuth;

  /// No description provided for @logsFilterEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Équipements'**
  String get logsFilterEquipment;

  /// No description provided for @logsFilterIncidents.
  ///
  /// In fr, this message translates to:
  /// **'Incidents'**
  String get logsFilterIncidents;

  /// No description provided for @logsFilterInventory.
  ///
  /// In fr, this message translates to:
  /// **'Inventaire'**
  String get logsFilterInventory;

  /// No description provided for @logsFilterUsers.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs'**
  String get logsFilterUsers;

  /// No description provided for @logsNewIp.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle IP'**
  String get logsNewIp;

  /// No description provided for @logsNewIpTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Première connexion depuis cette adresse IP'**
  String get logsNewIpTooltip;

  /// No description provided for @logsNoLogs.
  ///
  /// In fr, this message translates to:
  /// **'Aucun log trouvé'**
  String get logsNoLogs;

  /// No description provided for @logsNoLogsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les actions des utilisateurs apparaîtront ici.'**
  String get logsNoLogsSubtitle;

  /// No description provided for @logsLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get logsLoadError;

  /// No description provided for @logsRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get logsRetry;

  /// No description provided for @logsMetadata.
  ///
  /// In fr, this message translates to:
  /// **'Métadonnées'**
  String get logsMetadata;

  /// No description provided for @logsViewProfile.
  ///
  /// In fr, this message translates to:
  /// **'Voir profil'**
  String get logsViewProfile;

  /// No description provided for @logsViewDetails.
  ///
  /// In fr, this message translates to:
  /// **'Voir détails'**
  String get logsViewDetails;

  /// No description provided for @logsRestoring.
  ///
  /// In fr, this message translates to:
  /// **'Restauration…'**
  String get logsRestoring;

  /// No description provided for @logsAlreadyRestored.
  ///
  /// In fr, this message translates to:
  /// **'Cette action a déjà été restaurée.'**
  String get logsAlreadyRestored;

  /// No description provided for @logsUserProfileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil utilisateur'**
  String get logsUserProfileTitle;

  /// No description provided for @logsEquipmentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Équipement'**
  String get logsEquipmentTitle;

  /// No description provided for @logsEquipmentNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Équipement supprimé ou introuvable.'**
  String get logsEquipmentNotFound;

  /// No description provided for @logsDeviceMobile.
  ///
  /// In fr, this message translates to:
  /// **'Mobile'**
  String get logsDeviceMobile;

  /// No description provided for @logsDevicePc.
  ///
  /// In fr, this message translates to:
  /// **'PC / Navigateur'**
  String get logsDevicePc;

  /// No description provided for @logsDeviceUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get logsDeviceUnknown;

  /// No description provided for @logsTargetEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Équipement'**
  String get logsTargetEquipment;

  /// No description provided for @logsTargetUser.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur concerné'**
  String get logsTargetUser;

  /// No description provided for @logsTargetIncident.
  ///
  /// In fr, this message translates to:
  /// **'Incident'**
  String get logsTargetIncident;

  /// No description provided for @logsTargetInventory.
  ///
  /// In fr, this message translates to:
  /// **'Article d\'inventaire'**
  String get logsTargetInventory;

  /// No description provided for @logsTargetAuth.
  ///
  /// In fr, this message translates to:
  /// **'Authentification'**
  String get logsTargetAuth;

  /// No description provided for @logsTargetResource.
  ///
  /// In fr, this message translates to:
  /// **'Ressource'**
  String get logsTargetResource;

  /// No description provided for @logsUserLabel.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get logsUserLabel;

  /// No description provided for @logsActionLogin.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get logsActionLogin;

  /// No description provided for @logsActionLoginFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec connexion'**
  String get logsActionLoginFailed;

  /// No description provided for @logsActionLogout.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get logsActionLogout;

  /// No description provided for @logsActionCreateEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Créer équipement'**
  String get logsActionCreateEquipment;

  /// No description provided for @logsActionUpdateEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Modif. équipement'**
  String get logsActionUpdateEquipment;

  /// No description provided for @logsActionDeleteEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Suppr. équipement'**
  String get logsActionDeleteEquipment;

  /// No description provided for @logsActionRestoreEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Restaur. équipement'**
  String get logsActionRestoreEquipment;

  /// No description provided for @logsActionAddMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance'**
  String get logsActionAddMaintenance;

  /// No description provided for @logsActionScheduleMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Planif. maint.'**
  String get logsActionScheduleMaintenance;

  /// No description provided for @logsActionCreateIssue.
  ///
  /// In fr, this message translates to:
  /// **'Signaler incident'**
  String get logsActionCreateIssue;

  /// No description provided for @logsActionUpdateIssue.
  ///
  /// In fr, this message translates to:
  /// **'Modif. incident'**
  String get logsActionUpdateIssue;

  /// No description provided for @logsActionDeleteIssue.
  ///
  /// In fr, this message translates to:
  /// **'Suppr. incident'**
  String get logsActionDeleteIssue;

  /// No description provided for @logsActionCreateInventory.
  ///
  /// In fr, this message translates to:
  /// **'Créer article'**
  String get logsActionCreateInventory;

  /// No description provided for @logsActionUpdateInventory.
  ///
  /// In fr, this message translates to:
  /// **'Modif. stock'**
  String get logsActionUpdateInventory;

  /// No description provided for @logsActionRestockInventory.
  ///
  /// In fr, this message translates to:
  /// **'Réappro. stock'**
  String get logsActionRestockInventory;

  /// No description provided for @logsActionDeleteInventory.
  ///
  /// In fr, this message translates to:
  /// **'Suppr. article'**
  String get logsActionDeleteInventory;

  /// No description provided for @logsActionCreateUser.
  ///
  /// In fr, this message translates to:
  /// **'Créer compte'**
  String get logsActionCreateUser;

  /// No description provided for @logsActionUpdateUser.
  ///
  /// In fr, this message translates to:
  /// **'Modif. compte'**
  String get logsActionUpdateUser;

  /// No description provided for @logsActionDeleteUser.
  ///
  /// In fr, this message translates to:
  /// **'Suppr. compte'**
  String get logsActionDeleteUser;

  /// No description provided for @logsActionRestoreUser.
  ///
  /// In fr, this message translates to:
  /// **'Restaur. compte'**
  String get logsActionRestoreUser;

  /// No description provided for @logsActionChangePassword.
  ///
  /// In fr, this message translates to:
  /// **'Modif. mot de passe'**
  String get logsActionChangePassword;

  /// No description provided for @logsActionChangeName.
  ///
  /// In fr, this message translates to:
  /// **'Modif. nom'**
  String get logsActionChangeName;

  /// No description provided for @logsActionChangeEmail.
  ///
  /// In fr, this message translates to:
  /// **'Modif. email'**
  String get logsActionChangeEmail;

  /// No description provided for @logsActionChangePhone.
  ///
  /// In fr, this message translates to:
  /// **'Modif. téléphone'**
  String get logsActionChangePhone;

  /// No description provided for @logsActionActivateUser.
  ///
  /// In fr, this message translates to:
  /// **'Compte activé'**
  String get logsActionActivateUser;

  /// No description provided for @logsActionSuspendUser.
  ///
  /// In fr, this message translates to:
  /// **'Compte suspendu'**
  String get logsActionSuspendUser;

  /// No description provided for @logsRestoreGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get logsRestoreGeneric;

  /// No description provided for @logsRestoreEquipmentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer l\'équipement'**
  String get logsRestoreEquipmentLabel;

  /// No description provided for @logsRestorePreviousState.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer l\'état précédent'**
  String get logsRestorePreviousState;

  /// No description provided for @logsRestoreUserAccount.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer le compte'**
  String get logsRestoreUserAccount;

  /// No description provided for @logsReactivateUserAccount.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver le compte'**
  String get logsReactivateUserAccount;

  /// No description provided for @logsRestoreOldName.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer l\'ancien nom'**
  String get logsRestoreOldName;

  /// No description provided for @logsRestoreOldEmail.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer l\'ancien email'**
  String get logsRestoreOldEmail;

  /// No description provided for @logsRestoreOldPhone.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer l\'ancien numéro'**
  String get logsRestoreOldPhone;

  /// No description provided for @logsRestorePreviousValues.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer les valeurs précédentes'**
  String get logsRestorePreviousValues;

  /// No description provided for @logsConfirmRestoreTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la restauration'**
  String get logsConfirmRestoreTitle;

  /// No description provided for @logsConfirmRestoreShort.
  ///
  /// In fr, this message translates to:
  /// **'{label} ?'**
  String logsConfirmRestoreShort(String label);

  /// No description provided for @logsConfirmRestoreLong.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment {label} ?'**
  String logsConfirmRestoreLong(String label);

  /// No description provided for @logsRestoreButton.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get logsRestoreButton;

  /// No description provided for @logsEquipmentRestored.
  ///
  /// In fr, this message translates to:
  /// **'Équipement restauré avec succès.'**
  String get logsEquipmentRestored;

  /// No description provided for @logsEquipmentRestoredState.
  ///
  /// In fr, this message translates to:
  /// **'Équipement restauré à son état précédent.'**
  String get logsEquipmentRestoredState;

  /// No description provided for @logsUserAccountRestored.
  ///
  /// In fr, this message translates to:
  /// **'Compte restauré.\nMot de passe temporaire : {pwd}'**
  String logsUserAccountRestored(String pwd);

  /// No description provided for @logsUserAccountReactivated.
  ///
  /// In fr, this message translates to:
  /// **'Compte réactivé.'**
  String get logsUserAccountReactivated;

  /// No description provided for @logsNameRestored.
  ///
  /// In fr, this message translates to:
  /// **'Nom restauré : {old}'**
  String logsNameRestored(String old);

  /// No description provided for @logsEmailRestored.
  ///
  /// In fr, this message translates to:
  /// **'Email restauré : {old}'**
  String logsEmailRestored(String old);

  /// No description provided for @logsPhoneRestored.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone restauré : {old}'**
  String logsPhoneRestored(String old);

  /// No description provided for @logsPreviousValuesRestored.
  ///
  /// In fr, this message translates to:
  /// **'Valeurs précédentes restaurées.'**
  String get logsPreviousValuesRestored;

  /// No description provided for @logsRestoreErrorPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {message}'**
  String logsRestoreErrorPrefix(String message);

  /// No description provided for @logsErrSnapshotMissing.
  ///
  /// In fr, this message translates to:
  /// **'Données de snapshot manquantes'**
  String get logsErrSnapshotMissing;

  /// No description provided for @logsErrInsufficientData.
  ///
  /// In fr, this message translates to:
  /// **'Données insuffisantes'**
  String get logsErrInsufficientData;

  /// No description provided for @logsErrUserIdMissing.
  ///
  /// In fr, this message translates to:
  /// **'ID utilisateur manquant'**
  String get logsErrUserIdMissing;

  /// No description provided for @logsErrOldValueMissing.
  ///
  /// In fr, this message translates to:
  /// **'Ancienne valeur introuvable'**
  String get logsErrOldValueMissing;

  /// No description provided for @logsErrNothingToRestore.
  ///
  /// In fr, this message translates to:
  /// **'Aucune valeur à restaurer'**
  String get logsErrNothingToRestore;

  /// No description provided for @logsErrNotRestorable.
  ///
  /// In fr, this message translates to:
  /// **'Action non restaurable'**
  String get logsErrNotRestorable;

  /// No description provided for @logsDetailsBefore.
  ///
  /// In fr, this message translates to:
  /// **'Avant'**
  String get logsDetailsBefore;

  /// No description provided for @logsDetailsAfter.
  ///
  /// In fr, this message translates to:
  /// **'Après'**
  String get logsDetailsAfter;

  /// No description provided for @logsDetailsSnapshotAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Snapshot disponible'**
  String get logsDetailsSnapshotAvailable;

  /// No description provided for @logsDetailsPreviousAvailable.
  ///
  /// In fr, this message translates to:
  /// **'État précédent disponible'**
  String get logsDetailsPreviousAvailable;

  /// No description provided for @logsSectionDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails'**
  String get logsSectionDetails;

  /// No description provided for @logsSectionDeleteSnapshot.
  ///
  /// In fr, this message translates to:
  /// **'Données au moment de la suppression'**
  String get logsSectionDeleteSnapshot;

  /// No description provided for @logsSectionStateBeforeChange.
  ///
  /// In fr, this message translates to:
  /// **'État avant modification'**
  String get logsSectionStateBeforeChange;

  /// No description provided for @logsSectionUserStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get logsSectionUserStatus;

  /// No description provided for @logsFieldId.
  ///
  /// In fr, this message translates to:
  /// **'ID'**
  String get logsFieldId;

  /// No description provided for @logsFieldRole.
  ///
  /// In fr, this message translates to:
  /// **'Rôle'**
  String get logsFieldRole;

  /// No description provided for @logsFieldPhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get logsFieldPhone;

  /// No description provided for @logsFieldStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get logsFieldStatus;

  /// No description provided for @logsFieldSerial.
  ///
  /// In fr, this message translates to:
  /// **'N° série'**
  String get logsFieldSerial;

  /// No description provided for @logsFieldSupplier.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur'**
  String get logsFieldSupplier;

  /// No description provided for @logsFieldLocation.
  ///
  /// In fr, this message translates to:
  /// **'Emplacement'**
  String get logsFieldLocation;

  /// No description provided for @logsFieldActive.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get logsFieldActive;

  /// No description provided for @logsFieldNewStatus.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau statut'**
  String get logsFieldNewStatus;

  /// No description provided for @logsFieldReason.
  ///
  /// In fr, this message translates to:
  /// **'Raison'**
  String get logsFieldReason;

  /// No description provided for @logsFieldDeviceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Appareil'**
  String get logsFieldDeviceLabel;

  /// No description provided for @logsFieldIp.
  ///
  /// In fr, this message translates to:
  /// **'IP'**
  String get logsFieldIp;

  /// No description provided for @logsFieldIpUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Inconnue'**
  String get logsFieldIpUnknown;

  /// No description provided for @logsFieldUserAgent.
  ///
  /// In fr, this message translates to:
  /// **'User-Agent'**
  String get logsFieldUserAgent;

  /// No description provided for @logsFieldTimestamp.
  ///
  /// In fr, this message translates to:
  /// **'Horodatage'**
  String get logsFieldTimestamp;

  /// No description provided for @logsFieldType.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get logsFieldType;

  /// No description provided for @logsAlertNewIpFull.
  ///
  /// In fr, this message translates to:
  /// **'Première connexion depuis cette adresse IP pour ce compte.'**
  String get logsAlertNewIpFull;

  /// No description provided for @logsUserStatusActive.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get logsUserStatusActive;

  /// No description provided for @logsUserStatusSuspended.
  ///
  /// In fr, this message translates to:
  /// **'Suspendu'**
  String get logsUserStatusSuspended;

  /// No description provided for @logsErrorLoading.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {error}'**
  String logsErrorLoading(String error);

  /// No description provided for @logsTimeJustNow.
  ///
  /// In fr, this message translates to:
  /// **'À l\'instant'**
  String get logsTimeJustNow;

  /// No description provided for @logsTimeWithMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{time} (il y a {n} min)'**
  String logsTimeWithMinutes(String time, int n);

  /// No description provided for @logsTimeWithHours.
  ///
  /// In fr, this message translates to:
  /// **'{time} (il y a {n} h)'**
  String logsTimeWithHours(String time, int n);

  /// No description provided for @logsEntriesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} entrée(s)'**
  String logsEntriesCount(int count);

  /// No description provided for @settingsRolesTab.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des rôles'**
  String get settingsRolesTab;

  /// No description provided for @settingsRolesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rôles et permissions'**
  String get settingsRolesTitle;

  /// No description provided for @settingsRolesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier les permissions ou créer un rôle personnalisé'**
  String get settingsRolesSubtitle;

  /// No description provided for @settingsNewRole.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau rôle'**
  String get settingsNewRole;

  /// No description provided for @settingsAdminLockedInfo.
  ///
  /// In fr, this message translates to:
  /// **'Les permissions de l\'Administrateur sont verrouillées — il a toujours accès à tout. Les rôles personnalisés peuvent être supprimés.'**
  String get settingsAdminLockedInfo;

  /// No description provided for @settingsNoRoles.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rôle chargé.'**
  String get settingsNoRoles;

  /// No description provided for @settingsCustomBadge.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé'**
  String get settingsCustomBadge;

  /// No description provided for @settingsAdminAlwaysAll.
  ///
  /// In fr, this message translates to:
  /// **'L\'administrateur a toujours toutes les permissions'**
  String get settingsAdminAlwaysAll;

  /// No description provided for @settingsLocked.
  ///
  /// In fr, this message translates to:
  /// **'Verrouillé'**
  String get settingsLocked;

  /// No description provided for @settingsRoleActive.
  ///
  /// In fr, this message translates to:
  /// **'Permissions actives :'**
  String get settingsRoleActive;

  /// No description provided for @settingsNoPermissions.
  ///
  /// In fr, this message translates to:
  /// **'Aucune permission'**
  String get settingsNoPermissions;

  /// No description provided for @settingsNewRoleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau rôle personnalisé'**
  String get settingsNewRoleTitle;

  /// No description provided for @settingsRoleIdLabel.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant (ex: nurse)'**
  String get settingsRoleIdLabel;

  /// No description provided for @settingsRoleIdHint.
  ///
  /// In fr, this message translates to:
  /// **'Lettres, chiffres, underscores'**
  String get settingsRoleIdHint;

  /// No description provided for @settingsRoleDisplayLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom affiché (ex: Infirmier)'**
  String get settingsRoleDisplayLabel;

  /// No description provided for @settingsRoleDescLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description (optionnel)'**
  String get settingsRoleDescLabel;

  /// No description provided for @settingsPermissionsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Permissions'**
  String get settingsPermissionsLabel;

  /// No description provided for @settingsSelectAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout sélectionner'**
  String get settingsSelectAll;

  /// No description provided for @settingsDeselectAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout désélectionner'**
  String get settingsDeselectAll;

  /// No description provided for @settingsCreateRole.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get settingsCreateRole;

  /// No description provided for @settingsEditPermissionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Permissions — {role}'**
  String settingsEditPermissionsTitle(String role);

  /// No description provided for @settingsBuiltinRole.
  ///
  /// In fr, this message translates to:
  /// **'Rôle intégré'**
  String get settingsBuiltinRole;

  /// No description provided for @settingsAccessByRole.
  ///
  /// In fr, this message translates to:
  /// **'Accès aux pages par rôle'**
  String get settingsAccessByRole;

  /// No description provided for @settingsAccessDesc.
  ///
  /// In fr, this message translates to:
  /// **'Cochez les pages et fonctions accessibles pour le rôle sélectionné.'**
  String get settingsAccessDesc;

  /// No description provided for @settingsRoleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rôle'**
  String get settingsRoleLabel;

  /// No description provided for @settingsAdminAllAccess.
  ///
  /// In fr, this message translates to:
  /// **'L\'administrateur a accès à toutes les pages et fonctions sans restriction.'**
  String get settingsAdminAllAccess;

  /// No description provided for @settingsNoSpecificFunction.
  ///
  /// In fr, this message translates to:
  /// **'Aucune fonction spécifique'**
  String get settingsNoSpecificFunction;

  /// No description provided for @settingsResetToDefault.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialisé aux valeurs par défaut'**
  String get settingsResetToDefault;

  /// No description provided for @settingsReset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get settingsReset;

  /// No description provided for @settingsDeleteRole.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le rôle'**
  String get settingsDeleteRole;

  /// No description provided for @settingsRoleCreated.
  ///
  /// In fr, this message translates to:
  /// **'Rôle créé'**
  String get settingsRoleCreated;

  /// No description provided for @settingsRoleCreateError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création'**
  String get settingsRoleCreateError;

  /// No description provided for @settingsRoleSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la sauvegarde'**
  String get settingsRoleSaveError;

  /// No description provided for @settingsRoleDeleteError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression'**
  String get settingsRoleDeleteError;

  /// No description provided for @settingsRoleDeletedToast.
  ///
  /// In fr, this message translates to:
  /// **'Rôle \"{role}\" supprimé'**
  String settingsRoleDeletedToast(String role);

  /// No description provided for @settingsRoleDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer \"{role}\" ? Cette action est irréversible.'**
  String settingsRoleDeleteConfirm(String role);

  /// No description provided for @settingsRolePermissionsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Permissions de {role} mises à jour'**
  String settingsRolePermissionsUpdated(String role);

  /// No description provided for @settingsRoleConfigSaved.
  ///
  /// In fr, this message translates to:
  /// **'Configuration sauvegardée'**
  String get settingsRoleConfigSaved;

  /// No description provided for @settingsRoleConfigSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la sauvegarde'**
  String get settingsRoleConfigSaveError;

  /// No description provided for @settingsResetDone.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialisé aux valeurs par défaut'**
  String get settingsResetDone;

  /// No description provided for @roleHospitalStaff.
  ///
  /// In fr, this message translates to:
  /// **'Personnel hospitalier'**
  String get roleHospitalStaff;

  /// No description provided for @roleSupervisor.
  ///
  /// In fr, this message translates to:
  /// **'Superviseur'**
  String get roleSupervisor;

  /// No description provided for @roleTechnician.
  ///
  /// In fr, this message translates to:
  /// **'Technicien'**
  String get roleTechnician;

  /// No description provided for @roleTechnicianBiomedical.
  ///
  /// In fr, this message translates to:
  /// **'Tech. biomédical'**
  String get roleTechnicianBiomedical;

  /// No description provided for @roleTechnicianIt.
  ///
  /// In fr, this message translates to:
  /// **'Tech. IT'**
  String get roleTechnicianIt;

  /// No description provided for @roleTechnicianInfra.
  ///
  /// In fr, this message translates to:
  /// **'Tech. infrastructure'**
  String get roleTechnicianInfra;

  /// No description provided for @roleAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Administrateur ICT'**
  String get roleAdmin;

  /// No description provided for @permViewEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Consulter les équipements'**
  String get permViewEquipment;

  /// No description provided for @permReportIssue.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un problème'**
  String get permReportIssue;

  /// No description provided for @permTrackIssues.
  ///
  /// In fr, this message translates to:
  /// **'Suivre les demandes'**
  String get permTrackIssues;

  /// No description provided for @permApproveRequests.
  ///
  /// In fr, this message translates to:
  /// **'Approuver les demandes'**
  String get permApproveRequests;

  /// No description provided for @permAssignTasks.
  ///
  /// In fr, this message translates to:
  /// **'Assigner les tâches'**
  String get permAssignTasks;

  /// No description provided for @permUpdateRepairs.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour les réparations'**
  String get permUpdateRepairs;

  /// No description provided for @permRegisterParts.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les pièces'**
  String get permRegisterParts;

  /// No description provided for @permManageEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les équipements'**
  String get permManageEquipment;

  /// No description provided for @permManageUsers.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les utilisateurs'**
  String get permManageUsers;

  /// No description provided for @permManageDepartments.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les départements'**
  String get permManageDepartments;

  /// No description provided for @permManageCategories.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les catégories'**
  String get permManageCategories;

  /// No description provided for @permGenerateReports.
  ///
  /// In fr, this message translates to:
  /// **'Générer des rapports'**
  String get permGenerateReports;

  /// No description provided for @permViewInventory.
  ///
  /// In fr, this message translates to:
  /// **'Consulter l\'inventaire'**
  String get permViewInventory;

  /// No description provided for @permChangeDepartment.
  ///
  /// In fr, this message translates to:
  /// **'Changer son département directement'**
  String get permChangeDepartment;

  /// No description provided for @permManageFeatures.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les feature flags'**
  String get permManageFeatures;

  /// No description provided for @accountFirstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get accountFirstName;

  /// No description provided for @accountLastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get accountLastName;

  /// No description provided for @accountDirectChange.
  ///
  /// In fr, this message translates to:
  /// **'Direct'**
  String get accountDirectChange;

  /// No description provided for @accountDirectChangeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre département sera modifié immédiatement.'**
  String get accountDirectChangeSubtitle;

  /// No description provided for @accountConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get accountConfirm;

  /// No description provided for @accountCancelLabel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get accountCancelLabel;

  /// No description provided for @equipmentSelectDate.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une date (optionnel)'**
  String get equipmentSelectDate;

  /// No description provided for @equipmentRemoveDate.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la date'**
  String get equipmentRemoveDate;

  /// No description provided for @equipmentDeleteReason.
  ///
  /// In fr, this message translates to:
  /// **'Raison de la suppression (optionnel)'**
  String get equipmentDeleteReason;

  /// No description provided for @equipmentDeleteReasonHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Hors service, remplacé…'**
  String get equipmentDeleteReasonHint;

  /// No description provided for @widgetHistoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique — {name}'**
  String widgetHistoryTitle(String name);

  /// No description provided for @widgetMaintenanceEvent.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance — {intervention}'**
  String widgetMaintenanceEvent(String intervention);

  /// No description provided for @widgetPlannedMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance planifiée — {intervention}'**
  String widgetPlannedMaintenance(String intervention);

  /// No description provided for @widgetNoHistory.
  ///
  /// In fr, this message translates to:
  /// **'Aucun historique pour cet équipement.'**
  String get widgetNoHistory;

  /// No description provided for @widgetSerialNumber.
  ///
  /// In fr, this message translates to:
  /// **'N° {serial}'**
  String widgetSerialNumber(String serial);

  /// No description provided for @widgetEventCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} événement(s)'**
  String widgetEventCount(int count);

  /// No description provided for @usersDeptRequests.
  ///
  /// In fr, this message translates to:
  /// **'Demandes de changement de département'**
  String get usersDeptRequests;

  /// No description provided for @usersNoPendingRequests.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande en attente.'**
  String get usersNoPendingRequests;

  /// No description provided for @usersApproveTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Approuver'**
  String get usersApproveTooltip;

  /// No description provided for @usersRejectTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Rejeter'**
  String get usersRejectTooltip;

  /// No description provided for @usersApproveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Approuver la demande'**
  String get usersApproveTitle;

  /// No description provided for @usersRejectTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejeter la demande'**
  String get usersRejectTitle;

  /// No description provided for @usersFirstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get usersFirstName;

  /// No description provided for @usersLastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get usersLastName;

  /// No description provided for @usersDeleteReason.
  ///
  /// In fr, this message translates to:
  /// **'Raison de la suppression (optionnel)'**
  String get usersDeleteReason;

  /// No description provided for @usersDeleteReasonHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Départ de l\'établissement, doublon…'**
  String get usersDeleteReasonHint;

  /// No description provided for @usersRolesInfo.
  ///
  /// In fr, this message translates to:
  /// **'Pour modifier les permissions, rendez-vous dans l\'onglet Rôles.'**
  String get usersRolesInfo;

  /// No description provided for @issueFormSourceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type de signalement'**
  String get issueFormSourceLabel;

  /// No description provided for @issueFormSourceEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Équipement médical'**
  String get issueFormSourceEquipment;

  /// No description provided for @issueFormSourceLocation.
  ///
  /// In fr, this message translates to:
  /// **'Infrastructure / Lieu'**
  String get issueFormSourceLocation;

  /// No description provided for @issueFormSelectLocation.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un lieu'**
  String get issueFormSelectLocation;

  /// No description provided for @issueFormLocationRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un lieu'**
  String get issueFormLocationRequired;

  /// No description provided for @techReassignButton.
  ///
  /// In fr, this message translates to:
  /// **'Transférer vers un autre groupe'**
  String get techReassignButton;

  /// No description provided for @techReassignTitle.
  ///
  /// In fr, this message translates to:
  /// **'Transférer l\'incident'**
  String get techReassignTitle;

  /// No description provided for @techReassignSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez le groupe qui doit traiter cet incident.'**
  String get techReassignSubtitle;

  /// No description provided for @techReassignGroupHint.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un groupe'**
  String get techReassignGroupHint;

  /// No description provided for @techReassignGroupRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le groupe est obligatoire'**
  String get techReassignGroupRequired;

  /// No description provided for @techReassignReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif du transfert'**
  String get techReassignReasonLabel;

  /// No description provided for @techReassignReasonHint.
  ///
  /// In fr, this message translates to:
  /// **'Expliquez pourquoi vous transférez cet incident…'**
  String get techReassignReasonHint;

  /// No description provided for @techReassignReasonMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Le motif doit contenir au moins 10 caractères'**
  String get techReassignReasonMinLength;

  /// No description provided for @techReassignSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Incident transféré au groupe {group}'**
  String techReassignSuccess(String group);

  /// No description provided for @equipDetailCurrentIssues.
  ///
  /// In fr, this message translates to:
  /// **'Incidents en cours'**
  String get equipDetailCurrentIssues;

  /// No description provided for @equipDetailPastIssues.
  ///
  /// In fr, this message translates to:
  /// **'Historique des incidents'**
  String get equipDetailPastIssues;

  /// No description provided for @equipDetailNoCurrentIssues.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident en cours pour cet équipement'**
  String get equipDetailNoCurrentIssues;

  /// No description provided for @equipDetailNoPastIssues.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident résolu pour cet équipement'**
  String get equipDetailNoPastIssues;

  /// No description provided for @equipDetailIssuesSection.
  ///
  /// In fr, this message translates to:
  /// **'Incidents'**
  String get equipDetailIssuesSection;

  /// No description provided for @equipDetailLoadingError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du chargement des détails'**
  String get equipDetailLoadingError;

  /// No description provided for @issueCategorySelectorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quel type de problème rencontrez-vous ?'**
  String get issueCategorySelectorTitle;

  /// No description provided for @issueCategoryBiomedical.
  ///
  /// In fr, this message translates to:
  /// **'Équipements Biomédicaux'**
  String get issueCategoryBiomedical;

  /// No description provided for @issueCategoryBiomedicalDesc.
  ///
  /// In fr, this message translates to:
  /// **'Scanner, IRM, échographe, analyseurs, moniteurs, pompes à perfusion, ventilateurs…'**
  String get issueCategoryBiomedicalDesc;

  /// No description provided for @issueCategoryInfrastructure.
  ///
  /// In fr, this message translates to:
  /// **'Infrastructure & Électricité'**
  String get issueCategoryInfrastructure;

  /// No description provided for @issueCategoryInfrastructureDesc.
  ///
  /// In fr, this message translates to:
  /// **'Lits, tables d\'examen, fauteuils roulants, éclairage, prises électriques, plomberie…'**
  String get issueCategoryInfrastructureDesc;

  /// No description provided for @issueCategoryIT.
  ///
  /// In fr, this message translates to:
  /// **'Informatique (IT)'**
  String get issueCategoryIT;

  /// No description provided for @issueCategoryITDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ordinateurs, imprimantes, réseau, serveurs, logiciels, systèmes d\'information…'**
  String get issueCategoryITDesc;

  /// No description provided for @issueCategoryOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre / Je ne sais pas'**
  String get issueCategoryOther;

  /// No description provided for @issueCategoryOtherDesc.
  ///
  /// In fr, this message translates to:
  /// **'Problème non classé ou dont vous ne connaissez pas la catégorie — tous les équipements restent disponibles.'**
  String get issueCategoryOtherDesc;

  /// No description provided for @issueFormNoEquipmentInCategory.
  ///
  /// In fr, this message translates to:
  /// **'Aucun équipement de ce type trouvé dans votre département.'**
  String get issueFormNoEquipmentInCategory;

  /// No description provided for @issueFormTagNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de Tag IT'**
  String get issueFormTagNumber;

  /// No description provided for @issueFormTagNumberHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: TG-0042'**
  String get issueFormTagNumberHint;

  /// No description provided for @issueFormTagSearching.
  ///
  /// In fr, this message translates to:
  /// **'Recherche en cours...'**
  String get issueFormTagSearching;

  /// No description provided for @issueFormTagNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun équipement trouvé pour ce tag'**
  String get issueFormTagNotFound;

  /// No description provided for @issueFormTagFound.
  ///
  /// In fr, this message translates to:
  /// **'Équipement trouvé'**
  String get issueFormTagFound;

  /// No description provided for @issueFormBuilding.
  ///
  /// In fr, this message translates to:
  /// **'Bâtiment'**
  String get issueFormBuilding;

  /// No description provided for @issueFormSelectBuilding.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un bâtiment'**
  String get issueFormSelectBuilding;

  /// No description provided for @issueFormSelectDepartment.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un département'**
  String get issueFormSelectDepartment;

  /// No description provided for @issueFormProblemCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie de problème *'**
  String get issueFormProblemCategory;

  /// No description provided for @issueFormSelectProblemCategory.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez une catégorie'**
  String get issueFormSelectProblemCategory;

  /// No description provided for @issueFormProblemSubcategory.
  ///
  /// In fr, this message translates to:
  /// **'Sous-catégorie *'**
  String get issueFormProblemSubcategory;

  /// No description provided for @issueFormSelectProblemSubcategory.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez une sous-catégorie'**
  String get issueFormSelectProblemSubcategory;

  /// No description provided for @issueFormAutoFilled.
  ///
  /// In fr, this message translates to:
  /// **'Informations auto-remplies depuis l\'équipement'**
  String get issueFormAutoFilled;

  /// No description provided for @issueFormSearchEquipmentByTag.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par numéro de tag'**
  String get issueFormSearchEquipmentByTag;

  /// No description provided for @issueFormEquipmentRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un équipement'**
  String get issueFormEquipmentRequired;

  /// No description provided for @issueFormDepartmentRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un département'**
  String get issueFormDepartmentRequired;

  /// No description provided for @issueFormBuildingHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Bloc A, Bâtiment Principal...'**
  String get issueFormBuildingHint;

  /// No description provided for @issueFormLocationHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Salle 12, Couloir Nord...'**
  String get issueFormLocationHint;

  /// No description provided for @issueFormInfraTagNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de tag (optionnel)'**
  String get issueFormInfraTagNumber;

  /// No description provided for @issueFormInfraTagHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: TG-0042'**
  String get issueFormInfraTagHint;

  /// No description provided for @issueFormBuildingRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir le nom du bâtiment'**
  String get issueFormBuildingRequired;

  /// No description provided for @issueFormLocationRequired2.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir la localisation'**
  String get issueFormLocationRequired2;

  /// No description provided for @issueFormCategoryRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner une catégorie'**
  String get issueFormCategoryRequired;

  /// No description provided for @issueFormSubcategoryRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner une sous-catégorie'**
  String get issueFormSubcategoryRequired;

  /// No description provided for @issueFormTagRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir un numéro de tag et rechercher l\'équipement'**
  String get issueFormTagRequired;

  /// No description provided for @issueFormQuickSearch.
  ///
  /// In fr, this message translates to:
  /// **'Recherche rapide'**
  String get issueFormQuickSearch;

  /// No description provided for @issueFormQuickSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Tapez un mot-clé pour trouver un problème...'**
  String get issueFormQuickSearchHint;

  /// No description provided for @issueFormSpecificIssue.
  ///
  /// In fr, this message translates to:
  /// **'Problème spécifique *'**
  String get issueFormSpecificIssue;

  /// No description provided for @issueFormSelectSpecificIssue.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez le problème'**
  String get issueFormSelectSpecificIssue;

  /// No description provided for @issueFormIssueRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner le problème'**
  String get issueFormIssueRequired;

  /// No description provided for @registerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Inscription'**
  String get registerTitle;

  /// No description provided for @registerFirstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get registerFirstName;

  /// No description provided for @registerLastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get registerLastName;

  /// No description provided for @registerDepartment.
  ///
  /// In fr, this message translates to:
  /// **'Département'**
  String get registerDepartment;

  /// No description provided for @registerPhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone (optionnel)'**
  String get registerPhone;

  /// No description provided for @registerPasswordConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get registerPasswordConfirm;

  /// No description provided for @registerPasswordMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Minimum 8 caractères'**
  String get registerPasswordMinLength;

  /// No description provided for @registerPasswordMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get registerPasswordMismatch;

  /// No description provided for @registerSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get registerSubmit;

  /// No description provided for @registerSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Compte créé ! Vérifiez votre email pour l\'activer. Une fois connecté, vous pourrez demander un rôle supplémentaire depuis votre profil.'**
  String get registerSuccess;

  /// No description provided for @registerHaveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Déjà un compte ? Se connecter'**
  String get registerHaveAccount;

  /// No description provided for @registerNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ? S\'inscrire'**
  String get registerNoAccount;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le lien'**
  String get forgotPasswordSubmit;

  /// No description provided for @forgotPasswordSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Si cet email existe, vous recevrez un lien de réinitialisation. Vérifiez également vos spams.'**
  String get forgotPasswordSuccess;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get forgotPasswordLink;

  /// No description provided for @loginEmailNotVerified.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte n\'est pas encore activé. Vérifiez votre email ou contactez votre administrateur.'**
  String get loginEmailNotVerified;

  /// No description provided for @roleRequestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demander un rôle supplémentaire'**
  String get roleRequestTitle;

  /// No description provided for @roleRequestLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rôle demandé'**
  String get roleRequestLabel;

  /// No description provided for @roleRequestSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la demande'**
  String get roleRequestSubmit;

  /// No description provided for @roleRequestSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée, en attente de validation administrateur'**
  String get roleRequestSuccess;

  /// No description provided for @navAnalytics.
  ///
  /// In fr, this message translates to:
  /// **'Analytiques'**
  String get navAnalytics;

  /// No description provided for @navAnalyticsShort.
  ///
  /// In fr, this message translates to:
  /// **'Stats'**
  String get navAnalyticsShort;

  /// No description provided for @healthAuth.
  ///
  /// In fr, this message translates to:
  /// **'Auth'**
  String get healthAuth;

  /// No description provided for @healthDb.
  ///
  /// In fr, this message translates to:
  /// **'BD'**
  String get healthDb;

  /// No description provided for @healthIam.
  ///
  /// In fr, this message translates to:
  /// **'IAM'**
  String get healthIam;

  /// No description provided for @healthMail.
  ///
  /// In fr, this message translates to:
  /// **'Mail'**
  String get healthMail;

  /// No description provided for @analyticsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Analytiques'**
  String get analyticsTitle;

  /// No description provided for @analyticsPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Période :'**
  String get analyticsPeriod;

  /// No description provided for @analyticsToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get analyticsToday;

  /// No description provided for @analyticsWeek.
  ///
  /// In fr, this message translates to:
  /// **'7 jours'**
  String get analyticsWeek;

  /// No description provided for @analyticsMonth.
  ///
  /// In fr, this message translates to:
  /// **'30 jours'**
  String get analyticsMonth;

  /// No description provided for @analyticsLogins.
  ///
  /// In fr, this message translates to:
  /// **'Connexions'**
  String get analyticsLogins;

  /// No description provided for @analyticsFailedLogins.
  ///
  /// In fr, this message translates to:
  /// **'Échecs connexion'**
  String get analyticsFailedLogins;

  /// No description provided for @analyticsActiveUsers.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs actifs'**
  String get analyticsActiveUsers;

  /// No description provided for @analyticsIssuesCreated.
  ///
  /// In fr, this message translates to:
  /// **'Incidents créés'**
  String get analyticsIssuesCreated;

  /// No description provided for @analyticsIssuesResolved.
  ///
  /// In fr, this message translates to:
  /// **'Incidents résolus'**
  String get analyticsIssuesResolved;

  /// No description provided for @analyticsEquipmentTotal.
  ///
  /// In fr, this message translates to:
  /// **'Équipements'**
  String get analyticsEquipmentTotal;

  /// No description provided for @analyticsEquipmentByStatus.
  ///
  /// In fr, this message translates to:
  /// **'État des équipements'**
  String get analyticsEquipmentByStatus;

  /// No description provided for @analyticsTopActions.
  ///
  /// In fr, this message translates to:
  /// **'Activité par action'**
  String get analyticsTopActions;

  /// No description provided for @analyticsNoData.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée pour cette période.'**
  String get analyticsNoData;

  /// No description provided for @accountAlertEmailNotVerifiedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Email non vérifié'**
  String get accountAlertEmailNotVerifiedTitle;

  /// No description provided for @accountAlertEmailNotVerifiedSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre boîte mail et cliquez sur le lien de confirmation envoyé à l\'inscription.'**
  String get accountAlertEmailNotVerifiedSubtitle;

  /// No description provided for @accountAlertPhoneMissingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone manquant'**
  String get accountAlertPhoneMissingTitle;

  /// No description provided for @accountAlertPhoneMissingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez votre numéro dans vos informations personnelles pour être joignable en cas d\'incident.'**
  String get accountAlertPhoneMissingSubtitle;

  /// No description provided for @appVersionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Version {version}'**
  String appVersionLabel(String version);

  /// No description provided for @navFeatureManagement.
  ///
  /// In fr, this message translates to:
  /// **'Feature Flags'**
  String get navFeatureManagement;

  /// No description provided for @navFeatureManagementShort.
  ///
  /// In fr, this message translates to:
  /// **'Flags'**
  String get navFeatureManagementShort;

  /// No description provided for @featureMgmtTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Feature Flags'**
  String get featureMgmtTitle;

  /// No description provided for @featureMgmtSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Activez ou désactivez les modules de l\'application globalement ou par rôle'**
  String get featureMgmtSubtitle;

  /// No description provided for @featureMgmtGlobalStatusLabel.
  ///
  /// In fr, this message translates to:
  /// **'Actif globalement'**
  String get featureMgmtGlobalStatusLabel;

  /// No description provided for @featureMgmtRoleOverridesBtn.
  ///
  /// In fr, this message translates to:
  /// **'Exceptions par rôle'**
  String get featureMgmtRoleOverridesBtn;

  /// No description provided for @featureMgmtSaveSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Feature mise à jour avec succès'**
  String get featureMgmtSaveSuccess;

  /// No description provided for @featureMgmtSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la mise à jour : {error}'**
  String featureMgmtSaveError(String error);

  /// No description provided for @featureMgmtNoFeatures.
  ///
  /// In fr, this message translates to:
  /// **'Aucune feature disponible'**
  String get featureMgmtNoFeatures;

  /// No description provided for @featureMgmtRoleDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Exceptions par rôle — {name}'**
  String featureMgmtRoleDialogTitle(String name);

  /// No description provided for @featureMgmtRoleDialogHint.
  ///
  /// In fr, this message translates to:
  /// **'Sans exception, la feature suit son statut global.'**
  String get featureMgmtRoleDialogHint;

  /// No description provided for @featureMgmtRoleNoOverride.
  ///
  /// In fr, this message translates to:
  /// **'Aucune exception (statut global)'**
  String get featureMgmtRoleNoOverride;

  /// No description provided for @featureMgmtRoleForceActive.
  ///
  /// In fr, this message translates to:
  /// **'Forcé actif'**
  String get featureMgmtRoleForceActive;

  /// No description provided for @featureMgmtRoleForceInactive.
  ///
  /// In fr, this message translates to:
  /// **'Forcé inactif'**
  String get featureMgmtRoleForceInactive;

  /// No description provided for @featureMgmtLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des features...'**
  String get featureMgmtLoading;

  /// No description provided for @featureMgmtGlobalActive.
  ///
  /// In fr, this message translates to:
  /// **'Activé globalement'**
  String get featureMgmtGlobalActive;

  /// No description provided for @featureMgmtGlobalInactive.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé globalement'**
  String get featureMgmtGlobalInactive;

  /// No description provided for @navBackupManagement.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegardes'**
  String get navBackupManagement;

  /// No description provided for @navBackupManagementShort.
  ///
  /// In fr, this message translates to:
  /// **'Backup'**
  String get navBackupManagementShort;

  /// No description provided for @permManageBackups.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les sauvegardes'**
  String get permManageBackups;

  /// No description provided for @backupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Sauvegardes'**
  String get backupTitle;

  /// No description provided for @backupSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegardez, planifiez et téléchargez les données de l\'hôpital'**
  String get backupSubtitle;

  /// No description provided for @backupLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get backupLoading;

  /// No description provided for @backupLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du chargement des données'**
  String get backupLoadError;

  /// No description provided for @backupRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get backupRetry;

  /// No description provided for @backupLastStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut de la dernière sauvegarde'**
  String get backupLastStatus;

  /// No description provided for @backupNoLastBackup.
  ///
  /// In fr, this message translates to:
  /// **'Aucune sauvegarde effectuée'**
  String get backupNoLastBackup;

  /// No description provided for @backupDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get backupDate;

  /// No description provided for @backupSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get backupSize;

  /// No description provided for @backupStatusLabel.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get backupStatusLabel;

  /// No description provided for @backupStatusSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Succès'**
  String get backupStatusSuccess;

  /// No description provided for @backupStatusError.
  ///
  /// In fr, this message translates to:
  /// **'Échec'**
  String get backupStatusError;

  /// No description provided for @backupTypeManual.
  ///
  /// In fr, this message translates to:
  /// **'Manuelle'**
  String get backupTypeManual;

  /// No description provided for @backupTypeAutomated.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get backupTypeAutomated;

  /// No description provided for @backupTrigger.
  ///
  /// In fr, this message translates to:
  /// **'Exécuter une sauvegarde immédiate'**
  String get backupTrigger;

  /// No description provided for @backupTriggering.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde en cours...'**
  String get backupTriggering;

  /// No description provided for @backupTriggerSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde réussie'**
  String get backupTriggerSuccess;

  /// No description provided for @backupTriggerError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la sauvegarde : {error}'**
  String backupTriggerError(String error);

  /// No description provided for @backupAutomationSection.
  ///
  /// In fr, this message translates to:
  /// **'Automatisation'**
  String get backupAutomationSection;

  /// No description provided for @backupEnableAuto.
  ///
  /// In fr, this message translates to:
  /// **'Activer la sauvegarde automatique'**
  String get backupEnableAuto;

  /// No description provided for @backupScheduleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Récurrence'**
  String get backupScheduleLabel;

  /// No description provided for @backupScheduleDaily.
  ///
  /// In fr, this message translates to:
  /// **'Tous les jours à minuit'**
  String get backupScheduleDaily;

  /// No description provided for @backupScheduleWeekly.
  ///
  /// In fr, this message translates to:
  /// **'Chaque semaine (dimanche à minuit)'**
  String get backupScheduleWeekly;

  /// No description provided for @backupSettingsSaved.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres de sauvegarde enregistrés'**
  String get backupSettingsSaved;

  /// No description provided for @backupSettingsSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la mise à jour : {error}'**
  String backupSettingsSaveError(String error);

  /// No description provided for @backupAlertTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rappel Critique'**
  String get backupAlertTitle;

  /// No description provided for @backupAlertMessage.
  ///
  /// In fr, this message translates to:
  /// **'Pour des raisons de sécurité (incendie, panne matérielle majeure), veuillez régulièrement télécharger une sauvegarde et la stocker sur un support physique hors du serveur de l\'hôpital.'**
  String get backupAlertMessage;

  /// No description provided for @backupHistorySection.
  ///
  /// In fr, this message translates to:
  /// **'Historique des sauvegardes'**
  String get backupHistorySection;

  /// No description provided for @backupNoHistory.
  ///
  /// In fr, this message translates to:
  /// **'Aucune sauvegarde enregistrée'**
  String get backupNoHistory;

  /// No description provided for @backupDownload.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get backupDownload;

  /// No description provided for @backupDownloadSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement démarré'**
  String get backupDownloadSuccess;

  /// No description provided for @backupDownloadError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du téléchargement : {error}'**
  String backupDownloadError(String error);

  /// No description provided for @backupColDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get backupColDate;

  /// No description provided for @backupColType.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get backupColType;

  /// No description provided for @backupColSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get backupColSize;

  /// No description provided for @backupColStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get backupColStatus;

  /// No description provided for @backupColAction.
  ///
  /// In fr, this message translates to:
  /// **'Action'**
  String get backupColAction;

  /// No description provided for @backupAccessDeniedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accès Refusé — Espace Système'**
  String get backupAccessDeniedTitle;

  /// No description provided for @backupAccessDeniedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cet espace est réservé aux administrateurs ICT du système.'**
  String get backupAccessDeniedMessage;

  /// No description provided for @backupAccessDeniedSub.
  ///
  /// In fr, this message translates to:
  /// **'Contactez le service informatique si vous pensez que c\'est une erreur.'**
  String get backupAccessDeniedSub;

  /// No description provided for @backupAutoDisableWarning.
  ///
  /// In fr, this message translates to:
  /// **'Attention : La base de données de l\'hôpital n\'est plus protégée par les sauvegardes automatiques. Réactivez cette option dès que possible.'**
  String get backupAutoDisableWarning;

  /// No description provided for @backupRestoreButton.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get backupRestoreButton;

  /// No description provided for @backupRestoreDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la restauration'**
  String get backupRestoreDialogTitle;

  /// No description provided for @backupRestoreDialogWarning.
  ///
  /// In fr, this message translates to:
  /// **'Cette opération va écraser toutes les données de production actuelles et les remplacer par la sauvegarde du {date}. Cette action est irréversible.'**
  String backupRestoreDialogWarning(String date);

  /// No description provided for @backupRestoreTypeInstruction.
  ///
  /// In fr, this message translates to:
  /// **'Pour confirmer, tapez RESTAURER dans le champ ci-dessous :'**
  String get backupRestoreTypeInstruction;

  /// No description provided for @backupRestoreConfirmWord.
  ///
  /// In fr, this message translates to:
  /// **'RESTAURER'**
  String get backupRestoreConfirmWord;

  /// No description provided for @backupRestoreConfirmButton.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la restauration'**
  String get backupRestoreConfirmButton;

  /// No description provided for @backupRestoreSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Restauration effectuée avec succès'**
  String get backupRestoreSuccess;

  /// No description provided for @backupRestoreError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la restauration : {error}'**
  String backupRestoreError(String error);

  /// No description provided for @backupRestoring.
  ///
  /// In fr, this message translates to:
  /// **'Restauration en cours...'**
  String get backupRestoring;

  /// No description provided for @issueDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Détail de l\'Incident'**
  String get issueDetailTitle;

  /// No description provided for @issueDetailSectionContext.
  ///
  /// In fr, this message translates to:
  /// **'Contexte'**
  String get issueDetailSectionContext;

  /// No description provided for @issueDetailSectionFailure.
  ///
  /// In fr, this message translates to:
  /// **'Panne'**
  String get issueDetailSectionFailure;

  /// No description provided for @issueDetailSectionIntervention.
  ///
  /// In fr, this message translates to:
  /// **'Suivi d\'intervention'**
  String get issueDetailSectionIntervention;

  /// No description provided for @issueDetailSectionResources.
  ///
  /// In fr, this message translates to:
  /// **'Ressources'**
  String get issueDetailSectionResources;

  /// No description provided for @issueDetailSectionHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get issueDetailSectionHistory;

  /// No description provided for @issueDetailEquipmentLink.
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'équipement'**
  String get issueDetailEquipmentLink;

  /// No description provided for @issueDetailRootCause.
  ///
  /// In fr, this message translates to:
  /// **'Cause racine (diagnostic)'**
  String get issueDetailRootCause;

  /// No description provided for @issueDetailCorrectiveActions.
  ///
  /// In fr, this message translates to:
  /// **'Actions correctives'**
  String get issueDetailCorrectiveActions;

  /// No description provided for @issueDetailPartsUsed.
  ///
  /// In fr, this message translates to:
  /// **'Pièces remplacées'**
  String get issueDetailPartsUsed;

  /// No description provided for @issueDetailMaintenanceHistory.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance récente'**
  String get issueDetailMaintenanceHistory;

  /// No description provided for @issueDetailNoHistory.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement enregistré'**
  String get issueDetailNoHistory;

  /// No description provided for @issueDetailLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des détails...'**
  String get issueDetailLoading;

  /// No description provided for @issueDetailCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie d\'incident'**
  String get issueDetailCategory;

  /// No description provided for @issueDetailGroup.
  ///
  /// In fr, this message translates to:
  /// **'Groupe technique'**
  String get issueDetailGroup;

  /// No description provided for @issueDetailLocation.
  ///
  /// In fr, this message translates to:
  /// **'Localisation'**
  String get issueDetailLocation;

  /// No description provided for @issueDetailUpdatedAt.
  ///
  /// In fr, this message translates to:
  /// **'Dernière mise à jour'**
  String get issueDetailUpdatedAt;

  /// No description provided for @issueDetailUpdateButton.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour l\'incident'**
  String get issueDetailUpdateButton;

  /// No description provided for @issueDetailTypeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type de défaillance'**
  String get issueDetailTypeLabel;

  /// No description provided for @issueDetailReporter.
  ///
  /// In fr, this message translates to:
  /// **'Signalé par'**
  String get issueDetailReporter;

  /// No description provided for @issueDetailReportDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de signalement'**
  String get issueDetailReportDate;

  /// No description provided for @issueDetailAssignedTech.
  ///
  /// In fr, this message translates to:
  /// **'Technicien assigné'**
  String get issueDetailAssignedTech;

  /// No description provided for @issueDetailNoIntervention.
  ///
  /// In fr, this message translates to:
  /// **'Aucune intervention enregistrée'**
  String get issueDetailNoIntervention;

  /// No description provided for @issueDetailNoMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Aucune maintenance enregistrée'**
  String get issueDetailNoMaintenance;

  /// No description provided for @issueDetailTimelineCreated.
  ///
  /// In fr, this message translates to:
  /// **'Incident signalé'**
  String get issueDetailTimelineCreated;

  /// No description provided for @issueDetailLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les détails de l\'incident.'**
  String get issueDetailLoadError;

  /// No description provided for @macroCategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Macro-catégorie'**
  String get macroCategoryLabel;

  /// No description provided for @macroCategoryBiomedical.
  ///
  /// In fr, this message translates to:
  /// **'Biomédical'**
  String get macroCategoryBiomedical;

  /// No description provided for @macroCategoryInfrastructure.
  ///
  /// In fr, this message translates to:
  /// **'Infrastructure'**
  String get macroCategoryInfrastructure;

  /// No description provided for @macroCategoryIT.
  ///
  /// In fr, this message translates to:
  /// **'Informatique (IT)'**
  String get macroCategoryIT;

  /// No description provided for @subcategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Sous-catégorie'**
  String get subcategoryLabel;

  /// No description provided for @subcategorySelectHint.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez une sous-catégorie'**
  String get subcategorySelectHint;

  /// No description provided for @criticalityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Criticité (Matrice ABC)'**
  String get criticalityLabel;

  /// No description provided for @criticalityA.
  ///
  /// In fr, this message translates to:
  /// **'A — Critique'**
  String get criticalityA;

  /// No description provided for @criticalityB.
  ///
  /// In fr, this message translates to:
  /// **'B — Important'**
  String get criticalityB;

  /// No description provided for @criticalityC.
  ///
  /// In fr, this message translates to:
  /// **'C — Courant'**
  String get criticalityC;

  /// No description provided for @criticalityTooltipA.
  ///
  /// In fr, this message translates to:
  /// **'Panne = arrêt immédiat des soins. Priorité absolue.'**
  String get criticalityTooltipA;

  /// No description provided for @criticalityTooltipB.
  ///
  /// In fr, this message translates to:
  /// **'Impact significatif mais solution de repli possible.'**
  String get criticalityTooltipB;

  /// No description provided for @criticalityTooltipC.
  ///
  /// In fr, this message translates to:
  /// **'Peu d\'impact sur la continuité des soins.'**
  String get criticalityTooltipC;

  /// No description provided for @warrantyEndDate.
  ///
  /// In fr, this message translates to:
  /// **'Fin de garantie'**
  String get warrantyEndDate;

  /// No description provided for @warrantyEndDateHint.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner la date de fin de garantie (optionnel)'**
  String get warrantyEndDateHint;

  /// No description provided for @warrantyExpired.
  ///
  /// In fr, this message translates to:
  /// **'Garantie expirée'**
  String get warrantyExpired;

  /// No description provided for @warrantyExpiringSoon.
  ///
  /// In fr, this message translates to:
  /// **'Garantie expirée dans 30 jours'**
  String get warrantyExpiringSoon;

  /// No description provided for @warrantyValid.
  ///
  /// In fr, this message translates to:
  /// **'Sous garantie'**
  String get warrantyValid;

  /// No description provided for @pmProtocolsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Protocoles de Maintenance Préventive'**
  String get pmProtocolsTitle;

  /// No description provided for @pmProtocolsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Checklists et fréquences par type d\'équipement'**
  String get pmProtocolsSubtitle;

  /// No description provided for @pmProtocolFrequency.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence'**
  String get pmProtocolFrequency;

  /// No description provided for @pmProtocolFrequencyMonths.
  ///
  /// In fr, this message translates to:
  /// **'{n} mois'**
  String pmProtocolFrequencyMonths(int n);

  /// No description provided for @pmProtocolDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée estimée'**
  String get pmProtocolDuration;

  /// No description provided for @pmProtocolDurationHours.
  ///
  /// In fr, this message translates to:
  /// **'{h} h'**
  String pmProtocolDurationHours(String h);

  /// No description provided for @pmProtocolChecklist.
  ///
  /// In fr, this message translates to:
  /// **'Checklist'**
  String get pmProtocolChecklist;

  /// No description provided for @pmProtocolChecklistEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune tâche définie'**
  String get pmProtocolChecklistEmpty;

  /// No description provided for @pmProtocolAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un protocole'**
  String get pmProtocolAdd;

  /// No description provided for @pmProtocolEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le protocole'**
  String get pmProtocolEdit;

  /// No description provided for @pmProtocolDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le protocole'**
  String get pmProtocolDelete;

  /// No description provided for @pmProtocolDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le protocole \"{name}\" ?'**
  String pmProtocolDeleteConfirm(String name);

  /// No description provided for @pmProtocolSaved.
  ///
  /// In fr, this message translates to:
  /// **'Protocole enregistré'**
  String get pmProtocolSaved;

  /// No description provided for @pmProtocolDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Protocole supprimé'**
  String get pmProtocolDeleted;

  /// No description provided for @pmProtocolNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom du protocole *'**
  String get pmProtocolNameLabel;

  /// No description provided for @pmProtocolFrequencyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence (mois) *'**
  String get pmProtocolFrequencyLabel;

  /// No description provided for @pmProtocolDurationLabel.
  ///
  /// In fr, this message translates to:
  /// **'Durée estimée (heures)'**
  String get pmProtocolDurationLabel;

  /// No description provided for @pmProtocolChecklistLabel.
  ///
  /// In fr, this message translates to:
  /// **'Tâches de la checklist'**
  String get pmProtocolChecklistLabel;

  /// No description provided for @pmProtocolAddTask.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une tâche'**
  String get pmProtocolAddTask;

  /// No description provided for @pmProtocolTaskHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Vérifier la tension secteur'**
  String get pmProtocolTaskHint;

  /// No description provided for @pmProtocolNoProtocols.
  ///
  /// In fr, this message translates to:
  /// **'Aucun protocole PM pour ce type d\'équipement'**
  String get pmProtocolNoProtocols;

  /// No description provided for @equipmentSubcategorySection.
  ///
  /// In fr, this message translates to:
  /// **'Classification GMAO'**
  String get equipmentSubcategorySection;

  /// No description provided for @equipmentWarrantySection.
  ///
  /// In fr, this message translates to:
  /// **'Garantie & Criticité'**
  String get equipmentWarrantySection;

  /// No description provided for @equipmentPmSection.
  ///
  /// In fr, this message translates to:
  /// **'Protocoles PM applicables'**
  String get equipmentPmSection;

  /// No description provided for @systemStatusOperational.
  ///
  /// In fr, this message translates to:
  /// **'Statut système : Opérationnel'**
  String get systemStatusOperational;

  /// No description provided for @systemStatusDegraded.
  ///
  /// In fr, this message translates to:
  /// **'Statut système : Dégradé'**
  String get systemStatusDegraded;

  /// No description provided for @systemStatusChecking.
  ///
  /// In fr, this message translates to:
  /// **'Vérification en cours…'**
  String get systemStatusChecking;

  /// No description provided for @systemStatusLastCheck.
  ///
  /// In fr, this message translates to:
  /// **'Dernière vérif. à {time}'**
  String systemStatusLastCheck(String time);

  /// No description provided for @systemAlertBannerAuth.
  ///
  /// In fr, this message translates to:
  /// **'Service d\'authentification indisponible. Veuillez contacter l\'administrateur IT.'**
  String get systemAlertBannerAuth;

  /// No description provided for @systemAlertBannerGeneral.
  ///
  /// In fr, this message translates to:
  /// **'Service(s) système indisponible(s) — fonctionnalités limitées.'**
  String get systemAlertBannerGeneral;

  /// No description provided for @loginRecentSessionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Comptes récemment utilisés sur ce poste'**
  String get loginRecentSessionsTitle;

  /// No description provided for @loginBackToLogin.
  ///
  /// In fr, this message translates to:
  /// **'Retour à la connexion'**
  String get loginBackToLogin;

  /// No description provided for @forgotPasswordHint.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre adresse email. Vous recevrez un lien pour réinitialiser votre mot de passe.'**
  String get forgotPasswordHint;

  /// No description provided for @commonNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get commonNext;

  /// No description provided for @commonBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get commonBack;

  /// No description provided for @dashboardRefreshedJustNow.
  ///
  /// In fr, this message translates to:
  /// **'À l\'instant'**
  String get dashboardRefreshedJustNow;

  /// No description provided for @dashboardRefreshedAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {n} min'**
  String dashboardRefreshedAgo(int n);

  /// No description provided for @dashboardRefreshedAt.
  ///
  /// In fr, this message translates to:
  /// **'Actualisé à {time}'**
  String dashboardRefreshedAt(String time);

  /// No description provided for @dashboardRefreshTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get dashboardRefreshTooltip;

  /// No description provided for @dashboardPmOverdue.
  ///
  /// In fr, this message translates to:
  /// **'PM en retard'**
  String get dashboardPmOverdue;

  /// No description provided for @dashboardPriorityIssues.
  ///
  /// In fr, this message translates to:
  /// **'Incidents prioritaires'**
  String get dashboardPriorityIssues;

  /// No description provided for @dashboardCriticalIssue24h.
  ///
  /// In fr, this message translates to:
  /// **'Incident critique (24h)'**
  String get dashboardCriticalIssue24h;

  /// No description provided for @dashboardTechSection.
  ///
  /// In fr, this message translates to:
  /// **'Tableau technicien'**
  String get dashboardTechSection;

  /// No description provided for @dashboardTechBacklogLabel.
  ///
  /// In fr, this message translates to:
  /// **'File d\'attente'**
  String get dashboardTechBacklogLabel;

  /// No description provided for @dashboardTechCriticalOos.
  ///
  /// In fr, this message translates to:
  /// **'Hors service critiques'**
  String get dashboardTechCriticalOos;

  /// No description provided for @dashboardSidePanelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Hors service critiques'**
  String get dashboardSidePanelTitle;

  /// No description provided for @dashboardSidePanelSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Équipements hors service avec criticité A'**
  String get dashboardSidePanelSubtitle;

  /// No description provided for @dashboardSidePanelEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun équipement critique hors service'**
  String get dashboardSidePanelEmpty;

  /// No description provided for @dashboardWeatherTitle.
  ///
  /// In fr, this message translates to:
  /// **'Météo de l\'hôpital'**
  String get dashboardWeatherTitle;

  /// No description provided for @dashboardWeatherAllGood.
  ///
  /// In fr, this message translates to:
  /// **'Tout est opérationnel — aucune alerte en cours'**
  String get dashboardWeatherAllGood;

  /// No description provided for @dashboardWeatherCriticalCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} incident(s) critique(s) ou urgent(s) en cours'**
  String dashboardWeatherCriticalCount(int count);

  /// No description provided for @dashboardWeatherOosCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} équipement(s) hors service'**
  String dashboardWeatherOosCount(int count);

  /// No description provided for @dashboardWeatherReportBtn.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un incident'**
  String get dashboardWeatherReportBtn;

  /// No description provided for @dashboardMyTasksTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes tâches du jour'**
  String get dashboardMyTasksTitle;

  /// No description provided for @dashboardMyTasksNoTasks.
  ///
  /// In fr, this message translates to:
  /// **'Aucune tâche en cours'**
  String get dashboardMyTasksNoTasks;

  /// No description provided for @dashboardMyTasksPmDue.
  ///
  /// In fr, this message translates to:
  /// **'PM à faire / imminentes'**
  String get dashboardMyTasksPmDue;

  /// No description provided for @dashboardMyTasksViewIssues.
  ///
  /// In fr, this message translates to:
  /// **'Voir mes interventions'**
  String get dashboardMyTasksViewIssues;

  /// No description provided for @dashboardScopedTo.
  ///
  /// In fr, this message translates to:
  /// **'Périmètre : {scope}'**
  String dashboardScopedTo(String scope);

  /// No description provided for @equipmentExportCsv.
  ///
  /// In fr, this message translates to:
  /// **'Exporter CSV'**
  String get equipmentExportCsv;

  /// No description provided for @equipmentExportCsvTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger la liste filtrée en CSV'**
  String get equipmentExportCsvTooltip;

  /// No description provided for @equipmentSchedulePm.
  ///
  /// In fr, this message translates to:
  /// **'Planifier PM'**
  String get equipmentSchedulePm;

  /// No description provided for @equipmentSchedulePmSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance préventive planifiée'**
  String get equipmentSchedulePmSuccess;

  /// No description provided for @equipmentFilterPmOverdueChip.
  ///
  /// In fr, this message translates to:
  /// **'PM en retard'**
  String get equipmentFilterPmOverdueChip;

  /// No description provided for @equipmentFilterPmSoonChip.
  ///
  /// In fr, this message translates to:
  /// **'PM imminente (<7j)'**
  String get equipmentFilterPmSoonChip;

  /// No description provided for @equipmentFormStep1.
  ///
  /// In fr, this message translates to:
  /// **'Infos essentielles'**
  String get equipmentFormStep1;

  /// No description provided for @equipmentFormStep2.
  ///
  /// In fr, this message translates to:
  /// **'Infos techniques'**
  String get equipmentFormStep2;

  /// No description provided for @equipmentFormStep3.
  ///
  /// In fr, this message translates to:
  /// **'GMAO & Maintenance'**
  String get equipmentFormStep3;

  /// No description provided for @equipmentFormStep1Subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Nom, catégorie, département, statut'**
  String get equipmentFormStep1Subtitle;

  /// No description provided for @equipmentFormStep2Subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Fabricant, numéro de série, localisation'**
  String get equipmentFormStep2Subtitle;

  /// No description provided for @equipmentFormStep3Subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance préventive, criticité, révision'**
  String get equipmentFormStep3Subtitle;

  /// No description provided for @equipmentReportBreakdown.
  ///
  /// In fr, this message translates to:
  /// **'Signaler une panne'**
  String get equipmentReportBreakdown;

  /// No description provided for @equipmentColumnInstallDate.
  ///
  /// In fr, this message translates to:
  /// **'Date install.'**
  String get equipmentColumnInstallDate;

  /// No description provided for @equipmentCsvWebOnly.
  ///
  /// In fr, this message translates to:
  /// **'Export CSV disponible sur navigateur web uniquement'**
  String get equipmentCsvWebOnly;

  /// No description provided for @equipmentSortBy.
  ///
  /// In fr, this message translates to:
  /// **'Trier par'**
  String get equipmentSortBy;

  /// No description provided for @equipDetailTabInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations'**
  String get equipDetailTabInfo;

  /// No description provided for @equipDetailTabMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance'**
  String get equipDetailTabMaintenance;

  /// No description provided for @equipDetailTabIncidents.
  ///
  /// In fr, this message translates to:
  /// **'Incidents'**
  String get equipDetailTabIncidents;

  /// No description provided for @equipDetailTabDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Documents'**
  String get equipDetailTabDocuments;

  /// No description provided for @equipDetailCriticalBanner.
  ///
  /// In fr, this message translates to:
  /// **'ALERTE — Équipement critique hors service. Contactez immédiatement l\'équipe technique.'**
  String get equipDetailCriticalBanner;

  /// No description provided for @equipDetailQrCode.
  ///
  /// In fr, this message translates to:
  /// **'QR Code'**
  String get equipDetailQrCode;

  /// No description provided for @equipDetailQrCodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant de l\'équipement'**
  String get equipDetailQrCodeTitle;

  /// No description provided for @equipDetailQrCodeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Copiez ou partagez l\'ID pour lier cet équipement à un incident'**
  String get equipDetailQrCodeSubtitle;

  /// No description provided for @equipDetailQrCodeCopy.
  ///
  /// In fr, this message translates to:
  /// **'Copier l\'ID'**
  String get equipDetailQrCodeCopy;

  /// No description provided for @equipDetailQrCodeCopied.
  ///
  /// In fr, this message translates to:
  /// **'ID copié !'**
  String get equipDetailQrCodeCopied;

  /// No description provided for @equipDetailKpiSection.
  ///
  /// In fr, this message translates to:
  /// **'Indicateurs de performance'**
  String get equipDetailKpiSection;

  /// No description provided for @equipDetailMttr.
  ///
  /// In fr, this message translates to:
  /// **'MTTR (Temps Moyen de Réparation)'**
  String get equipDetailMttr;

  /// No description provided for @equipDetailMttrValue.
  ///
  /// In fr, this message translates to:
  /// **'{n} jour(s)'**
  String equipDetailMttrValue(int n);

  /// No description provided for @equipDetailMttrNoData.
  ///
  /// In fr, this message translates to:
  /// **'Données insuffisantes'**
  String get equipDetailMttrNoData;

  /// No description provided for @equipDetailTotalRepairs.
  ///
  /// In fr, this message translates to:
  /// **'Réparations enregistrées'**
  String get equipDetailTotalRepairs;

  /// No description provided for @equipDetailCreatePm.
  ///
  /// In fr, this message translates to:
  /// **'Créer une intervention PM'**
  String get equipDetailCreatePm;

  /// No description provided for @equipDetailStaffReportButton.
  ///
  /// In fr, this message translates to:
  /// **'Signaler une panne'**
  String get equipDetailStaffReportButton;

  /// No description provided for @equipDetailStaffContactSection.
  ///
  /// In fr, this message translates to:
  /// **'Contact équipe technique'**
  String get equipDetailStaffContactSection;

  /// No description provided for @equipDetailStaffContactBiomedical.
  ///
  /// In fr, this message translates to:
  /// **'Équipe biomédicale'**
  String get equipDetailStaffContactBiomedical;

  /// No description provided for @equipDetailStaffContactIt.
  ///
  /// In fr, this message translates to:
  /// **'Service IT'**
  String get equipDetailStaffContactIt;

  /// No description provided for @equipDetailStaffContactInfra.
  ///
  /// In fr, this message translates to:
  /// **'Équipe infrastructure'**
  String get equipDetailStaffContactInfra;

  /// No description provided for @equipDetailStaffContactGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Service technique'**
  String get equipDetailStaffContactGeneric;

  /// No description provided for @equipDetailStaffActiveIssues.
  ///
  /// In fr, this message translates to:
  /// **'Incidents en cours sur cet équipement'**
  String get equipDetailStaffActiveIssues;

  /// No description provided for @equipDetailStaffNoActiveIssues.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident en cours'**
  String get equipDetailStaffNoActiveIssues;

  /// No description provided for @equipDetailNoDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Aucun document disponible'**
  String get equipDetailNoDocuments;

  /// No description provided for @equipDetailDocumentsHint.
  ///
  /// In fr, this message translates to:
  /// **'Les manuels d\'utilisation, fiches techniques et procédures PM seront affichés ici.'**
  String get equipDetailDocumentsHint;

  /// No description provided for @equipDetailDeleteConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'équipement'**
  String get equipDetailDeleteConfirmTitle;

  /// No description provided for @equipDetailDeleteConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Tapez le nom exact de l\'équipement pour confirmer :'**
  String get equipDetailDeleteConfirmBody;

  /// No description provided for @equipDetailDeleteConfirmLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'équipement'**
  String get equipDetailDeleteConfirmLabel;

  /// No description provided for @equipDetailDeleteConfirmHint.
  ///
  /// In fr, this message translates to:
  /// **'Tapez exactement : {name}'**
  String equipDetailDeleteConfirmHint(String name);

  /// No description provided for @equipDetailDeleteConfirmMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Le nom ne correspond pas'**
  String get equipDetailDeleteConfirmMismatch;

  /// No description provided for @equipDetailDeleteConfirmButton.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement'**
  String get equipDetailDeleteConfirmButton;

  /// No description provided for @equipDetailDeleteReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Raison (optionnel)'**
  String get equipDetailDeleteReasonLabel;

  /// No description provided for @equipDetailDeleteReasonHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Hors service définitif, remplacé…'**
  String get equipDetailDeleteReasonHint;

  /// No description provided for @equipDetailMaintenanceCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} intervention(s)'**
  String equipDetailMaintenanceCount(int count);

  /// No description provided for @issueFormSwitchTabTitle.
  ///
  /// In fr, this message translates to:
  /// **'Changer de catégorie ?'**
  String get issueFormSwitchTabTitle;

  /// No description provided for @issueFormSwitchTabMessage.
  ///
  /// In fr, this message translates to:
  /// **'Les données saisies (description, photos) seront effacées si vous changez d\'onglet. Continuer ?'**
  String get issueFormSwitchTabMessage;

  /// No description provided for @issueFormSwitchTabConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get issueFormSwitchTabConfirm;

  /// No description provided for @issueFormScanQrTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Scanner le QR code de l\'équipement'**
  String get issueFormScanQrTooltip;

  /// No description provided for @issueFormScanQrTitle.
  ///
  /// In fr, this message translates to:
  /// **'Scanner le QR code'**
  String get issueFormScanQrTitle;

  /// No description provided for @issueFormScanQrFallbackTitle.
  ///
  /// In fr, this message translates to:
  /// **'Saisir l\'identifiant'**
  String get issueFormScanQrFallbackTitle;

  /// No description provided for @issueFormScanQrFallbackHint.
  ///
  /// In fr, this message translates to:
  /// **'ID ou numéro de série de l\'équipement'**
  String get issueFormScanQrFallbackHint;

  /// No description provided for @issueFormScanQrFallbackConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get issueFormScanQrFallbackConfirm;

  /// No description provided for @issueFormScanQrNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun équipement trouvé pour cet identifiant'**
  String get issueFormScanQrNotFound;

  /// No description provided for @issueFormEquipmentAvailableLabel.
  ///
  /// In fr, this message translates to:
  /// **'Disponible pour intervention immédiate'**
  String get issueFormEquipmentAvailableLabel;

  /// No description provided for @issueFormEquipmentAvailableHint.
  ///
  /// In fr, this message translates to:
  /// **'L\'équipement peut être mis hors tension pour la réparation'**
  String get issueFormEquipmentAvailableHint;

  /// No description provided for @issueFormSuccessTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signalement soumis avec succès'**
  String get issueFormSuccessTitle;

  /// No description provided for @issueFormSuccessTicketId.
  ///
  /// In fr, this message translates to:
  /// **'N° de ticket : {id}'**
  String issueFormSuccessTicketId(String id);

  /// No description provided for @issueFormSuccessSlaLabel.
  ///
  /// In fr, this message translates to:
  /// **'Délai cible (SLA)'**
  String get issueFormSuccessSlaLabel;

  /// No description provided for @issueFormSla2h.
  ///
  /// In fr, this message translates to:
  /// **'2 heures — urgence critique'**
  String get issueFormSla2h;

  /// No description provided for @issueFormSla12h.
  ///
  /// In fr, this message translates to:
  /// **'12 heures — urgent'**
  String get issueFormSla12h;

  /// No description provided for @issueFormSla48h.
  ///
  /// In fr, this message translates to:
  /// **'48 heures — priorité moyenne'**
  String get issueFormSla48h;

  /// No description provided for @issueFormSla1week.
  ///
  /// In fr, this message translates to:
  /// **'1 semaine — faible priorité'**
  String get issueFormSla1week;

  /// No description provided for @issueFormSuccessClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get issueFormSuccessClose;

  /// No description provided for @issuesSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher incident, équipement, déclarant…'**
  String get issuesSearchHint;

  /// No description provided for @issuesFilterPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Période'**
  String get issuesFilterPeriod;

  /// No description provided for @issuesFilterPeriodAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get issuesFilterPeriodAll;

  /// No description provided for @issuesFilterPeriodLast7.
  ///
  /// In fr, this message translates to:
  /// **'7 derniers jours'**
  String get issuesFilterPeriodLast7;

  /// No description provided for @issuesFilterPeriodLast30.
  ///
  /// In fr, this message translates to:
  /// **'30 derniers jours'**
  String get issuesFilterPeriodLast30;

  /// No description provided for @issuesFilterUrgency.
  ///
  /// In fr, this message translates to:
  /// **'Urgence'**
  String get issuesFilterUrgency;

  /// No description provided for @issuesFilterGroup.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get issuesFilterGroup;

  /// No description provided for @issuesFilterGroupBiomedical.
  ///
  /// In fr, this message translates to:
  /// **'Biomédical'**
  String get issuesFilterGroupBiomedical;

  /// No description provided for @issuesFilterGroupIT.
  ///
  /// In fr, this message translates to:
  /// **'IT'**
  String get issuesFilterGroupIT;

  /// No description provided for @issuesFilterGroupInfra.
  ///
  /// In fr, this message translates to:
  /// **'Infrastructure'**
  String get issuesFilterGroupInfra;

  /// No description provided for @issuesViewSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get issuesViewSeeAll;

  /// No description provided for @issuesClearFilter.
  ///
  /// In fr, this message translates to:
  /// **'Effacer le filtre'**
  String get issuesClearFilter;

  /// No description provided for @issuesViewList.
  ///
  /// In fr, this message translates to:
  /// **'Liste'**
  String get issuesViewList;

  /// No description provided for @issuesViewKanban.
  ///
  /// In fr, this message translates to:
  /// **'Kanban'**
  String get issuesViewKanban;

  /// No description provided for @issuesExportCsv.
  ///
  /// In fr, this message translates to:
  /// **'Exporter CSV'**
  String get issuesExportCsv;

  /// No description provided for @issuesCsvWebOnly.
  ///
  /// In fr, this message translates to:
  /// **'Export CSV disponible sur navigateur web uniquement'**
  String get issuesCsvWebOnly;

  /// No description provided for @issuesKanbanColTodo.
  ///
  /// In fr, this message translates to:
  /// **'À faire'**
  String get issuesKanbanColTodo;

  /// No description provided for @issuesKanbanColInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get issuesKanbanColInProgress;

  /// No description provided for @issuesKanbanColWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get issuesKanbanColWaiting;

  /// No description provided for @issuesKanbanColDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get issuesKanbanColDone;

  /// No description provided for @issuesKanbanEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident'**
  String get issuesKanbanEmpty;

  /// No description provided for @issuesActiveFilterMyIssues.
  ///
  /// In fr, this message translates to:
  /// **'Mes incidents uniquement'**
  String get issuesActiveFilterMyIssues;

  /// No description provided for @issuesActiveFilterDeptIssues.
  ///
  /// In fr, this message translates to:
  /// **'Mon département uniquement'**
  String get issuesActiveFilterDeptIssues;

  /// No description provided for @issuesActiveFilterLabel.
  ///
  /// In fr, this message translates to:
  /// **'Filtre actif :'**
  String get issuesActiveFilterLabel;

  /// No description provided for @issueDetailHandledBy.
  ///
  /// In fr, this message translates to:
  /// **'Pris en charge par {technician} le {date}'**
  String issueDetailHandledBy(String technician, String date);

  /// No description provided for @issueDetailNotHandledYet.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'attribution à un technicien'**
  String get issueDetailNotHandledYet;

  /// No description provided for @issueDetailReassignButton.
  ///
  /// In fr, this message translates to:
  /// **'Réassigner'**
  String get issueDetailReassignButton;

  /// No description provided for @issueDetailReassignTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réassigner l\'incident'**
  String get issueDetailReassignTitle;

  /// No description provided for @issueDetailReassignGroupLabel.
  ///
  /// In fr, this message translates to:
  /// **'Groupe technique'**
  String get issueDetailReassignGroupLabel;

  /// No description provided for @issueDetailReassignReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif (obligatoire)'**
  String get issueDetailReassignReasonLabel;

  /// No description provided for @issueDetailReassignReasonHint.
  ///
  /// In fr, this message translates to:
  /// **'Expliquez la raison de la réassignation…'**
  String get issueDetailReassignReasonHint;

  /// No description provided for @issueDetailReassignReasonMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Le motif doit contenir au moins 5 caractères'**
  String get issueDetailReassignReasonMinLength;

  /// No description provided for @issueDetailReassignSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Incident réassigné avec succès'**
  String get issueDetailReassignSuccess;

  /// No description provided for @issueDetailReassignError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la réassignation : {error}'**
  String issueDetailReassignError(String error);

  /// No description provided for @issueDetailAddCommentButton.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un commentaire'**
  String get issueDetailAddCommentButton;

  /// No description provided for @issueDetailCommentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un commentaire'**
  String get issueDetailCommentTitle;

  /// No description provided for @issueDetailCommentHint.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre commentaire…'**
  String get issueDetailCommentHint;

  /// No description provided for @issueDetailCommentMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Le commentaire doit contenir au moins 5 caractères'**
  String get issueDetailCommentMinLength;

  /// No description provided for @issueDetailCommentSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get issueDetailCommentSubmit;

  /// No description provided for @issueDetailCommentSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire ajouté à l\'historique'**
  String get issueDetailCommentSuccess;

  /// No description provided for @issueDetailCommentError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {error}'**
  String issueDetailCommentError(String error);

  /// No description provided for @issueDetailSectionDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Documents & Pièces jointes'**
  String get issueDetailSectionDocuments;

  /// No description provided for @issueDetailAddDocument.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un fichier'**
  String get issueDetailAddDocument;

  /// No description provided for @issueDetailNoDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Aucun document attaché à cet incident'**
  String get issueDetailNoDocuments;

  /// No description provided for @issueDetailDocumentsHint.
  ///
  /// In fr, this message translates to:
  /// **'Rapports PDF, bons de commande, photos supplémentaires…'**
  String get issueDetailDocumentsHint;

  /// No description provided for @issueDetailPanelNoSelection.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un incident dans la liste pour voir ses détails'**
  String get issueDetailPanelNoSelection;

  /// No description provided for @issueDetailClosePanel.
  ///
  /// In fr, this message translates to:
  /// **'Fermer le panneau'**
  String get issueDetailClosePanel;

  /// No description provided for @techMarkResolvedTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez d\'abord le statut « Réparé » pour clore l\'incident'**
  String get techMarkResolvedTooltip;

  /// No description provided for @techPartsFromInventory.
  ///
  /// In fr, this message translates to:
  /// **'Pièces remplacées (inventaire)'**
  String get techPartsFromInventory;

  /// No description provided for @techPartsSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un article d\'inventaire...'**
  String get techPartsSearchHint;

  /// No description provided for @techPartsNoResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun article trouvé'**
  String get techPartsNoResults;

  /// No description provided for @techPartsStockLabel.
  ///
  /// In fr, this message translates to:
  /// **'Stock : {n} {unit}'**
  String techPartsStockLabel(int n, String unit);

  /// No description provided for @techPartsNoneSelected.
  ///
  /// In fr, this message translates to:
  /// **'Aucune pièce sélectionnée'**
  String get techPartsNoneSelected;

  /// No description provided for @techPartsOutOfStock.
  ///
  /// In fr, this message translates to:
  /// **'Rupture de stock'**
  String get techPartsOutOfStock;

  /// No description provided for @techTakenAtLabel.
  ///
  /// In fr, this message translates to:
  /// **'Prise en charge le {date}'**
  String techTakenAtLabel(String date);

  /// No description provided for @techAvailableGroupedSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Regroupés par département / localisation'**
  String get techAvailableGroupedSubtitle;

  /// No description provided for @techAvailableDeptCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} incident(s)'**
  String techAvailableDeptCount(int count);

  /// No description provided for @techDestockConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le déstockage'**
  String get techDestockConfirmTitle;

  /// No description provided for @techDestockConfirmSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déclaré les pièces suivantes :'**
  String get techDestockConfirmSubtitle;

  /// No description provided for @techDestockItemLine.
  ///
  /// In fr, this message translates to:
  /// **'{name} × {quantity} {unit}  (stock actuel : {stock})'**
  String techDestockItemLine(String name, int quantity, String unit, int stock);

  /// No description provided for @techDestockStockAfter.
  ///
  /// In fr, this message translates to:
  /// **'Stock restant estimé : {after} {unit}'**
  String techDestockStockAfter(int after, String unit);

  /// No description provided for @techDestockLowWarning.
  ///
  /// In fr, this message translates to:
  /// **'⚠ Stock faible après cette opération'**
  String get techDestockLowWarning;

  /// No description provided for @techDestockConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer et déstockerter'**
  String get techDestockConfirm;

  /// No description provided for @techEscalateButton.
  ///
  /// In fr, this message translates to:
  /// **'Escalader / Suspendre'**
  String get techEscalateButton;

  /// No description provided for @techEscalateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Escalader l\'incident'**
  String get techEscalateTitle;

  /// No description provided for @techEscalateSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Suspendez l\'incident si vous manquez de matériel ou de compétences spécifiques. Cela le rend visible aux superviseurs.'**
  String get techEscalateSubtitle;

  /// No description provided for @techEscalateStatusLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type d\'escalade'**
  String get techEscalateStatusLabel;

  /// No description provided for @techEscalateWaitingMaterials.
  ///
  /// In fr, this message translates to:
  /// **'Attente de matériaux / pièces'**
  String get techEscalateWaitingMaterials;

  /// No description provided for @techEscalateRedirected.
  ///
  /// In fr, this message translates to:
  /// **'Rediriger vers un spécialiste'**
  String get techEscalateRedirected;

  /// No description provided for @techEscalateStatusRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le type d\'escalade est obligatoire'**
  String get techEscalateStatusRequired;

  /// No description provided for @techEscalateCommentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire obligatoire'**
  String get techEscalateCommentLabel;

  /// No description provided for @techEscalateCommentHint.
  ///
  /// In fr, this message translates to:
  /// **'Expliquez le problème (pièces manquantes, expertise externe requise…)'**
  String get techEscalateCommentHint;

  /// No description provided for @techEscalateCommentMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Le commentaire doit contenir au moins 10 caractères'**
  String get techEscalateCommentMinLength;

  /// No description provided for @techEscalateSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Incident escaladé — statut : {status}'**
  String techEscalateSuccess(String status);

  /// No description provided for @techWorkOrderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bon de Travail — Clôture formelle'**
  String get techWorkOrderTitle;

  /// No description provided for @techWorkOrderSafetyCheck.
  ///
  /// In fr, this message translates to:
  /// **'J\'atteste que toutes les vérifications de sécurité ont été effectuées et que l\'équipement est en état de fonctionnement.'**
  String get techWorkOrderSafetyCheck;

  /// No description provided for @techWorkOrderSafetyRequired.
  ///
  /// In fr, this message translates to:
  /// **'Vous devez valider les vérifications de sécurité avant de clore l\'incident.'**
  String get techWorkOrderSafetyRequired;

  /// No description provided for @techWorkOrderClosingNotes.
  ///
  /// In fr, this message translates to:
  /// **'Notes de clôture'**
  String get techWorkOrderClosingNotes;

  /// No description provided for @techWorkOrderClosingNotesHint.
  ///
  /// In fr, this message translates to:
  /// **'Informations complémentaires pour le superviseur ou les futurs intervenants…'**
  String get techWorkOrderClosingNotesHint;

  /// No description provided for @techWorkOrderConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la clôture'**
  String get techWorkOrderConfirm;

  /// No description provided for @reportsPeriodLabel.
  ///
  /// In fr, this message translates to:
  /// **'Période d\'analyse'**
  String get reportsPeriodLabel;

  /// No description provided for @reportsPeriodLast7.
  ///
  /// In fr, this message translates to:
  /// **'7 jours'**
  String get reportsPeriodLast7;

  /// No description provided for @reportsPeriodLast30.
  ///
  /// In fr, this message translates to:
  /// **'30 jours'**
  String get reportsPeriodLast30;

  /// No description provided for @reportsPeriodLast90.
  ///
  /// In fr, this message translates to:
  /// **'90 jours'**
  String get reportsPeriodLast90;

  /// No description provided for @reportsPeriodYearToDate.
  ///
  /// In fr, this message translates to:
  /// **'Année en cours'**
  String get reportsPeriodYearToDate;

  /// No description provided for @reportsPeriodCustom.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisée'**
  String get reportsPeriodCustom;

  /// No description provided for @reportsKpiSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Indicateurs GMAO (KPIs)'**
  String get reportsKpiSectionTitle;

  /// No description provided for @reportsMttr.
  ///
  /// In fr, this message translates to:
  /// **'Délai moyen d\'intervention'**
  String get reportsMttr;

  /// No description provided for @reportsMttrNoData.
  ///
  /// In fr, this message translates to:
  /// **'Données insuffisantes'**
  String get reportsMttrNoData;

  /// No description provided for @reportsMttrHint.
  ///
  /// In fr, this message translates to:
  /// **'Temps moyen entre signalement et prise en charge (incidents clôturés)'**
  String get reportsMttrHint;

  /// No description provided for @reportsMttrDays.
  ///
  /// In fr, this message translates to:
  /// **'{n} jour(s)'**
  String reportsMttrDays(String n);

  /// No description provided for @reportsPmCompliance.
  ///
  /// In fr, this message translates to:
  /// **'Conformité PM'**
  String get reportsPmCompliance;

  /// No description provided for @reportsPmComplianceHint.
  ///
  /// In fr, this message translates to:
  /// **'% des équipements dont la PM n\'est pas en retard'**
  String get reportsPmComplianceHint;

  /// No description provided for @reportsPmTotal.
  ///
  /// In fr, this message translates to:
  /// **'{n} équipement(s) avec PM planifiée'**
  String reportsPmTotal(int n);

  /// No description provided for @reportsPmNoData.
  ///
  /// In fr, this message translates to:
  /// **'Aucun plan PM configuré'**
  String get reportsPmNoData;

  /// No description provided for @reportsTopDepts.
  ///
  /// In fr, this message translates to:
  /// **'Départements les plus impactés'**
  String get reportsTopDepts;

  /// No description provided for @reportsTopDeptsHint.
  ///
  /// In fr, this message translates to:
  /// **'Par nombre d\'incidents sur la période'**
  String get reportsTopDeptsHint;

  /// No description provided for @reportsTopDeptsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident sur la période sélectionnée'**
  String get reportsTopDeptsEmpty;

  /// No description provided for @reportsExportCsv.
  ///
  /// In fr, this message translates to:
  /// **'Export CSV'**
  String get reportsExportCsv;

  /// No description provided for @reportsExportCsvSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Fichier CSV téléchargé'**
  String get reportsExportCsvSuccess;

  /// No description provided for @reportsExportCsvWebOnly.
  ///
  /// In fr, this message translates to:
  /// **'Export CSV disponible sur navigateur web uniquement'**
  String get reportsExportCsvWebOnly;

  /// No description provided for @reportsIssuesInPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Incidents (période)'**
  String get reportsIssuesInPeriod;

  /// No description provided for @reportsResolutionRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux de résolution'**
  String get reportsResolutionRate;

  /// No description provided for @analyticsIssueKpiSection.
  ///
  /// In fr, this message translates to:
  /// **'Métriques incidents'**
  String get analyticsIssueKpiSection;

  /// No description provided for @analyticsEquipmentSection.
  ///
  /// In fr, this message translates to:
  /// **'État des équipements'**
  String get analyticsEquipmentSection;

  /// No description provided for @analyticsChartsSection.
  ///
  /// In fr, this message translates to:
  /// **'Graphiques de tendance'**
  String get analyticsChartsSection;

  /// No description provided for @analyticsChartsPeriodNote.
  ///
  /// In fr, this message translates to:
  /// **'Fenêtre glissante — 13 semaines (indépendant du filtre)'**
  String get analyticsChartsPeriodNote;

  /// No description provided for @analyticsIncidentTrend.
  ///
  /// In fr, this message translates to:
  /// **'Signalements vs Résolus — 13 semaines'**
  String get analyticsIncidentTrend;

  /// No description provided for @analyticsCreatedSeries.
  ///
  /// In fr, this message translates to:
  /// **'Signalés'**
  String get analyticsCreatedSeries;

  /// No description provided for @analyticsResolvedSeries.
  ///
  /// In fr, this message translates to:
  /// **'Résolus'**
  String get analyticsResolvedSeries;

  /// No description provided for @analyticsResolutionRateLabel.
  ///
  /// In fr, this message translates to:
  /// **'Taux de résolution'**
  String get analyticsResolutionRateLabel;

  /// No description provided for @analyticsOpenIssuesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Incidents ouverts'**
  String get analyticsOpenIssuesLabel;

  /// No description provided for @analyticsGroupBarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Incidents par groupe technique'**
  String get analyticsGroupBarTitle;

  /// No description provided for @analyticsGroupBiomedical.
  ///
  /// In fr, this message translates to:
  /// **'Biomédical'**
  String get analyticsGroupBiomedical;

  /// No description provided for @analyticsGroupIT.
  ///
  /// In fr, this message translates to:
  /// **'IT'**
  String get analyticsGroupIT;

  /// No description provided for @analyticsGroupInfra.
  ///
  /// In fr, this message translates to:
  /// **'Infrastructure'**
  String get analyticsGroupInfra;

  /// No description provided for @analyticsGroupOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get analyticsGroupOther;

  /// No description provided for @analyticsRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get analyticsRetry;

  /// No description provided for @analyticsNoChartData.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les données pour les graphiques'**
  String get analyticsNoChartData;

  /// No description provided for @healthStatusOk.
  ///
  /// In fr, this message translates to:
  /// **'Opérationnel'**
  String get healthStatusOk;

  /// No description provided for @healthStatusKo.
  ///
  /// In fr, this message translates to:
  /// **'Indisponible'**
  String get healthStatusKo;

  /// No description provided for @healthTooltipTitle.
  ///
  /// In fr, this message translates to:
  /// **'État des services'**
  String get healthTooltipTitle;

  /// No description provided for @healthTooltipLastCheck.
  ///
  /// In fr, this message translates to:
  /// **'Dernière vérif. : {time}'**
  String healthTooltipLastCheck(String time);

  /// No description provided for @healthTooltipNoCheck.
  ///
  /// In fr, this message translates to:
  /// **'Vérification en cours…'**
  String get healthTooltipNoCheck;

  /// No description provided for @accessRequestLink.
  ///
  /// In fr, this message translates to:
  /// **'Demander un accès'**
  String get accessRequestLink;

  /// No description provided for @accessRequestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demande d\'accès au système'**
  String get accessRequestTitle;

  /// No description provided for @accessRequestSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Créez votre compte en quelques secondes. Vous serez connecté automatiquement avec le rôle Personnel hospitalier.'**
  String get accessRequestSubtitle;

  /// No description provided for @accessRequestFirstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom *'**
  String get accessRequestFirstName;

  /// No description provided for @accessRequestLastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom *'**
  String get accessRequestLastName;

  /// No description provided for @accessRequestEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email professionnel *'**
  String get accessRequestEmail;

  /// No description provided for @accessRequestDepartment.
  ///
  /// In fr, this message translates to:
  /// **'Département (optionnel)'**
  String get accessRequestDepartment;

  /// No description provided for @accessRequestPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe *'**
  String get accessRequestPassword;

  /// No description provided for @accessRequestPasswordConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe *'**
  String get accessRequestPasswordConfirm;

  /// No description provided for @accessRequestPasswordTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Minimum 8 caractères'**
  String get accessRequestPasswordTooShort;

  /// No description provided for @accessRequestPasswordMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get accessRequestPasswordMismatch;

  /// No description provided for @accessRequestAccountExists.
  ///
  /// In fr, this message translates to:
  /// **'Cet email est déjà associé à un compte'**
  String get accessRequestAccountExists;

  /// No description provided for @accessRequestSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get accessRequestSubmit;

  /// No description provided for @accessRequestSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Compte créé ! Connexion en cours…'**
  String get accessRequestSuccess;

  /// No description provided for @accessRequestError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création. Réessayez ou contactez directement l\'administrateur IT.'**
  String get accessRequestError;

  /// No description provided for @accessRequestOtherOption.
  ///
  /// In fr, this message translates to:
  /// **'Autre / Non listé'**
  String get accessRequestOtherOption;

  /// No description provided for @emergencyContactTitle.
  ///
  /// In fr, this message translates to:
  /// **'Urgence ou compte bloqué ?'**
  String get emergencyContactTitle;

  /// No description provided for @emergencyContactInfo.
  ///
  /// In fr, this message translates to:
  /// **'Admin IT : nzephmd@gmail.com  •  +250 788 823 228'**
  String get emergencyContactInfo;

  /// No description provided for @hubStaffTitle.
  ///
  /// In fr, this message translates to:
  /// **'Que souhaitez-vous faire ?'**
  String get hubStaffTitle;

  /// No description provided for @hubStaffReportButton.
  ///
  /// In fr, this message translates to:
  /// **'Signaler une panne'**
  String get hubStaffReportButton;

  /// No description provided for @hubStaffActiveIssuesButton.
  ///
  /// In fr, this message translates to:
  /// **'Mes incidents actifs'**
  String get hubStaffActiveIssuesButton;

  /// No description provided for @hubStaffActiveIssuesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} incident(s) en cours'**
  String hubStaffActiveIssuesCount(int count);

  /// No description provided for @hubStaffNoActiveIssues.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident actif pour le moment'**
  String get hubStaffNoActiveIssues;

  /// No description provided for @hubTechWorkplanTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon plan de travail du jour'**
  String get hubTechWorkplanTitle;

  /// No description provided for @hubTechWorkplanSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Tâches planifiées et interventions assignées'**
  String get hubTechWorkplanSubtitle;

  /// No description provided for @hubTechPmSection.
  ///
  /// In fr, this message translates to:
  /// **'Maintenances préventives (PM)'**
  String get hubTechPmSection;

  /// No description provided for @hubTechAssignedSection.
  ///
  /// In fr, this message translates to:
  /// **'Mes interventions assignées'**
  String get hubTechAssignedSection;

  /// No description provided for @hubTechPendingPartsSection.
  ///
  /// In fr, this message translates to:
  /// **'En attente de pièces'**
  String get hubTechPendingPartsSection;

  /// No description provided for @hubTechNoPm.
  ///
  /// In fr, this message translates to:
  /// **'Aucune PM en retard ou imminente'**
  String get hubTechNoPm;

  /// No description provided for @hubTechNoAssigned.
  ///
  /// In fr, this message translates to:
  /// **'Aucune intervention assignée en cours'**
  String get hubTechNoAssigned;

  /// No description provided for @hubTechNoPendingParts.
  ///
  /// In fr, this message translates to:
  /// **'Aucune pièce en attente'**
  String get hubTechNoPendingParts;

  /// No description provided for @hubTechViewAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get hubTechViewAll;

  /// No description provided for @hubTechPmOverdueLabel.
  ///
  /// In fr, this message translates to:
  /// **'PM en retard'**
  String get hubTechPmOverdueLabel;

  /// No description provided for @hubTechPmSoonLabel.
  ///
  /// In fr, this message translates to:
  /// **'PM imminente (< 7 j)'**
  String get hubTechPmSoonLabel;

  /// No description provided for @hubKpiLastRefreshLabel.
  ///
  /// In fr, this message translates to:
  /// **'Données actualisées'**
  String get hubKpiLastRefreshLabel;

  /// No description provided for @equipmentViewGrid.
  ///
  /// In fr, this message translates to:
  /// **'Vue grille'**
  String get equipmentViewGrid;

  /// No description provided for @equipmentViewList.
  ///
  /// In fr, this message translates to:
  /// **'Vue liste'**
  String get equipmentViewList;

  /// No description provided for @equipmentColumnLastPm.
  ///
  /// In fr, this message translates to:
  /// **'Dernière PM / Intervention'**
  String get equipmentColumnLastPm;

  /// No description provided for @equipmentFilterMyUnit.
  ///
  /// In fr, this message translates to:
  /// **'Mon unité / Ma salle'**
  String get equipmentFilterMyUnit;

  /// No description provided for @equipmentFilterUnit.
  ///
  /// In fr, this message translates to:
  /// **'Unité / Salle'**
  String get equipmentFilterUnit;

  /// No description provided for @equipmentScanQrTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par QR code'**
  String get equipmentScanQrTooltip;

  /// No description provided for @equipmentScanQrTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par QR'**
  String get equipmentScanQrTitle;

  /// No description provided for @equipmentScanQrManualTitle.
  ///
  /// In fr, this message translates to:
  /// **'Saisir l\'identifiant manuellement'**
  String get equipmentScanQrManualTitle;

  /// No description provided for @equipmentScanQrManualHint.
  ///
  /// In fr, this message translates to:
  /// **'ID ou numéro de série de l\'équipement'**
  String get equipmentScanQrManualHint;

  /// No description provided for @equipmentScanQrNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun équipement trouvé pour cet identifiant'**
  String get equipmentScanQrNotFound;

  /// No description provided for @equipmentCsvShared.
  ///
  /// In fr, this message translates to:
  /// **'Fichier CSV prêt à partager'**
  String get equipmentCsvShared;

  /// No description provided for @equipmentCsvShareError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du partage du CSV'**
  String get equipmentCsvShareError;

  /// No description provided for @issueFormStep1Label.
  ///
  /// In fr, this message translates to:
  /// **'Étape 1 / 2 — Catégorie & Équipement'**
  String get issueFormStep1Label;

  /// No description provided for @issueFormStep2Label.
  ///
  /// In fr, this message translates to:
  /// **'Étape 2 / 2 — Description & Photos'**
  String get issueFormStep2Label;

  /// No description provided for @issueFormScanBlock.
  ///
  /// In fr, this message translates to:
  /// **'Signaler par QR Code'**
  String get issueFormScanBlock;

  /// No description provided for @issueFormScanBlockTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Mode ultra-rapide : scanner → urgence Critique → 2 champs à remplir'**
  String get issueFormScanBlockTooltip;

  /// No description provided for @issueFormScanBlockUrgencySet.
  ///
  /// In fr, this message translates to:
  /// **'Urgence mise à Critique — complétez la description'**
  String get issueFormScanBlockUrgencySet;

  /// No description provided for @issueFormUnlistedEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Équipement non répertorié'**
  String get issueFormUnlistedEquipment;

  /// No description provided for @issueFormUnlistedEquipmentNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'équipement'**
  String get issueFormUnlistedEquipmentNameLabel;

  /// No description provided for @issueFormUnlistedEquipmentHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Respirateur salle 3, Moniteur lit 12...'**
  String get issueFormUnlistedEquipmentHint;

  /// No description provided for @issueFormUnlistedEquipmentRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir le nom de l\'équipement'**
  String get issueFormUnlistedEquipmentRequired;

  /// No description provided for @issueFormUnlistedWarning.
  ///
  /// In fr, this message translates to:
  /// **'Le technicien devra identifier cet équipement sur site.'**
  String get issueFormUnlistedWarning;

  /// No description provided for @issueFormPhotoGuide.
  ///
  /// In fr, this message translates to:
  /// **'Conseil : photographiez l\'écran d\'erreur, l\'étiquette de l\'équipement ou la zone défaillante.'**
  String get issueFormPhotoGuide;

  /// No description provided for @notifPrefsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Alertes emails — Incidents critiques'**
  String get notifPrefsTitle;

  /// No description provided for @notifPrefsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les notifications portent sur les incidents de niveau Critique uniquement.'**
  String get notifPrefsSubtitle;

  /// No description provided for @notifPrefsScope.
  ///
  /// In fr, this message translates to:
  /// **'Incidents de niveau Critique seulement'**
  String get notifPrefsScope;

  /// No description provided for @notifPrefsFirstSetupSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue ! Configurez vos alertes email.'**
  String get notifPrefsFirstSetupSubtitle;

  /// No description provided for @notifPrefsSkip.
  ///
  /// In fr, this message translates to:
  /// **'Ignorer'**
  String get notifPrefsSkip;

  /// No description provided for @notifPrefsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Préférences d\'alerte mises à jour'**
  String get notifPrefsUpdated;

  /// No description provided for @notifPrefsAllEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les alertes activées'**
  String get notifPrefsAllEnabled;

  /// No description provided for @notifPrefsSomeEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Alertes partiellement activées'**
  String get notifPrefsSomeEnabled;

  /// No description provided for @notifPrefsAllDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les alertes désactivées'**
  String get notifPrefsAllDisabled;

  /// No description provided for @notifPrefsSectionTechnician.
  ///
  /// In fr, this message translates to:
  /// **'Alertes technicien'**
  String get notifPrefsSectionTechnician;

  /// No description provided for @notifPrefsSectionSupervisor.
  ///
  /// In fr, this message translates to:
  /// **'Alertes superviseur'**
  String get notifPrefsSectionSupervisor;

  /// No description provided for @notifPrefsCriticalNewIssue.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel incident critique signalé'**
  String get notifPrefsCriticalNewIssue;

  /// No description provided for @notifPrefsCriticalNewIssueDesc.
  ///
  /// In fr, this message translates to:
  /// **'Email dès qu\'un incident CRITIQUE est signalé dans votre groupe technique.'**
  String get notifPrefsCriticalNewIssueDesc;

  /// No description provided for @notifPrefsCriticalAcknowledged.
  ///
  /// In fr, this message translates to:
  /// **'Incident critique pris en charge'**
  String get notifPrefsCriticalAcknowledged;

  /// No description provided for @notifPrefsCriticalAcknowledgedDesc.
  ///
  /// In fr, this message translates to:
  /// **'Email quand un technicien prend en charge un incident critique.'**
  String get notifPrefsCriticalAcknowledgedDesc;

  /// No description provided for @notifPrefsCriticalDiagnosed.
  ///
  /// In fr, this message translates to:
  /// **'Diagnostic posé sur un incident critique'**
  String get notifPrefsCriticalDiagnosed;

  /// No description provided for @notifPrefsCriticalDiagnosedDesc.
  ///
  /// In fr, this message translates to:
  /// **'Email dès qu\'un technicien renseigne le diagnostic d\'un incident critique.'**
  String get notifPrefsCriticalDiagnosedDesc;

  /// No description provided for @notifPrefsCriticalResolved.
  ///
  /// In fr, this message translates to:
  /// **'Incident critique résolu (avec KPIs)'**
  String get notifPrefsCriticalResolved;

  /// No description provided for @notifPrefsCriticalResolvedDesc.
  ///
  /// In fr, this message translates to:
  /// **'Email de clôture avec délai de résolution, diagnostic, actions et pièces remplacées.'**
  String get notifPrefsCriticalResolvedDesc;

  /// No description provided for @notifPrefsPmDue.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance préventive à planifier'**
  String get notifPrefsPmDue;

  /// No description provided for @notifPrefsPmDueDesc.
  ///
  /// In fr, this message translates to:
  /// **'Email quand une maintenance préventive est en retard ou imminente.'**
  String get notifPrefsPmDueDesc;

  /// No description provided for @reportsPdfExportTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Générer et télécharger le rapport PDF'**
  String get reportsPdfExportTooltip;

  /// No description provided for @reportsPdfSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Rapport PDF prêt — enregistrez-le depuis la boîte de dialogue'**
  String get reportsPdfSuccess;

  /// No description provided for @reportsPdfError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la génération du PDF'**
  String get reportsPdfError;

  /// No description provided for @navDebugTest.
  ///
  /// In fr, this message translates to:
  /// **'Debug & Test'**
  String get navDebugTest;

  /// No description provided for @navDebugTestShort.
  ///
  /// In fr, this message translates to:
  /// **'Debug'**
  String get navDebugTestShort;

  /// No description provided for @debugTitle.
  ///
  /// In fr, this message translates to:
  /// **'Module Debug & Test'**
  String get debugTitle;

  /// No description provided for @debugSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Réservé aux administrateurs — actions irréversibles sur les données'**
  String get debugSubtitle;

  /// No description provided for @debugDbSection.
  ///
  /// In fr, this message translates to:
  /// **'Gestion de la Base de Données'**
  String get debugDbSection;

  /// No description provided for @debugClearIssuesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nettoyer tous les signalements d\'incidents'**
  String get debugClearIssuesLabel;

  /// No description provided for @debugClearIssuesDesc.
  ///
  /// In fr, this message translates to:
  /// **'Supprime définitivement tous les incidents de la base de données. Cette action est irréversible.'**
  String get debugClearIssuesDesc;

  /// No description provided for @debugClearIssuesButton.
  ///
  /// In fr, this message translates to:
  /// **'Nettoyer tous les signalements'**
  String get debugClearIssuesButton;

  /// No description provided for @debugClearIssuesLoading.
  ///
  /// In fr, this message translates to:
  /// **'Nettoyage en cours...'**
  String get debugClearIssuesLoading;

  /// No description provided for @debugClearIssuesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le nettoyage'**
  String get debugClearIssuesTitle;

  /// No description provided for @debugClearIssuesMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette action va supprimer TOUS les incidents de la base de données. Cette opération est irréversible et ne peut pas être annulée.'**
  String get debugClearIssuesMessage;

  /// No description provided for @debugClearIssuesConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Tout supprimer'**
  String get debugClearIssuesConfirm;

  /// No description provided for @debugClearIssuesSuccess.
  ///
  /// In fr, this message translates to:
  /// **'{count} incident(s) supprimé(s) avec succès'**
  String debugClearIssuesSuccess(int count);

  /// No description provided for @debugClearIssuesError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du nettoyage : {error}'**
  String debugClearIssuesError(String error);

  /// No description provided for @reportsArchivesSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Archives & Rapports Historiques'**
  String get reportsArchivesSectionTitle;

  /// No description provided for @reportsArchivesTypeMonthly.
  ///
  /// In fr, this message translates to:
  /// **'Mensuel'**
  String get reportsArchivesTypeMonthly;

  /// No description provided for @reportsArchivesTypeAnnual.
  ///
  /// In fr, this message translates to:
  /// **'Annuel'**
  String get reportsArchivesTypeAnnual;

  /// No description provided for @reportsArchivesDownload.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger le rapport PDF'**
  String get reportsArchivesDownload;

  /// No description provided for @reportsArchivesDownloading.
  ///
  /// In fr, this message translates to:
  /// **'Génération en cours…'**
  String get reportsArchivesDownloading;

  /// No description provided for @reportsArchivesHint.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez une période pour télécharger un rapport historique au format PDF.'**
  String get reportsArchivesHint;

  /// No description provided for @pmProtocols.
  ///
  /// In fr, this message translates to:
  /// **'Protocoles de maintenance'**
  String get pmProtocols;

  /// No description provided for @pmChecklist.
  ///
  /// In fr, this message translates to:
  /// **'Checklist de maintenance'**
  String get pmChecklist;

  /// No description provided for @pmStepsProgress.
  ///
  /// In fr, this message translates to:
  /// **'{done} / {total} étapes validées'**
  String pmStepsProgress(int done, int total);

  /// No description provided for @pmNoProtocolAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucun protocole défini pour ce type d\'équipement'**
  String get pmNoProtocolAvailable;

  /// No description provided for @pmFrequencyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence de maintenance'**
  String get pmFrequencyLabel;

  /// No description provided for @pmFrequencyValue.
  ///
  /// In fr, this message translates to:
  /// **'Tous les {months} mois'**
  String pmFrequencyValue(int months);

  /// No description provided for @pmDurationEstimated.
  ///
  /// In fr, this message translates to:
  /// **'Durée estimée : {min} min'**
  String pmDurationEstimated(int min);

  /// No description provided for @pmDurationActual.
  ///
  /// In fr, this message translates to:
  /// **'Durée réelle : {min} min'**
  String pmDurationActual(int min);

  /// No description provided for @pmValidateButton.
  ///
  /// In fr, this message translates to:
  /// **'Valider la maintenance préventive'**
  String get pmValidateButton;

  /// No description provided for @pmValidateConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la validation'**
  String get pmValidateConfirmTitle;

  /// No description provided for @pmValidateConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'{unchecked} étape(s) non cochée(s). Valider quand même ?'**
  String pmValidateConfirmBody(int unchecked);

  /// No description provided for @pmValidateSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance enregistrée'**
  String get pmValidateSuccess;

  /// No description provided for @pmNextDate.
  ///
  /// In fr, this message translates to:
  /// **'Prochaine maintenance : {date}'**
  String pmNextDate(String date);

  /// No description provided for @pmPrintLabel.
  ///
  /// In fr, this message translates to:
  /// **'Imprimer l\'étiquette'**
  String get pmPrintLabel;

  /// No description provided for @pmEditLabel.
  ///
  /// In fr, this message translates to:
  /// **'Étiquette de maintenance'**
  String get pmEditLabel;

  /// No description provided for @pmHistoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique des maintenances préventives'**
  String get pmHistoryTitle;

  /// No description provided for @pmComplianceRate.
  ///
  /// In fr, this message translates to:
  /// **'Conformité : {rate}%'**
  String pmComplianceRate(int rate);

  /// No description provided for @pmPartsUsed.
  ///
  /// In fr, this message translates to:
  /// **'Pièces utilisées'**
  String get pmPartsUsed;

  /// No description provided for @pmSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get pmSeeAll;

  /// No description provided for @pmFrequencySaved.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence de maintenance mise à jour'**
  String get pmFrequencySaved;

  /// No description provided for @pmFrequencySelectLabel.
  ///
  /// In fr, this message translates to:
  /// **'Définir la fréquence PM'**
  String get pmFrequencySelectLabel;

  /// No description provided for @docTabTitle.
  ///
  /// In fr, this message translates to:
  /// **'Documents'**
  String get docTabTitle;

  /// No description provided for @docTechnicalSection.
  ///
  /// In fr, this message translates to:
  /// **'Documents techniques'**
  String get docTechnicalSection;

  /// No description provided for @docInterventionSection.
  ///
  /// In fr, this message translates to:
  /// **'Documents d\'intervention'**
  String get docInterventionSection;

  /// No description provided for @docCertificationSection.
  ///
  /// In fr, this message translates to:
  /// **'Certificats & Conformité'**
  String get docCertificationSection;

  /// No description provided for @docAddButton.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un document'**
  String get docAddButton;

  /// No description provided for @docTypeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type de document'**
  String get docTypeLabel;

  /// No description provided for @docTypeTechnical.
  ///
  /// In fr, this message translates to:
  /// **'Manuel / Fiche technique'**
  String get docTypeTechnical;

  /// No description provided for @docTypeIntervention.
  ///
  /// In fr, this message translates to:
  /// **'Rapport / Facture'**
  String get docTypeIntervention;

  /// No description provided for @docTypeCertification.
  ///
  /// In fr, this message translates to:
  /// **'Certificat / Conformité'**
  String get docTypeCertification;

  /// No description provided for @docUploadSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Document ajouté avec succès'**
  String get docUploadSuccess;

  /// No description provided for @docUploadError.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'upload : {error}'**
  String docUploadError(String error);

  /// No description provided for @docDeleteConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce document ?'**
  String get docDeleteConfirmTitle;

  /// No description provided for @docDeleteConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible.'**
  String get docDeleteConfirmBody;

  /// No description provided for @docDeleteSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Document supprimé'**
  String get docDeleteSuccess;

  /// No description provided for @docDownloadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir le document'**
  String get docDownloadError;

  /// No description provided for @docNoDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Aucun document dans cette section'**
  String get docNoDocuments;

  /// No description provided for @docRestrictedAccess.
  ///
  /// In fr, this message translates to:
  /// **'Accès réservé aux techniciens et superviseurs'**
  String get docRestrictedAccess;

  /// No description provided for @issuePhotosSection.
  ///
  /// In fr, this message translates to:
  /// **'Photos de l\'incident'**
  String get issuePhotosSection;

  /// No description provided for @issuePhotoLimitReached.
  ///
  /// In fr, this message translates to:
  /// **'Limite de 5 photos atteinte'**
  String get issuePhotoLimitReached;

  /// No description provided for @issuePhotoCompressing.
  ///
  /// In fr, this message translates to:
  /// **'Compression en cours…'**
  String get issuePhotoCompressing;

  /// No description provided for @issuePhotosUploading.
  ///
  /// In fr, this message translates to:
  /// **'Envoi des photos…'**
  String get issuePhotosUploading;

  /// No description provided for @issuePhotosNoPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Aucune photo jointe'**
  String get issuePhotosNoPhotos;

  /// No description provided for @showMore.
  ///
  /// In fr, this message translates to:
  /// **'Afficher plus'**
  String get showMore;

  /// No description provided for @allEquipmentDisplayed.
  ///
  /// In fr, this message translates to:
  /// **'Tous les équipements sont affichés'**
  String get allEquipmentDisplayed;

  /// No description provided for @issueStaffDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suivi de mon signalement'**
  String get issueStaffDetailTitle;

  /// No description provided for @issueTimelineReported.
  ///
  /// In fr, this message translates to:
  /// **'Signalé'**
  String get issueTimelineReported;

  /// No description provided for @issueTimelineAcknowledged.
  ///
  /// In fr, this message translates to:
  /// **'Pris en charge'**
  String get issueTimelineAcknowledged;

  /// No description provided for @issueTimelineInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours de réparation'**
  String get issueTimelineInProgress;

  /// No description provided for @issueTimelineResolved.
  ///
  /// In fr, this message translates to:
  /// **'Résolu'**
  String get issueTimelineResolved;

  /// No description provided for @sidebarTitleEquipment.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des équipements'**
  String get sidebarTitleEquipment;

  /// No description provided for @sidebarTitleSettings.
  ///
  /// In fr, this message translates to:
  /// **'Configuration'**
  String get sidebarTitleSettings;

  /// No description provided for @sidebarTitleInventory.
  ///
  /// In fr, this message translates to:
  /// **'Inventaire'**
  String get sidebarTitleInventory;

  /// No description provided for @sidebarTitleReports.
  ///
  /// In fr, this message translates to:
  /// **'Rapports'**
  String get sidebarTitleReports;

  /// No description provided for @see.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get see;

  /// No description provided for @exportingPdf.
  ///
  /// In fr, this message translates to:
  /// **'Génération du PDF…'**
  String get exportingPdf;

  /// No description provided for @exportError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'export. Réessayez.'**
  String get exportError;

  /// No description provided for @pushBannerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notifications désactivées'**
  String get pushBannerTitle;

  /// No description provided for @pushBannerBody.
  ///
  /// In fr, this message translates to:
  /// **'Activez les notifications pour recevoir les alertes critiques en temps réel.'**
  String get pushBannerBody;

  /// No description provided for @pushBannerActivate.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get pushBannerActivate;

  /// No description provided for @debugNotifySection.
  ///
  /// In fr, this message translates to:
  /// **'Tests de Notifications'**
  String get debugNotifySection;

  /// No description provided for @debugNotifyWarning.
  ///
  /// In fr, this message translates to:
  /// **'Scheduling actif ({interval}). Sera réinitialisé au prochain redémarrage du serveur.'**
  String debugNotifyWarning(String interval);

  /// No description provided for @debugNotifyNow.
  ///
  /// In fr, this message translates to:
  /// **'Notification immédiate'**
  String get debugNotifyNow;

  /// No description provided for @debugNotifyMinute.
  ///
  /// In fr, this message translates to:
  /// **'Notif auto (toutes les minutes)'**
  String get debugNotifyMinute;

  /// No description provided for @debugNotifyHour.
  ///
  /// In fr, this message translates to:
  /// **'Notif auto (toutes les heures)'**
  String get debugNotifyHour;

  /// No description provided for @debugNotifyStop.
  ///
  /// In fr, this message translates to:
  /// **'Stopper les notifs auto'**
  String get debugNotifyStop;

  /// No description provided for @debugNotifySent.
  ///
  /// In fr, this message translates to:
  /// **'Notification envoyée à {email}'**
  String debugNotifySent(String email);

  /// No description provided for @debugNotifyStarted.
  ///
  /// In fr, this message translates to:
  /// **'Notifications auto activées ({interval})'**
  String debugNotifyStarted(String interval);

  /// No description provided for @debugNotifyStopped.
  ///
  /// In fr, this message translates to:
  /// **'Notifications auto arrêtées'**
  String get debugNotifyStopped;

  /// No description provided for @debugNotifyAlreadyStopped.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification auto en cours'**
  String get debugNotifyAlreadyStopped;

  /// No description provided for @notificationsBell.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notificationsBell;

  /// No description provided for @notificationsUnread.
  ///
  /// In fr, this message translates to:
  /// **'{count} non lue(s)'**
  String notificationsUnread(int count);

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In fr, this message translates to:
  /// **'Tout marquer comme lu'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification'**
  String get notificationsEmpty;

  /// No description provided for @notificationsOsPermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'Notifications système désactivées. Activez-les dans les paramètres.'**
  String get notificationsOsPermissionDenied;

  /// No description provided for @notificationsTitleNewIssue.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel incident signalé'**
  String get notificationsTitleNewIssue;

  /// No description provided for @notificationsTitleCritical.
  ///
  /// In fr, this message translates to:
  /// **'Incident critique'**
  String get notificationsTitleCritical;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
