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
  /// **'Chargement des donnees...'**
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
  /// **'Parametres'**
  String get navSettings;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Se deconnecter'**
  String get logout;

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
  /// **'Details'**
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

  /// No description provided for @dashboardAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Disponibles'**
  String get dashboardAvailable;

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

  /// No description provided for @dashboardAvailableStatus.
  ///
  /// In fr, this message translates to:
  /// **'Disponible'**
  String get dashboardAvailableStatus;

  /// No description provided for @dashboardInUse.
  ///
  /// In fr, this message translates to:
  /// **'En usage'**
  String get dashboardInUse;

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
  /// **'Ouverts'**
  String get issuesOpen;

  /// No description provided for @issuesInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get issuesInProgress;

  /// No description provided for @issuesResolved.
  ///
  /// In fr, this message translates to:
  /// **'Resolus'**
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

  /// No description provided for @reportsAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Disponible'**
  String get reportsAvailable;

  /// No description provided for @reportsInUse.
  ///
  /// In fr, this message translates to:
  /// **'En usage'**
  String get reportsInUse;

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
