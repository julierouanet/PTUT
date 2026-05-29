import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../models/equipment.dart';
import '../models/issue.dart';
import '../models/user_role.dart';
import '../widgets/progress_bar.dart';
import '../widgets/alert_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/urgency_badge.dart';
import '../widgets/issue_category_selector.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _lastRefresh = DateTime.now();

  // Statuts "ouverts" : non terminés, non clôturés
  static const _openStatuses = {
    IssueStatus.reported,
    IssueStatus.acknowledged,
    IssueStatus.assigned,
    IssueStatus.inProgress,
    IssueStatus.waitingMaterials,
    IssueStatus.redirected,
  };

  // Déclenche un rechargement API puis met à jour le timestamp de fraîcheur
  Future<void> _refresh() async {
    await Future.wait([
      DataService().reloadEquipment(),
      DataService().reloadIssues(),
    ]);
    if (mounted) setState(() => _lastRefresh = DateTime.now());
  }

  // Libellé de fraîcheur selon l'ancienneté de _lastRefresh
  String _freshnessLabel(AppLocalizations l10n) {
    final diff = DateTime.now().difference(_lastRefresh);
    if (diff.inSeconds < 60) return l10n.dashboardRefreshedJustNow;
    if (diff.inMinutes < 60) return l10n.dashboardRefreshedAgo(diff.inMinutes);
    final h = _lastRefresh.hour.toString().padLeft(2, '0');
    final m = _lastRefresh.minute.toString().padLeft(2, '0');
    return l10n.dashboardRefreshedAt('$h:$m');
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

    // Rôle principal : détermine la vue affichée
    final role = auth.primaryRole;
    final isStaffOnly = role == UserRole.hospitalStaff;
    final isTechOrMore = role == UserRole.technicianBiomedical ||
        role == UserRole.technicianIt ||
        role == UserRole.technicianInfra ||
        role == UserRole.technician ||
        role == UserRole.supervisor ||
        role == UserRole.admin;

    // ── KPIs équipements ────────────────────────────────────────────────────
    final allEquip = DataService().equipment;
    final total        = allEquip.length;
    final operational  = allEquip.where((e) => e.status == EquipmentStatus.operational).length;
    final maintenance  = allEquip.where((e) => e.status == EquipmentStatus.maintenance).length;
    final outOfService = allEquip.where((e) => e.status == EquipmentStatus.outOfService).length;

    // PM en retard : preventiveMaintenanceAlertLevel == 'due' signifie nextPreventiveMaintenance < aujourd'hui
    final pmOverdue = allEquip.where((e) => e.preventiveMaintenanceAlertLevel == 'due').length;

    // ── Incidents prioritaires ──────────────────────────────────────────────
    // Tri : urgence décroissante (critique=3 > urgent=2 > moyen=1 > faible=0),
    // puis date décroissante (plus récent en premier si urgences égales)
    final openIssues = DataService().issues.where((i) => _openStatuses.contains(i.status)).toList();
    openIssues.sort((a, b) {
      final byUrgency = b.urgency.index.compareTo(a.urgency.index);
      if (byUrgency != 0) return byUrgency;
      return b.createdAt.compareTo(a.createdAt);
    });
    final priorityIssues = openIssues.take(4).toList();

    // ── Alertes urgentes ────────────────────────────────────────────────────
    // 1. Équipements hors service
    final criticalEquipment = allEquip.where((e) => e.status == EquipmentStatus.outOfService).toList();

    // 2. Incidents critiques ou urgents ouverts depuis plus de 24h
    final now = DateTime.now();
    final criticalIssueAlerts = DataService().issues.where((i) {
      if (i.urgency != IssueUrgency.critique && i.urgency != IssueUrgency.urgent) return false;
      if (!_openStatuses.contains(i.status)) return false;
      final dt = DateTime.tryParse(i.createdAt);
      if (dt == null) return false;
      return now.difference(dt).inHours >= 24;
    }).toList();

    // ── Métriques opérationnelles (technicien/superviseur/admin) ────────────
    // Équipements critiques (criticité A) hors service
    final criticalOos = allEquip
        .where((e) => e.status == EquipmentStatus.outOfService && e.criticality == EquipmentCriticality.a)
        .toList();

    // Groupe technique de l'utilisateur connecté (pour filtrer le backlog)
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

    // Backlog : incidents actifs filtrés par groupe si technicien spécialisé,
    // sinon tous les incidents actifs (superviseur/admin)
    final backlog = DataService().issues.where((i) {
      if (!_openStatuses.contains(i.status)) return false;
      if (techGroup != null && i.assignedGroup != null) {
        return i.assignedGroup!.toLowerCase() == techGroup.toLowerCase();
      }
      return true;
    }).length;

    // ── Breakpoints layout ──────────────────────────────────────────────────
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile    = screenWidth < 600;
    final isDesktop   = screenWidth >= 800;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête + indicateur de fraîcheur ─────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      l10n.dashboardSubtitle,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Bouton actualiser + timestamp discret
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Boutons d'action rapide ────────────────────────────────────
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
              // Bouton "Voir les incidents" : masqué pour le simple personnel hospitalier
              if (!isStaffOnly)
                ElevatedButton.icon(
                  onPressed: () => widget.onNavigate(2),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: Text(l10n.dashboardViewIssues),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ── StatCards (5ème carte = PM en retard) ─────────────────────
          if (isMobile) ...[
            Row(children: [
              Expanded(child: _buildStatCard(l10n.dashboardTotal, '$total', Icons.inventory_2_outlined, AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(l10n.dashboardOperational, '$operational', Icons.check_circle_outline, AppColors.success)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _buildStatCard(l10n.dashboardMaintenance, '$maintenance', Icons.build_outlined, AppColors.warning)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(l10n.dashboardOutOfService, '$outOfService', Icons.cancel_outlined, AppColors.error)),
            ]),
            const SizedBox(height: 12),
            // PM en retard : pleine largeur en mobile, couleur rouge si non nul
            _buildStatCard(
              l10n.dashboardPmOverdue,
              '$pmOverdue',
              Icons.event_busy_outlined,
              pmOverdue > 0 ? AppColors.error : AppColors.textSecondary,
            ),
          ] else
            Row(children: [
              Expanded(child: _buildStatCard(l10n.dashboardTotal, '$total', Icons.inventory_2_outlined, AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(l10n.dashboardOperational, '$operational', Icons.check_circle_outline, AppColors.success)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(l10n.dashboardMaintenance, '$maintenance', Icons.build_outlined, AppColors.warning)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(l10n.dashboardOutOfService, '$outOfService', Icons.cancel_outlined, AppColors.error)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  l10n.dashboardPmOverdue,
                  '$pmOverdue',
                  Icons.event_busy_outlined,
                  pmOverdue > 0 ? AppColors.error : AppColors.textSecondary,
                ),
              ),
            ]),
          const SizedBox(height: 24),

          // ── Barre de progression statut équipements ────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dashboardEquipmentStatus,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LabeledProgressBar(label: l10n.dashboardOperationalStatus, current: operational, total: total, color: AppColors.success),
                  const SizedBox(height: 12),
                  LabeledProgressBar(label: l10n.dashboardInMaintenance, current: maintenance, total: total, color: AppColors.warning),
                  const SizedBox(height: 12),
                  LabeledProgressBar(label: l10n.dashboardOutOfServiceStatus, current: outOfService, total: total, color: AppColors.error),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Indicateurs opérationnels — visible uniquement pour les techniciens,
          //    superviseurs et admins ──────────────────────────────────────
          if (isTechOrMore) ...[
            _buildTechMetrics(l10n, backlog, criticalOos.length, techGroup),
            const SizedBox(height: 24),
          ],

          // ── Section principale : incidents prioritaires + alertes + panel
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colonne gauche : incidents prioritaires (plus large)
                Expanded(
                  flex: 2,
                  child: _buildPriorityIssues(l10n, priorityIssues),
                ),
                const SizedBox(width: 24),
                // Colonne centrale : alertes urgentes
                Expanded(
                  flex: 2,
                  child: _buildUrgentAlerts(l10n, criticalEquipment, criticalIssueAlerts),
                ),
                // Colonne droite : panel équipements critiques (technicien/admin/superviseur uniquement)
                if (isTechOrMore) ...[
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: _buildCriticalPanel(l10n, criticalOos),
                  ),
                ],
              ],
            )
          else
            Column(
              children: [
                _buildPriorityIssues(l10n, priorityIssues),
                const SizedBox(height: 24),
                _buildUrgentAlerts(l10n, criticalEquipment, criticalIssueAlerts),
                if (isTechOrMore) ...[
                  const SizedBox(height: 24),
                  _buildCriticalPanel(l10n, criticalOos),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // ── Widget helpers ──────────────────────────────────────────────────────────

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
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
              Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }

  // Section incidents prioritaires :
  // Tri par urgence décroissante (critique > urgent > moyen > faible),
  // puis par date décroissante à urgence égale.
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
      trailing: IssueStatusBadge(status: issue.status.displayName),
    );
  }

  // Section alertes urgentes :
  // - Équipements hors service (tous)
  // - Incidents urgents/critiques ouverts depuis plus de 24 heures
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
            // Équipements hors service
            ...criticalEquipment.map((eq) => AlertCard(
                  title: l10n.dashboardCriticalFailure,
                  message: '${eq.name} — ${eq.department}',
                  severity: AlertSeverity.critical,
                )),
            // Incidents critiques/urgents >24h
            ...criticalIssues.map((issue) => AlertCard(
                  title: l10n.dashboardCriticalIssue24h,
                  message: '${issue.displayName} — ${issue.urgency.localizedName(l10n)}',
                  severity: AlertSeverity.critical,
                )),
          ],
        ]),
      ),
    );
  }

  // Indicateurs opérationnels pour techniciens, superviseurs et admins
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
                // Affiche le groupe si l'utilisateur est un technicien spécialisé
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
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
              ),
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
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          eq.department,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
