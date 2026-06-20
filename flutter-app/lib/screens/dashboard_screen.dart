import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/db_api_service.dart';
import '../services/notification_service.dart';
import '../services/equipment_filter_state.dart';
import '../models/equipment.dart';
import '../models/issue.dart';
import '../models/user_role.dart';
import '../widgets/progress_bar.dart';
import '../widgets/alert_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/urgency_badge.dart';
import '../widgets/issue_category_selector.dart';
import 'equipment_detail_screen.dart';
import 'issue_detail_screen.dart';
class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _lastRefresh = DateTime.now();
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  // Statuts "ouverts" : non terminés, non clôturés
  static const _openStatuses = {
    IssueStatus.reported,
    IssueStatus.acknowledged,
    IssueStatus.assigned,
    IssueStatus.inProgress,
    IssueStatus.waitingMaterials,
    IssueStatus.redirected,
  };

  @override
  void initState() {
    super.initState();
    // Auto-refresh silencieux toutes les 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    await Future.wait([
      DataService().reloadEquipment(),
      DataService().reloadIssues(),
    ]);
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _lastRefresh = DateTime.now();
      });
    }
  }

  String _freshnessLabel(AppLocalizations l10n) {
    final diff = DateTime.now().difference(_lastRefresh);
    if (diff.inSeconds < 60) return l10n.dashboardRefreshedJustNow;
    if (diff.inMinutes < 60) return l10n.dashboardRefreshedAgo(diff.inMinutes);
    final h = _lastRefresh.hour.toString().padLeft(2, '0');
    final m = _lastRefresh.minute.toString().padLeft(2, '0');
    return l10n.dashboardRefreshedAt('$h:$m');
  }

  // Retourne la macroCategory filtrée pour les rôles techniciens spécialisés.
  // Null = pas de filtre (admin, superviseur, staff, technician générique).
  static String? _macroCategoryForRole(UserRole? role) => switch (role) {
    UserRole.technicianBiomedical => 'Biomedical',
    UserRole.technicianIt         => 'IT',
    UserRole.technicianInfra      => 'Infrastructure',
    _                             => null,
  };

  // Navigation vers EquipmentListScreen avec filtres pré-appliqués depuis une StatCard.
  // Passe par widget.onNavigate pour rester dans le MainScaffold (sidebar conservée).
  void _navigateToEquipList({EquipmentStatus? status, bool pmOverdue = false}) {
    final macroCategory = _macroCategoryForRole(AuthService().primaryRole);

    // Pré-remplir le singleton de filtres — lu par EquipmentListScreen.initState
    final fs = EquipmentFilterState();
    fs.reset();
    if (status != null) fs.statusFilter = status.displayName;
    if (pmOverdue) fs.filterPmOverdue = true;
    if (macroCategory != null) fs.macroCategoryFilter = macroCategory;

    // ScreenType.equipment = index 1
    widget.onNavigate(1);
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder réagit aux notifyListeners() de DataService (chargements API)
    return ListenableBuilder(
      listenable: DataService(),
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = AuthService();
    final role = auth.primaryRole;

    // ── Scope technicien ────────────────────────────────────────────────────
    // Filtre macroCategory pour les techniciens spécialisés (null = tous)
    final techMacroCategory = _macroCategoryForRole(role);
    final allEquip = DataService().equipment;
    final scopedEquip = techMacroCategory != null
        ? allEquip.where((e) => e.hasMacroCategory(techMacroCategory)).toList()
        : allEquip;

    // ── KPIs sur le périmètre scopé ─────────────────────────────────────────
    final total        = scopedEquip.length;
    final operational  = scopedEquip.where((e) => e.status == EquipmentStatus.operational).length;
    final maintenance  = scopedEquip.where((e) => e.status == EquipmentStatus.maintenance).length;
    final outOfService = scopedEquip.where((e) => e.status == EquipmentStatus.outOfService).length;
    final pmOverdue    = scopedEquip.where((e) => e.preventiveMaintenanceAlertLevel == 'due').length;

    // ── Incidents prioritaires ──────────────────────────────────────────────
    final openIssues = DataService().issues.where((i) => _openStatuses.contains(i.status)).toList();
    openIssues.sort((a, b) {
      final byUrgency = b.urgency.index.compareTo(a.urgency.index);
      if (byUrgency != 0) return byUrgency;
      return b.createdAt.compareTo(a.createdAt);
    });
    final priorityIssues = openIssues.take(4).toList();

    // ── Alertes urgentes ────────────────────────────────────────────────────
    final criticalEquipment = allEquip.where((e) => e.status == EquipmentStatus.outOfService).toList();
    final now = DateTime.now();
    final criticalIssueAlerts = DataService().issues.where((i) {
      if (i.urgency != IssueUrgency.critique && i.urgency != IssueUrgency.urgent) return false;
      if (!_openStatuses.contains(i.status)) return false;
      final dt = DateTime.tryParse(i.createdAt);
      return dt != null && now.difference(dt).inHours >= 24;
    }).toList();

    // Incidents critiques/urgents ouverts (pour la météo staff)
    final criticalOpenCount = DataService().issues.where((i) {
      if (i.urgency != IssueUrgency.critique && i.urgency != IssueUrgency.urgent) return false;
      return _openStatuses.contains(i.status);
    }).length;

    // ── Groupe tech et backlog ──────────────────────────────────────────────
    String? techGroup;
    final user = auth.currentUser;
    if (user != null) {
      if (user.hasRole(UserRole.technicianBiomedical)) {
        techGroup = 'Biomedical';
      } else if (user.hasRole(UserRole.technicianIt)) {
        techGroup = 'IT';
      } else if (user.hasRole(UserRole.technicianInfra)) {
        techGroup = 'Infrastructure';
      }
    }

    final myBacklogIssues = DataService().issues.where((i) {
      if (!_openStatuses.contains(i.status)) return false;
      if (techGroup != null && i.assignedGroup != null) {
        return i.assignedGroup!.toLowerCase() == techGroup.toLowerCase();
      }
      return techGroup == null;
    }).toList();
    final backlog = myBacklogIssues.length;

    // PM à faire (due ou imminente <7j) dans le périmètre scopé
    final pmMyDue = scopedEquip.where((e) {
      final lvl = e.preventiveMaintenanceAlertLevel;
      return lvl == 'due' || lvl == 'soon';
    }).length;

    // Équipements criticité A hors service dans le périmètre scopé
    final criticalOos = scopedEquip
        .where((e) => e.status == EquipmentStatus.outOfService && e.criticality == EquipmentCriticality.a)
        .toList();

    // ── Breakpoints layout ──────────────────────────────────────────────────
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile  = screenWidth < 600;
    final isDesktop = screenWidth >= 800;

    // ── Routing par rôle ────────────────────────────────────────────────────
    final isTechRole = role == UserRole.technicianBiomedical ||
        role == UserRole.technicianIt ||
        role == UserRole.technicianInfra ||
        role == UserRole.technician;
    final isStaffRole = role == UserRole.hospitalStaff;

    Widget body;
    if (isStaffRole) {
      body = _buildStaffView(l10n, isMobile, criticalEquipment.length, criticalOpenCount);
    } else if (isTechRole) {
      body = _buildTechView(
        l10n: l10n,
        isMobile: isMobile,
        isDesktop: isDesktop,
        total: total,
        operational: operational,
        maintenance: maintenance,
        outOfService: outOfService,
        pmOverdue: pmOverdue,
        backlog: backlog,
        pmMyDue: pmMyDue,
        techMacroCategory: techMacroCategory,
        topBacklogIssues: myBacklogIssues.take(3).toList(),
        priorityIssues: priorityIssues,
        criticalOos: criticalOos,
      );
    } else {
      body = _buildAdminView(
        l10n: l10n,
        isMobile: isMobile,
        isDesktop: isDesktop,
        total: total,
        operational: operational,
        maintenance: maintenance,
        outOfService: outOfService,
        pmOverdue: pmOverdue,
        backlog: backlog,
        criticalOos: criticalOos,
        priorityIssues: priorityIssues,
        criticalEquipment: criticalEquipment,
        criticalIssueAlerts: criticalIssueAlerts,
        techGroup: techGroup,
      );
    }

    // Indicateur de refresh en cours : barre fine de 2px en position absolue
    return Stack(
      children: [
        body,
        if (_isRefreshing)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }

  // ── Vue Personnel Soignant (hospitalStaff) ─────────────────────────────────
  // Uniquement : widget "Météo de l'hôpital" + bouton "Signaler un incident"

  Widget _buildStaffView(
    AppLocalizations l10n,
    bool isMobile,
    int oosCount,
    int criticalCount,
  ) {
    final hasAlert = oosCount > 0 || criticalCount > 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              l10n.dashboardTitle,
              style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              color: AppColors.textSecondary,
              tooltip: l10n.dashboardRefreshTooltip,
              onPressed: _refresh,
            ),
          ]),
          Text(
            _freshnessLabel(l10n),
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          // Widget Météo de l'hôpital
          Card(
            elevation: 0,
            color: hasAlert
                ? AppColors.error.withValues(alpha: 0.05)
                : AppColors.success.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: hasAlert
                    ? AppColors.error.withValues(alpha: 0.3)
                    : AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(
                    hasAlert ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    color: hasAlert ? AppColors.error : AppColors.success,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.dashboardWeatherTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                if (!hasAlert)
                  Text(
                    l10n.dashboardWeatherAllGood,
                    style: const TextStyle(color: AppColors.success, fontSize: 15),
                  ),
                if (criticalCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.report_problem_outlined, size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.dashboardWeatherCriticalCount(criticalCount),
                          style: const TextStyle(color: AppColors.error, fontSize: 15),
                        ),
                      ),
                    ]),
                  ),
                if (oosCount > 0)
                  Row(children: [
                    const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.dashboardWeatherOosCount(oosCount),
                        style: const TextStyle(color: AppColors.error, fontSize: 15),
                      ),
                    ),
                  ]),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          // Bouton massif "Signaler un incident"
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => showIssueCategorySelector(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.report_problem_outlined, size: 22),
              label: Text(
                l10n.dashboardWeatherReportBtn,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Vue Technicien ─────────────────────────────────────────────────────────
  // KPIs scopés par périmètre + Mes tâches du jour + incidents prioritaires

  Widget _buildTechView({
    required AppLocalizations l10n,
    required bool isMobile,
    required bool isDesktop,
    required int total,
    required int operational,
    required int maintenance,
    required int outOfService,
    required int pmOverdue,
    required int backlog,
    required int pmMyDue,
    required String? techMacroCategory,
    required List<Issue> topBacklogIssues,
    required List<Issue> priorityIssues,
    required List<Equipment> criticalOos,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // En-tête avec scope
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                l10n.dashboardTitle,
                style: TextStyle(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                techMacroCategory != null
                    ? l10n.dashboardScopedTo(techMacroCategory)
                    : l10n.dashboardSubtitle,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              color: AppColors.textSecondary,
              tooltip: l10n.dashboardRefreshTooltip,
              onPressed: _refresh,
            ),
            Text(
              _freshnessLabel(l10n),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ]),
        ]),
        const SizedBox(height: 16),

        // Bouton signaler
        ElevatedButton.icon(
          onPressed: () => showIssueCategorySelector(context),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
          icon: const Icon(Icons.report_problem_outlined, size: 18),
          label: Text(l10n.dashboardReportProblem),
        ),
        const SizedBox(height: 24),

        // StatCards scopées et interactives
        _buildStatCards(l10n, isMobile, total, operational, maintenance, outOfService, pmOverdue),
        const SizedBox(height: 24),

        // Mes tâches du jour
        _buildMyTasksSection(l10n, backlog, pmMyDue, topBacklogIssues),
        const SizedBox(height: 24),

        // Incidents prioritaires + panel critique (desktop = côte à côte)
        if (isDesktop)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: _buildPriorityIssues(l10n, priorityIssues)),
            if (criticalOos.isNotEmpty) ...[
              const SizedBox(width: 24),
              Expanded(flex: 1, child: _buildCriticalPanel(l10n, criticalOos)),
            ],
          ])
        else
          Column(children: [
            _buildPriorityIssues(l10n, priorityIssues),
            if (criticalOos.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildCriticalPanel(l10n, criticalOos),
            ],
          ]),
      ]),
    );
  }

  // ── Vue Admin / Superviseur ────────────────────────────────────────────────
  // Vue globale complète : toutes les sections, KPIs non filtrés

  Widget _buildAdminView({
    required AppLocalizations l10n,
    required bool isMobile,
    required bool isDesktop,
    required int total,
    required int operational,
    required int maintenance,
    required int outOfService,
    required int pmOverdue,
    required int backlog,
    required List<Equipment> criticalOos,
    required List<Issue> priorityIssues,
    required List<Equipment> criticalEquipment,
    required List<Issue> criticalIssueAlerts,
    required String? techGroup,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // En-tête + indicateur de fraîcheur
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                l10n.dashboardTitle,
                style: TextStyle(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(l10n.dashboardSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              color: AppColors.textSecondary,
              tooltip: l10n.dashboardRefreshTooltip,
              onPressed: _refresh,
            ),
            Text(
              _freshnessLabel(l10n),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ]),
        ]),
        const SizedBox(height: 16),

        // Boutons d'action rapide
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate(1),
              icon: const Icon(Icons.inventory_2, size: 18),
              label: Text(l10n.dashboardViewEquipment),
            ),
            ElevatedButton.icon(
              onPressed: () => showIssueCategorySelector(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              icon: const Icon(Icons.report_problem_outlined, size: 18),
              label: Text(l10n.dashboardReportProblem),
            ),
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate(2),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              icon: const Icon(Icons.list_alt, size: 18),
              label: Text(l10n.dashboardViewIssues),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // StatCards interactives (scope global pour admin)
        _buildStatCards(l10n, isMobile, total, operational, maintenance, outOfService, pmOverdue),
        const SizedBox(height: 24),

        // Barre de progression statut équipements
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                l10n.dashboardEquipmentStatus,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              LabeledProgressBar(
                  label: l10n.dashboardOperationalStatus,
                  current: operational,
                  total: total,
                  color: AppColors.success),
              const SizedBox(height: 12),
              LabeledProgressBar(
                  label: l10n.dashboardInMaintenance,
                  current: maintenance,
                  total: total,
                  color: AppColors.warning),
              const SizedBox(height: 12),
              LabeledProgressBar(
                  label: l10n.dashboardOutOfServiceStatus,
                  current: outOfService,
                  total: total,
                  color: AppColors.error),
            ]),
          ),
        ),
        const SizedBox(height: 24),

        // Indicateurs opérationnels (backlog global + critiques HS)
        _buildTechMetrics(l10n, backlog, criticalOos.length, techGroup),
        const SizedBox(height: 24),

        // Incidents + alertes + panel critique (desktop = 3 colonnes)
        if (isDesktop)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: _buildPriorityIssues(l10n, priorityIssues)),
            const SizedBox(width: 24),
            Expanded(flex: 2, child: _buildUrgentAlerts(l10n, criticalEquipment, criticalIssueAlerts)),
            const SizedBox(width: 24),
            Expanded(flex: 1, child: _buildCriticalPanel(l10n, criticalOos)),
          ])
        else
          Column(children: [
            _buildPriorityIssues(l10n, priorityIssues),
            const SizedBox(height: 24),
            _buildUrgentAlerts(l10n, criticalEquipment, criticalIssueAlerts),
            const SizedBox(height: 24),
            _buildCriticalPanel(l10n, criticalOos),
          ]),
      ]),
    );
  }

  // ── Grille de StatCards interactive (partagée tech + admin) ───────────────

  Widget _buildStatCards(
    AppLocalizations l10n,
    bool isMobile,
    int total,
    int operational,
    int maintenance,
    int outOfService,
    int pmOverdue,
  ) {
    if (isMobile) {
      return Column(children: [
        Row(children: [
          Expanded(
            child: _buildStatCard(
              l10n.dashboardTotal, '$total',
              Icons.inventory_2_outlined, AppColors.primary,
              onTap: () => _navigateToEquipList(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              l10n.dashboardOperational, '$operational',
              Icons.check_circle_outline, AppColors.success,
              onTap: () => _navigateToEquipList(status: EquipmentStatus.operational),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _buildStatCard(
              l10n.dashboardMaintenance, '$maintenance',
              Icons.build_outlined, AppColors.warning,
              onTap: () => _navigateToEquipList(status: EquipmentStatus.maintenance),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              l10n.dashboardOutOfService, '$outOfService',
              Icons.cancel_outlined, AppColors.error,
              onTap: () => _navigateToEquipList(status: EquipmentStatus.outOfService),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // PM en retard : pleine largeur en mobile, couleur rouge si non nul
        _buildStatCard(
          l10n.dashboardPmOverdue, '$pmOverdue',
          Icons.event_busy_outlined,
          pmOverdue > 0 ? AppColors.error : AppColors.textSecondary,
          onTap: pmOverdue > 0 ? () => _navigateToEquipList(pmOverdue: true) : null,
        ),
      ]);
    }

    return Row(children: [
      Expanded(
        child: _buildStatCard(
          l10n.dashboardTotal, '$total',
          Icons.inventory_2_outlined, AppColors.primary,
          onTap: () => _navigateToEquipList(),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _buildStatCard(
          l10n.dashboardOperational, '$operational',
          Icons.check_circle_outline, AppColors.success,
          onTap: () => _navigateToEquipList(status: EquipmentStatus.operational),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _buildStatCard(
          l10n.dashboardMaintenance, '$maintenance',
          Icons.build_outlined, AppColors.warning,
          onTap: () => _navigateToEquipList(status: EquipmentStatus.maintenance),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _buildStatCard(
          l10n.dashboardOutOfService, '$outOfService',
          Icons.cancel_outlined, AppColors.error,
          onTap: () => _navigateToEquipList(status: EquipmentStatus.outOfService),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _buildStatCard(
          l10n.dashboardPmOverdue, '$pmOverdue',
          Icons.event_busy_outlined,
          pmOverdue > 0 ? AppColors.error : AppColors.textSecondary,
          onTap: pmOverdue > 0 ? () => _navigateToEquipList(pmOverdue: true) : null,
        ),
      ),
    ]);
  }

  // ── Widget "Mes tâches du jour" (vue technicien) ───────────────────────────

  Widget _buildMyTasksSection(
    AppLocalizations l10n,
    int backlog,
    int pmMyDue,
    List<Issue> topIssues,
  ) {
    final hasWork = backlog > 0 || pmMyDue > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.assignment_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              l10n.dashboardMyTasksTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (!hasWork)
            Text(
              l10n.dashboardMyTasksNoTasks,
              style: const TextStyle(color: AppColors.textSecondary),
            )
          else ...[
            Row(children: [
              if (backlog > 0)
                Expanded(
                  child: _buildMetricTile(
                    label: l10n.dashboardTechBacklogLabel,
                    value: '$backlog',
                    icon: Icons.inbox_outlined,
                    color: AppColors.warning,
                  ),
                ),
              if (backlog > 0 && pmMyDue > 0) const SizedBox(width: 12),
              if (pmMyDue > 0)
                Expanded(
                  child: _buildMetricTile(
                    label: l10n.dashboardMyTasksPmDue,
                    value: '$pmMyDue',
                    icon: Icons.event_busy_outlined,
                    color: AppColors.error,
                  ),
                ),
            ]),
            if (topIssues.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              ...topIssues.map((issue) => _buildIssueRow(l10n, issue)),
            ],
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => widget.onNavigate(2),
              child: Text(l10n.dashboardMyTasksViewIssues),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Widget helpers ──────────────────────────────────────────────────────────

  // Stat card avec support onTap (InkWell + flèche discrète si tappable)
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Card(
      clipBehavior: onTap != null ? Clip.hardEdge : Clip.none,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value,
                    style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(title,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ]),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }

  Widget _buildPriorityIssues(AppLocalizations l10n, List<Issue> issues) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.priority_high, size: 18, color: AppColors.error),
            const SizedBox(width: 8),
            Text(
              l10n.dashboardPriorityIssues,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (issues.isEmpty)
            Text(l10n.dashboardNoIssues, style: const TextStyle(color: AppColors.textSecondary))
          else
            ...issues.map((issue) => _buildIssueRow(l10n, issue)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => widget.onNavigate(2),
              child: Text(l10n.dashboardViewAllIssues),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildIssueRow(AppLocalizations l10n, Issue issue) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(4),
        child: UrgencyBadge(urgency: issue.urgency, isCompact: true),
      ),
      title: Text(
        issue.displayName,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        issue.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IssueStatusBadge(status: issue.status.displayName),
          // Action rapide « Prendre en charge » réservée au technicien éligible.
          if (_canTakeOver(issue))
            IconButton(
              tooltip: l10n.techTakeCharge,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.handyman_outlined,
                  size: 18, color: AppColors.primary),
              onPressed: () => _quickTakeOver(issue),
            ),
        ],
      ),
    );
  }

  // ── Action rapide « Prendre en charge » (technicien) ─────────────────────

  /// Groupes assignables selon les rôles techniciens de l'utilisateur courant.
  /// Réplique de [_myAssignableGroups] de l'écran technicien.
  Set<String> _assignableGroups() {
    final roles  = AuthService().currentRoles;
    final groups = <String>{};
    if (roles.contains(UserRole.technicianBiomedical)) groups.add('Biomédical');
    if (roles.contains(UserRole.technicianIt))         groups.add('IT');
    if (roles.contains(UserRole.technicianInfra))      groups.add('Infrastructure');
    return groups;
  }

  /// Vrai si l'incident est éligible à une prise en charge rapide par
  /// l'utilisateur courant (technicien d'un groupe compatible).
  bool _canTakeOver(Issue i) {
    final groups = _assignableGroups();
    return (i.status == IssueStatus.acknowledged ||
            i.status == IssueStatus.assigned) &&
        groups.isNotEmpty &&
        (i.assignedGroup == null || groups.contains(i.assignedGroup));
  }

  Future<void> _quickTakeOver(Issue issue) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.techTakeChargeTitle),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.techTakeChargeContent),
              const SizedBox(height: 8),
              Text(issue.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(l10n.techTakeChargeMessage,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.handyman_outlined, size: 16),
            label: Text(l10n.commonConfirm),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DbApiService.instance
          .takeOverIssue(issue.id, AuthService().currentUser?.fullName ?? '');
      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.techTakeChargeSuccess(issue.displayName)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.commonApiError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _buildUrgentAlerts(
    AppLocalizations l10n,
    List<Equipment> criticalEquipment,
    List<Issue> criticalIssues,
  ) {
    final hasAlerts = criticalEquipment.isNotEmpty || criticalIssues.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
              Icons.notifications_active,
              size: 18,
              color: hasAlerts ? AppColors.error : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.dashboardUrgentAlerts,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (!hasAlerts)
            Text(l10n.dashboardNoAlerts, style: const TextStyle(color: AppColors.textSecondary))
          else ...[
            ...criticalEquipment.map((eq) => AlertCard(
                  title: l10n.dashboardCriticalFailure,
                  message: '${eq.name} — ${eq.department}',
                  severity: AlertSeverity.critical,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EquipmentDetailScreen(equipmentId: eq.id),
                    ),
                  ),
                )),
            ...criticalIssues.map((issue) => AlertCard(
                  title: l10n.dashboardCriticalIssue24h,
                  message: '${issue.displayName} — ${issue.urgency.localizedName(l10n)}',
                  severity: AlertSeverity.critical,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IssueDetailScreen(issueId: issue.id),
                    ),
                  ),
                )),
          ],
        ]),
      ),
    );
  }

  // Indicateurs opérationnels globaux (admin/superviseur)
  Widget _buildTechMetrics(
    AppLocalizations l10n,
    int backlog,
    int criticalOosCount,
    String? techGroup,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.engineering, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              l10n.dashboardTechSection,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _buildMetricTile(
                label: l10n.dashboardTechBacklogLabel,
                value: '$backlog',
                icon: Icons.inbox_outlined,
                color: backlog > 0 ? AppColors.warning : AppColors.success,
                subtitle: techGroup,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                label: l10n.dashboardTechCriticalOos,
                value: '$criticalOosCount',
                icon: Icons.dangerous_outlined,
                color: criticalOosCount > 0 ? AppColors.error : AppColors.success,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            if (subtitle != null)
              Text(subtitle,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }

  // Panel latéral desktop : liste des équipements de criticité A hors service
  Widget _buildCriticalPanel(AppLocalizations l10n, List<Equipment> criticalOos) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.emergency, size: 18, color: AppColors.critical),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.dashboardSidePanelTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 2),
          Text(
            l10n.dashboardSidePanelSubtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (criticalOos.isEmpty)
            Row(children: [
              const Icon(Icons.check_circle, size: 16, color: AppColors.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.dashboardSidePanelEmpty,
                  style: const TextStyle(color: AppColors.success, fontSize: 12),
                ),
              ),
            ])
          else
            // Maximum 8 items pour éviter un panel trop long
            ...criticalOos.take(8).map((eq) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          eq.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          eq.department,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                    ),
                  ]),
                )),
        ]),
      ),
    );
  }
}
