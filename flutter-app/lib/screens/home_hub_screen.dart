import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/api_config.dart';
import '../services/notification_service.dart';
import '../models/issue.dart';
import '../models/inventory_item.dart';
import '../models/equipment.dart';
import '../models/user_role.dart';
import '../models/notification.dart';
import '../widgets/issue_category_selector.dart';
import '../services/feature_service.dart';
import '../services/push_notification_web_service.dart';
import 'account_settings_screen.dart';

/// Hub post-connexion — tableau de bord personnalisé selon le rôle (RBAC).
///
/// • hospitalStaff  → vue ultra-simplifiée : gros bouton "Signaler" + incidents actifs
/// • technician*    → plan de travail du jour (PM dues, interventions assignées, pièces en attente)
/// • supervisor     → KPIs + accès modules Équipement & Inventaire
/// • admin          → KPIs + accès aux 3 modules complets
class HomeHubScreen extends StatelessWidget {
  final VoidCallback onEquipmentModule;
  final VoidCallback onTechnicianModule;
  final VoidCallback onSettingsModule;
  final VoidCallback onInventoryModule;
  final VoidCallback onMyActiveIssues;
  final void Function(String department) onDepartmentIssues;

  const HomeHubScreen({
    super.key,
    required this.onEquipmentModule,
    required this.onTechnicianModule,
    required this.onSettingsModule,
    required this.onInventoryModule,
    required this.onMyActiveIssues,
    required this.onDepartmentIssues,
  });

  // ── Helpers de classification des rôles ──────────────────────────────────

  bool _isHospitalStaff(AuthService auth) {
    final roles = auth.currentRoles;
    // Personnel soignant pur : hospitalStaff sans rôle technique ou admin
    return roles.contains(UserRole.hospitalStaff) &&
        !roles.any((r) => r == UserRole.admin ||
            r == UserRole.supervisor ||
            r == UserRole.technician ||
            r == UserRole.technicianBiomedical ||
            r == UserRole.technicianIt ||
            r == UserRole.technicianInfra);
  }

  bool _isTechnician(AuthService auth) {
    final roles = auth.currentRoles;
    // Un admin ou superviseur cumulant un rôle technicien reste prioritairement
    // routé vers la vue manager (cartes modules) — cohérent avec _isHospitalStaff.
    if (roles.contains(UserRole.admin) || roles.contains(UserRole.supervisor)) {
      return false;
    }
    return roles.any((r) =>
        r == UserRole.technician ||
        r == UserRole.technicianBiomedical ||
        r == UserRole.technicianIt ||
        r == UserRole.technicianInfra);
  }

  // ── Calcul des KPIs depuis DataService ────────────────────────────────────

  int _countCriticalUrgent(DataService data) => data.issues.where((i) =>
      (i.urgency == IssueUrgency.critique || i.urgency == IssueUrgency.urgent) &&
      i.status != IssueStatus.completed &&
      i.status != IssueStatus.closed &&
      i.status != IssueStatus.verified).length;

  int _countStockAlerts(DataService data) => data.inventory.where((i) =>
      i.status == StockStatus.low || i.status == StockStatus.outOfStock).length;

  int _countOutOfService(DataService data) => data.equipment.where((e) =>
      e.status == EquipmentStatus.outOfService).length;

  // ── Données pour la vue technicien ───────────────────────────────────────

  List<Equipment> _pmDueOrOverdue(DataService data) {
    final today = DateTime.now();
    final threshold = today.add(const Duration(days: 7));
    return data.equipment.where((e) {
      final iso = e.nextPreventiveMaintenance;
      if (iso == null || iso.length < 10) return false;
      try {
        final date = DateTime.parse(iso.substring(0, 10));
        return !date.isAfter(threshold);
      } catch (_) {
        return false;
      }
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a.nextPreventiveMaintenance!.substring(0, 10)) ?? DateTime(9999);
        final db = DateTime.tryParse(b.nextPreventiveMaintenance!.substring(0, 10)) ?? DateTime(9999);
        return da.compareTo(db);
      });
  }

  List<Issue> _myAssignedIssues(DataService data, AuthService auth) {
    final me = auth.currentUser;
    if (me == null) return [];
    return data.issues.where((i) =>
        (i.assignedTechnician == me.id || i.assignedTechnician == me.name) &&
        i.status != IssueStatus.completed &&
        i.status != IssueStatus.closed &&
        i.status != IssueStatus.verified).toList();
  }

  List<Issue> _pendingParts(DataService data, AuthService auth) {
    final me = auth.currentUser;
    if (me == null) return [];
    return data.issues.where((i) =>
        i.status == IssueStatus.waitingMaterials &&
        (i.assignedTechnician == me.id || i.assignedTechnician == me.name)).toList();
  }

  List<Issue> _myActiveIssues(DataService data, AuthService auth) {
    final me = auth.currentUser;
    if (me == null) return [];
    return data.issues.where((i) =>
        (i.reporterId == me.id ||
            i.reporter == me.name ||
            i.reporter == '${me.firstName} ${me.lastName}'.trim()) &&
        i.status != IssueStatus.completed &&
        i.status != IssueStatus.closed &&
        i.status != IssueStatus.verified).toList();
  }

  List<Issue> _myDepartmentOpenIssues(DataService data, AuthService auth) {
    final dept = auth.currentUser?.department;
    if (dept == null || dept.isEmpty) return [];
    return data.issues.where((i) => i.department == dept && i.status.isOpen).toList();
  }

  // ── Build principal ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = AuthService().currentUser;
    final auth = AuthService();
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showIssueCategorySelector(context),
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.report_problem_rounded),
        label: Text(
          l10n.hubReportUrgentButton,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        tooltip: l10n.hubReportUrgentTooltip,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, user),
            const _PushNotificationBanner(),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([DataService(), FeatureService()]),
                builder: (context, _) {
                  final data = DataService();
                  if (_isHospitalStaff(auth)) {
                    return _buildStaffView(context, l10n, isWide, data, auth);
                  } else if (_isTechnician(auth)) {
                    return _buildTechWorkplan(context, l10n, isWide, data, auth);
                  } else {
                    return _buildManagerView(context, l10n, isWide, data, auth);
                  }
                },
              ),
            ),
            _buildVersionFooter(context),
          ],
        ),
      ),
    );
  }

  // ── Vue Personnel soignant ────────────────────────────────────────────────

  Widget _buildStaffView(
    BuildContext context,
    AppLocalizations l10n,
    bool isWide,
    DataService data,
    AuthService auth,
  ) {
    final activeIssues = _myActiveIssues(data, auth);
    final department = auth.currentUser?.department ?? '';
    final departmentIssues = _myDepartmentOpenIssues(data, auth);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isWide ? 48 : 24,
        32,
        isWide ? 48 : 24,
        96,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.hubStaffTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // ── Gros bouton principal "Signaler une panne" ──────────────────
          SizedBox(
            height: isWide ? 90 : 80,
            child: ElevatedButton.icon(
              onPressed: () => showIssueCategorySelector(context),
              icon: const Icon(Icons.report_problem_rounded, size: 32),
              label: Text(
                l10n.hubStaffReportButton,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Accès "Mes incidents actifs" ────────────────────────────────
          _buildIssuesAccessButton(
            icon: Icons.troubleshoot_outlined,
            label: l10n.hubStaffActiveIssuesButton,
            count: activeIssues.length,
            countLabel: l10n.hubStaffActiveIssuesCount(activeIssues.length),
            emptyLabel: l10n.hubStaffNoActiveIssues,
            onPressed: onMyActiveIssues,
          ),

          if (activeIssues.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...activeIssues.take(3).map((issue) => _buildStaffIssueChip(l10n, issue)),
            if (activeIssues.length > 3) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onMyActiveIssues,
                child: Text(
                  '+ ${activeIssues.length - 3} ${l10n.issuesAndMore(activeIssues.length - 3)}',
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ],

          // ── Accès "Incidents de mon département" ────────────────────────
          if (department.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildIssuesAccessButton(
              icon: Icons.business_outlined,
              label: l10n.hubStaffDepartmentIssuesButton,
              count: departmentIssues.length,
              countLabel: l10n.hubStaffDepartmentIssuesCount(departmentIssues.length),
              emptyLabel: l10n.hubStaffNoDepartmentIssues,
              onPressed: () => onDepartmentIssues(department),
            ),
          ],
        ],
      ),
    );
  }

  /// Bouton d'accès générique vers une liste d'incidents — affiche un compteur
  /// si non vide, sinon un libellé "aucun incident". Réutilisé pour "Mes
  /// incidents actifs" et "Incidents de mon département".
  Widget _buildIssuesAccessButton({
    required IconData icon,
    required String label,
    required int count,
    required String countLabel,
    required String emptyLabel,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            count > 0 ? countLabel : emptyLabel,
            style: TextStyle(
              fontSize: 12,
              color: count > 0 ? AppColors.warning : AppColors.textSecondary,
            ),
          ),
        ],
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
    );
  }

  Widget _buildStaffIssueChip(AppLocalizations l10n, Issue issue) {
    final color = _urgencyColor(issue.urgency);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, color: color, size: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                issue.equipmentName ?? issue.id,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                issue.status.displayName,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Vue Technicien : Plan de travail du jour ──────────────────────────────

  Widget _buildTechWorkplan(
    BuildContext context,
    AppLocalizations l10n,
    bool isWide,
    DataService data,
    AuthService auth,
  ) {
    final pmDue      = _pmDueOrOverdue(data);
    final assigned   = _myAssignedIssues(data, auth);
    final waitParts  = _pendingParts(data, auth);
    final totalActive = pmDue.length + assigned.length + waitParts.length;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isWide ? 32 : 16,
        20,
        isWide ? 32 : 16,
        96,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête plan de travail ─────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.hubTechWorkplanTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.hubTechWorkplanSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Bouton CTA accès module technicien — toujours visible ───────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTechnicianModule,
              icon: const Icon(Icons.build_rounded),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.hubTechGoToTechnicianButton),
                  if (totalActive > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalActive',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Section PM dues ─────────────────────────────────────────────
          _buildWorkplanSection(
            context: context,
            l10n: l10n,
            icon: Icons.build_circle_outlined,
            color: AppColors.warning,
            title: l10n.hubTechPmSection,
            count: pmDue.length,
            onViewAll: onTechnicianModule,
            emptyLabel: l10n.hubTechNoPm,
            children: pmDue.take(3).map((eq) => _buildPmTile(l10n, eq, onTap: onTechnicianModule)).toList(),
          ),
          const SizedBox(height: 16),

          // ── Section interventions assignées ─────────────────────────────
          _buildWorkplanSection(
            context: context,
            l10n: l10n,
            icon: Icons.engineering_outlined,
            color: AppColors.primary,
            title: l10n.hubTechAssignedSection,
            count: assigned.length,
            onViewAll: onTechnicianModule,
            emptyLabel: l10n.hubTechNoAssigned,
            children: assigned.take(3).map((issue) => _buildIssueTile(l10n, issue, AppColors.primary, onTap: onTechnicianModule)).toList(),
          ),
          const SizedBox(height: 16),

          // ── Section pièces en attente ───────────────────────────────────
          _buildWorkplanSection(
            context: context,
            l10n: l10n,
            icon: Icons.inventory_2_outlined,
            color: AppColors.error,
            title: l10n.hubTechPendingPartsSection,
            count: waitParts.length,
            onViewAll: onTechnicianModule,
            emptyLabel: l10n.hubTechNoPendingParts,
            children: waitParts.take(3).map((issue) => _buildIssueTile(l10n, issue, AppColors.error, onTap: onTechnicianModule)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkplanSection({
    required BuildContext context,
    required AppLocalizations l10n,
    required IconData icon,
    required Color color,
    required String title,
    required int count,
    required VoidCallback onViewAll,
    required String emptyLabel,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête section ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (count > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: onViewAll,
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l10n.hubTechViewAll,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // ── Contenu ─────────────────────────────────────────────────────
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.success, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    emptyLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _buildPmTile(AppLocalizations l10n, Equipment equipment, {required VoidCallback onTap}) {
    final iso   = equipment.nextPreventiveMaintenance ?? '';
    final today = DateTime.now();
    DateTime? pmDate;
    try {
      if (iso.length >= 10) pmDate = DateTime.parse(iso.substring(0, 10));
    } catch (_) {}

    final isOverdue = pmDate != null && pmDate.isBefore(today);
    final color     = isOverdue ? AppColors.error : AppColors.warning;
    final tag       = isOverdue ? l10n.hubTechPmOverdueLabel : l10n.hubTechPmSoonLabel;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.build_outlined, color: color, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    equipment.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (equipment.department.isNotEmpty)
                    Text(
                      equipment.department,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueTile(AppLocalizations l10n, Issue issue, Color color, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.troubleshoot_outlined, color: color, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.equipmentName ?? issue.id,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (issue.description.isNotEmpty)
                    Text(
                      issue.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _urgencyColor(issue.urgency).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                issue.urgency.displayName,
                style: TextStyle(
                  fontSize: 11,
                  color: _urgencyColor(issue.urgency),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Vue Superviseur / Admin ───────────────────────────────────────────────

  Widget _buildManagerView(
    BuildContext context,
    AppLocalizations l10n,
    bool isWide,
    DataService data,
    AuthService auth,
  ) {
    final criticalCount     = _countCriticalUrgent(data);
    final outOfServiceCount = _countOutOfService(data);

    // Alertes stock masquées si le module inventaire est désactivé dans les feature flags
    final role = auth.primaryRole?.apiName;
    final inventoryEnabled = auth.hasPermission(Permission.viewInventory) &&
        FeatureService().isModuleEnabled('inventory', role);
    final stockAlertCount = inventoryEnabled ? _countStockAlerts(data) : 0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isWide ? 32 : 16,
        20,
        isWide ? 32 : 16,
        96,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Titre + fraîcheur des données ───────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.hubKpiTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.hubKpiSubtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildFreshnessChip(l10n, data),
            ],
          ),
          const SizedBox(height: 20),

          // ── Tuiles KPI ──────────────────────────────────────────────────
          _buildKpiRow(
            l10n,
            isWide,
            criticalCount,
            stockAlertCount,
            outOfServiceCount,
          ),
          const SizedBox(height: 28),

          // ── Titre accès rapide ──────────────────────────────────────────
          Text(
            l10n.hubQuickAccessTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // ── Cartes modules ──────────────────────────────────────────────
          _buildModuleCards(
            context,
            l10n,
            isWide,
            auth,
            criticalCount,
            stockAlertCount,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Indicateur de fraîcheur des données ──────────────────────────────────

  Widget _buildFreshnessChip(AppLocalizations l10n, DataService data) {
    final lastRefresh = data.lastRefresh;
    if (lastRefresh == null) return const SizedBox.shrink();

    final now     = DateTime.now();
    final diff    = now.difference(lastRefresh);
    final String label;

    if (diff.inMinutes < 1) {
      label = l10n.dashboardRefreshedJustNow;
    } else if (diff.inMinutes < 60) {
      label = l10n.dashboardRefreshedAgo(diff.inMinutes);
    } else {
      final h = diff.inHours;
      final m = diff.inMinutes.remainder(60);
      final timeStr = '${h}h${m.toString().padLeft(2, '0')}';
      label = l10n.dashboardRefreshedAt(timeStr);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sync_rounded, size: 13, color: AppColors.success),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Rangée de tuiles KPI ──────────────────────────────────────────────────

  Widget _buildKpiRow(
    AppLocalizations l10n,
    bool isWide,
    int criticalCount,
    int stockAlertCount,
    int outOfServiceCount,
  ) {
    // Vérification des mêmes conditions que _buildModuleCards pour cohérence :
    // ne pas naviguer vers un module désactivé depuis les tuiles KPI.
    final auth     = AuthService();
    final features = FeatureService();
    final role     = auth.primaryRole?.apiName;
    final canGoInventory = auth.hasPermission(Permission.viewInventory) &&
        features.isModuleEnabled('inventory', role);
    final canGoEquipment = features.isModuleEnabled('equipment', role);

    // Tuiles construites conditionnellement : une tuile n'est ajoutée que si son
    // module est actif. Désactiver un module retire donc ses tuiles KPI (cohérence
    // UI aval) au lieu de les afficher avec un compteur à 0.
    final tiles = <_KpiTile>[
      if (canGoEquipment)
        _KpiTile(
          label: l10n.hubKpiCriticalUrgentLabel,
          count: criticalCount,
          icon: Icons.warning_amber_rounded,
          color: criticalCount > 0 ? AppColors.error : AppColors.success,
          subtitle: criticalCount == 0 ? l10n.hubKpiNoAlert : l10n.hubKpiOpenIssues,
          onTap: onEquipmentModule,
        ),
      if (canGoInventory)
        _KpiTile(
          label: l10n.hubKpiStockAlertsLabel,
          count: stockAlertCount,
          icon: Icons.inventory_outlined,
          color: stockAlertCount > 0 ? AppColors.warning : AppColors.success,
          subtitle: stockAlertCount == 0 ? l10n.hubKpiNoAlert : l10n.hubKpiStockAlertsSubtitle,
          onTap: onInventoryModule,
        ),
      if (canGoEquipment)
        _KpiTile(
          label: l10n.hubKpiOutOfServiceLabel,
          count: outOfServiceCount,
          icon: Icons.power_off_outlined,
          color: outOfServiceCount > 0 ? AppColors.warning : AppColors.success,
          subtitle: outOfServiceCount == 0 ? l10n.hubKpiNoAlert : l10n.hubKpiOutOfServiceSubtitle,
          onTap: onEquipmentModule,
        ),
    ];

    // Aucun module actif → pas de rangée KPI (évite un cadre vide).
    if (tiles.isEmpty) return const SizedBox.shrink();

    // Tuile unique en mobile : ne pas l'étirer plein écran, l'aligner à gauche
    // avec une largeur bornée. Sur écran large ou ≥ 2 tuiles, on garde Expanded.
    if (!isWide && tiles.length == 1) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: tiles.first,
        ),
      );
    }

    // Rangée recomposée dynamiquement sur le nombre réel de tuiles restantes ;
    // espacement uniquement ENTRE les tuiles.
    return Row(
      children: [
        for (int i = 0; i < tiles.length; i++) ...[
          Expanded(child: tiles[i]),
          if (i < tiles.length - 1) SizedBox(width: isWide ? 16 : 8),
        ],
      ],
    );
  }

  // ── Disposition des cartes modules ────────────────────────────────────────

  Widget _buildModuleCards(
    BuildContext context,
    AppLocalizations l10n,
    bool isWide,
    AuthService auth,
    int criticalCount,
    int stockAlertCount,
  ) {
    final role     = auth.primaryRole?.apiName;
    final features = FeatureService();

    final showSettings  = auth.hasPermission(Permission.manageDepartments) ||
        auth.hasPermission(Permission.manageUsers);
    // Module Inventaire : permission ET flag actif pour le rôle
    final showInventory = auth.hasPermission(Permission.viewInventory) &&
        features.isModuleEnabled('inventory', role);
    // Module Équipement : toujours visible si flag actif (permission gérée côté sidebar)
    final showEquipment = features.isModuleEnabled('equipment', role);

    final cards = <Widget>[
      if (showEquipment) _buildEquipmentCard(l10n, criticalCount),
      if (showInventory) _buildInventoryCard(l10n, stockAlertCount),
      if (showSettings)  _buildSettingsCard(l10n),   // Settings jamais conditionné par un flag
    ];

    if (cards.isEmpty) return const SizedBox.shrink();

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i < cards.length - 1) const SizedBox(width: 16),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i < cards.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ── Cartes modules ────────────────────────────────────────────────────────

  Widget _buildEquipmentCard(AppLocalizations l10n, int badgeCount) =>
      _HubModuleCard(
        color: AppColors.primary,
        lightColor: AppColors.primaryLight,
        icon: Icons.medical_services_outlined,
        title: l10n.hubEquipmentTitle,
        description: l10n.hubEquipmentDesc,
        badgeCount: badgeCount,
        pages: [
          _PageEntry(l10n.navDashboard,     Icons.dashboard_outlined),
          _PageEntry(l10n.navEquipment,     Icons.inventory_2_outlined),
          _PageEntry(l10n.navIssueTracking, Icons.troubleshoot_outlined),
          _PageEntry(l10n.navReportIssue,   Icons.report_problem_outlined),
          _PageEntry(l10n.navTechnician,    Icons.build_outlined),
          _PageEntry(l10n.navAnalytics,     Icons.analytics_outlined),
        ],
        onTap: onEquipmentModule,
      );

  Widget _buildSettingsCard(AppLocalizations l10n) => _HubModuleCard(
        color: AppColors.warning,
        lightColor: AppColors.warningLight,
        icon: Icons.settings_outlined,
        title: l10n.hubSettingsTitle,
        description: l10n.hubSettingsDesc,
        badgeCount: 0,
        pages: [
          _PageEntry(l10n.navSettings, Icons.tune_outlined),
          _PageEntry(l10n.navUsers,    Icons.people_outlined),
          _PageEntry(l10n.navLogs,     Icons.history_outlined),
        ],
        onTap: onSettingsModule,
      );

  Widget _buildInventoryCard(AppLocalizations l10n, int badgeCount) =>
      _HubModuleCard(
        color: AppColors.success,
        lightColor: AppColors.successLight,
        icon: Icons.archive_outlined,
        title: l10n.hubInventoryTitle,
        description: l10n.hubInventoryDesc,
        badgeCount: badgeCount,
        pages: [
          _PageEntry(l10n.navInventory, Icons.inventory_outlined),
        ],
        onTap: onInventoryModule,
      );

  // ── En-tête ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, dynamic user) {
    final l10n = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l10n.greetingMorning
        : hour < 18
            ? l10n.greetingAfternoon
            : l10n.greetingEvening;
    final firstName = (user?.firstName?.isNotEmpty == true)
        ? user!.firstName
        : (user?.name ?? l10n.user);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Image.asset(
              'assets/images/logo_hopital.png',
              height: 42,
              width: 42,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.hospitalName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '$greeting, $firstName',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined,
                color: AppColors.textSecondary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
            ),
            tooltip: l10n.tooltipAccountSettings,
          ),
          // ── Cloche de notifications avec badge ──────────────────────────
          ListenableBuilder(
            listenable: NotificationService(),
            builder: (ctx, _) {
              final unread = NotificationService().unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: AppColors.textSecondary),
                    tooltip: l10n.notificationsBell,
                    onPressed: () => _showNotificationsPanel(ctx, l10n),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        child: Text(
                          unread > 99 ? '99+' : unread.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            tooltip: l10n.logout,
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  final dl10n = AppLocalizations.of(ctx)!;
                  return AlertDialog(
                    title: Row(children: [
                      const Icon(Icons.logout, color: AppColors.error),
                      const SizedBox(width: 12),
                      Text(dl10n.logoutConfirmTitle),
                    ]),
                    content: Text(dl10n.logoutConfirmMessage),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(dl10n.commonCancel),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(dl10n.logout),
                      ),
                    ],
                  );
                },
              );
              if (confirmed == true && context.mounted) {
                await AuthService().logoutApi();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Panneau de notifications (bottom sheet) ───────────────────────────────────

  void _showNotificationsPanel(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (_, scrollCtrl) => Column(
          children: [
            // ── En-tête ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.notificationsBell,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      NotificationService().markAllAsRead();
                    },
                    child: Text(
                      l10n.notificationsMarkAllRead,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Liste ──────────────────────────────────────────────────────
            Expanded(
              child: ListenableBuilder(
                listenable: NotificationService(),
                builder: (context2, _) {
                  final notifs = NotificationService().all;
                  if (notifs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none_outlined,
                              size: 48,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            l10n.notificationsEmpty,
                            style: const TextStyle(
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollCtrl,
                    itemCount: notifs.length,
                    separatorBuilder: (context3, _) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) {
                      final n = notifs[i];
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (n.read
                                    ? AppColors.textSecondary
                                    : AppColors.primary)
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _notifIcon(n.type),
                            size: 18,
                            color: n.read
                                ? AppColors.textSecondary
                                : AppColors.primary,
                          ),
                        ),
                        title: Text(
                          n.title ?? n.equipmentName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: n.read
                                ? FontWeight.normal
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          n.body ?? n.department,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: n.read
                            ? null
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                        onTap: () {
                          NotificationService().markAsRead(n.id);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _notifIcon(NotificationType type) => switch (type) {
    NotificationType.newIssue        => Icons.report_problem_outlined,
    NotificationType.issueInProgress => Icons.build_outlined,
    NotificationType.issueResolved   => Icons.check_circle_outline,
    NotificationType.deptRequest     => Icons.swap_horiz_outlined,
    NotificationType.roleRequest     => Icons.badge_outlined,
  };

  // ── Pied de page version ───────────────────────────────────────────────────

  Widget _buildVersionFooter(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        l10n.appVersionLabel(ApiConfig.appVersion),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.55),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ── Utilitaire couleur urgence ─────────────────────────────────────────────

  Color _urgencyColor(IssueUrgency urgency) {
    switch (urgency) {
      case IssueUrgency.critique:
        return AppColors.error;
      case IssueUrgency.urgent:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }
}

// ── Modèle interne pour les chips de pages ─────────────────────────────────

class _PageEntry {
  final String name;
  final IconData icon;
  const _PageEntry(this.name, this.icon);
}

// ── Tuile KPI ──────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final String subtitle;
  final VoidCallback? onTap;

  const _KpiTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 17),
                  ),
                  const Spacer(),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Carte de module ────────────────────────────────────────────────────────

class _HubModuleCard extends StatelessWidget {
  final Color color;
  final Color lightColor;
  final IconData icon;
  final String title;
  final String description;
  final int badgeCount;
  final List<_PageEntry> pages;
  final VoidCallback onTap;

  const _HubModuleCard({
    required this.color,
    required this.lightColor,
    required this.icon,
    required this.title,
    required this.description,
    required this.badgeCount,
    required this.pages,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lightColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                      if (badgeCount > 0)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: color.withValues(alpha: 0.6),
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pages
                    .map(
                      (p) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: lightColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(p.icon, size: 13, color: color),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                p.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: color,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                  child: Builder(
                    builder: (ctx) => Text(
                      AppLocalizations.of(ctx)!.hubOpenModule(title),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bannière push notifications ───────────────────────────────────────────────
// Affiche un avertissement compact si les notifications push ne sont pas activées.
// Se retire automatiquement après activation réussie ou fermeture manuelle.
class _PushNotificationBanner extends StatefulWidget {
  const _PushNotificationBanner();

  @override
  State<_PushNotificationBanner> createState() => _PushNotificationBannerState();
}

class _PushNotificationBannerState extends State<_PushNotificationBanner> {
  bool _visible = false;
  bool _loading = false;
  PushEnvironment? _env;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  static const TextStyle _titleStyle =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning);
  static const TextStyle _bodyStyle = TextStyle(fontSize: 12, color: AppColors.textSecondary);

  /// Détermine si la bannière doit s'afficher à partir de l'environnement détecté.
  /// Les branches "installation requise", "non supporté" et "permission refusée"
  /// s'affichent indépendamment de l'état de la souscription (aucun re-prompt possible).
  Future<bool> _computeVisible(PushEnvironment env) async {
    if (env.variant != PushBannerVariant.promptActivate) return true;
    final active = await PushNotificationWebService().isPushActive();
    return !active;
  }

  Widget _bannerContent(String title, List<String> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: _titleStyle),
        for (final line in lines) Text(line, style: _bodyStyle),
      ],
    );
  }

  Future<void> _checkStatus() async {
    final env = await PushNotificationWebService().getEnvironment();
    final visible = await _computeVisible(env);
    if (mounted) setState(() { _env = env; _visible = visible; });
  }

  Future<void> _activate() async {
    setState(() => _loading = true);
    final ok = await PushNotificationWebService().requestAndSubscribe();
    final env = await PushNotificationWebService().getEnvironment();
    final visible = await _computeVisible(env);
    if (mounted) {
      setState(() { _env = env; _visible = visible; _loading = false; });
      if (!ok && env.permissionState == 'granted') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.pushSubscribeFailed),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _env == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final variant = _env!.variant;

    final icon =
        variant == PushBannerVariant.iosInstallGuide ? Icons.ios_share : Icons.notifications_off_outlined;

    late final Widget content;
    Widget? actionButton;

    switch (variant) {
      case PushBannerVariant.iosInstallGuide:
        content = _bannerContent(l10n.pushBannerIosInstallTitle, [
          l10n.pushBannerIosInstallStep1,
          l10n.pushBannerIosInstallStep2,
          l10n.pushBannerIosInstallStep3,
        ]);
      case PushBannerVariant.unsupported:
        content = _bannerContent(l10n.pushBannerTitle, [l10n.pushBannerUnsupported]);
      case PushBannerVariant.permissionDenied:
        content = _bannerContent(l10n.pushBannerTitle, [l10n.pushBannerPermissionDenied]);
      case PushBannerVariant.promptActivate:
        content = _bannerContent(l10n.pushBannerTitle, [l10n.pushBannerBody]);
        actionButton = _loading
            ? SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
              )
            : TextButton(
                onPressed: _activate,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l10n.pushBannerActivate,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          border: Border(bottom: BorderSide(color: AppColors.warning.withValues(alpha: 0.4))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(child: content),
            const SizedBox(width: 8),
            ?actionButton,
            IconButton(
              onPressed: () => setState(() => _visible = false),
              icon: const Icon(Icons.close, size: 16),
              color: AppColors.textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}
