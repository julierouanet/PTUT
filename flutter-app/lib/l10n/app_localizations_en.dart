// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Equipment Management - Kabutare Hospital';

  @override
  String get hospitalName => 'Kabutare Hospital';

  @override
  String get hospitalSubtitle => 'Equipment Management';

  @override
  String get hospitalSubtitleLong => 'Equipment Management';

  @override
  String get loadingData => 'Loading data...';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navEquipment => 'Equipment';

  @override
  String get navIssueTracking => 'Issue Tracking';

  @override
  String get navReportIssue => 'Report';

  @override
  String get navTechnician => 'Technician';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navReports => 'Reports';

  @override
  String get navUsers => 'Users';

  @override
  String get navSettings => 'Admin';

  @override
  String get navLogs => 'Activity Logs';

  @override
  String get navLogsShort => 'Logs';

  @override
  String get navDashboardShort => 'Home';

  @override
  String get navEquipmentShort => 'Equipment';

  @override
  String get navIssueTrackingShort => 'Incidents';

  @override
  String get navReportIssueShort => 'Report';

  @override
  String get navTechnicianShort => 'Technician';

  @override
  String get navInventoryShort => 'Inventory';

  @override
  String get navReportsShort => 'Reports';

  @override
  String get navUsersShort => 'Users';

  @override
  String get navSettingsShort => 'Admin';

  @override
  String get tooltipBack => 'Back';

  @override
  String get tooltipMenu => 'Menu';

  @override
  String get tooltipAccountSettings => 'Account settings';

  @override
  String get tooltipNotifications => 'Notifications';

  @override
  String get logout => 'Log out';

  @override
  String get logoutConfirmTitle => 'Log out';

  @override
  String get logoutConfirmMessage => 'Are you sure you want to log out?';

  @override
  String get accessDenied => 'Access Denied';

  @override
  String get accessDeniedMessage =>
      'You do not have the necessary permissions to access this page.';

  @override
  String accessDeniedNav(String target) {
    return 'Access denied: you do not have permission to access \"$target\"';
  }

  @override
  String get backToDashboard => 'Back to dashboard';

  @override
  String get user => 'User';

  @override
  String get commonAll => 'All';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSearch => 'Search...';

  @override
  String get commonError => 'Error';

  @override
  String get commonDetails => 'Details';

  @override
  String get commonReport => 'Report';

  @override
  String get commonActions => 'Actions';

  @override
  String get commonStatus => 'Status';

  @override
  String get commonCategory => 'Category';

  @override
  String get commonDepartment => 'Department';

  @override
  String get commonName => 'Name';

  @override
  String get commonEmail => 'Email';

  @override
  String get commonRole => 'Role';

  @override
  String get commonDefault => 'Default';

  @override
  String get commonAbbreviation => 'Abbreviation';

  @override
  String get commonFillRequiredFields => 'Please fill in the required fields';

  @override
  String get commonFillAllFields => 'Please fill in all fields';

  @override
  String get commonIrreversible => 'This action cannot be undone.';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get loginTitle => 'Login';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginEmailRequired => 'Email required';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginPasswordRequired => 'Password required';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginInvalidCredentials => 'Invalid credentials';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardSubtitle => 'Equipment management overview';

  @override
  String get dashboardViewEquipment => 'View equipment';

  @override
  String get dashboardReportProblem => 'Report a problem';

  @override
  String get dashboardViewIssues => 'View issues';

  @override
  String get dashboardTotal => 'Total';

  @override
  String get dashboardOperational => 'Operational';

  @override
  String get dashboardMaintenance => 'Maintenance';

  @override
  String get dashboardOutOfService => 'Out of Service';

  @override
  String get dashboardEquipmentStatus => 'Equipment status';

  @override
  String get dashboardOperationalStatus => 'Operational';

  @override
  String get dashboardInMaintenance => 'In maintenance';

  @override
  String get dashboardOutOfServiceStatus => 'Out of service';

  @override
  String get dashboardRecentIssues => 'Recent reported issues';

  @override
  String get dashboardNoIssues => 'No current issues';

  @override
  String get dashboardViewAllIssues => 'View all issues';

  @override
  String get dashboardUrgentAlerts => 'Urgent alerts';

  @override
  String get dashboardNoAlerts => 'No urgent alerts';

  @override
  String get dashboardCriticalFailure => 'Critical failure';

  @override
  String get dashboardOpenIssue => 'Open issue';

  @override
  String get equipmentTitle => 'Equipment list';

  @override
  String get equipmentSubtitle => 'Management and tracking of all equipment';

  @override
  String get equipmentNew => 'New equipment';

  @override
  String get equipmentName => 'Equipment name';

  @override
  String get equipmentSerialNumber => 'Serial number';

  @override
  String equipmentFound(int count) {
    return '$count equipment found';
  }

  @override
  String get equipmentEditTitle => 'Edit equipment';

  @override
  String get equipmentNewTitle => 'New equipment';

  @override
  String get equipmentNameLabel => 'Equipment name *';

  @override
  String get equipmentNameHint => 'E.g.: Siemens MRI Scanner';

  @override
  String get equipmentSerialLabel => 'Serial number *';

  @override
  String get equipmentSerialHint => 'E.g.: SN-2023-001';

  @override
  String get equipmentDepartmentLabel => 'Department *';

  @override
  String get equipmentCategoryLabel => 'Category *';

  @override
  String get equipmentSupplier => 'Supplier';

  @override
  String get equipmentSupplierHint => 'E.g.: Siemens Healthineers';

  @override
  String get equipmentLocation => 'Location';

  @override
  String get equipmentLocationHint => 'E.g.: Building A, Room 101';

  @override
  String get equipmentModified => 'Equipment modified';

  @override
  String get equipmentAdded => 'Equipment added';

  @override
  String get equipmentSaveChanges => 'Save changes';

  @override
  String get equipmentAddButton => 'Add equipment';

  @override
  String get equipmentDeleteTitle => 'Delete equipment';

  @override
  String equipmentDeleteConfirm(String name) {
    return 'Confirm deletion of \"$name\"? This action cannot be undone.';
  }

  @override
  String get equipmentDeleted => 'Equipment deleted';

  @override
  String get equipmentMaintenanceHistory => 'Maintenance history';

  @override
  String get equipmentReportProblem => 'Report a problem';

  @override
  String get issuesApproved => 'In Progress';

  @override
  String get issuesTitle => 'Issue Tracking';

  @override
  String get issuesSubtitle => 'Manage and track equipment issues';

  @override
  String get issuesOpen => 'Reported';

  @override
  String get issuesInProgress => 'Waiting';

  @override
  String get issuesResolved => 'Completed';

  @override
  String get issuesReport => 'Report an issue';

  @override
  String get issuesFilterByStatus => 'Filter by status: ';

  @override
  String issuesCount(int count) {
    return '$count issue(s)';
  }

  @override
  String get issuesMyIssues => 'My issues';

  @override
  String get issuesMyIssuesSubtitle => 'Issues you have submitted';

  @override
  String get issuesNoMyIssues => 'You have not reported any issue yet';

  @override
  String get issuesDeptIssues => 'My department issues';

  @override
  String issuesDeptIssuesSubtitle(String dept) {
    return 'Department: $dept';
  }

  @override
  String get issuesNoDeptIssues => 'No issue reported in your department';

  @override
  String issuesAndMore(int count) {
    return '... and $count more';
  }

  @override
  String get issuesAllIssues => 'All issues';

  @override
  String issuesIncidentId(String id) {
    return 'Issue #$id';
  }

  @override
  String get issuesEquipment => 'Equipment';

  @override
  String get issuesType => 'Type';

  @override
  String get issuesDescription => 'Description';

  @override
  String get issuesReportedBy => 'Reported by';

  @override
  String get issuesReportDate => 'Report date';

  @override
  String get issuesAssignedTech => 'Assigned technician';

  @override
  String get issuesDiagnosis => 'Diagnosis';

  @override
  String get issuesUpdate => 'Update';

  @override
  String issuesReportedByDate(String reporter, String date) {
    return 'Reported by $reporter • $date';
  }

  @override
  String get issueFormTitle => 'Report a problem';

  @override
  String get issueFormSubtitle =>
      'Fill out the form to report an equipment problem';

  @override
  String get issueFormEquipment => 'Related equipment *';

  @override
  String get issueFormSelectEquipment => 'Select equipment';

  @override
  String get issueFormProblemType => 'Problem type *';

  @override
  String get issueFormBreakdown => 'Breakdown';

  @override
  String get issueFormMalfunction => 'Malfunction';

  @override
  String get issueFormWear => 'Wear';

  @override
  String get issueFormAbnormalNoise => 'Abnormal noise';

  @override
  String get issueFormLeak => 'Leak';

  @override
  String get issueFormOther => 'Other';

  @override
  String get issueFormDescription => 'Problem description *';

  @override
  String get issueFormDescriptionHint => 'Describe the problem in detail...';

  @override
  String get issueFormDescriptionRequired => 'Description is required';

  @override
  String get issueFormDescriptionMinLength =>
      'Description must be at least 10 characters';

  @override
  String get issueFormPhotos => 'Photos (optional)';

  @override
  String issueFormPhotosHint(int max) {
    return 'Add up to $max photos to illustrate the problem';
  }

  @override
  String get issueFormAddPhoto => 'Add';

  @override
  String issueFormMaxPhotos(int max) {
    return 'Maximum $max photos allowed';
  }

  @override
  String get issueFormYourName => 'Your name *';

  @override
  String get issueFormYourNameHint => 'E.g.: Dr. Martin';

  @override
  String get issueFormYourNameRequired => 'Your name is required';

  @override
  String get issueFormSubmit => 'Submit report';

  @override
  String issueFormSubmitWithPhotos(int count) {
    return 'Submit report ($count photo(s))';
  }

  @override
  String get issueFormLeaveTitle => 'Leave the form?';

  @override
  String get issueFormLeaveMessage =>
      'Information has been entered. If you leave now, it will be lost.';

  @override
  String get issueFormLeaveConfirm => 'Leave';

  @override
  String get issueFormSuccess => 'Report sent!';

  @override
  String issueFormSuccessWithPhotos(int count) {
    return 'Report sent! ($count photo(s))';
  }

  @override
  String issueFormError(String error) {
    return 'Error sending: $error';
  }

  @override
  String get techTitle => 'Technician update';

  @override
  String get techSubtitle => 'Update repair status';

  @override
  String get techNoIssues => 'No current issues';

  @override
  String get techAllResolved => 'All issues have been resolved';

  @override
  String get techSelectIssue => 'Issue to update';

  @override
  String get techSelectIssueHint => 'Select an issue';

  @override
  String techReportedByDate(String reporter, String date) {
    return 'Reported by $reporter on $date';
  }

  @override
  String get techRepairStatus => 'Repair status';

  @override
  String get techDiagnosisInProgress => 'Diagnosis in progress';

  @override
  String get techPartsOrdered => 'Parts ordered';

  @override
  String get techRepairInProgress => 'Repair in progress';

  @override
  String get techTestInProgress => 'Testing in progress';

  @override
  String get techRepaired => 'Repaired';

  @override
  String get techDiagnosis => 'Diagnosis';

  @override
  String get techDiagnosisHint => 'Describe the diagnosis...';

  @override
  String get techActionsTaken => 'Actions taken';

  @override
  String get techActionsHint => 'Describe the actions taken...';

  @override
  String get techPartsReplaced => 'Parts replaced';

  @override
  String get techPartsHint => 'E.g.: O2 sensor, Vacuum pump...';

  @override
  String get techSave => 'Save';

  @override
  String get techMarkResolved => 'Mark resolved';

  @override
  String get techProgressSaved => 'Progress saved';

  @override
  String get techIssueResolved => 'Issue marked as resolved!';

  @override
  String get inventoryTitle => 'Inventory';

  @override
  String get inventorySubtitle => 'Consumables stock management';

  @override
  String get inventoryNewItem => 'New item';

  @override
  String get inventoryCriticalStock => 'Warning: Critical stock';

  @override
  String inventoryOutOfStockCount(int count) {
    return '$count item(s) out of stock';
  }

  @override
  String inventoryLowStockCount(int count) {
    return '$count item(s) low stock';
  }

  @override
  String get inventoryFilter => 'Filter: ';

  @override
  String get inventoryMedicalConsumable => 'Medical consumable';

  @override
  String get inventoryHygiene => 'Hygiene';

  @override
  String get inventoryOffice => 'Office supplies';

  @override
  String inventoryItemCount(int count) {
    return '$count items';
  }

  @override
  String get inventoryItem => 'Item';

  @override
  String get inventoryCurrentStock => 'Current stock';

  @override
  String get inventoryMinStock => 'Min stock';

  @override
  String get inventoryUnit => 'Unit';

  @override
  String get inventoryLastRestocked => 'Last restocked';

  @override
  String get inventoryEditItem => 'Edit item';

  @override
  String get inventoryNewItemTitle => 'New item';

  @override
  String get inventoryNameLabel => 'Name *';

  @override
  String get inventoryCategoryLabel => 'Category *';

  @override
  String get inventoryCurrentStockLabel => 'Current stock *';

  @override
  String get inventoryMinStockLabel => 'Minimum stock *';

  @override
  String get inventoryUnitLabel => 'Unit (e.g.: boxes) *';

  @override
  String get inventoryItemModified => 'Item modified';

  @override
  String get inventoryItemAdded => 'Item added';

  @override
  String get inventoryDeleteItem => 'Delete item';

  @override
  String inventoryDeleteConfirm(String name) {
    return 'Delete \"$name\" from inventory?';
  }

  @override
  String get inventoryItemDeleted => 'Item deleted';

  @override
  String get reportsTitle => 'Reports & Analytics';

  @override
  String get reportsSubtitle => 'Statistics overview';

  @override
  String get reportsExport => 'Export';

  @override
  String get reportsTotalEquipment => 'Total equipment';

  @override
  String get reportsAvailabilityRate => 'Availability rate';

  @override
  String get reportsTotalIssues => 'Total issues';

  @override
  String get reportsResolvedIssues => 'Resolved issues';

  @override
  String get reportsStatusBreakdown => 'Breakdown by status';

  @override
  String get reportsOperational => 'Operational';

  @override
  String get reportsInMaintenance => 'In maintenance';

  @override
  String get reportsOutOfService => 'Out of service';

  @override
  String get reportsByDepartment => 'Equipment by department';

  @override
  String get reportsByCategory => 'Equipment by category';

  @override
  String get reportsIssueStats => 'Issue statistics';

  @override
  String get reportsExportData => 'Export data';

  @override
  String get reportsExportExcel => 'Export to Excel';

  @override
  String get reportsExportPDF => 'Export to PDF';

  @override
  String get reportsExportExcelProgress => 'Excel export in progress...';

  @override
  String get reportsExportPDFProgress => 'PDF export in progress...';

  @override
  String get reportsOpenIssues => 'Open';

  @override
  String get reportsInProgressIssues => 'In progress';

  @override
  String get reportsResolvedIssuesLabel => 'Resolved';

  @override
  String get usersTitle => 'User Management';

  @override
  String get usersSubtitle => 'Manage accounts and user roles';

  @override
  String get usersNew => 'New user';

  @override
  String get usersTotal => 'Total';

  @override
  String get usersAdmins => 'Admins';

  @override
  String get usersSupervisors => 'Supervisors';

  @override
  String get usersTechnicians => 'Technicians';

  @override
  String get usersStaff => 'Staff';

  @override
  String get usersSearchHint => 'Search by name or email...';

  @override
  String get usersFilterByRole => 'Filter by role';

  @override
  String get usersUser => 'User';

  @override
  String get usersPermissions => 'Permissions';

  @override
  String get usersEditTitle => 'Edit user';

  @override
  String get usersNewTitle => 'New user';

  @override
  String get usersFullName => 'Full name *';

  @override
  String get usersEmailLabel => 'Email *';

  @override
  String get usersNewPassword => 'New password (leave empty = unchanged)';

  @override
  String get usersPasswordLabel => 'Password *';

  @override
  String get usersPhone => 'Phone';

  @override
  String get usersModified => 'User modified';

  @override
  String get usersCreated => 'User created';

  @override
  String usersPermissionsTitle(String name) {
    return 'Permissions — $name';
  }

  @override
  String get usersActivePermissions => 'Active permissions:';

  @override
  String get usersAccountActivated => 'Account activated';

  @override
  String get usersAccountDeactivated => 'Account deactivated';

  @override
  String get usersDeleteTitle => 'Delete user';

  @override
  String usersDeleteConfirm(String name) {
    return 'Delete the account of \"$name\"? This action cannot be undone.';
  }

  @override
  String get usersDeleted => 'User deleted';

  @override
  String get usersActive => 'Active';

  @override
  String get usersInactive => 'Inactive';

  @override
  String get usersDisable => 'Disable';

  @override
  String get usersEnable => 'Enable';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'Manage departments and equipment categories';

  @override
  String settingsDepartmentsTab(int count) {
    return 'Departments ($count)';
  }

  @override
  String settingsCategoriesTab(int count) {
    return 'Categories ($count)';
  }

  @override
  String get settingsNewDepartment => 'New department';

  @override
  String get settingsEditDepartment => 'Edit department';

  @override
  String get settingsDepartmentName => 'Department name';

  @override
  String get settingsDepartmentNameHint => 'E.g.: Cardiology';

  @override
  String get settingsShortName => 'Short name';

  @override
  String get settingsShortNameHint => 'E.g.: Cardio';

  @override
  String get settingsDepartmentModified => 'Department modified';

  @override
  String get settingsDepartmentAdded => 'Department added';

  @override
  String get settingsNewCategory => 'New category';

  @override
  String get settingsEditCategory => 'Edit category';

  @override
  String get settingsCategoryName => 'Category name';

  @override
  String get settingsCategoryNameHint => 'E.g.: Radiological equipment';

  @override
  String get settingsCategoryShortHint => 'E.g.: Radio';

  @override
  String get settingsCategoryModified => 'Category modified';

  @override
  String get settingsCategoryAdded => 'Category added';

  @override
  String get settingsDeleteDepartment => 'Delete department';

  @override
  String get settingsDeleteCategory => 'Delete category';

  @override
  String settingsDeleteConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?\n\nThis action cannot be undone.';
  }

  @override
  String settingsDeleted(String type) {
    return '$type deleted';
  }

  @override
  String settingsDeletedFeminine(String type) {
    return '$type deleted';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Change the application language';

  @override
  String get settingsFrench => 'Francais';

  @override
  String get settingsEnglish => 'English';

  @override
  String get settingsAccountSection => 'Account settings';

  @override
  String get settingsAccountSubtitle =>
      'Manage your personal information and preferences';

  @override
  String get settingsPersonalInfo => 'Personal information';

  @override
  String get settingsPersonalInfoSubtitle =>
      'Edit your name, email and phone number';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String get settingsChangePasswordSubtitle => 'Update your login password';

  @override
  String get settingsNewPassword => 'New password';

  @override
  String get settingsConfirmPassword => 'Confirm new password';

  @override
  String get settingsPasswordMismatch => 'Passwords do not match';

  @override
  String get settingsPasswordMinLength => 'Minimum 6 characters required';

  @override
  String get settingsPasswordChanged => 'Password changed successfully';

  @override
  String get settingsProfileUpdated => 'Profile updated';

  @override
  String get settingsAdminSection => 'Administration';

  @override
  String get settingsAdminSubtitle =>
      'Manage departments and equipment categories';

  @override
  String get settingsFullName => 'Full name';

  @override
  String get settingsFullNameHint => 'E.g.: Dr. Martin';

  @override
  String get settingsPhoneLabel => 'Phone number';

  @override
  String get settingsPhoneHint => 'E.g.: +250 788 123 456';

  @override
  String get settingsDepartmentHint => 'E.g.: Cardiology';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifMarkAllRead => 'Mark all as read';

  @override
  String get notifEmpty => 'No notifications';

  @override
  String get notifNewIssue => 'New issue reported';

  @override
  String notifNewIssueBody(String equipment, String dept) {
    return 'Issue on $equipment ($dept)';
  }

  @override
  String get notifInProgress => 'Your issue is being handled';

  @override
  String notifInProgressBody(String equipment) {
    return 'The issue on $equipment is being processed';
  }

  @override
  String get notifResolved => 'Your issue has been resolved';

  @override
  String notifResolvedBody(String equipment) {
    return 'The issue on $equipment is marked as resolved';
  }

  @override
  String get notifTimeJustNow => 'Just now';

  @override
  String notifTimeMinutes(int n) {
    return '$n min ago';
  }

  @override
  String notifTimeHours(int n) {
    return '$n h ago';
  }

  @override
  String notifTimeDays(int n) {
    return '$n d ago';
  }

  @override
  String get hubSelectModule => 'Select a module';

  @override
  String get hubSelectModuleSubtitle => 'Choose the module you want to access';

  @override
  String hubOpenModule(String title) {
    return 'Open $title';
  }

  @override
  String get issueTrackingTab => 'Issue tracking';

  @override
  String get issueValidationTab => 'To validate';

  @override
  String get issueValidationTitle => 'Issues to validate';

  @override
  String get issueValidationSubtitleAll =>
      'All open issues awaiting validation';

  @override
  String issueValidationSubtitleDept(String dept) {
    return 'Open issues from department \"$dept\" awaiting validation';
  }

  @override
  String issueValidationOpenCount(int count) {
    return '$count open issue(s)';
  }

  @override
  String get issueValidationNone => 'No open issues to validate';

  @override
  String get issueValidationDetails => 'Details';

  @override
  String get issueValidationValidate => 'Validate';

  @override
  String get issueValidationConfirmTitle => 'Validate issue';

  @override
  String get issueValidationConfirmContent =>
      'Confirm validation of the issue on:';

  @override
  String get issueValidationUrgencyLabel => 'Urgency level:';

  @override
  String get issueValidationConfirmMessage =>
      'The issue will be moved to \"Approved\" status and assigned to the technical team.';

  @override
  String issueValidationSuccess(String equipment) {
    return 'Issue on \"$equipment\" successfully validated.';
  }

  @override
  String issueValidationError(String error) {
    return 'Validation error: $error';
  }

  @override
  String issueValidationSignaledBy(String reporter, String date) {
    return 'Reported by $reporter • $date';
  }

  @override
  String get issueUrgencyLabel => 'Urgency level';

  @override
  String get issueValidationGroupLabel => 'Assigned technical team:';

  @override
  String get issueValidationGroupBiomedical => 'Biomedical';

  @override
  String get issueValidationGroupIT => 'IT';

  @override
  String get issueValidationGroupInfrastructure => 'Infrastructure';

  @override
  String get issueValidationGroupNoChange => 'Keep current team';

  @override
  String get issueValidationRedirectLabel => 'Redirect to another team';

  @override
  String get settingsMenuOrder => 'Menu order';

  @override
  String get settingsMenuOrderRole => 'Configure for role:';

  @override
  String get settingsMenuOrderHint =>
      'Drag items to change their order in the navigation bar.';

  @override
  String get settingsMenuOrderReset => 'Reset';

  @override
  String get settingsMenuOrderResetDone =>
      'Default order restored (not yet saved)';

  @override
  String get settingsMenuOrderSave => 'Save';

  @override
  String get settingsMenuOrderSaved => 'Menu order saved';

  @override
  String get backToModules => '← Modules';

  @override
  String get backToModulesLabel => 'Back to modules';

  @override
  String get equipmentRevisionColumn => 'Revision';

  @override
  String get accountDepartmentChange => 'Change department';

  @override
  String get accountDepartmentChangeTitle => 'Change request';

  @override
  String get accountDepartmentChangeSubtitle =>
      'Your request will be submitted to an administrator for approval.';

  @override
  String get accountDepartmentCurrent => 'Current: ';

  @override
  String get accountDepartmentNew => 'New department';

  @override
  String get accountDepartmentRequestSent =>
      'Request sent - awaiting admin approval';

  @override
  String get accountDepartmentRequestSend => 'Send request';

  @override
  String get commonApiError => 'An error occurred. Please try again.';

  @override
  String get commonNetworkError =>
      'Unable to connect to the server. Check your connection.';

  @override
  String get commonDeleteError =>
      'Unable to delete this item. Please try again.';

  @override
  String get commonSaveError => 'Unable to save. Please try again.';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get hubEquipmentTitle => 'Equipment';

  @override
  String get hubEquipmentDesc =>
      'Manage medical equipment, track incidents and plan interventions.';

  @override
  String get hubSettingsTitle => 'Settings';

  @override
  String get hubSettingsDesc =>
      'Manage users, configure the system and view activity logs.';

  @override
  String get hubInventoryTitle => 'Inventory';

  @override
  String get hubInventoryDesc =>
      'View and manage medical supplies and consumables stock.';

  @override
  String get hubKpiTitle => 'Global Dashboard';

  @override
  String get hubKpiSubtitle => 'Real-time key indicators';

  @override
  String get hubKpiCriticalUrgentLabel => 'Critical / urgent incidents';

  @override
  String get hubKpiOpenIssues => 'open incidents';

  @override
  String get hubKpiStockAlertsLabel => 'Stock alerts';

  @override
  String get hubKpiStockAlertsSubtitle => 'out of stock or low levels';

  @override
  String get hubKpiOutOfServiceLabel => 'Out of service';

  @override
  String get hubKpiOutOfServiceSubtitle => 'equipment out of service';

  @override
  String get hubKpiNoAlert => 'No alerts';

  @override
  String get hubReportUrgentButton => 'Report an incident';

  @override
  String get hubReportUrgentTooltip => 'Report an incident immediately';

  @override
  String get hubQuickAccessTitle => 'Quick access to modules';

  @override
  String get equipStatusOperational => 'Operational';

  @override
  String get equipStatusInMaintenance => 'In Maintenance';

  @override
  String get equipStatusOutOfService => 'Out of Service';

  @override
  String get equipStatusToBeDisposal => 'To be disposal';

  @override
  String get equipStatusDisposed => 'Disposed';

  @override
  String get equipmentManufacturer => 'Manufacturer';

  @override
  String get equipmentManufacturerHint => 'Ex: Philips Healthcare';

  @override
  String get equipmentModel => 'Model';

  @override
  String get equipmentModelHint => 'Ex: IntelliVue MX450';

  @override
  String get equipmentManufYear => 'Manufacturing year';

  @override
  String get equipmentManufYearHint => 'Ex: 2023';

  @override
  String get equipmentInstallDate => 'Install date';

  @override
  String get equipmentInstallDateHint => 'Select a date (optional)';

  @override
  String get equipmentTags => 'Tags';

  @override
  String get equipmentNoTags => 'No tags';

  @override
  String get equipmentInternalId => 'Internal ID';

  @override
  String get equipmentCreatedAt => 'Created at';

  @override
  String get equipmentUpdatedAt => 'Updated at';

  @override
  String get equipmentNextRevision => 'Next revision';

  @override
  String get equipmentFutureMaintenance => 'Scheduled maintenance';

  @override
  String get lastPreventiveDate => 'Last preventive maintenance';

  @override
  String get nextPreventiveDate => 'Next preventive maintenance';

  @override
  String get preventiveAlert => 'Preventive maintenance due';

  @override
  String get preventiveAlertOverdue => 'Preventive maintenance overdue';

  @override
  String get preventiveAlertSoon => 'Preventive maintenance within 7 days';

  @override
  String get preventiveSection => 'Preventive maintenance';

  @override
  String get equipmentSystemInfoSection => 'System info';

  @override
  String get equipmentInventorySection => 'Inventory';

  @override
  String get equipmentGeneralSection => 'General info';

  @override
  String get issueStatusReported => 'Reported';

  @override
  String get issueStatusAcknowledged => 'Acknowledged';

  @override
  String get issueStatusAssigned => 'Assigned';

  @override
  String get issueStatusInProgress => 'In Progress';

  @override
  String get issueStatusWaitingMaterials => 'Waiting Materials';

  @override
  String get issueStatusCompleted => 'Completed';

  @override
  String get issueStatusVerified => 'Verified';

  @override
  String get issueStatusClosed => 'Closed';

  @override
  String get issueStatusRedirected => 'Redirected';

  @override
  String get urgencyLow => 'Low';

  @override
  String get urgencyMedium => 'Medium';

  @override
  String get urgencyHigh => 'High';

  @override
  String get urgencyCritical => 'Critical';

  @override
  String get deptAdministration => 'Administration';

  @override
  String get deptOpd => 'OPD (Outpatient)';

  @override
  String get deptInternalMedicine => 'Internal Medicine';

  @override
  String get deptPediatrics => 'Pediatrics';

  @override
  String get deptEmergency => 'Emergency';

  @override
  String get deptLaboratory => 'Laboratory';

  @override
  String get deptStomatology => 'Stomatology';

  @override
  String get deptPhysiotherapy => 'Physiotherapy';

  @override
  String get deptNeonatology => 'Neonatology';

  @override
  String get deptMaternity => 'Maternity';

  @override
  String get deptSurgery => 'Surgery';

  @override
  String get deptOperatingTheater => 'Operating Theater';

  @override
  String get deptOphthalmology => 'Ophthalmology';

  @override
  String get deptTbMr => 'TB-MR (Tuberculosis)';

  @override
  String get deptGbv => 'GBV (Gender-Based Violence)';

  @override
  String get deptMentalHealth => 'Mental Health';

  @override
  String get deptArv => 'ARV (HIV/AIDS Treatment)';

  @override
  String get deptPharmacy => 'Pharmacy';

  @override
  String get catIct => 'ICT Equipment';

  @override
  String get catHygiene => 'Hygiene Supplies';

  @override
  String get catBiomedical => 'Biomedical Equipment';

  @override
  String get catElectrical => 'Electrical Equipment';

  @override
  String get catSterilization => 'Sterilization & Laundry';

  @override
  String get catPharmacy => 'Pharmacy';

  @override
  String get techAvailableTab => 'Available incidents';

  @override
  String get techMyInterventionsTab => 'My interventions';

  @override
  String get techScheduleTab => 'Schedule';

  @override
  String get techAvailableTitle => 'Available incidents';

  @override
  String get techScheduleTitle => 'Schedule';

  @override
  String get techAvailableSubtitle =>
      'Approved incidents awaiting a technician — take charge of those you wish to handle.';

  @override
  String get techNoAvailableIncidents => 'No approved incidents available.';

  @override
  String get techTakeCharge => 'Take charge';

  @override
  String get techSheet => 'Sheet';

  @override
  String get techTakeChargeTitle => 'Take charge of the incident';

  @override
  String get techTakeChargeContent =>
      'You are about to take charge of the incident on:';

  @override
  String get techTakeChargeMessage =>
      'The incident will change to \"In Progress\" status and be assigned to you.';

  @override
  String techTakeChargeSuccess(String equipment) {
    return 'You have taken charge of the incident on \"$equipment\".';
  }

  @override
  String get techNoInterventions => 'No interventions recorded';

  @override
  String get techNoInterventionsHint =>
      'Incidents you take charge of will appear here.';

  @override
  String get techNoCurrentInterventions => 'No current interventions';

  @override
  String get techFindIncidentsHint =>
      'To find incidents to process, check the \"Available incidents\" tab.';

  @override
  String get techSearchHint => 'Search for an intervention…';

  @override
  String get techNoResults => 'No results';

  @override
  String get techScheduleSubtitle =>
      'Your schedule of interventions and planned maintenances.';

  @override
  String get techLegendInProgress => 'In progress';

  @override
  String get techLegendResolved => 'Completed';

  @override
  String get techLegendPastMaintenance => 'Past maintenance';

  @override
  String get techLegendPlanned => 'Planned';

  @override
  String get techFullHistory => 'Complete history';

  @override
  String get techNoEventsToday => 'No events this day.';

  @override
  String techEventsOn(String date) {
    return 'Events on $date';
  }

  @override
  String techEventCount(int count) {
    return '$count event(s)';
  }

  @override
  String get techEventStatusCompleted => 'Completed';

  @override
  String get monthJanuary => 'January';

  @override
  String get monthFebruary => 'February';

  @override
  String get monthMarch => 'March';

  @override
  String get monthApril => 'April';

  @override
  String get monthMay => 'May';

  @override
  String get monthJune => 'June';

  @override
  String get monthJuly => 'July';

  @override
  String get monthAugust => 'August';

  @override
  String get monthSeptember => 'September';

  @override
  String get monthOctober => 'October';

  @override
  String get monthNovember => 'November';

  @override
  String get monthDecember => 'December';

  @override
  String get logsTitle => 'Activity Logs';

  @override
  String get logsRefresh => 'Refresh';

  @override
  String get logsColAction => 'Action';

  @override
  String get logsColUser => 'User';

  @override
  String get logsColResource => 'Resource';

  @override
  String get logsColIpDevice => 'IP / Device';

  @override
  String get logsColTimestamp => 'Timestamp';

  @override
  String get logsSearchHint => 'Search (user, resource…)';

  @override
  String get logsFilterAll => 'All';

  @override
  String get logsFilterAuth => 'Auth';

  @override
  String get logsFilterEquipment => 'Equipment';

  @override
  String get logsFilterIncidents => 'Incidents';

  @override
  String get logsFilterInventory => 'Inventory';

  @override
  String get logsFilterUsers => 'Users';

  @override
  String get logsNewIp => 'New IP';

  @override
  String get logsNewIpTooltip => 'First login from this IP address';

  @override
  String get logsNoLogs => 'No logs found';

  @override
  String get logsNoLogsSubtitle => 'User actions will appear here.';

  @override
  String get logsLoadError => 'Loading error';

  @override
  String get logsRetry => 'Retry';

  @override
  String get logsMetadata => 'Metadata';

  @override
  String get logsViewProfile => 'View profile';

  @override
  String get logsViewDetails => 'View details';

  @override
  String get logsRestoring => 'Restoring…';

  @override
  String get logsAlreadyRestored => 'This action has already been restored.';

  @override
  String get logsUserProfileTitle => 'User profile';

  @override
  String get logsEquipmentTitle => 'Equipment';

  @override
  String get logsEquipmentNotFound => 'Equipment deleted or not found.';

  @override
  String get logsDeviceMobile => 'Mobile';

  @override
  String get logsDevicePc => 'PC / Browser';

  @override
  String get logsDeviceUnknown => 'Unknown';

  @override
  String get logsTargetEquipment => 'Equipment';

  @override
  String get logsTargetUser => 'Affected user';

  @override
  String get logsTargetIncident => 'Incident';

  @override
  String get logsTargetInventory => 'Inventory item';

  @override
  String get logsTargetAuth => 'Authentication';

  @override
  String get logsTargetResource => 'Resource';

  @override
  String get logsUserLabel => 'User';

  @override
  String get logsActionLogin => 'Sign-in';

  @override
  String get logsActionLoginFailed => 'Failed sign-in';

  @override
  String get logsActionLogout => 'Sign-out';

  @override
  String get logsActionCreateEquipment => 'Create equipment';

  @override
  String get logsActionUpdateEquipment => 'Update equipment';

  @override
  String get logsActionDeleteEquipment => 'Delete equipment';

  @override
  String get logsActionRestoreEquipment => 'Restore equipment';

  @override
  String get logsActionAddMaintenance => 'Maintenance';

  @override
  String get logsActionScheduleMaintenance => 'Schedule maint.';

  @override
  String get logsActionCreateIssue => 'Report issue';

  @override
  String get logsActionUpdateIssue => 'Update issue';

  @override
  String get logsActionDeleteIssue => 'Delete issue';

  @override
  String get logsActionCreateInventory => 'Create item';

  @override
  String get logsActionUpdateInventory => 'Update stock';

  @override
  String get logsActionRestockInventory => 'Restock';

  @override
  String get logsActionDeleteInventory => 'Delete item';

  @override
  String get logsActionCreateUser => 'Create account';

  @override
  String get logsActionUpdateUser => 'Update account';

  @override
  String get logsActionDeleteUser => 'Delete account';

  @override
  String get logsActionRestoreUser => 'Restore account';

  @override
  String get logsActionChangePassword => 'Change password';

  @override
  String get logsActionChangeName => 'Change name';

  @override
  String get logsActionChangeEmail => 'Change email';

  @override
  String get logsActionChangePhone => 'Change phone';

  @override
  String get logsActionActivateUser => 'Account activated';

  @override
  String get logsActionSuspendUser => 'Account suspended';

  @override
  String get logsRestoreGeneric => 'Restore';

  @override
  String get logsRestoreEquipmentLabel => 'Restore equipment';

  @override
  String get logsRestorePreviousState => 'Restore previous state';

  @override
  String get logsRestoreUserAccount => 'Restore account';

  @override
  String get logsReactivateUserAccount => 'Reactivate account';

  @override
  String get logsRestoreOldName => 'Restore previous name';

  @override
  String get logsRestoreOldEmail => 'Restore previous email';

  @override
  String get logsRestoreOldPhone => 'Restore previous phone';

  @override
  String get logsRestorePreviousValues => 'Restore previous values';

  @override
  String get logsConfirmRestoreTitle => 'Confirm restoration';

  @override
  String logsConfirmRestoreShort(String label) {
    return '$label?';
  }

  @override
  String logsConfirmRestoreLong(String label) {
    return 'Do you really want to $label?';
  }

  @override
  String get logsRestoreButton => 'Restore';

  @override
  String get logsEquipmentRestored => 'Equipment restored successfully.';

  @override
  String get logsEquipmentRestoredState =>
      'Equipment restored to previous state.';

  @override
  String logsUserAccountRestored(String pwd) {
    return 'Account restored.\nTemporary password: $pwd';
  }

  @override
  String get logsUserAccountReactivated => 'Account reactivated.';

  @override
  String logsNameRestored(String old) {
    return 'Name restored: $old';
  }

  @override
  String logsEmailRestored(String old) {
    return 'Email restored: $old';
  }

  @override
  String logsPhoneRestored(String old) {
    return 'Phone restored: $old';
  }

  @override
  String get logsPreviousValuesRestored => 'Previous values restored.';

  @override
  String logsRestoreErrorPrefix(String message) {
    return 'Error: $message';
  }

  @override
  String get logsErrSnapshotMissing => 'Snapshot data is missing';

  @override
  String get logsErrInsufficientData => 'Insufficient data';

  @override
  String get logsErrUserIdMissing => 'Missing user ID';

  @override
  String get logsErrOldValueMissing => 'Previous value not found';

  @override
  String get logsErrNothingToRestore => 'Nothing to restore';

  @override
  String get logsErrNotRestorable => 'Action cannot be restored';

  @override
  String get logsDetailsBefore => 'Before';

  @override
  String get logsDetailsAfter => 'After';

  @override
  String get logsDetailsSnapshotAvailable => 'Snapshot available';

  @override
  String get logsDetailsPreviousAvailable => 'Previous state available';

  @override
  String get logsSectionDetails => 'Details';

  @override
  String get logsSectionDeleteSnapshot => 'Data at time of deletion';

  @override
  String get logsSectionStateBeforeChange => 'State before change';

  @override
  String get logsSectionUserStatus => 'Status';

  @override
  String get logsFieldId => 'ID';

  @override
  String get logsFieldRole => 'Role';

  @override
  String get logsFieldPhone => 'Phone';

  @override
  String get logsFieldStatus => 'Status';

  @override
  String get logsFieldSerial => 'Serial No.';

  @override
  String get logsFieldSupplier => 'Supplier';

  @override
  String get logsFieldLocation => 'Location';

  @override
  String get logsFieldActive => 'Active';

  @override
  String get logsFieldNewStatus => 'New status';

  @override
  String get logsFieldReason => 'Reason';

  @override
  String get logsFieldDeviceLabel => 'Device';

  @override
  String get logsFieldIp => 'IP';

  @override
  String get logsFieldIpUnknown => 'Unknown';

  @override
  String get logsFieldUserAgent => 'User-Agent';

  @override
  String get logsFieldTimestamp => 'Timestamp';

  @override
  String get logsFieldType => 'Type';

  @override
  String get logsAlertNewIpFull =>
      'First sign-in from this IP for this account.';

  @override
  String get logsUserStatusActive => 'Active';

  @override
  String get logsUserStatusSuspended => 'Suspended';

  @override
  String logsErrorLoading(String error) {
    return 'Error: $error';
  }

  @override
  String get logsTimeJustNow => 'Just now';

  @override
  String logsTimeWithMinutes(String time, int n) {
    return '$time ($n min ago)';
  }

  @override
  String logsTimeWithHours(String time, int n) {
    return '$time ($n h ago)';
  }

  @override
  String logsEntriesCount(int count) {
    return '$count entry(ies)';
  }

  @override
  String get settingsRolesTab => 'Roles & permissions';

  @override
  String get settingsRolesTitle => 'Roles and permissions';

  @override
  String get settingsRolesSubtitle =>
      'Edit permissions or create a custom role';

  @override
  String get settingsNewRole => 'New role';

  @override
  String get settingsAdminLockedInfo =>
      'Administrator permissions are locked — admin always has full access. Custom roles can be deleted.';

  @override
  String get settingsNoRoles => 'No roles loaded.';

  @override
  String get settingsCustomBadge => 'Custom';

  @override
  String get settingsAdminAlwaysAll =>
      'Administrator always has all permissions';

  @override
  String get settingsLocked => 'Locked';

  @override
  String get settingsRoleActive => 'Active permissions:';

  @override
  String get settingsNoPermissions => 'No permissions';

  @override
  String get settingsNewRoleTitle => 'New custom role';

  @override
  String get settingsRoleIdLabel => 'Identifier (e.g.: nurse)';

  @override
  String get settingsRoleIdHint => 'Letters, digits, underscores';

  @override
  String get settingsRoleDisplayLabel => 'Display name (e.g.: Nurse)';

  @override
  String get settingsRoleDescLabel => 'Description (optional)';

  @override
  String get settingsPermissionsLabel => 'Permissions';

  @override
  String get settingsSelectAll => 'Select all';

  @override
  String get settingsDeselectAll => 'Deselect all';

  @override
  String get settingsCreateRole => 'Create';

  @override
  String settingsEditPermissionsTitle(String role) {
    return 'Permissions — $role';
  }

  @override
  String get settingsBuiltinRole => 'Built-in role';

  @override
  String get settingsAccessByRole => 'Page access by role';

  @override
  String get settingsAccessDesc =>
      'Check the pages and functions accessible for the selected role.';

  @override
  String get settingsRoleLabel => 'Role';

  @override
  String get settingsAdminAllAccess =>
      'Administrator has access to all pages and functions without restriction.';

  @override
  String get settingsNoSpecificFunction => 'No specific function';

  @override
  String get settingsResetToDefault => 'Reset to defaults';

  @override
  String get settingsReset => 'Reset';

  @override
  String get settingsDeleteRole => 'Delete role';

  @override
  String get settingsRoleCreated => 'Role created';

  @override
  String get settingsRoleCreateError => 'Error while creating';

  @override
  String get settingsRoleSaveError => 'Error while saving';

  @override
  String get settingsRoleDeleteError => 'Error while deleting';

  @override
  String settingsRoleDeletedToast(String role) {
    return 'Role \"$role\" deleted';
  }

  @override
  String settingsRoleDeleteConfirm(String role) {
    return 'Delete \"$role\"? This action cannot be undone.';
  }

  @override
  String settingsRolePermissionsUpdated(String role) {
    return 'Permissions for $role updated';
  }

  @override
  String get settingsRoleConfigSaved => 'Configuration saved';

  @override
  String get settingsRoleConfigSaveError => 'Error while saving';

  @override
  String get settingsResetDone => 'Reset to defaults';

  @override
  String get roleHospitalStaff => 'Hospital staff';

  @override
  String get roleSupervisor => 'Supervisor';

  @override
  String get roleTechnician => 'Technician';

  @override
  String get roleTechnicianBiomedical => 'Biomedical technician';

  @override
  String get roleTechnicianIt => 'IT technician';

  @override
  String get roleTechnicianInfra => 'Infrastructure technician';

  @override
  String get roleAdmin => 'ICT Administrator';

  @override
  String get permViewEquipment => 'View equipment';

  @override
  String get permReportIssue => 'Report an issue';

  @override
  String get permTrackIssues => 'Track requests';

  @override
  String get permApproveRequests => 'Approve requests';

  @override
  String get permAssignTasks => 'Assign tasks';

  @override
  String get permUpdateRepairs => 'Update repairs';

  @override
  String get permRegisterParts => 'Register parts';

  @override
  String get permManageEquipment => 'Manage equipment';

  @override
  String get permManageUsers => 'Manage users';

  @override
  String get permManageDepartments => 'Manage departments';

  @override
  String get permManageCategories => 'Manage categories';

  @override
  String get permGenerateReports => 'Generate reports';

  @override
  String get permViewInventory => 'View inventory';

  @override
  String get permChangeDepartment => 'Change own department directly';

  @override
  String get permManageFeatures => 'Manage feature flags';

  @override
  String get accountFirstName => 'First name';

  @override
  String get accountLastName => 'Last name';

  @override
  String get accountDirectChange => 'Direct';

  @override
  String get accountDirectChangeSubtitle =>
      'Your department will be changed immediately.';

  @override
  String get accountConfirm => 'Confirm';

  @override
  String get accountCancelLabel => 'Cancel';

  @override
  String get equipmentSelectDate => 'Select a date (optional)';

  @override
  String get equipmentRemoveDate => 'Remove date';

  @override
  String get equipmentDeleteReason => 'Deletion reason (optional)';

  @override
  String get equipmentDeleteReasonHint => 'E.g.: Out of service, replaced…';

  @override
  String widgetHistoryTitle(String name) {
    return 'History — $name';
  }

  @override
  String widgetMaintenanceEvent(String intervention) {
    return 'Maintenance — $intervention';
  }

  @override
  String widgetPlannedMaintenance(String intervention) {
    return 'Planned maintenance — $intervention';
  }

  @override
  String get widgetNoHistory => 'No history for this equipment.';

  @override
  String widgetSerialNumber(String serial) {
    return 'No. $serial';
  }

  @override
  String widgetEventCount(int count) {
    return '$count event(s)';
  }

  @override
  String get usersDeptRequests => 'Department change requests';

  @override
  String get usersNoPendingRequests => 'No pending requests.';

  @override
  String get usersApproveTooltip => 'Approve';

  @override
  String get usersRejectTooltip => 'Reject';

  @override
  String get usersApproveTitle => 'Approve request';

  @override
  String get usersRejectTitle => 'Reject request';

  @override
  String get usersFirstName => 'First name';

  @override
  String get usersLastName => 'Last name';

  @override
  String get usersDeleteReason => 'Deletion reason (optional)';

  @override
  String get usersDeleteReasonHint => 'E.g.: Left the facility, duplicate…';

  @override
  String get usersRolesInfo => 'To modify permissions, go to the Roles tab.';

  @override
  String get issueFormSourceLabel => 'Report type';

  @override
  String get issueFormSourceEquipment => 'Medical equipment';

  @override
  String get issueFormSourceLocation => 'Infrastructure / Location';

  @override
  String get issueFormSelectLocation => 'Select a location';

  @override
  String get issueFormLocationRequired => 'Please select a location';

  @override
  String get techReassignButton => 'Transfer to another group';

  @override
  String get techReassignTitle => 'Transfer issue';

  @override
  String get techReassignSubtitle =>
      'Choose the group that should handle this issue.';

  @override
  String get techReassignGroupHint => 'Select a group';

  @override
  String get techReassignGroupRequired => 'Group is required';

  @override
  String get techReassignReasonLabel => 'Transfer reason';

  @override
  String get techReassignReasonHint =>
      'Explain why you are transferring this issue…';

  @override
  String get techReassignReasonMinLength =>
      'Reason must be at least 10 characters';

  @override
  String techReassignSuccess(String group) {
    return 'Issue transferred to group $group';
  }

  @override
  String get equipDetailCurrentIssues => 'Current Issues';

  @override
  String get equipDetailPastIssues => 'Issue History';

  @override
  String get equipDetailNoCurrentIssues =>
      'No current issues for this equipment';

  @override
  String get equipDetailNoPastIssues => 'No resolved issues for this equipment';

  @override
  String get equipDetailIssuesSection => 'Issues';

  @override
  String get equipDetailLoadingError => 'Error loading equipment details';

  @override
  String get issueCategorySelectorTitle =>
      'What type of problem are you experiencing?';

  @override
  String get issueCategoryBiomedical => 'Biomedical Equipment';

  @override
  String get issueCategoryBiomedicalDesc =>
      'Scanner, MRI, ultrasound, analyzers, monitors, infusion pumps, ventilators…';

  @override
  String get issueCategoryInfrastructure => 'Infrastructure & Electrical';

  @override
  String get issueCategoryInfrastructureDesc =>
      'Beds, examination tables, wheelchairs, lighting, electrical outlets, plumbing…';

  @override
  String get issueCategoryIT => 'IT (Information Technology)';

  @override
  String get issueCategoryITDesc =>
      'Computers, printers, network, servers, software, information systems…';

  @override
  String get issueCategoryOther => 'Other / I don\'t know';

  @override
  String get issueCategoryOtherDesc =>
      'Unclassified issue or unknown category — all equipment remains available.';

  @override
  String get issueFormNoEquipmentInCategory =>
      'No equipment of this type found in your department.';

  @override
  String get issueFormTagNumber => 'IT Tag Number';

  @override
  String get issueFormTagNumberHint => 'E.g.: TG-0042';

  @override
  String get issueFormTagSearching => 'Searching...';

  @override
  String get issueFormTagNotFound => 'No equipment found for this tag';

  @override
  String get issueFormTagFound => 'Equipment found';

  @override
  String get issueFormBuilding => 'Building';

  @override
  String get issueFormSelectBuilding => 'Select a building';

  @override
  String get issueFormSelectDepartment => 'Select a department';

  @override
  String get issueFormProblemCategory => 'Problem category *';

  @override
  String get issueFormSelectProblemCategory => 'Select a category';

  @override
  String get issueFormProblemSubcategory => 'Subcategory *';

  @override
  String get issueFormSelectProblemSubcategory => 'Select a subcategory';

  @override
  String get issueFormAutoFilled => 'Auto-filled from equipment';

  @override
  String get issueFormSearchEquipmentByTag => 'Search by tag number';

  @override
  String get issueFormEquipmentRequired => 'Please select an equipment';

  @override
  String get issueFormDepartmentRequired => 'Please select a department';

  @override
  String get issueFormBuildingHint => 'E.g.: Block A, Main Building...';

  @override
  String get issueFormLocationHint => 'E.g.: Room 12, North Corridor...';

  @override
  String get issueFormInfraTagNumber => 'Tag number (optional)';

  @override
  String get issueFormInfraTagHint => 'E.g.: TG-0042';

  @override
  String get issueFormBuildingRequired => 'Please select a building';

  @override
  String get issueFormLocationRequired2 => 'Please select a location';

  @override
  String get issueFormCategoryRequired => 'Please select a category';

  @override
  String get issueFormSubcategoryRequired => 'Please select a subcategory';

  @override
  String get issueFormTagRequired =>
      'Please enter a tag number and search for the equipment';

  @override
  String get issueFormQuickSearch => 'Quick Search';

  @override
  String get issueFormQuickSearchHint => 'Type a keyword to find an issue...';

  @override
  String get issueFormSpecificIssue => 'Specific Issue *';

  @override
  String get issueFormSelectSpecificIssue => 'Select the specific issue';

  @override
  String get issueFormIssueRequired => 'Please select the specific issue';

  @override
  String get registerTitle => 'Sign Up';

  @override
  String get registerFirstName => 'First Name';

  @override
  String get registerLastName => 'Last Name';

  @override
  String get registerDepartment => 'Department';

  @override
  String get registerPhone => 'Phone (optional)';

  @override
  String get registerPasswordConfirm => 'Confirm Password';

  @override
  String get registerPasswordMinLength => 'Minimum 8 characters';

  @override
  String get registerPasswordMismatch => 'Passwords do not match';

  @override
  String get registerSubmit => 'Create Account';

  @override
  String get registerSuccess =>
      'Account created! Check your email to activate it. Once logged in, you can request an additional role from your profile.';

  @override
  String get registerHaveAccount => 'Already have an account? Sign In';

  @override
  String get registerNoAccount => 'No account yet? Sign Up';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotPasswordSubmit => 'Send Reset Link';

  @override
  String get forgotPasswordSuccess =>
      'If this email exists, you will receive a reset link. Check your spam folder too.';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get loginEmailNotVerified =>
      'Your account is not yet activated. Check your email or contact your administrator.';

  @override
  String get roleRequestTitle => 'Request Additional Role';

  @override
  String get roleRequestLabel => 'Requested Role';

  @override
  String get roleRequestSubmit => 'Submit Request';

  @override
  String get roleRequestSuccess => 'Request sent, pending admin approval';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get navAnalyticsShort => 'Stats';

  @override
  String get healthAuth => 'Auth';

  @override
  String get healthDb => 'DB';

  @override
  String get healthIam => 'IAM';

  @override
  String get healthMail => 'Mail';

  @override
  String get analyticsTitle => 'Analytics';

  @override
  String get analyticsPeriod => 'Period:';

  @override
  String get analyticsToday => 'Today';

  @override
  String get analyticsWeek => '7 days';

  @override
  String get analyticsMonth => '30 days';

  @override
  String get analyticsLogins => 'Logins';

  @override
  String get analyticsFailedLogins => 'Failed logins';

  @override
  String get analyticsActiveUsers => 'Active users';

  @override
  String get analyticsIssuesCreated => 'Issues created';

  @override
  String get analyticsIssuesResolved => 'Issues resolved';

  @override
  String get analyticsEquipmentTotal => 'Equipment';

  @override
  String get analyticsEquipmentByStatus => 'Equipment status';

  @override
  String get analyticsTopActions => 'Activity by action';

  @override
  String get analyticsNoData => 'No data for this period.';

  @override
  String get accountAlertEmailNotVerifiedTitle => 'Email not verified';

  @override
  String get accountAlertEmailNotVerifiedSubtitle =>
      'Check your inbox and click the confirmation link sent at registration.';

  @override
  String get accountAlertPhoneMissingTitle => 'Phone number missing';

  @override
  String get accountAlertPhoneMissingSubtitle =>
      'Add your phone number in your personal info to be reachable in case of an incident.';

  @override
  String appVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get navFeatureManagement => 'Feature Flags';

  @override
  String get navFeatureManagementShort => 'Flags';

  @override
  String get featureMgmtTitle => 'Feature Flags Management';

  @override
  String get featureMgmtSubtitle =>
      'Enable or disable application modules globally or per role';

  @override
  String get featureMgmtGlobalStatusLabel => 'Globally active';

  @override
  String get featureMgmtRoleOverridesBtn => 'Role overrides';

  @override
  String get featureMgmtSaveSuccess => 'Feature updated successfully';

  @override
  String featureMgmtSaveError(String error) {
    return 'Error while updating: $error';
  }

  @override
  String get featureMgmtNoFeatures => 'No features available';

  @override
  String featureMgmtRoleDialogTitle(String name) {
    return 'Role overrides — $name';
  }

  @override
  String get featureMgmtRoleDialogHint =>
      'Without override, the feature follows its global status.';

  @override
  String get featureMgmtRoleNoOverride => 'No override (global status)';

  @override
  String get featureMgmtRoleForceActive => 'Force active';

  @override
  String get featureMgmtRoleForceInactive => 'Force inactive';

  @override
  String get featureMgmtLoading => 'Loading features...';

  @override
  String get featureMgmtGlobalActive => 'Enabled globally';

  @override
  String get featureMgmtGlobalInactive => 'Disabled globally';

  @override
  String get navBackupManagement => 'Backups';

  @override
  String get navBackupManagementShort => 'Backup';

  @override
  String get permManageBackups => 'Manage backups';

  @override
  String get backupTitle => 'Backup Management';

  @override
  String get backupSubtitle => 'Back up, schedule, and download hospital data';

  @override
  String get backupLoading => 'Loading...';

  @override
  String get backupLoadError => 'Error loading backup data';

  @override
  String get backupRetry => 'Retry';

  @override
  String get backupLastStatus => 'Last Backup Status';

  @override
  String get backupNoLastBackup => 'No backup performed yet';

  @override
  String get backupDate => 'Date';

  @override
  String get backupSize => 'Size';

  @override
  String get backupStatusLabel => 'Status';

  @override
  String get backupStatusSuccess => 'Success';

  @override
  String get backupStatusError => 'Failed';

  @override
  String get backupTypeManual => 'Manual';

  @override
  String get backupTypeAutomated => 'Automated';

  @override
  String get backupTrigger => 'Run Immediate Backup';

  @override
  String get backupTriggering => 'Backup in progress...';

  @override
  String get backupTriggerSuccess => 'Backup completed successfully';

  @override
  String backupTriggerError(String error) {
    return 'Backup error: $error';
  }

  @override
  String get backupAutomationSection => 'Automation';

  @override
  String get backupEnableAuto => 'Enable automatic backup';

  @override
  String get backupScheduleLabel => 'Frequency';

  @override
  String get backupScheduleDaily => 'Every day at midnight';

  @override
  String get backupScheduleWeekly => 'Every week (Sunday at midnight)';

  @override
  String get backupSettingsSaved => 'Backup settings saved';

  @override
  String backupSettingsSaveError(String error) {
    return 'Error saving settings: $error';
  }

  @override
  String get backupAlertTitle => 'Critical Reminder';

  @override
  String get backupAlertMessage =>
      'For security reasons (fire, major hardware failure), please regularly download a backup and store it on a physical medium outside the hospital server.';

  @override
  String get backupHistorySection => 'Backup History';

  @override
  String get backupNoHistory => 'No backups recorded';

  @override
  String get backupDownload => 'Download';

  @override
  String get backupDownloadSuccess => 'Download started';

  @override
  String backupDownloadError(String error) {
    return 'Download error: $error';
  }

  @override
  String get backupColDate => 'Date';

  @override
  String get backupColType => 'Type';

  @override
  String get backupColSize => 'Size';

  @override
  String get backupColStatus => 'Status';

  @override
  String get backupColAction => 'Action';

  @override
  String get backupAccessDeniedTitle => 'Access Denied — System Area';

  @override
  String get backupAccessDeniedMessage =>
      'This area is reserved for ICT system administrators.';

  @override
  String get backupAccessDeniedSub =>
      'Contact IT support if you believe this is an error.';

  @override
  String get backupAutoDisableWarning =>
      'Warning: The hospital database is no longer protected by automatic backups. Please re-enable this option as soon as possible.';

  @override
  String get backupRestoreButton => 'Restore';

  @override
  String get backupRestoreDialogTitle => 'Confirm database restoration';

  @override
  String backupRestoreDialogWarning(String date) {
    return 'This operation will overwrite all current production data and replace it with the backup from $date. This action is irreversible.';
  }

  @override
  String get backupRestoreTypeInstruction =>
      'To confirm, type RESTORE in the field below:';

  @override
  String get backupRestoreConfirmWord => 'RESTORE';

  @override
  String get backupRestoreConfirmButton => 'Confirm restoration';

  @override
  String get backupRestoreSuccess => 'Restoration completed successfully';

  @override
  String backupRestoreError(String error) {
    return 'Restoration error: $error';
  }

  @override
  String get backupRestoring => 'Restoration in progress...';

  @override
  String get issueDetailTitle => 'Issue Detail';

  @override
  String get issueDetailSectionContext => 'Context';

  @override
  String get issueDetailSectionFailure => 'Failure';

  @override
  String get issueDetailSectionIntervention => 'Intervention Follow-up';

  @override
  String get issueDetailSectionResources => 'Resources';

  @override
  String get issueDetailSectionHistory => 'History';

  @override
  String get issueDetailEquipmentLink => 'View equipment';

  @override
  String get issueDetailRootCause => 'Root cause (diagnosis)';

  @override
  String get issueDetailCorrectiveActions => 'Corrective actions';

  @override
  String get issueDetailPartsUsed => 'Parts replaced';

  @override
  String get issueDetailMaintenanceHistory => 'Recent maintenance';

  @override
  String get issueDetailNoHistory => 'No events recorded';

  @override
  String get issueDetailLoading => 'Loading details...';

  @override
  String get issueDetailCategory => 'Issue category';

  @override
  String get issueDetailGroup => 'Technical group';

  @override
  String get issueDetailLocation => 'Location';

  @override
  String get issueDetailUpdatedAt => 'Last updated';

  @override
  String get issueDetailUpdateButton => 'Update issue';

  @override
  String get issueDetailTypeLabel => 'Failure type';

  @override
  String get issueDetailReporter => 'Reported by';

  @override
  String get issueDetailReportDate => 'Report date';

  @override
  String get issueDetailAssignedTech => 'Assigned technician';

  @override
  String get issueDetailNoIntervention => 'No intervention recorded';

  @override
  String get issueDetailNoMaintenance => 'No maintenance recorded';

  @override
  String get issueDetailTimelineCreated => 'Issue reported';

  @override
  String get issueDetailLoadError => 'Unable to load issue details.';

  @override
  String get macroCategoryLabel => 'Macro-category';

  @override
  String get macroCategoryBiomedical => 'Biomedical';

  @override
  String get macroCategoryInfrastructure => 'Infrastructure';

  @override
  String get macroCategoryIT => 'IT (Information Technology)';

  @override
  String get subcategoryLabel => 'Sub-category';

  @override
  String get subcategorySelectHint => 'Select a sub-category';

  @override
  String get criticalityLabel => 'Criticality (ABC Matrix)';

  @override
  String get criticalityA => 'A — Critical';

  @override
  String get criticalityB => 'B — Important';

  @override
  String get criticalityC => 'C — Standard';

  @override
  String get criticalityTooltipA =>
      'Failure = immediate stop of care. Top priority.';

  @override
  String get criticalityTooltipB =>
      'Significant impact but workaround possible.';

  @override
  String get criticalityTooltipC => 'Low impact on continuity of care.';

  @override
  String get warrantyEndDate => 'Warranty end date';

  @override
  String get warrantyEndDateHint => 'Select warranty expiry date (optional)';

  @override
  String get warrantyExpired => 'Warranty expired';

  @override
  String get warrantyExpiringSoon => 'Warranty expires within 30 days';

  @override
  String get warrantyValid => 'Under warranty';

  @override
  String get pmProtocolsTitle => 'Preventive Maintenance Protocols';

  @override
  String get pmProtocolsSubtitle =>
      'Checklists and frequencies by equipment type';

  @override
  String get pmProtocolFrequency => 'Frequency';

  @override
  String pmProtocolFrequencyMonths(int n) {
    return '$n months';
  }

  @override
  String get pmProtocolDuration => 'Estimated duration';

  @override
  String pmProtocolDurationHours(String h) {
    return '$h h';
  }

  @override
  String get pmProtocolChecklist => 'Checklist';

  @override
  String get pmProtocolChecklistEmpty => 'No tasks defined';

  @override
  String get pmProtocolAdd => 'Add protocol';

  @override
  String get pmProtocolEdit => 'Edit protocol';

  @override
  String get pmProtocolDelete => 'Delete protocol';

  @override
  String pmProtocolDeleteConfirm(String name) {
    return 'Delete protocol \"$name\"?';
  }

  @override
  String get pmProtocolSaved => 'Protocol saved';

  @override
  String get pmProtocolDeleted => 'Protocol deleted';

  @override
  String get pmProtocolNameLabel => 'Protocol name *';

  @override
  String get pmProtocolFrequencyLabel => 'Frequency (months) *';

  @override
  String get pmProtocolDurationLabel => 'Estimated duration (hours)';

  @override
  String get pmProtocolChecklistLabel => 'Checklist tasks';

  @override
  String get pmProtocolAddTask => 'Add a task';

  @override
  String get pmProtocolTaskHint => 'E.g.: Check mains voltage';

  @override
  String get pmProtocolNoProtocols => 'No PM protocols for this equipment type';

  @override
  String get equipmentSubcategorySection => 'CMMS Classification';

  @override
  String get equipmentWarrantySection => 'Warranty & Criticality';

  @override
  String get equipmentPmSection => 'Applicable PM Protocols';

  @override
  String get systemStatusOperational => 'System status: Operational';

  @override
  String get systemStatusDegraded => 'System status: Degraded';

  @override
  String get systemStatusChecking => 'Checking…';

  @override
  String systemStatusLastCheck(String time) {
    return 'Last check at $time';
  }

  @override
  String get systemAlertBannerAuth =>
      'Authentication service unavailable. Please contact your IT administrator.';

  @override
  String get systemAlertBannerGeneral =>
      'System service(s) unavailable — limited functionality.';

  @override
  String get loginRecentSessionsTitle =>
      'Recently used accounts on this device';

  @override
  String get loginBackToLogin => 'Back to sign-in';

  @override
  String get forgotPasswordHint =>
      'Enter your email address. You will receive a link to reset your password.';

  @override
  String get commonNext => 'Next';

  @override
  String get commonBack => 'Back';

  @override
  String get dashboardRefreshedJustNow => 'Just now';

  @override
  String dashboardRefreshedAgo(int n) {
    return '$n min ago';
  }

  @override
  String dashboardRefreshedAt(String time) {
    return 'Updated at $time';
  }

  @override
  String get dashboardRefreshTooltip => 'Refresh';

  @override
  String get dashboardPmOverdue => 'Overdue PM';

  @override
  String get dashboardPriorityIssues => 'Priority issues';

  @override
  String get dashboardCriticalIssue24h => 'Critical issue (24h)';

  @override
  String get dashboardTechSection => 'Technician dashboard';

  @override
  String get dashboardTechBacklogLabel => 'Backlog';

  @override
  String get dashboardTechCriticalOos => 'Critical out of service';

  @override
  String get dashboardSidePanelTitle => 'Critical out of service';

  @override
  String get dashboardSidePanelSubtitle =>
      'Equipment out of service with criticality A';

  @override
  String get dashboardSidePanelEmpty => 'No critical equipment out of service';

  @override
  String get dashboardWeatherTitle => 'Hospital Status';

  @override
  String get dashboardWeatherAllGood => 'All clear — no current alerts';

  @override
  String dashboardWeatherCriticalCount(int count) {
    return '$count critical or urgent issue(s) in progress';
  }

  @override
  String dashboardWeatherOosCount(int count) {
    return '$count equipment out of service';
  }

  @override
  String get dashboardWeatherReportBtn => 'Report an incident';

  @override
  String get dashboardMyTasksTitle => 'My tasks today';

  @override
  String get dashboardMyTasksNoTasks => 'No pending tasks';

  @override
  String get dashboardMyTasksPmDue => 'PM due / upcoming';

  @override
  String get dashboardMyTasksViewIssues => 'View my interventions';

  @override
  String dashboardScopedTo(String scope) {
    return 'Scope: $scope';
  }

  @override
  String get equipmentExportCsv => 'Export CSV';

  @override
  String get equipmentExportCsvTooltip => 'Download filtered list as CSV';

  @override
  String get equipmentSchedulePm => 'Schedule PM';

  @override
  String get equipmentSchedulePmSuccess => 'Preventive maintenance scheduled';

  @override
  String get equipmentFilterPmOverdueChip => 'Overdue PM';

  @override
  String get equipmentFilterPmSoonChip => 'Upcoming PM (<7d)';

  @override
  String get equipmentFormStep1 => 'Essential info';

  @override
  String get equipmentFormStep2 => 'Technical info';

  @override
  String get equipmentFormStep3 => 'CMMS & Maintenance';

  @override
  String get equipmentFormStep1Subtitle => 'Name, category, department, status';

  @override
  String get equipmentFormStep2Subtitle =>
      'Manufacturer, serial number, location';

  @override
  String get equipmentFormStep3Subtitle =>
      'Preventive maintenance, criticality, revision';

  @override
  String get equipmentReportBreakdown => 'Report a breakdown';

  @override
  String get equipmentColumnInstallDate => 'Install date';

  @override
  String get equipmentCsvWebOnly => 'CSV export available on web browser only';

  @override
  String get equipmentSortBy => 'Sort by';

  @override
  String get equipDetailTabInfo => 'Information';

  @override
  String get equipDetailTabMaintenance => 'Maintenance';

  @override
  String get equipDetailTabIncidents => 'Incidents';

  @override
  String get equipDetailTabDocuments => 'Documents';

  @override
  String get equipDetailCriticalBanner =>
      'ALERT — Critical equipment out of service. Contact the technical team immediately.';

  @override
  String get equipDetailQrCode => 'QR Code';

  @override
  String get equipDetailQrCodeTitle => 'Equipment Identifier';

  @override
  String get equipDetailQrCodeSubtitle =>
      'Copy or share the ID to link this equipment to an incident';

  @override
  String get equipDetailQrCodeCopy => 'Copy ID';

  @override
  String get equipDetailQrCodeCopied => 'ID copied!';

  @override
  String get equipDetailKpiSection => 'Performance indicators';

  @override
  String get equipDetailMttr => 'MTTR (Mean Time To Repair)';

  @override
  String equipDetailMttrValue(int n) {
    return '$n day(s)';
  }

  @override
  String get equipDetailMttrNoData => 'Insufficient data';

  @override
  String get equipDetailTotalRepairs => 'Recorded repairs';

  @override
  String get equipDetailCreatePm => 'Create PM intervention';

  @override
  String get equipDetailStaffReportButton => 'Report a breakdown';

  @override
  String get equipDetailStaffContactSection => 'Technical team contact';

  @override
  String get equipDetailStaffContactBiomedical => 'Biomedical team';

  @override
  String get equipDetailStaffContactIt => 'IT department';

  @override
  String get equipDetailStaffContactInfra => 'Infrastructure team';

  @override
  String get equipDetailStaffContactGeneric => 'Technical department';

  @override
  String get equipDetailStaffActiveIssues =>
      'Active incidents on this equipment';

  @override
  String get equipDetailStaffNoActiveIssues => 'No active incidents';

  @override
  String get equipDetailNoDocuments => 'No documents available';

  @override
  String get equipDetailDocumentsHint =>
      'User manuals, technical datasheets and PM procedures will be displayed here.';

  @override
  String get equipDetailDeleteConfirmTitle => 'Delete equipment';

  @override
  String get equipDetailDeleteConfirmBody =>
      'This action is irreversible. Type the exact equipment name to confirm:';

  @override
  String get equipDetailDeleteConfirmLabel => 'Equipment name';

  @override
  String equipDetailDeleteConfirmHint(String name) {
    return 'Type exactly: $name';
  }

  @override
  String get equipDetailDeleteConfirmMismatch => 'Name does not match';

  @override
  String get equipDetailDeleteConfirmButton => 'Permanently delete';

  @override
  String get equipDetailDeleteReasonLabel => 'Reason (optional)';

  @override
  String get equipDetailDeleteReasonHint =>
      'E.g. Permanently out of service, replaced…';

  @override
  String equipDetailMaintenanceCount(int count) {
    return '$count intervention(s)';
  }

  @override
  String get issueFormSwitchTabTitle => 'Change category?';

  @override
  String get issueFormSwitchTabMessage =>
      'Entered data (description, photos) will be erased if you switch tabs. Continue?';

  @override
  String get issueFormSwitchTabConfirm => 'Switch';

  @override
  String get issueFormScanQrTooltip => 'Scan equipment QR code';

  @override
  String get issueFormScanQrTitle => 'Scan QR Code';

  @override
  String get issueFormScanQrFallbackTitle => 'Enter equipment ID';

  @override
  String get issueFormScanQrFallbackHint => 'Equipment ID or serial number';

  @override
  String get issueFormScanQrFallbackConfirm => 'Confirm';

  @override
  String get issueFormScanQrNotFound =>
      'No equipment found for this identifier';

  @override
  String get issueFormEquipmentAvailableLabel =>
      'Available for immediate intervention';

  @override
  String get issueFormEquipmentAvailableHint =>
      'Equipment can be powered off for repair';

  @override
  String get issueFormSuccessTitle => 'Report submitted successfully';

  @override
  String issueFormSuccessTicketId(String id) {
    return 'Ticket #: $id';
  }

  @override
  String get issueFormSuccessSlaLabel => 'Target deadline (SLA)';

  @override
  String get issueFormSla2h => '2 hours — critical priority';

  @override
  String get issueFormSla12h => '12 hours — urgent';

  @override
  String get issueFormSla48h => '48 hours — medium priority';

  @override
  String get issueFormSla1week => '1 week — low priority';

  @override
  String get issueFormSuccessClose => 'Close';

  @override
  String get issuesSearchHint => 'Search by incident, equipment, reporter…';

  @override
  String get issuesFilterPeriod => 'Period';

  @override
  String get issuesFilterPeriodAll => 'All';

  @override
  String get issuesFilterPeriodLast7 => 'Last 7 days';

  @override
  String get issuesFilterPeriodLast30 => 'Last 30 days';

  @override
  String get issuesFilterUrgency => 'Urgency';

  @override
  String get issuesFilterGroup => 'Group';

  @override
  String get issuesFilterGroupBiomedical => 'Biomedical';

  @override
  String get issuesFilterGroupIT => 'IT';

  @override
  String get issuesFilterGroupInfra => 'Infrastructure';

  @override
  String get issuesViewSeeAll => 'See all';

  @override
  String get issuesClearFilter => 'Clear filter';

  @override
  String get issuesViewList => 'List';

  @override
  String get issuesViewKanban => 'Kanban';

  @override
  String get issuesExportCsv => 'Export CSV';

  @override
  String get issuesCsvWebOnly => 'CSV export available on web browser only';

  @override
  String get issuesKanbanColTodo => 'To do';

  @override
  String get issuesKanbanColInProgress => 'In progress';

  @override
  String get issuesKanbanColWaiting => 'Waiting';

  @override
  String get issuesKanbanColDone => 'Done';

  @override
  String get issuesKanbanEmpty => 'No issues';

  @override
  String get issuesActiveFilterMyIssues => 'My issues only';

  @override
  String get issuesActiveFilterDeptIssues => 'My department only';

  @override
  String get issuesActiveFilterLabel => 'Active filter:';

  @override
  String issueDetailHandledBy(String technician, String date) {
    return 'Handled by $technician on $date';
  }

  @override
  String get issueDetailNotHandledYet => 'Pending assignment to a technician';

  @override
  String get issueDetailReassignButton => 'Reassign';

  @override
  String get issueDetailReassignTitle => 'Reassign issue';

  @override
  String get issueDetailReassignGroupLabel => 'Technical group';

  @override
  String get issueDetailReassignReasonLabel => 'Reason (required)';

  @override
  String get issueDetailReassignReasonHint =>
      'Explain the reason for reassigning…';

  @override
  String get issueDetailReassignReasonMinLength =>
      'Reason must be at least 5 characters';

  @override
  String get issueDetailReassignSuccess => 'Issue reassigned successfully';

  @override
  String issueDetailReassignError(String error) {
    return 'Error during reassignment: $error';
  }

  @override
  String get issueDetailAddCommentButton => 'Add a comment';

  @override
  String get issueDetailCommentTitle => 'Add a comment';

  @override
  String get issueDetailCommentHint => 'Enter your comment…';

  @override
  String get issueDetailCommentMinLength =>
      'Comment must be at least 5 characters';

  @override
  String get issueDetailCommentSubmit => 'Send';

  @override
  String get issueDetailCommentSuccess => 'Comment added to history';

  @override
  String issueDetailCommentError(String error) {
    return 'Error: $error';
  }

  @override
  String get issueDetailSectionDocuments => 'Documents & Attachments';

  @override
  String get issueDetailAddDocument => 'Add a file';

  @override
  String get issueDetailNoDocuments => 'No documents attached to this issue';

  @override
  String get issueDetailDocumentsHint =>
      'PDF reports, purchase orders, additional photos…';

  @override
  String get issueDetailPanelNoSelection =>
      'Select an issue from the list to see its details';

  @override
  String get issueDetailClosePanel => 'Close panel';

  @override
  String get techMarkResolvedTooltip =>
      'Select the \"Repaired\" status first to close the issue';

  @override
  String get techPartsFromInventory => 'Parts replaced (inventory)';

  @override
  String get techPartsSearchHint => 'Search for an inventory item...';

  @override
  String get techPartsNoResults => 'No items found';

  @override
  String techPartsStockLabel(int n, String unit) {
    return 'Stock: $n $unit';
  }

  @override
  String get techPartsNoneSelected => 'No parts selected';

  @override
  String get techPartsOutOfStock => 'Out of stock';

  @override
  String techTakenAtLabel(String date) {
    return 'Taken over on $date';
  }

  @override
  String get techAvailableGroupedSubtitle => 'Grouped by department / location';

  @override
  String techAvailableDeptCount(int count) {
    return '$count issue(s)';
  }

  @override
  String get techDestockConfirmTitle => 'Confirm stock deduction';

  @override
  String get techDestockConfirmSubtitle =>
      'You have declared the following parts:';

  @override
  String techDestockItemLine(
    String name,
    int quantity,
    String unit,
    int stock,
  ) {
    return '$name × $quantity $unit  (current stock: $stock)';
  }

  @override
  String techDestockStockAfter(int after, String unit) {
    return 'Estimated remaining stock: $after $unit';
  }

  @override
  String get techDestockLowWarning => '⚠ Low stock after this operation';

  @override
  String get techDestockConfirm => 'Confirm & deduct stock';

  @override
  String get techEscalateButton => 'Escalate / Suspend';

  @override
  String get techEscalateTitle => 'Escalate issue';

  @override
  String get techEscalateSubtitle =>
      'Suspend the issue if you lack materials or specific skills. This makes it visible to supervisors.';

  @override
  String get techEscalateStatusLabel => 'Escalation type';

  @override
  String get techEscalateWaitingMaterials => 'Waiting for materials / parts';

  @override
  String get techEscalateRedirected => 'Redirect to a specialist';

  @override
  String get techEscalateStatusRequired => 'Escalation type is required';

  @override
  String get techEscalateCommentLabel => 'Mandatory comment';

  @override
  String get techEscalateCommentHint =>
      'Explain the issue (missing parts, external expertise needed…)';

  @override
  String get techEscalateCommentMinLength =>
      'Comment must be at least 10 characters';

  @override
  String techEscalateSuccess(String status) {
    return 'Issue escalated — status: $status';
  }

  @override
  String get techWorkOrderTitle => 'Work Order — Formal closure';

  @override
  String get techWorkOrderSafetyCheck =>
      'I confirm that all safety checks have been performed and the equipment is operational.';

  @override
  String get techWorkOrderSafetyRequired =>
      'You must validate the safety checks before closing the issue.';

  @override
  String get techWorkOrderClosingNotes => 'Closing notes';

  @override
  String get techWorkOrderClosingNotesHint =>
      'Additional information for the supervisor or future technicians…';

  @override
  String get techWorkOrderConfirm => 'Confirm closure';

  @override
  String get reportsPeriodLabel => 'Analysis period';

  @override
  String get reportsPeriodLast7 => '7 days';

  @override
  String get reportsPeriodLast30 => '30 days';

  @override
  String get reportsPeriodLast90 => '90 days';

  @override
  String get reportsPeriodYearToDate => 'Year to date';

  @override
  String get reportsPeriodCustom => 'Custom';

  @override
  String get reportsKpiSectionTitle => 'CMMS KPIs';

  @override
  String get reportsMttr => 'Mean Response Time';

  @override
  String get reportsMttrNoData => 'Insufficient data';

  @override
  String get reportsMttrHint =>
      'Mean time from report to first intervention (closed issues)';

  @override
  String reportsMttrDays(String n) {
    return '$n day(s)';
  }

  @override
  String get reportsPmCompliance => 'PM Compliance';

  @override
  String get reportsPmComplianceHint => '% of equipment with PM not overdue';

  @override
  String reportsPmTotal(int n) {
    return '$n equipment with scheduled PM';
  }

  @override
  String get reportsPmNoData => 'No PM plan configured';

  @override
  String get reportsTopDepts => 'Most impacted departments';

  @override
  String get reportsTopDeptsHint => 'By number of incidents in the period';

  @override
  String get reportsTopDeptsEmpty => 'No incidents in the selected period';

  @override
  String get reportsExportCsv => 'Export CSV';

  @override
  String get reportsExportCsvSuccess => 'CSV file downloaded';

  @override
  String get reportsExportCsvWebOnly =>
      'CSV export available on web browser only';

  @override
  String get reportsIssuesInPeriod => 'Issues (period)';

  @override
  String get reportsResolutionRate => 'Resolution rate';

  @override
  String get analyticsIssueKpiSection => 'Incident metrics';

  @override
  String get analyticsEquipmentSection => 'Equipment status';

  @override
  String get analyticsChartsSection => 'Trend charts';

  @override
  String get analyticsChartsPeriodNote =>
      'Rolling window — 13 weeks (independent of period filter)';

  @override
  String get analyticsIncidentTrend => 'Reported vs Resolved — 13 weeks';

  @override
  String get analyticsCreatedSeries => 'Reported';

  @override
  String get analyticsResolvedSeries => 'Resolved';

  @override
  String get analyticsResolutionRateLabel => 'Resolution rate';

  @override
  String get analyticsOpenIssuesLabel => 'Open issues';

  @override
  String get analyticsGroupBarTitle => 'Issues by technical group';

  @override
  String get analyticsGroupBiomedical => 'Biomedical';

  @override
  String get analyticsGroupIT => 'IT';

  @override
  String get analyticsGroupInfra => 'Infrastructure';

  @override
  String get analyticsGroupOther => 'Other';

  @override
  String get analyticsRetry => 'Retry';

  @override
  String get analyticsNoChartData => 'Unable to load chart data';

  @override
  String get healthStatusOk => 'Operational';

  @override
  String get healthStatusKo => 'Unavailable';

  @override
  String get healthTooltipTitle => 'Service status';

  @override
  String healthTooltipLastCheck(String time) {
    return 'Last check: $time';
  }

  @override
  String get healthTooltipNoCheck => 'Checking…';

  @override
  String get accessRequestLink => 'Request access';

  @override
  String get accessRequestTitle => 'System access request';

  @override
  String get accessRequestSubtitle =>
      'Create your account in seconds. You\'ll be logged in automatically with the Hospital Staff role.';

  @override
  String get accessRequestFirstName => 'First name *';

  @override
  String get accessRequestLastName => 'Last name *';

  @override
  String get accessRequestEmail => 'Work email *';

  @override
  String get accessRequestDepartment => 'Department (optional)';

  @override
  String get accessRequestPassword => 'Password *';

  @override
  String get accessRequestPasswordConfirm => 'Confirm password *';

  @override
  String get accessRequestPasswordTooShort => 'Minimum 8 characters';

  @override
  String get accessRequestPasswordMismatch => 'Passwords do not match';

  @override
  String get accessRequestAccountExists =>
      'This email is already associated with an account';

  @override
  String get accessRequestSubmit => 'Create my account';

  @override
  String get accessRequestSuccess => 'Account created! Logging in…';

  @override
  String get accessRequestError =>
      'Error creating account. Try again or contact the IT admin directly.';

  @override
  String get accessRequestOtherOption => 'Other / Not listed';

  @override
  String get emergencyContactTitle => 'Emergency or locked account?';

  @override
  String get emergencyContactInfo =>
      'IT admin: nzephmd@gmail.com  •  +250 788 823 228';

  @override
  String get hubStaffTitle => 'What would you like to do?';

  @override
  String get hubStaffReportButton => 'Report a breakdown';

  @override
  String get hubStaffActiveIssuesButton => 'My active incidents';

  @override
  String hubStaffActiveIssuesCount(int count) {
    return '$count active incident(s)';
  }

  @override
  String get hubStaffNoActiveIssues => 'No active incidents at the moment';

  @override
  String get hubTechWorkplanTitle => 'My workplan for today';

  @override
  String get hubTechWorkplanSubtitle =>
      'Planned tasks and assigned interventions';

  @override
  String get hubTechPmSection => 'Preventive maintenance (PM)';

  @override
  String get hubTechAssignedSection => 'My assigned interventions';

  @override
  String get hubTechPendingPartsSection => 'Pending parts';

  @override
  String get hubTechNoPm => 'No overdue or upcoming PM';

  @override
  String get hubTechNoAssigned => 'No assigned intervention in progress';

  @override
  String get hubTechNoPendingParts => 'No parts pending';

  @override
  String get hubTechViewAll => 'View all';

  @override
  String get hubTechPmOverdueLabel => 'PM overdue';

  @override
  String get hubTechPmSoonLabel => 'PM soon (< 7 d)';

  @override
  String get hubKpiLastRefreshLabel => 'Data updated';

  @override
  String get equipmentViewGrid => 'Grid view';

  @override
  String get equipmentViewList => 'List view';

  @override
  String get equipmentColumnLastPm => 'Last PM / Intervention';

  @override
  String get equipmentFilterMyUnit => 'My unit / Room';

  @override
  String get equipmentFilterUnit => 'Unit / Room';

  @override
  String get equipmentScanQrTooltip => 'Search by QR code';

  @override
  String get equipmentScanQrTitle => 'Search by QR';

  @override
  String get equipmentScanQrManualTitle => 'Enter identifier manually';

  @override
  String get equipmentScanQrManualHint => 'Equipment ID or serial number';

  @override
  String get equipmentScanQrNotFound =>
      'No equipment found for this identifier';

  @override
  String get equipmentCsvShared => 'CSV file ready to share';

  @override
  String get equipmentCsvShareError => 'Error while sharing CSV';

  @override
  String get issueFormStep1Label => 'Step 1 / 2 — Category & Equipment';

  @override
  String get issueFormStep2Label => 'Step 2 / 2 — Description & Photos';

  @override
  String get issueFormScanBlock => 'Report by QR Code';

  @override
  String get issueFormScanBlockTooltip =>
      'Ultra-fast mode: scan → Critical urgency → 2 fields to fill';

  @override
  String get issueFormScanBlockUrgencySet =>
      'Urgency set to Critical — complete the description';

  @override
  String get issueFormUnlistedEquipment => 'Unlisted equipment';

  @override
  String get issueFormUnlistedEquipmentNameLabel => 'Equipment name';

  @override
  String get issueFormUnlistedEquipmentHint =>
      'E.g.: Ventilator room 3, Monitor bed 12...';

  @override
  String get issueFormUnlistedEquipmentRequired =>
      'Please enter the equipment name';

  @override
  String get issueFormUnlistedWarning =>
      'The technician will need to identify this equipment on site.';

  @override
  String get issueFormPhotoGuide =>
      'Tip: take a photo of the error screen, the equipment label, or the defective area.';

  @override
  String get notifPrefsTitle => 'Email alerts — Critical incidents';

  @override
  String get notifPrefsSubtitle =>
      'All notifications relate to Critical-level incidents only.';

  @override
  String get notifPrefsScope => 'Critical-level incidents only';

  @override
  String get notifPrefsFirstSetupSubtitle =>
      'Welcome! Configure your email alerts.';

  @override
  String get notifPrefsSkip => 'Skip';

  @override
  String get notifPrefsUpdated => 'Alert preferences updated';

  @override
  String get notifPrefsAllEnabled => 'All alerts enabled';

  @override
  String get notifPrefsSomeEnabled => 'Alerts partially enabled';

  @override
  String get notifPrefsAllDisabled => 'All alerts disabled';

  @override
  String get notifPrefsSectionTechnician => 'Technician alerts';

  @override
  String get notifPrefsSectionSupervisor => 'Supervisor alerts';

  @override
  String get notifPrefsCriticalNewIssue => 'New critical incident reported';

  @override
  String get notifPrefsCriticalNewIssueDesc =>
      'Email as soon as a CRITICAL incident is reported in your technical group.';

  @override
  String get notifPrefsCriticalAcknowledged =>
      'Critical incident taken in charge';

  @override
  String get notifPrefsCriticalAcknowledgedDesc =>
      'Email when a technician takes charge of a critical incident.';

  @override
  String get notifPrefsCriticalDiagnosed =>
      'Diagnosis set on critical incident';

  @override
  String get notifPrefsCriticalDiagnosedDesc =>
      'Email when a technician fills in the diagnosis for a critical incident.';

  @override
  String get notifPrefsCriticalResolved =>
      'Critical incident resolved (with KPIs)';

  @override
  String get notifPrefsCriticalResolvedDesc =>
      'Closure email with resolution time, diagnosis, corrective actions, and replaced parts.';

  @override
  String get notifPrefsPmDue => 'Preventive maintenance due';

  @override
  String get notifPrefsPmDueDesc =>
      'Email when a preventive maintenance is overdue or upcoming.';

  @override
  String get reportsPdfExportTooltip => 'Generate and download the PDF report';

  @override
  String get reportsPdfSuccess => 'PDF report ready — save it from the dialog';

  @override
  String get reportsPdfError => 'Error generating PDF report';

  @override
  String get navDebugTest => 'Debug & Test';

  @override
  String get navDebugTestShort => 'Debug';

  @override
  String get debugTitle => 'Debug & Test Module';

  @override
  String get debugSubtitle =>
      'Reserved for administrators — irreversible data operations';

  @override
  String get debugDbSection => 'Database Management';

  @override
  String get debugClearIssuesLabel => 'Clear all incident reports';

  @override
  String get debugClearIssuesDesc =>
      'Permanently deletes all incidents from the database. This action is irreversible.';

  @override
  String get debugClearIssuesButton => 'Clear all incidents';

  @override
  String get debugClearIssuesLoading => 'Clearing...';

  @override
  String get debugClearIssuesTitle => 'Confirm clearing';

  @override
  String get debugClearIssuesMessage =>
      'This action will permanently delete ALL incidents from the database. This operation is irreversible and cannot be undone.';

  @override
  String get debugClearIssuesConfirm => 'Delete all';

  @override
  String debugClearIssuesSuccess(int count) {
    return '$count incident(s) successfully deleted';
  }

  @override
  String debugClearIssuesError(String error) {
    return 'Error during clearing: $error';
  }

  @override
  String get reportsArchivesSectionTitle => 'Archives & Historical Reports';

  @override
  String get reportsArchivesTypeMonthly => 'Monthly';

  @override
  String get reportsArchivesTypeAnnual => 'Annual';

  @override
  String get reportsArchivesDownload => 'Download PDF Report';

  @override
  String get reportsArchivesDownloading => 'Generating...';

  @override
  String get reportsArchivesHint =>
      'Select a period to download a historical report as PDF.';

  @override
  String get pmProtocols => 'Maintenance protocols';

  @override
  String get pmChecklist => 'Maintenance checklist';

  @override
  String pmStepsProgress(int done, int total) {
    return '$done / $total steps validated';
  }

  @override
  String get pmNoProtocolAvailable =>
      'No protocol defined for this equipment type';

  @override
  String get pmFrequencyLabel => 'Maintenance frequency';

  @override
  String pmFrequencyValue(int months) {
    return 'Every $months months';
  }

  @override
  String pmDurationEstimated(int min) {
    return 'Estimated duration: $min min';
  }

  @override
  String pmDurationActual(int min) {
    return 'Actual duration: $min min';
  }

  @override
  String get pmValidateButton => 'Validate preventive maintenance';

  @override
  String get pmValidateConfirmTitle => 'Confirm validation';

  @override
  String pmValidateConfirmBody(int unchecked) {
    return '$unchecked unchecked step(s). Validate anyway?';
  }

  @override
  String get pmValidateSuccess => 'Maintenance recorded';

  @override
  String pmNextDate(String date) {
    return 'Next maintenance: $date';
  }

  @override
  String get pmPrintLabel => 'Print label';

  @override
  String get pmEditLabel => 'Maintenance label';

  @override
  String get pmHistoryTitle => 'Preventive maintenance history';

  @override
  String pmComplianceRate(int rate) {
    return 'Compliance: $rate%';
  }

  @override
  String get pmPartsUsed => 'Parts used';

  @override
  String get pmSeeAll => 'See all';

  @override
  String get pmFrequencySaved => 'Maintenance frequency updated';

  @override
  String get pmFrequencySelectLabel => 'Set PM frequency';

  @override
  String get docTabTitle => 'Documents';

  @override
  String get docTechnicalSection => 'Technical documents';

  @override
  String get docInterventionSection => 'Intervention documents';

  @override
  String get docCertificationSection => 'Certificates & Compliance';

  @override
  String get docAddButton => 'Add document';

  @override
  String get docTypeLabel => 'Document type';

  @override
  String get docTypeTechnical => 'Manual / Technical sheet';

  @override
  String get docTypeIntervention => 'Report / Invoice';

  @override
  String get docTypeCertification => 'Certificate / Compliance';

  @override
  String get docUploadSuccess => 'Document successfully added';

  @override
  String docUploadError(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get docDeleteConfirmTitle => 'Delete this document?';

  @override
  String get docDeleteConfirmBody => 'This action cannot be undone.';

  @override
  String get docDeleteSuccess => 'Document deleted';

  @override
  String get docDownloadError => 'Unable to open document';

  @override
  String get docNoDocuments => 'No documents in this section';

  @override
  String get docRestrictedAccess =>
      'Access restricted to technicians and supervisors';

  @override
  String get issuePhotosSection => 'Incident photos';

  @override
  String get issuePhotoLimitReached => '5-photo limit reached';

  @override
  String get issuePhotoCompressing => 'Compressing…';

  @override
  String get issuePhotosUploading => 'Uploading photos…';

  @override
  String get issuePhotosNoPhotos => 'No photos attached';
}
