import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/issue.dart';
import '../models/equipment.dart';
import '../models/inventory_item.dart';
import '../models/user_role.dart';
import '../widgets/urgency_badge.dart';
import '../widgets/status_badge.dart';
import '../widgets/equipment_detail_dialog.dart';
import '../widgets/tab_label.dart';
import '../widgets/issue_validation_sheet.dart';
import 'issue_detail_screen.dart';
import 'technician_schedule_screen.dart';

// ── Modèles internes ──────────────────────────────────────────────────────────

/// Pièce sélectionnée depuis le catalogue d'inventaire.
class _SelectedPart {
  final String itemId;
  final String name;
  final String unit;
  int quantity = 1;

  _SelectedPart({
    required this.itemId,
    required this.name,
    required this.unit,
  });
}

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
  String? _selectedIssueId;
  String  _interventionSearch = '';
  String  _legacyPartsText    = ''; // pièces sauvegardées en texte libre

  // ── Formulaire ──────────────────────────────────────────────────────────────
  final _diagnosisController   = TextEditingController();
  final _actionsController     = TextEditingController();
  final _partsSearchController = TextEditingController();

  bool _isSaving      = false;
  bool _isReassigning = false;
  bool _isEscalating  = false;
  bool _isDetaching   = false;

  /// Vrai si une action API du formulaire d'intervention est en cours
  /// (désactive tous les boutons d'action pour éviter les appels concurrents).
  bool get _isBusy =>
      _isSaving || _isReassigning || _isEscalating || _isDetaching;

  // Vrai si l'utilisateur peut valider des incidents (admin ou superviseur)
  bool _canValidate = false;

  // Index de l'onglet "Mes interventions" — dépend de la présence de "À valider"
  int get _myInterventionsIndex => _canValidate ? 2 : 1;

  // ── Chronomètre d'intervention ───────────────────────────────────────────────
  Timer?    _timer;
  Duration  _elapsed             = Duration.zero;
  DateTime? _currentIssueTakenAt;

  // ── Sélection de pièces depuis l'inventaire ──────────────────────────────────
  final List<_SelectedPart> _selectedParts = [];

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

  Issue? get _selectedIssue {
    if (_selectedIssueId == null) return null;
    return DataService().issues.where((i) => i.id == _selectedIssueId).firstOrNull;
  }

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

  InventoryItem? _inventoryItemFor(String itemId) =>
      DataService().inventory.where((it) => it.id == itemId).firstOrNull;

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
        (_) => _onIssueSelected(widget.issueId!),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    _diagnosisController.dispose();
    _actionsController.dispose();
    _partsSearchController.dispose();
    super.dispose();
  }

  // ── Sélection d'un incident ──────────────────────────────────────────────────

  void _onIssueSelected(String issueId) {
    _stopTimer();
    final issue = DataService().issues.where((i) => i.id == issueId).firstOrNull;
    setState(() {
      _selectedIssueId = issueId;
      _selectedParts.clear();
      _partsSearchController.clear();
      if (issue != null) {
        _diagnosisController.text = issue.diagnosis     ?? '';
        _actionsController.text   = issue.actions       ?? '';
        _legacyPartsText          = issue.partsReplaced ?? '';
      }
    });
    // Reprend le chrono depuis taken_at persisté en DB
    if (issue != null && issue.status == IssueStatus.inProgress) {
      final takenAt = issue.takenAt != null ? DateTime.tryParse(issue.takenAt!) : null;
      _startTimer(takenAt ?? DateTime.now());
    }
  }

  void _loadIssueData() {
    final issue = DataService().issues.where((i) => i.id == _selectedIssueId).firstOrNull;
    if (issue == null) return;
    _diagnosisController.text = issue.diagnosis     ?? '';
    _actionsController.text   = issue.actions       ?? '';
    _legacyPartsText          = issue.partsReplaced ?? '';
    _selectedParts.clear();
  }

  // ── Chronomètre ─────────────────────────────────────────────────────────────

  void _startTimer(DateTime takenAt) {
    _currentIssueTakenAt = takenAt;
    _elapsed = DateTime.now().difference(takenAt);
    _timer   = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(_currentIssueTakenAt!));
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer               = null;
    _currentIssueTakenAt = null;
    _elapsed             = Duration.zero;
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── Sérialisation des pièces ─────────────────────────────────────────────────

  String _serializeParts() {
    final structured = _selectedParts
        .map((p) => '${p.name} × ${p.quantity} (${p.unit})')
        .join(', ');
    if (_legacyPartsText.isNotEmpty && structured.isEmpty) return _legacyPartsText;
    if (_legacyPartsText.isNotEmpty) return '$structured ; $_legacyPartsText';
    return structured;
  }

  List<Map<String, dynamic>> _buildPartsConsumed() => _selectedParts
      .map((p) => {'item_id': p.itemId, 'quantity': p.quantity})
      .toList();

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
          // ── En-tête + chrono ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.techTitle,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(l10n.techSubtitle,
                        style:
                            const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (_currentIssueTakenAt != null) _buildStopwatchBadge(),
            ],
          ),
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

          // ── Master-Detail ────────────────────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colonne gauche — liste des incidents (1/3)
                SizedBox(
                  width: 300,
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
                              itemBuilder: (_, i) => _buildInterventionCard(
                                  filtered[i],
                                  _selectedIssueId == filtered[i].id,
                                  l10n),
                            ),
                ),

                // Séparateur vertical
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: VerticalDivider(
                      color: AppColors.border, thickness: 1, width: 1),
                ),

                // Colonne droite — formulaire de détail (2/3)
                Expanded(
                  child: _selectedIssue != null
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.only(left: 8),
                          child: _buildInterventionFormContent(l10n),
                        )
                      : _buildDetailPlaceholder(l10n),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPlaceholder(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app_outlined,
              size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(l10n.techSelectIssue,
              style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(l10n.techSelectIssueHint,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted)),
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

          // Chronomètre si intervention active
          if (_currentIssueTakenAt != null) ...[
            const SizedBox(height: 12),
            _buildStopwatchBadge(),
          ],
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
          else ...[
            ...filtered.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildInterventionCard(
                    issue, _selectedIssueId == issue.id, l10n),
              ),
            ),
            if (_selectedIssue != null) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildInterventionFormContent(l10n),
                ),
              ),
            ],
          ],
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
      onTap: () {
        if (_selectedIssueId == issue.id) {
          _stopTimer();
          setState(() {
            _selectedIssueId = null;
            _selectedParts.clear();
            _partsSearchController.clear();
          });
        } else {
          _onIssueSelected(issue.id);
        }
      },
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
                // Chrono inline si sélectionné et actif
                if (isSelected && _currentIssueTakenAt != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 11, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(
                        _formatElapsed(_elapsed),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Badge chronomètre
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildStopwatchBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 17, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            _formatElapsed(_elapsed),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.warning,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Formulaire de mise à jour (Bon de Travail)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildInterventionFormContent(AppLocalizations l10n) {
    final issue = _selectedIssue!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Récapitulatif incident ──────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(issue.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                UrgencyBadge(urgency: issue.urgency, isCompact: true),
              ]),
              const SizedBox(height: 4),
              Text(issue.description,
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                l10n.techReportedByDate(issue.reporter, issue.createdAt),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              // Date de prise en charge si disponible
              if (issue.takenAt != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.play_circle_outline,
                      size: 13, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    l10n.techTakenAtLabel(
                        issue.takenAt!.split('T').first),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.primary),
                  ),
                ]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ── Diagnostic ──────────────────────────────────────────────────────
        Text(l10n.techDiagnosis,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _diagnosisController,
          maxLines: 3,
          decoration: InputDecoration(hintText: l10n.techDiagnosisHint),
        ),
        const SizedBox(height: 22),

        // ── Actions ─────────────────────────────────────────────────────────
        Text(l10n.techActionsTaken,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _actionsController,
          maxLines: 3,
          decoration: InputDecoration(hintText: l10n.techActionsHint),
        ),
        const SizedBox(height: 22),

        // ── Sélecteur de pièces ─────────────────────────────────────────────
        _buildPartsPicker(l10n),
        const SizedBox(height: 28),

        // ── Bouton Sauvegarder ───────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isBusy
                ? null
                : _saveProgress,
            icon: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.save_outlined, size: 16),
            label: Text(l10n.techSave),
          ),
        ),
        const SizedBox(height: 10),

        // ── Bouton Clôture formelle (Bon de Travail) ─────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isBusy
                ? null
                : () => _showWorkOrderDialog(issue),
            icon: const Icon(Icons.verified_outlined, size: 16),
            label: Text(l10n.techMarkResolved),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(height: 10),

        // ── Bouton Escalader / Suspendre ─────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isBusy
                ? null
                : () => _showEscalateDialog(issue),
            icon: _isEscalating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.error))
                : const Icon(Icons.report_problem_outlined,
                    size: 16, color: AppColors.error),
            label: Text(l10n.techEscalateButton,
                style: const TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Bouton Transférer (reassign groupe) ──────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isBusy
                ? null
                : () => _showReassignDialog(issue),
            icon: _isReassigning
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.warning))
                : const Icon(Icons.swap_horiz, size: 16, color: AppColors.warning),
            label: Text(l10n.techReassignButton,
                style: const TextStyle(color: AppColors.warning)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.warning),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Bouton Détacher (retour au pool) ─────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isBusy
                ? null
                : () => _showDetachDialog(issue),
            icon: _isDetaching
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.textSecondary))
                : const Icon(Icons.link_off,
                    size: 16, color: AppColors.textSecondary),
            label: Text(l10n.detachButton,
                style: const TextStyle(color: AppColors.textSecondary)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Dialog : Détachement d'un incident (retour au pool)
  // ─────────────────────────────────────────────────────────────────────────────

  void _showDetachDialog(Issue issue) {
    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.detachDialogTitle),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reasonController,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.detachReasonLabel),
            validator: (v) => (v == null || v.trim().length < 10)
                ? l10n.detachReasonMinLength
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final reason = reasonController.text.trim();
              Navigator.pop(ctx);
              await _doDetach(issue, reason);
            },
            icon: const Icon(Icons.link_off, size: 16),
            label: Text(l10n.commonConfirm),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textSecondary,
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _doDetach(Issue issue, String reason) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isDetaching = true);
    try {
      await DbApiService.instance.detachIssue(issue.id, reason);
      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.link_off, color: Colors.white),
          const SizedBox(width: 12),
          Text(l10n.detachSuccess),
        ]),
        backgroundColor: AppColors.textSecondary,
        behavior: SnackBarBehavior.floating,
      ));
      _stopTimer();
      setState(() {
        _selectedIssueId = null;
        _diagnosisController.clear();
        _actionsController.clear();
        _partsSearchController.clear();
        _selectedParts.clear();
        _legacyPartsText = '';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.commonApiError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isDetaching = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Sélecteur de pièces depuis l'inventaire
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildPartsPicker(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.techPartsFromInventory,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _partsSearchController,
          decoration: InputDecoration(
            hintText: l10n.techPartsSearchHint,
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        // Suggestions si la requête fait ≥ 2 caractères
        if (_partsSearchController.text.trim().length >= 2)
          _buildPartsSuggestions(l10n),
        const SizedBox(height: 10),

        // Pièces sélectionnées
        if (_selectedParts.isEmpty && _legacyPartsText.isEmpty)
          Text(l10n.techPartsNoneSelected,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary))
        else ...[
          if (_selectedParts.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedParts
                  .map((p) => _buildSelectedPartChip(p, l10n))
                  .toList(),
            ),
          // Valeur texte libre sauvegardée antérieurement
          if (_legacyPartsText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_legacyPartsText,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ),
                ]),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPartsSuggestions(AppLocalizations l10n) {
    final query = _partsSearchController.text.trim().toLowerCase();
    final suggestions = DataService()
        .inventory
        .where((item) => item.name.toLowerCase().contains(query))
        .take(5)
        .toList();

    if (suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(l10n.techPartsNoResults,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Column(
        children: suggestions.asMap().entries.map((entry) {
          final item         = entry.value;
          final isOutOfStock = item.status == StockStatus.outOfStock;
          final alreadyAdded =
              _selectedParts.any((p) => p.itemId == item.id);
          final isLast = entry.key == suggestions.length - 1;

          return Column(children: [
            ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              title: Text(item.name,
                  style: TextStyle(
                      fontSize: 13,
                      color: isOutOfStock
                          ? AppColors.textMuted
                          : AppColors.textPrimary)),
              subtitle: Text(
                isOutOfStock
                    ? l10n.techPartsOutOfStock
                    : l10n.techPartsStockLabel(
                        item.currentStock, item.unit),
                style: TextStyle(
                    fontSize: 11,
                    color: isOutOfStock
                        ? AppColors.error
                        : AppColors.textSecondary),
              ),
              trailing: alreadyAdded
                  ? const Icon(Icons.check_circle,
                      size: 18, color: AppColors.success)
                  : IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          size: 20, color: AppColors.primary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: isOutOfStock
                          ? null
                          : () => setState(() {
                                _selectedParts.add(_SelectedPart(
                                  itemId: item.id,
                                  name:   item.name,
                                  unit:   item.unit,
                                ));
                                _partsSearchController.clear();
                              }),
                    ),
            ),
            if (!isLast)
              const Divider(height: 1, indent: 12, endIndent: 12),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedPartChip(_SelectedPart part, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() {
              if (part.quantity > 1) part.quantity--;
            }),
            child:
                const Icon(Icons.remove, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 6),
          Text(
            '${part.name} × ${part.quantity} (${part.unit})',
            style: const TextStyle(fontSize: 12, color: AppColors.primary),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => part.quantity++),
            child: const Icon(Icons.add, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _selectedParts.remove(part)),
            child: const Icon(Icons.close,
                size: 14, color: AppColors.textSecondary),
          ),
        ],
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
      setState(() {
        _selectedIssueId = issue.id;
        _loadIssueData();
        _tabController.animateTo(_myInterventionsIndex);
      });
      _startTimer(DateTime.now());
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
  // Dialog : Bon de Travail — Clôture formelle
  // ─────────────────────────────────────────────────────────────────────────────

  void _showWorkOrderDialog(Issue issue) {
    final l10n            = AppLocalizations.of(context)!;
    bool safetyChecked    = false;
    final closingNotesCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.verified_outlined,
                color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(l10n.techWorkOrderTitle,
                    style: const TextStyle(fontSize: 16))),
          ]),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Récapitulatif
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(issue.displayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(issue.department,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        if (_selectedParts.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${l10n.techPartsFromInventory} : '
                            '${_selectedParts.map((p) => '${p.name} ×${p.quantity}').join(', ')}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.primary),
                          ),
                        ],
                      ]),
                ),
                const SizedBox(height: 16),

                // Checkbox de sécurité
                InkWell(
                  onTap: () => setDialogState(
                      () => safetyChecked = !safetyChecked),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: safetyChecked,
                        onChanged: (v) => setDialogState(
                            () => safetyChecked = v ?? false),
                        activeColor: AppColors.success,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            l10n.techWorkOrderSafetyCheck,
                            style: TextStyle(
                              fontSize: 13,
                              color: safetyChecked
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                              fontWeight: safetyChecked
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!safetyChecked)
                  Padding(
                    padding: const EdgeInsets.only(left: 46, top: 2),
                    child: Text(
                      l10n.techWorkOrderSafetyRequired,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.error),
                    ),
                  ),
                const SizedBox(height: 12),

                // Notes de clôture
                TextField(
                  controller: closingNotesCtl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.techWorkOrderClosingNotes,
                    hintText: l10n.techWorkOrderClosingNotesHint,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                closingNotesCtl.dispose();
                Navigator.pop(ctx);
              },
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: safetyChecked
                  ? () async {
                      final notes = closingNotesCtl.text.trim();
                      closingNotesCtl.dispose();
                      Navigator.pop(ctx);
                      // Si des pièces sont sélectionnées → confirmation déstockage
                      if (_selectedParts.isNotEmpty) {
                        final confirmed =
                            await _showDestockConfirmDialog(issue);
                        if (!confirmed) return;
                      }
                      await _doWorkOrderClose(issue, notes);
                    }
                  : null,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(l10n.techWorkOrderConfirm),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Dialog : Confirmation déstockage
  // ─────────────────────────────────────────────────────────────────────────────

  Future<bool> _showDestockConfirmDialog(Issue issue) async {
    final l10n = AppLocalizations.of(context)!;

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(children: [
              const Icon(Icons.inventory_2_outlined,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(l10n.techDestockConfirmTitle,
                  style: const TextStyle(fontSize: 16)),
            ]),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.techDestockConfirmSubtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),

                  // Liste des pièces avec stock actuel et estimé
                  ..._selectedParts.map((part) {
                    final inventoryItem = _inventoryItemFor(part.itemId);
                    final currentStock  = inventoryItem?.currentStock ?? 0;
                    final afterStock    = currentStock - part.quantity;
                    final isLow         = afterStock <= (inventoryItem?.minStock ?? 0);
                    final isNegative    = afterStock < 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isNegative
                            ? AppColors.errorLight
                            : isLow
                                ? AppColors.warningLight
                                : AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isNegative
                              ? AppColors.error
                              : isLow
                                  ? AppColors.warning
                                  : AppColors.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.techDestockItemLine(
                              part.name,
                              part.quantity,
                              part.unit,
                              currentStock,
                            ),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.techDestockStockAfter(
                                afterStock.clamp(0, 999999), part.unit),
                            style: TextStyle(
                              fontSize: 12,
                              color: isNegative
                                  ? AppColors.error
                                  : isLow
                                      ? AppColors.warning
                                      : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isLow && !isNegative) ...[
                            const SizedBox(height: 2),
                            Text(l10n.techDestockLowWarning,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.warning)),
                          ],
                          if (isNegative) ...[
                            const SizedBox(height: 2),
                            Text(
                              '⛔ Stock insuffisant pour cette quantité',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel),
              ),
              ElevatedButton.icon(
                // Désactivé si au moins une pièce est en stock insuffisant
                onPressed: _selectedParts.any((p) {
                  final inv = _inventoryItemFor(p.itemId);
                  return (inv?.currentStock ?? 0) < p.quantity;
                })
                    ? null
                    : () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check, size: 16),
                label: Text(l10n.techDestockConfirm),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Dialog : Escalade / Suspension
  // ─────────────────────────────────────────────────────────────────────────────

  void _showEscalateDialog(Issue issue) {
    final l10n          = AppLocalizations.of(context)!;
    final formKey       = GlobalKey<FormState>();
    String? escalStatus;
    final commentCtl    = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.report_problem_outlined,
                color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Text(l10n.techEscalateTitle,
                style: const TextStyle(fontSize: 16)),
          ]),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.techEscalateSubtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),

                  // Type d'escalade
                  Text(l10n.techEscalateStatusLabel,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: escalStatus,
                    hint: Text(l10n.techEscalateStatusLabel),
                    items: [
                      DropdownMenuItem(
                        value: 'Waiting Materials',
                        child: Row(children: [
                          const Icon(Icons.inventory_outlined,
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Text(l10n.techEscalateWaitingMaterials),
                        ]),
                      ),
                      DropdownMenuItem(
                        value: 'Redirected',
                        child: Row(children: [
                          const Icon(Icons.forward_outlined,
                              size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text(l10n.techEscalateRedirected),
                        ]),
                      ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => escalStatus = v),
                    validator: (v) =>
                        v == null ? l10n.techEscalateStatusRequired : null,
                  ),
                  const SizedBox(height: 16),

                  // Commentaire obligatoire
                  TextFormField(
                    controller: commentCtl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.techEscalateCommentLabel,
                      hintText: l10n.techEscalateCommentHint,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 10) {
                        return l10n.techEscalateCommentMinLength;
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                commentCtl.dispose();
                Navigator.pop(ctx);
              },
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final status  = escalStatus!;
                final comment = commentCtl.text.trim();
                commentCtl.dispose();
                Navigator.pop(ctx);
                await _doEscalate(issue, status, comment);
              },
              icon: const Icon(Icons.report_problem_outlined, size: 16),
              label: Text(l10n.commonConfirm),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Dialog : Transfert de groupe (réassignation)
  // ─────────────────────────────────────────────────────────────────────────────

  void _showReassignDialog(Issue issue) {
    final l10n        = AppLocalizations.of(context)!;
    final formKey     = GlobalKey<FormState>();
    String? selectedGroup;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.techReassignTitle),
          content: Form(
            key: formKey,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.techReassignSubtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    hint: Text(l10n.techReassignGroupHint),
                    value: selectedGroup,
                    items: const ['IT', 'Infrastructure', 'Biomédical']
                        .map((g) =>
                            DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedGroup = v),
                    validator: (v) =>
                        v == null ? l10n.techReassignGroupRequired : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.techReassignReasonLabel,
                      hintText:  l10n.techReassignReasonHint,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 10) {
                        return l10n.techReassignReasonMinLength;
                      }
                      return null;
                    },
                  ),
                ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                await _doReassign(
                    issue, selectedGroup!, reasonController.text.trim());
              },
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: Text(l10n.commonConfirm),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Actions API
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _doReassign(
      Issue issue, String newGroup, String reason) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isReassigning = true);
    try {
      await DbApiService.instance.reassignIssue(issue.id, newGroup, reason);
      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.swap_horiz, color: Colors.white),
          const SizedBox(width: 12),
          Text(l10n.techReassignSuccess(newGroup)),
        ]),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ));
      _stopTimer();
      setState(() {
        _selectedIssueId = null;
        _diagnosisController.clear();
        _actionsController.clear();
        _partsSearchController.clear();
        _selectedParts.clear();
        _legacyPartsText = '';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.commonApiError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isReassigning = false);
    }
  }

  Future<void> _doEscalate(
      Issue issue, String escalStatus, String comment) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isEscalating = true);
    try {
      await DbApiService.instance.escalateIssue(issue.id, escalStatus, comment);
      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.report_problem_outlined, color: Colors.white),
          const SizedBox(width: 12),
          Text(l10n.techEscalateSuccess(escalStatus)),
        ]),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      _stopTimer();
      setState(() {
        _selectedIssueId = null;
        _diagnosisController.clear();
        _actionsController.clear();
        _partsSearchController.clear();
        _selectedParts.clear();
        _legacyPartsText = '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${l10n.commonApiError}: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isEscalating = false);
    }
  }

  Future<void> _saveProgress() async {
    if (_selectedIssueId == null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      await DbApiService.instance.updateIssue(_selectedIssueId!, {
        'status':              'In Progress',
        'assigned_technician': _currentTechnicianName,
        'diagnosis': _diagnosisController.text.trim().isNotEmpty
            ? _diagnosisController.text.trim()
            : null,
        'actions': _actionsController.text.trim().isNotEmpty
            ? _actionsController.text.trim()
            : null,
        'parts_replaced': _serializeParts().isNotEmpty
            ? _serializeParts()
            : null,
        // Pas de parts_consumed ici — le déstockage se fait uniquement à la clôture
      });
      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.save, color: Colors.white),
          const SizedBox(width: 12),
          Text(l10n.techProgressSaved),
        ]),
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

  Future<void> _doWorkOrderClose(Issue issue, String closingNotes) async {
    if (_selectedIssueId == null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);

    // Fusionne les notes de clôture dans les actions si fournies
    String? finalActions;
    final existingActions = _actionsController.text.trim();
    if (closingNotes.isNotEmpty) {
      finalActions = existingActions.isNotEmpty
          ? '$existingActions\n[Clôture] $closingNotes'
          : '[Clôture] $closingNotes';
    } else if (existingActions.isNotEmpty) {
      finalActions = existingActions;
    }

    try {
      await DbApiService.instance.updateIssue(_selectedIssueId!, {
        'status':              'Completed',
        'assigned_technician': _currentTechnicianName,
        'diagnosis': _diagnosisController.text.trim().isNotEmpty
            ? _diagnosisController.text.trim()
            : null,
        'actions':        finalActions,
        'parts_replaced': _serializeParts().isNotEmpty ? _serializeParts() : null,
        // Déstockage transactionnel côté backend
        if (_selectedParts.isNotEmpty) 'parts_consumed': _buildPartsConsumed(),
      });
      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Text(l10n.techIssueResolved),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      _stopTimer();
      setState(() {
        _selectedIssueId = null;
        _diagnosisController.clear();
        _actionsController.clear();
        _partsSearchController.clear();
        _selectedParts.clear();
        _legacyPartsText = '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${l10n.commonApiError}: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
