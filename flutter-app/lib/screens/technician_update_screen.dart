import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
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
import '../widgets/equipment_detail_dialog.dart';

// ── Modèles internes ──────────────────────────────────────────────────────────

/// Événement unifié pour l'onglet Agenda du technicien.
class _AgendaEvent {
  final String title;
  final String subtitle;
  final String type; // 'in_progress' | 'resolved' | 'maintenance' | 'future_maintenance'
  final DateTime date;

  const _AgendaEvent({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.date,
  });
}

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

/// Espace technicien — trois onglets : incidents disponibles, mes interventions, agenda.
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
  String  _repairStatus       = 'Diagnostic en cours';
  String  _interventionSearch = '';
  String  _legacyPartsText    = ''; // pièces sauvegardées en texte libre

  // ── Formulaire ──────────────────────────────────────────────────────────────
  final _diagnosisController   = TextEditingController();
  final _actionsController     = TextEditingController();
  final _partsSearchController = TextEditingController();

  bool _isSaving      = false;
  bool _isReassigning = false;

  // ── Chronomètre d'intervention ───────────────────────────────────────────────
  Timer?    _timer;
  Duration  _elapsed             = Duration.zero;
  DateTime? _currentIssueTakenAt;

  // ── Sélection de pièces depuis l'inventaire ──────────────────────────────────
  final List<_SelectedPart> _selectedParts = [];

  // ── Onglet "Agenda" ─────────────────────────────────────────────────────────
  DateTime _focusedDay  = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // ── Statuts internes (clés FR côté API) ──────────────────────────────────────
  final List<String> _repairStatuses = [
    'Diagnostic en cours',
    'Pièces commandées',
    'Réparation en cours',
    'Test en cours',
    'Réparé',
  ];

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

  // ── Init / Dispose ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final startTab = widget.issueId != null ? 1 : 0;
    _tabController = TabController(length: 3, vsync: this, initialIndex: startTab);
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
    // Démarre le chrono si l'incident est déjà en cours
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

  String _getRepairStatusDisplay(String status, AppLocalizations l10n) {
    switch (status) {
      case 'Diagnostic en cours': return l10n.techDiagnosisInProgress;
      case 'Pièces commandées':   return l10n.techPartsOrdered;
      case 'Réparation en cours': return l10n.techRepairInProgress;
      case 'Test en cours':       return l10n.techTestInProgress;
      case 'Réparé':              return l10n.techRepaired;
      default:                    return status;
    }
  }

  // ── Build principal ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n      = AppLocalizations.of(context)!;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Column(
      children: [
        // ── TabBar ──────────────────────────────────────────────────────────
        Material(
          color: Theme.of(context).cardColor,
          elevation: 1,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(
                icon: Badge(
                  isLabelVisible: _availableIssues.isNotEmpty,
                  label: Text('${_availableIssues.length}'),
                  child: const Icon(Icons.inbox_outlined, size: 18),
                ),
                text: l10n.techAvailableTab,
              ),
              Tab(
                icon: Badge(
                  isLabelVisible: _myIssues.isNotEmpty,
                  label: Text('${_myIssues.length}'),
                  child: const Icon(Icons.build_outlined, size: 18),
                ),
                text: l10n.techMyInterventionsTab,
              ),
              Tab(
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                text: l10n.techScheduleTab,
              ),
            ],
          ),
        ),

        // ── TabBarView ──────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAvailableTab(l10n, !isDesktop),
              isDesktop
                  ? _buildDesktopInterventionsTab(l10n)
                  : _buildMobileInterventionsTab(l10n),
              _buildAgendaTab(!isDesktop),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Onglet 0 : Incidents disponibles
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildAvailableTab(AppLocalizations l10n, bool isMobile) {
    final issues = _availableIssues;

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
            Text(l10n.techAvailableSubtitle,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
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
                            Text(l10n.techNoAvailableIncidents,
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : Column(
                        children: issues
                            .map((i) => _buildAvailableIssueItem(i, isMobile))
                            .toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableIssueItem(Issue issue, bool isMobile) {
    final l10n = AppLocalizations.of(context)!;
    final eq   = _equipmentFor(issue);

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
                    color: _urgencyBgColor(issue.urgency),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.warning_amber_rounded,
                      color: _urgencyFgColor(issue.urgency), size: 18),
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
                UrgencyBadge(urgency: issue.urgency, isCompact: true),
              ]),
              const SizedBox(height: 8),
              Text(issue.type,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(issue.description,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (eq != null) ...[
                const SizedBox(height: 4),
                Wrap(spacing: 8, children: [
                  if (eq.category.isNotEmpty)
                    _miniChip(Icons.category, eq.category),
                  if (eq.location.isNotEmpty)
                    _miniChip(Icons.location_on, eq.location),
                  if (eq.serialNumber.isNotEmpty)
                    _miniChip(Icons.qr_code, eq.serialNumber),
                ]),
              ],
              const SizedBox(height: 4),
              Text(
                  l10n.issuesReportedByDate(issue.reporter, issue.createdAt),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              Row(children: [
                if (eq != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => EquipmentDetailDialog.show(context, eq),
                      icon: const Icon(Icons.info_outline, size: 14),
                      label: Text(l10n.techSheet),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _showTakeOverDialog(issue),
                    icon: const Icon(Icons.handyman_outlined, size: 16),
                    label: Text(l10n.techTakeCharge),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white),
                  ),
                ),
              ]),
            ])
          : Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _urgencyBgColor(issue.urgency),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    color: _urgencyFgColor(issue.urgency), size: 20),
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
                        _infoChip(issue.department, AppColors.primaryLight,
                            AppColors.primary),
                        const SizedBox(width: 6),
                        _infoChip(issue.type, AppColors.background,
                            AppColors.textSecondary),
                        if (eq != null && eq.category.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _infoChip(eq.category, AppColors.successLight,
                              AppColors.success),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(issue.description,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(
                            l10n.issuesReportedByDate(
                                issue.reporter, issue.createdAt),
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                        if (eq != null && eq.location.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.location_on,
                              size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 2),
                          Text(eq.location,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)),
                        ],
                        if (eq != null && eq.serialNumber.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.qr_code,
                              size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 2),
                          Text(eq.serialNumber,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ]),
                    ]),
              ),
              const SizedBox(width: 16),
              UrgencyBadge(urgency: issue.urgency),
              const SizedBox(width: 8),
              if (eq != null)
                OutlinedButton.icon(
                  onPressed: () => EquipmentDetailDialog.show(context, eq),
                  icon: const Icon(Icons.info_outline, size: 14),
                  label: Text(l10n.techSheet),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showTakeOverDialog(issue),
                icon: const Icon(Icons.handyman_outlined, size: 16),
                label: Text(l10n.techTakeCharge),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
              ),
            ]),
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
          // Désélectionner
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
                            color: AppColors.primary,
                            fontFeatures: []),
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
  // Formulaire de mise à jour (partagé desktop / mobile)
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

        // ── Statut de réparation ────────────────────────────────────────────
        Text(l10n.techRepairStatus,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _repairStatus,
          items: _repairStatuses
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(_getRepairStatusDisplay(s, l10n)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _repairStatus = v!),
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

        // ── Boutons Enregistrer / Marquer résolu ─────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    (_isSaving || _isReassigning) ? null : _saveProgress,
                child: Text(l10n.techSave),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: (_repairStatus == 'Réparé' &&
                            !_isSaving &&
                            !_isReassigning)
                        ? _markResolved
                        : null,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16),
                    label: Text(l10n.techMarkResolved),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white),
                  ),
                  // Explication si le bouton est désactivé
                  if (_repairStatus != 'Réparé')
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        l10n.techMarkResolvedTooltip,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Bouton Transférer ────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (_isSaving || _isReassigning)
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
        const SizedBox(height: 16),
      ],
    );
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
  // Onglet 2 : Agenda
  // ─────────────────────────────────────────────────────────────────────────────

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr.split('T').first);
    } catch (_) {
      return null;
    }
  }

  List<_AgendaEvent> get _allAgendaEvents {
    final events   = <_AgendaEvent>[];
    final techName = _currentTechnicianName;

    // Incidents assignés à ce technicien — utilise taken_at si disponible,
    // sinon created_at comme fallback.
    for (final issue in DataService().issues) {
      if (issue.assignedTechnician != techName) continue;
      if (issue.status != IssueStatus.inProgress &&
          issue.status != IssueStatus.completed) continue;
      final dateStr = issue.takenAt ?? issue.createdAt;
      final date    = _parseDate(dateStr);
      if (date == null) continue;
      events.add(_AgendaEvent(
        title:    issue.displayName,
        subtitle: issue.type,
        type:
            issue.status == IssueStatus.inProgress ? 'in_progress' : 'resolved',
        date: date,
      ));
    }

    // Maintenances passées
    for (final eq in DataService().equipment) {
      for (final rec in eq.maintenanceHistory) {
        if (rec.technician != techName) continue;
        final date = _parseDate(rec.date);
        if (date == null) continue;
        events.add(_AgendaEvent(
            title:    eq.name,
            subtitle: rec.intervention,
            type:     'maintenance',
            date:     date));
      }
      // Maintenances futures
      for (final rec in eq.futureMaintenance) {
        if (rec.technician != techName) continue;
        final date = _parseDate(rec.date);
        if (date == null) continue;
        events.add(_AgendaEvent(
            title:    eq.name,
            subtitle: rec.intervention,
            type:     'future_maintenance',
            date:     date));
      }
    }

    return events;
  }

  List<_AgendaEvent> _eventsForDay(DateTime day) {
    return _allAgendaEvents
        .where((e) =>
            e.date.year  == day.year &&
            e.date.month == day.month &&
            e.date.day   == day.day)
        .toList();
  }

  String _monthName(int month, AppLocalizations l10n) {
    switch (month) {
      case 1:  return l10n.monthJanuary;
      case 2:  return l10n.monthFebruary;
      case 3:  return l10n.monthMarch;
      case 4:  return l10n.monthApril;
      case 5:  return l10n.monthMay;
      case 6:  return l10n.monthJune;
      case 7:  return l10n.monthJuly;
      case 8:  return l10n.monthAugust;
      case 9:  return l10n.monthSeptember;
      case 10: return l10n.monthOctober;
      case 11: return l10n.monthNovember;
      case 12: return l10n.monthDecember;
      default: return '';
    }
  }

  Widget _buildAgendaTab(bool isMobile) {
    final l10n           = AppLocalizations.of(context)!;
    final selectedEvents = _eventsForDay(_selectedDay);
    final allEvents      = _allAgendaEvents;

    final Map<String, List<_AgendaEvent>> byMonth = {};
    for (final e in allEvents) {
      final key =
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(e);
    }
    final monthKeys = byMonth.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.techScheduleTitle,
              style: TextStyle(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(l10n.techScheduleSubtitle,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),

          // Légende
          Wrap(spacing: 12, runSpacing: 4, children: [
            _legendItem(AppColors.warning, Icons.build_circle_outlined,
                l10n.techLegendInProgress),
            _legendItem(AppColors.success, Icons.check_circle_outlined,
                l10n.techLegendResolved),
            _legendItem(AppColors.textSecondary, Icons.build_outlined,
                l10n.techLegendPastMaintenance),
            _legendItem(
                AppColors.primary, Icons.event_repeat, l10n.techLegendPlanned),
          ]),
          const SizedBox(height: 12),

          // Calendrier
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: TableCalendar<_AgendaEvent>(
                firstDay:
                    DateTime.now().subtract(const Duration(days: 365)),
                lastDay:
                    DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) =>
                    isSameDay(_selectedDay, day),
                eventLoader: _eventsForDay,
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle),
                  todayTextStyle: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold),
                  selectedDecoration: BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  markerDecoration: BoxDecoration(
                      color: AppColors.warning, shape: BoxShape.circle),
                  outsideDaysVisible: false,
                  markersMaxCount: 3,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay  = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) =>
                    setState(() => _focusedDay = focusedDay),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Événements du jour sélectionné
          Text(
            l10n.techEventsOn(
              '${_selectedDay.day.toString().padLeft(2, '0')}/'
              '${_selectedDay.month.toString().padLeft(2, '0')}/'
              '${_selectedDay.year}',
            ),
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          selectedEvents.isEmpty
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const Icon(Icons.event_available,
                          color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(l10n.techNoEventsToday,
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                    ]),
                  ),
                )
              : Card(
                  child: Column(
                    children: selectedEvents.asMap().entries.map((entry) {
                      final isLast =
                          entry.key == selectedEvents.length - 1;
                      return Column(children: [
                        _buildEventTile(entry.value, l10n),
                        if (!isLast)
                          const Divider(height: 1, indent: 56),
                      ]);
                    }).toList(),
                  ),
                ),
          const SizedBox(height: 24),

          // Historique complet
          if (allEvents.isNotEmpty) ...[
            Text(l10n.techFullHistory,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            ...monthKeys.map((key) {
              final events = List<_AgendaEvent>.from(byMonth[key]!)
                ..sort((a, b) => b.date.compareTo(a.date));
              final parts      = key.split('-');
              final monthLabel =
                  '${_monthName(int.parse(parts[1]), l10n)} ${parts[0]}';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(monthLabel,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.techEventCount(events.length),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ]),
                  ),
                  Card(
                    child: Column(
                      children: events.asMap().entries.map((entry) {
                        final isLast =
                            entry.key == events.length - 1;
                        return Column(children: [
                          _buildEventTile(entry.value, l10n),
                          if (!isLast)
                            const Divider(height: 1, indent: 56),
                        ]);
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 40, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(l10n.techNoInterventions,
                      style:
                          const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(l10n.techNoInterventionsHint,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventTile(_AgendaEvent event, AppLocalizations l10n) {
    final IconData icon;
    final Color    color;
    final String   statusLabel;

    switch (event.type) {
      case 'in_progress':
        icon        = Icons.build_circle_outlined;
        color       = AppColors.warning;
        statusLabel = l10n.techLegendInProgress;
      case 'resolved':
        icon        = Icons.check_circle_outline;
        color       = AppColors.success;
        statusLabel = l10n.techLegendResolved;
      case 'future_maintenance':
        icon        = Icons.event_repeat;
        color       = AppColors.primary;
        statusLabel = l10n.techLegendPlanned;
      default: // 'maintenance'
        icon        = Icons.build_outlined;
        color       = AppColors.textSecondary;
        statusLabel = l10n.techEventStatusCompleted;
    }

    return ListTile(
      leading: Container(
        width:   36,
        height:  36,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(event.title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(
        '${event.subtitle}  ·  $statusLabel',
        style:
            const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Text(
        '${event.date.day.toString().padLeft(2, '0')}/'
        '${event.date.month.toString().padLeft(2, '0')}/'
        '${event.date.year}',
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
    );
  }

  Widget _legendItem(Color color, IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers visuels
  // ─────────────────────────────────────────────────────────────────────────────

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
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
      );

  Widget _miniChip(IconData icon, String label) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );

  // ─────────────────────────────────────────────────────────────────────────────
  // Dialogues et actions
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
    final now = DateTime.now().toIso8601String();
    try {
      await DbApiService.instance.updateIssue(issue.id, {
        'status':              'In Progress',
        'assigned_technician': _currentTechnicianName,
        'taken_at':            now,
      });
      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
      if (!mounted) return;
      setState(() {
        _selectedIssueId = issue.id;
        _loadIssueData();
        _tabController.animateTo(1);
      });
      // Démarre le chrono dès la prise en charge
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
        _repairStatus    = 'Diagnostic en cours';
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
        content: Text(AppLocalizations.of(context)!.commonApiError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _markResolved() async {
    if (_selectedIssueId == null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      await DbApiService.instance.updateIssue(_selectedIssueId!, {
        'status':              'Completed',
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
        _repairStatus    = 'Diagnostic en cours';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.commonApiError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
