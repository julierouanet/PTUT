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
  String get navSettings => 'Settings';

  @override
  String get logout => 'Log out';

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
  String get dashboardAvailable => 'Available';

  @override
  String get dashboardMaintenance => 'Maintenance';

  @override
  String get dashboardOutOfService => 'Out of Service';

  @override
  String get dashboardEquipmentStatus => 'Equipment status';

  @override
  String get dashboardAvailableStatus => 'Available';

  @override
  String get dashboardInUse => 'In use';

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
  String get issuesTitle => 'Issue Tracking';

  @override
  String get issuesSubtitle => 'Manage and track equipment issues';

  @override
  String get issuesOpen => 'Open';

  @override
  String get issuesInProgress => 'In Progress';

  @override
  String get issuesResolved => 'Resolved';

  @override
  String get issuesReport => 'Report an issue';

  @override
  String get issuesFilterByStatus => 'Filter by status: ';

  @override
  String issuesCount(int count) {
    return '$count issue(s)';
  }

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
  String get reportsAvailable => 'Available';

  @override
  String get reportsInUse => 'In use';

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
}
