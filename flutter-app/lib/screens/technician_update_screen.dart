import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/issue.dart';
import '../models/equipment.dart';
import '../models/user_role.dart';
import '../widgets/urgency_badge.dart';
import '../widgets/status_badge.dart';
import '../widgets/equipment_detail_dialog.dart';
import '../widgets/tab_label.dart';
import '../widgets/issue_validation_sheet.dart';
import 'issue_detail_screen.dart';
import 'technician_intervention_update_screen.dart';
import 'technician_schedule_screen.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

/// Espace technicien — onglets : à valider (admin/superviseur), incidents
/// disponibles, mes interventions. Le planning est sur un écran séparé.
class TechnicianUpdateScreen extends StatefulWidget {
  final String? issueId;

  const TechnicianUpdateScreen({super.key, this.issueId});

  @override
  State<TechnicianUpdateScreen> createState() => _TechnicianUpdateScreenState();
}

class _TechnicianUpdateScreenState extends State<TechnicianUpdateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Onglet "Mes interventions" ──────────────────────────────────────────────
  String  _interventionSearch = '';

  // Vrai si l'utilisateur peut valider des incidents (admin ou superviseur)
  bool _canValidate = false;

  // Index de l'onglet "Mes interventions" — dépend de la présence de "À valider"
  int get _myInterventionsIndex => _canValidate ? 2 : 1;

  // ── Getters de données ────────────────────────────────────────────────────────

  String get _currentTechnicianName => AuthService().currentUser?.fullName ?? '';

  Set<String> get _myAssignableGroups {
    final roles  = AuthService().currentRoles;
    final groups = <String>{};
    if (roles.contains(UserRole.technicianBiomedical)) groups.add('Biomédical');
    if (roles.contains(UserRole.technicianIt))         groups.add('IT');
    if (roles.contains(UserRole.technicianInfra))      groups.add('Infrastructure');
    return groups;
  }

  List<Issue> get _availableIssues {
    final myGroups = _myAssignableGroups;
    final list = DataService().issues.where((i) {
      if (i.status != IssueStatus.acknowledged && i.status != IssueStatus.assigned) {
        return false;
      }
      if (myGroups.isEmpty) return true;
      final group = i.assignedGroup;
      return group == null || myGroups.contains(group);
    }).toList();
    list.sort((a, b) => _urgencyOrder(b.urgency) - _urgencyOrder(a.urgency));
    return list;
  }

  /// Incidents disponibles regroupés par département (tri urgence interne).
  Map<String, List<Issue>> get _availableIssuesByDept {
    final result = <String, List<Issue>>{};
    for (final issue in _availableIssues) {
      final dept = issue.department.isNotEmpty ? issue.department : 'Autre';
      result.putIfAbsent(dept, () => []).add(issue);
    }
    // Trie les clés par département, puis chaque groupe par urgence décroissante
    final sorted = Map.fromEntries(
      result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return sorted;
  }

  int _urgencyOrder(IssueUrgency u) {
    switch (u) {
      case IssueUrgency.critique: return 3;
      case IssueUrgency.urgent:   return 2;
      case IssueUrgency.moyen:    return 1;
      case IssueUrgency.faible:   return 0;
    }
  }

  Equipment? _equipmentFor(Issue issue) {
    final eid = issue.equipmentId;
    if (eid == null || eid.isEmpty) return null;
    return DataService().equipment.where((e) => e.id == eid).firstOrNull;
  }

  List<Issue> get _myIssues => DataService().issues
      .where((i) =>
          i.status == IssueStatus.inProgress &&
          i.assignedTechnician == _currentTechnicianName)
      .toList();

  List<Issue> get _filteredIssues {
    final query  = _interventionSearch.toLowerCase();
    final issues = _myIssues;
    if (query.isEmpty) return issues;
    return issues.where((i) =>
        i.displayName.toLowerCase().contains(query) ||
        i.description.toLowerCase().contains(query) ||
        i.department.toLowerCase().contains(query)  ||
        i.type.toLowerCase().contains(query),
    ).toList();
  }

  // ── Init / Dispose ──────────────────────────────────────────────────────────

  // ── Incidents en attente de validation (statut 'reported') ─────────────────

  List<Issue> get _openIssuesForValidation {
    final roles   = AuthService().currentRoles;
    final allOpen = DataService().issues
        .where((i) => i.status == IssueStatus.reported)
        .toList();
    if (roles.contains(UserRole.admin)) return allOpen;
    if (roles.contains(UserRole.supervisor)) {
      final dept = AuthService().currentUser?.department ?? '';
      return allOpen.where((i) => i.department == dept).toList();
    }
    // Technicien avec droit de validation : limité aux incidents de son/ses groupe(s)
    final myGroups = _myAssignableGroups;
    if (myGroups.isNotEmpty) {
      return allOpen.where((i) {
        final group = i.assignedGroup;
        return group == null || myGroups.contains(group);
      }).toList();
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    // Détermine si l'utilisateur a le droit de valider des incidents
    _canValidate = AuthService().canApproveRequests;
    // Onglets : [À valider?, Disponibles, Mes interventions]
    final tabCount = _canValidate ? 3 : 2;
    // Deep-link incident → on atterrit sur "Mes interventions" (dernier onglet)
    final startTab = widget.issueId != null ? _myInterventionsIndex : 0;
    _tabController = TabController(length: tabCount, vsync: this, initialIndex: startTab);
    if (widget.issueId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openIssueUpdateScreen(widget.issueId!),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Ouverture de la page de mise à jour d'un incident ───────────────────────

  void _openIssueUpdateScreen(String issueId) {
    final issue = DataService().issues.where((i) => i.id == issueId).firstOrNull;
    if (issue == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TechnicianInterventionUpdateScreen(issue: issue)),
    );
  }

  // ── Build principal ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n      = AppLocalizations.of(context)!;
    final isDesktop = MediaQuery.of(context).size.width >= AppBreakpoints.desktop;

    // Sur mobile (< 600px), icônes seules pour éviter l'overflow du TabBar
    final isMobileTab = MediaQuery.of(context).size.width < AppBreakpoints.tablet;

    return Column(
      children: [
        // TabBar : icône + texte sur desktop, icône seule sur mobile.
        // Le bouton calendrier (planning) est à droite, hors des onglets.
        Material(
          color: Theme.of(context).cardColor,
          elevation: 1,
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  tabs: [
                    // Onglet Validation — visible uniquement pour admin/superviseur
                    if (_canValidate)
                      Tab(
                        height: 40,
                        child: TabLabel(
                          isMobile: isMobileTab,
                          icon: Icons.pending_actions_outlined,
                          label: l10n.issueValidationTab,
                          badgeCount: _openIssuesForValidation.length,
                        ),
                      ),
                    Tab(
                      height: 40,
                      child: TabLabel(
                        isMobile: isMobileTab,
                        icon: Icons.inbox_outlined,
                        label: l10n.techAvailableTab,
                        badgeCount: _availableIssues.length,
                      ),
                    ),
                    Tab(
                      height: 40,
                      child: TabLabel(
                        isMobile: isMobileTab,
                        icon: Icons.build_outlined,
                        label: l10n.techMyInterventionsTab,
                        badgeCount: _myIssues.length,
                      ),
                    ),
                  ],
                ),
              ),
              // Bouton planning — accessible quelle que soit la config d'onglets
              IconButton(
                icon: const Icon(Icons.calendar_today_outlined),
                color: AppColors.textSecondary,
                tooltip: l10n.techScheduleTab,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TechnicianScheduleScreen()),
                ),
              ),
            ],
          ),
        ),

        // ── TabBarView (même ordre que les onglets) ─────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              if (_canValidate)
                _buildValidationTab(!isDesktop),
              _buildAvailableTab(l10n, !isDesktop),
              isDesktop
                  ? _buildDesktopInterventionsTab(l10n)
                  : _buildMobileInterventionsTab(l10n),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Onglet 0 : Incidents disponibles — regroupés par département
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildAvailableTab(AppLocalizations l10n, bool isMobile) {
    final byDept = _availableIssuesByDept;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.techAvailableTitle,
              style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(l10n.techAvailableGroupedSubtitle,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            if (byDept.isEmpty)
              SizedBox(
                width: double.infinity,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: AppColors.success, size: 24),
                        const SizedBox(width: 12),
                        Text(l10n.techNoAvailableIncidents,
                            style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...byDept.entries.map((entry) {
                final dept   = entry.key;
                final issues = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── En-tête de section département ──────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_city_outlined,
                                    size: 13, color: AppColors.primary),
                                const SizedBox(width: 5),
                                Text(
                                  dept,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.techAvailableDeptCount(issues.length),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: Card(
                        child: Column(
                          children: issues
                              .map((i) => _AvailableIssueCard(
                                    issue: i,
                                    equipment: _equipmentFor(i),
                                    isMobile: isMobile,
                                    onTakeOver: () => _showTakeOverDialog(i),
                                    onViewSheet: _equipmentFor(i) != null
                                        ? () => EquipmentDetailDialog.show(context, _equipmentFor(i)!)
                                        : null,
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }


  // ─────────────────────────────────────────────────────────────────────────────
  // Onglet 1 : Mes interventions — Layout Desktop (Master-Detail)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildDesktopInterventionsTab(AppLocalizations l10n) {
    final myIssues = _myIssues;
    final filtered = _filteredIssues;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────────────────────────
          Text(l10n.techTitle,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(l10n.techSubtitle,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),

          // ── Barre de recherche ───────────────────────────────────────────
          SizedBox(
            width: 300,
            child: TextField(
              onChanged: (v) => setState(() => _interventionSearch = v),
              decoration: InputDecoration(
                hintText: l10n.techSearchHint,
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Liste des incidents (plein-écran) ────────────────────────────
          Expanded(
            child: myIssues.isEmpty
                ? _buildEmptyInterventions(l10n)
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.techNoResults,
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _buildInterventionCard(filtered[i], false, l10n),
                      ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Onglet 1 : Mes interventions — Layout Mobile (scroll vertical)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildMobileInterventionsTab(AppLocalizations l10n) {
    final myIssues = _myIssues;
    final filtered = _filteredIssues;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.techTitle,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(l10n.techSubtitle,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),

          TextField(
            onChanged: (v) => setState(() => _interventionSearch = v),
            decoration: InputDecoration(
              hintText: l10n.techSearchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          if (myIssues.isEmpty)
            _buildEmptyInterventions(l10n)
          else if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.techNoResults,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...filtered.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildInterventionCard(issue, false, l10n),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyInterventions(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(l10n.techNoCurrentInterventions,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(l10n.techFindIncidentsHint,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Carte d'intervention (shared desktop/mobile)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildInterventionCard(
      Issue issue, bool isSelected, AppLocalizations l10n) {
    final Color urgencyColor;
    switch (issue.urgency) {
      case IssueUrgency.critique:
        urgencyColor = AppColors.critical;
      case IssueUrgency.urgent:
        urgencyColor = AppColors.error;
      case IssueUrgency.moyen:
        urgencyColor = AppColors.warning;
      case IssueUrgency.faible:
        urgencyColor = AppColors.success;
    }

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TechnicianInterventionUpdateScreen(issue: issue)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.white,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : [
                  const BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 1))
                ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                      color: urgencyColor,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(issue.displayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(issue.department,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                UrgencyBadge(urgency: issue.urgency, isCompact: true),
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.check_circle,
                        size: 16, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(issue.description,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 11, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(issue.createdAt,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Dialog : Prise en charge
  // ─────────────────────────────────────────────────────────────────────────────

  void _showTakeOverDialog(Issue issue) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
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
              const SizedBox(height: 4),
              Text(issue.description,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              Text(l10n.techTakeChargeMessage,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _takeOverIssue(issue);
            },
            icon: const Icon(Icons.handyman_outlined, size: 16),
            label: Text(l10n.commonConfirm),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _takeOverIssue(Issue issue) async {
    try {
      await DbApiService.instance
          .takeOverIssue(issue.id, _currentTechnicianName);
      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
      if (!mounted) return;
      _tabController.animateTo(_myInterventionsIndex);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            AppLocalizations.of(context)!
                .techTakeChargeSuccess(issue.displayName)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.commonApiError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Onglet 3 : À valider (admin / superviseur uniquement)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildValidationTab(bool isMobile) {
    final l10n    = AppLocalizations.of(context)!;
    final issues  = _openIssuesForValidation;
    final isAdmin = AuthService().currentRoles.contains(UserRole.admin);
    final dept    = AuthService().currentUser?.department ?? '';

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.issueValidationTitle,
              style: TextStyle(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              isAdmin
                  ? l10n.issueValidationSubtitleAll
                  : l10n.issueValidationSubtitleDept(dept),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${issues.length}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error)),
                  const SizedBox(width: 8),
                  Text(l10n.issueValidationOpenCount(issues.length),
                      style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Card(
                child: issues.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppColors.success, size: 24),
                            const SizedBox(width: 12),
                            Text(l10n.issueValidationNone,
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : Column(
                        children: issues
                            .map((issue) => _buildValidationIssueItem(issue, isMobile))
                            .toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationIssueItem(Issue issue, bool isMobile) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: AppColors.error, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(issue.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(issue.department,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ]),
                ),
                IssueStatusBadge(status: issue.status.displayName),
              ]),
              const SizedBox(height: 8),
              Text(issue.description,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                l10n.issueValidationSignaledBy(issue.reporter, issue.createdAt),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              if (issue.assignedGroup != null) ...[
                const SizedBox(height: 6),
                _buildValidationGroupChip(issue.assignedGroup!),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showValidationIssueDetail(issue),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(l10n.issueValidationReview),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white),
                ),
              ),
            ])
          : Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(issue.displayName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(issue.department,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.primary)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(issue.description,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        l10n.issueValidationSignaledBy(
                            issue.reporter, issue.createdAt),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ]),
              ),
              const SizedBox(width: 16),
              IssueStatusBadge(status: issue.status.displayName),
              if (issue.assignedGroup != null) ...[
                const SizedBox(width: 8),
                _buildValidationGroupChip(issue.assignedGroup!),
              ],
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showValidationIssueDetail(issue),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: Text(l10n.issueValidationReview),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
              ),
            ]),
    );
  }

  // Ouvre le sheet de validation rapide depuis l'onglet "À valider".
  // Valider / rejeter / réassigner se font dans le sheet (sans page de détail) :
  // on attend la fermeture puis on rafraîchit la liste.
  Future<void> _showValidationIssueDetail(Issue issue) async {
    await showIssueValidationSheet(context, issue);
    await DataService().reloadIssues();
    if (mounted) setState(() {});
  }

  ({Color color, IconData icon, String label}) _validationGroupMeta(
      String group, AppLocalizations l10n) {
    switch (group) {
      case 'IT':
        return (
          color: const Color(0xFF1565C0),
          icon: Icons.computer,
          label: l10n.issueValidationGroupIT
        );
      case 'Infrastructure':
        return (
          color: const Color(0xFFE65100),
          icon: Icons.construction,
          label: l10n.issueValidationGroupInfrastructure
        );
      default:
        return (
          color: const Color(0xFFC62828),
          icon: Icons.medical_services,
          label: l10n.issueValidationGroupBiomedical
        );
    }
  }

  Widget _buildValidationGroupChip(String group) {
    final l10n = AppLocalizations.of(context)!;
    final meta = _validationGroupMeta(group, l10n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: meta.color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(meta.icon, size: 12, color: meta.color),
        const SizedBox(width: 4),
        Text(meta.label,
            style: TextStyle(
                fontSize: 11,
                color: meta.color,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

}

// ── Fonctions utilitaires pures — couleurs d'urgence et chips ────────────────

Color _urgencyBgColor(IssueUrgency u) {
  switch (u) {
    case IssueUrgency.critique: return AppColors.criticalLight;
    case IssueUrgency.urgent:   return AppColors.errorLight;
    case IssueUrgency.moyen:    return AppColors.warningLight;
    case IssueUrgency.faible:   return AppColors.background;
  }
}

Color _urgencyFgColor(IssueUrgency u) {
  switch (u) {
    case IssueUrgency.critique: return AppColors.critical;
    case IssueUrgency.urgent:   return AppColors.error;
    case IssueUrgency.moyen:    return AppColors.warning;
    case IssueUrgency.faible:   return AppColors.textSecondary;
  }
}

Widget _infoChip(String label, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
    );

Widget _miniChip(IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    );

// ── Widget : carte d'un incident disponible (onglet 0 du technicien) ─────────

/// Affiche un incident disponible en version mobile (colonne) ou desktop (ligne).
/// Tous les callbacks sont passés explicitement — ce widget est sans état.
class _AvailableIssueCard extends StatelessWidget {
  final Issue issue;
  final Equipment? equipment;
  final bool isMobile;
  final VoidCallback onTakeOver;
  final VoidCallback? onViewSheet;

  const _AvailableIssueCard({
    required this.issue,
    required this.isMobile,
    required this.onTakeOver,
    this.equipment,
    this.onViewSheet,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final eq   = equipment;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => IssueDetailScreen(issueId: issue.id)),
        ),
        child: isMobile ? _buildMobile(l10n, eq) : _buildDesktop(l10n, eq),
      ),
    );
  }

  Widget _buildMobile(AppLocalizations l10n, Equipment? eq) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _urgencyBgColor(issue.urgency),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.warning_amber_rounded, color: _urgencyFgColor(issue.urgency), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(issue.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(issue.department, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ),
        UrgencyBadge(urgency: issue.urgency, isCompact: true),
      ]),
      const SizedBox(height: 8),
      Text(issue.type, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text(issue.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
      if (eq != null) ...[
        const SizedBox(height: 4),
        Wrap(spacing: 8, children: [
          if (eq.category.isNotEmpty)     _miniChip(Icons.category, eq.category),
          if (eq.location.isNotEmpty)     _miniChip(Icons.location_on, eq.location),
          if (eq.serialNumber.isNotEmpty) _miniChip(Icons.qr_code, eq.serialNumber),
        ]),
      ],
      const SizedBox(height: 4),
      Text(l10n.issuesReportedByDate(issue.reporter, issue.createdAt),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      const SizedBox(height: 12),
      Row(children: [
        if (onViewSheet != null) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onViewSheet,
              icon: const Icon(Icons.info_outline, size: 14),
              label: Text(l10n.techSheet),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: onTakeOver,
            icon: const Icon(Icons.handyman_outlined, size: 16),
            label: Text(l10n.techTakeCharge),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildDesktop(AppLocalizations l10n, Equipment? eq) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _urgencyBgColor(issue.urgency),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.warning_amber_rounded, color: _urgencyFgColor(issue.urgency), size: 20),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(issue.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            _infoChip(issue.department, AppColors.primaryLight, AppColors.primary),
            const SizedBox(width: 6),
            _infoChip(issue.type, AppColors.background, AppColors.textSecondary),
            if (eq != null && eq.category.isNotEmpty) ...[
              const SizedBox(width: 6),
              _infoChip(eq.category, AppColors.successLight, AppColors.success),
            ],
          ]),
          const SizedBox(height: 4),
          Text(issue.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            Text(l10n.issuesReportedByDate(issue.reporter, issue.createdAt),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            if (eq != null && eq.location.isNotEmpty) ...[
              const SizedBox(width: 10),
              const Icon(Icons.location_on, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 2),
              Text(eq.location, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
            if (eq != null && eq.serialNumber.isNotEmpty) ...[
              const SizedBox(width: 10),
              const Icon(Icons.qr_code, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 2),
              Text(eq.serialNumber, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ]),
        ]),
      ),
      const SizedBox(width: 16),
      UrgencyBadge(urgency: issue.urgency),
      const SizedBox(width: 8),
      if (onViewSheet != null)
        OutlinedButton.icon(
          onPressed: onViewSheet,
          icon: const Icon(Icons.info_outline, size: 14),
          label: Text(l10n.techSheet),
        ),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        onPressed: onTakeOver,
        icon: const Icon(Icons.handyman_outlined, size: 16),
        label: Text(l10n.techTakeCharge),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      ),
    ]);
  }
}
