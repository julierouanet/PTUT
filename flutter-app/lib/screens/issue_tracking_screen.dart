import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/db_api_service.dart';
import '../models/issue.dart';
import '../models/user_role.dart';
import '../widgets/status_badge.dart';
import '../widgets/urgency_badge.dart';
import '../widgets/issue_category_selector.dart';
import '../widgets/issues/kanban_board.dart';
import '../utils/csv_export.dart';
import 'issue_detail_screen.dart';

// Filtre période
enum _PeriodFilter { all, last7Days, last30Days }

/// Écran de suivi des incidents avec recherche globale, filtres avancés,
/// tri par urgence, vue Kanban (desktop), export CSV et split view desktop.
class IssueTrackingScreen extends StatefulWidget {
  final Function(int, {String? issueId}) onNavigate;

  const IssueTrackingScreen({super.key, required this.onNavigate});

  @override
  State<IssueTrackingScreen> createState() => _IssueTrackingScreenState();
}

class _IssueTrackingScreenState extends State<IssueTrackingScreen>
    with SingleTickerProviderStateMixin {

  // ── Services ───────────────────────────────────────────────────────────────
  final AuthService _authService = AuthService();

  // ── Onglets (Admin / Supervisor) ───────────────────────────────────────────
  TabController? _tabController;
  bool _isValidating = false;

  // ── Filtre statut ──────────────────────────────────────────────────────────
  IssueStatus? _statusFilter;

  // ── Filtres avancés ────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  IssueUrgency? _urgencyFilter;
  String? _groupFilter;
  _PeriodFilter _periodFilter = _PeriodFilter.all;

  // ── Vue Liste / Kanban ─────────────────────────────────────────────────────
  bool _isKanban = false;

  // ── Filtres rapides ────────────────────────────────────────────────────────
  bool _showOnlyMyIssues   = false;
  bool _showOnlyDeptIssues = false;

  // ── Split View Desktop — incident sélectionné ─────────────────────────────
  String? _selectedIssueId;

  // ── Rôle ──────────────────────────────────────────────────────────────────
  bool get _isPrivileged {
    final roles = _authService.currentRoles;
    return roles.contains(UserRole.supervisor) || roles.contains(UserRole.admin);
  }

  @override
  void initState() {
    super.initState();
    if (_isPrivileged) {
      _tabController = TabController(length: 2, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Sources d'incidents ────────────────────────────────────────────────────

  List<Issue> get _myIssues {
    final user = _authService.currentUser;
    if (user == null) return [];
    return DataService().issues.where((i) {
      if (i.reporterId != null && i.reporterId!.isNotEmpty) {
        return i.reporterId == user.id;
      }
      return i.reporter == user.name;
    }).toList();
  }

  List<Issue> get _deptIssues {
    final dept = _authService.currentUser?.department ?? '';
    if (dept.isEmpty) return [];
    return DataService().issues.where((i) => i.department == dept).toList();
  }

  List<Issue> get _openIssuesForValidation {
    final roles   = _authService.currentRoles;
    final allOpen = DataService().issues
        .where((i) => i.status == IssueStatus.reported)
        .toList();
    if (roles.contains(UserRole.admin)) return allOpen;
    if (roles.contains(UserRole.supervisor)) {
      final dept = _authService.currentUser?.department ?? '';
      return allOpen.where((i) => i.department == dept).toList();
    }
    return [];
  }

  // ── Filtre + tri principal ─────────────────────────────────────────────────

  List<Issue> get _filteredIssues {
    List<Issue> source;
    if (_showOnlyMyIssues) {
      source = List<Issue>.from(_myIssues);
    } else if (_showOnlyDeptIssues) {
      source = List<Issue>.from(_deptIssues);
    } else {
      source = List<Issue>.from(DataService().issues);
    }

    if (_statusFilter != null) {
      source = source.where((i) => i.status == _statusFilter).toList();
    }

    if (_urgencyFilter != null) {
      source = source.where((i) => i.urgency == _urgencyFilter).toList();
    }

    if (_groupFilter != null) {
      source = source.where((i) => i.assignedGroup == _groupFilter).toList();
    }

    if (_periodFilter != _PeriodFilter.all) {
      final days   = _periodFilter == _PeriodFilter.last7Days ? 7 : 30;
      final cutoff = DateTime.now().subtract(Duration(days: days));
      source = source.where((i) {
        try {
          return DateTime.parse(i.createdAt).isAfter(cutoff);
        } catch (_) {
          return true;
        }
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      source = source.where((i) =>
        i.displayName.toLowerCase().contains(q) ||
        i.description.toLowerCase().contains(q) ||
        i.reporter.toLowerCase().contains(q) ||
        (i.equipmentName?.toLowerCase().contains(q) ?? false)
      ).toList();
    }

    return _applySort(source);
  }

  List<Issue> _applySort(List<Issue> issues) {
    const urgencyOrder = {
      IssueUrgency.critique: 0,
      IssueUrgency.urgent:   1,
      IssueUrgency.moyen:    2,
      IssueUrgency.faible:   3,
    };
    final sorted = List<Issue>.from(issues);
    sorted.sort((a, b) {
      final ua = urgencyOrder[a.urgency] ?? 4;
      final ub = urgencyOrder[b.urgency] ?? 4;
      if (ua != ub) return ua.compareTo(ub);
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  void _clearQuickFilter() =>
      setState(() { _showOnlyMyIssues = false; _showOnlyDeptIssues = false; });

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_isPrivileged) return _buildMainContent(context);

    return Column(children: [
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
              icon: const Icon(Icons.list_alt, size: 18),
              text: AppLocalizations.of(context)!.issueTrackingTab,
            ),
            Tab(
              icon: const Icon(Icons.pending_actions, size: 18),
              text: AppLocalizations.of(context)!.issueValidationTab,
            ),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMainContent(context),
            _buildValidationTab(context),
          ],
        ),
      ),
    ]);
  }

  // ── Onglet principal — adaptatif Mobile / Desktop ──────────────────────────

  Widget _buildMainContent(BuildContext context) {
    final l10n      = AppLocalizations.of(context)!;
    final isMobile  = MediaQuery.of(context).size.width < 600;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    // Contenu de liste partagé entre les deux modes
    final listPanel = SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildListColumnContent(context, l10n, isMobile, isDesktop),
      ),
    );

    // ── Desktop : Split View Gmail-style ──────────────────────────────────
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panneau gauche : liste
          Expanded(flex: 5, child: listPanel),
          // Séparateur
          Container(width: 1, color: AppColors.border),
          // Panneau droit : détail ou placeholder
          Expanded(
            flex: 7,
            child: _selectedIssueId != null
                ? IssueDetailScreen(
                    key: ValueKey(_selectedIssueId),
                    issueId: _selectedIssueId!,
                    isPanel: true,
                    onNavigate: widget.onNavigate,
                    onClosePanel: () =>
                        setState(() => _selectedIssueId = null),
                  )
                : _buildEmptyDetailPanel(context, l10n),
          ),
        ],
      );
    }

    // ── Mobile : liste seule ───────────────────────────────────────────────
    return Align(alignment: Alignment.topLeft, child: listPanel);
  }

  // ── Placeholder panneau droit vide ────────────────────────────────────────

  Widget _buildEmptyDetailPanel(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.article_outlined, size: 64, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text(
          l10n.issueDetailPanelNoSelection,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  // ── Contenu colonne de la liste ────────────────────────────────────────────

  List<Widget> _buildListColumnContent(
    BuildContext context,
    AppLocalizations l10n,
    bool isMobile,
    bool isDesktop,
  ) {
    final openCount       = DataService().issues
        .where((i) => i.status == IssueStatus.reported).length;
    final approvedCount   = DataService().issues
        .where((i) => i.status == IssueStatus.inProgress).length;
    final inProgressCount = DataService().issues
        .where((i) => i.status == IssueStatus.waitingMaterials).length;
    final resolvedCount   = DataService().issues
        .where((i) => i.status == IssueStatus.completed).length;

    return [
      // ── Header ─────────────────────────────────────────────────────
      Text(l10n.issuesTitle,
          style: TextStyle(
              fontSize: isMobile ? 20 : 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Text(l10n.issuesSubtitle,
          style: const TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 16),

      // ── Stats KPI + bouton Signaler ────────────────────────────────
      if (isMobile) ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          _buildMiniStat(l10n.issuesOpen,       openCount,       AppColors.error),
          _buildMiniStat(l10n.issuesApproved,   approvedCount,   AppColors.primary),
          _buildMiniStat(l10n.issuesInProgress, inProgressCount, AppColors.warning),
          _buildMiniStat(l10n.issuesResolved,   resolvedCount,   AppColors.success),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => showIssueCategorySelector(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.issuesReport),
          ),
        ),
      ] else
        Row(children: [
          _buildMiniStat(l10n.issuesOpen,       openCount,       AppColors.error),
          const SizedBox(width: 12),
          _buildMiniStat(l10n.issuesApproved,   approvedCount,   AppColors.primary),
          const SizedBox(width: 12),
          _buildMiniStat(l10n.issuesInProgress, inProgressCount, AppColors.warning),
          const SizedBox(width: 12),
          _buildMiniStat(l10n.issuesResolved,   resolvedCount,   AppColors.success),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => showIssueCategorySelector(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.issuesReport),
          ),
        ]),
      const SizedBox(height: 24),

      // ── Encadrés personnels ────────────────────────────────────────
      _buildPersonalCard(l10n),
      const SizedBox(height: 16),
      _buildDeptCard(l10n),
      const SizedBox(height: 24),

      // ── Séparateur "Tous les incidents" ────────────────────────────
      Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(l10n.issuesAllIssues,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ),
        const Expanded(child: Divider()),
      ]),
      const SizedBox(height: 16),

      // ── Barre de recherche ─────────────────────────────────────────
      _buildSearchBar(l10n),
      const SizedBox(height: 12),

      // ── Filtres avancés ────────────────────────────────────────────
      _buildFilterCard(l10n, isMobile, isDesktop),

      // ── Bannière filtre rapide actif ───────────────────────────────
      if (_showOnlyMyIssues || _showOnlyDeptIssues) ...[
        const SizedBox(height: 8),
        _buildActiveFilterBanner(l10n),
      ],
      const SizedBox(height: 12),

      // ── Liste ou Kanban ────────────────────────────────────────────
      if (_isKanban && isDesktop)
        SizedBox(
          width: double.infinity,
          height: 520,
          child: IssueKanbanBoard(
            issues: _filteredIssues,
            onIssueTap: _showIssueDetail,
          ),
        )
      else
        SizedBox(
          width: double.infinity,
          child: Card(
            child: Column(
              children: _filteredIssues.isEmpty
                  ? [Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l10n.issuesNoMyIssues,
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                    )]
                  : _filteredIssues
                      .map((issue) => _buildIssueItem(issue))
                      .toList(),
            ),
          ),
        ),
    ];
  }

  // ── Barre de recherche ──────────────────────────────────────────────────────

  Widget _buildSearchBar(AppLocalizations l10n) {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v.trim()),
      decoration: InputDecoration(
        hintText: l10n.issuesSearchHint,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
      ),
    );
  }

  // ── Carte de filtres avancés ────────────────────────────────────────────────

  Widget _buildFilterCard(
      AppLocalizations l10n, bool isMobile, bool isDesktop) {
    final statuses  = <IssueStatus?>[null, ...IssueStatus.values];
    final urgencies = <IssueUrgency?>[null, ...IssueUrgency.values];
    const groups    = <String?>['Biomédical', 'IT', 'Infrastructure'];
    const periods   = <_PeriodFilter>[
      _PeriodFilter.all,
      _PeriodFilter.last7Days,
      _PeriodFilter.last30Days
    ];

    String statusLabel(IssueStatus? s) =>
        s == null ? l10n.commonAll : s.localizedName(l10n);
    String urgencyLabel(IssueUrgency? u) =>
        u == null ? l10n.commonAll : u.localizedName(l10n);
    String groupLabel(String? g) {
      if (g == null) return l10n.commonAll;
      switch (g) {
        case 'IT':             return l10n.issuesFilterGroupIT;
        case 'Infrastructure': return l10n.issuesFilterGroupInfra;
        default:               return l10n.issuesFilterGroupBiomedical;
      }
    }

    String periodLabel(_PeriodFilter p) {
      switch (p) {
        case _PeriodFilter.last7Days:  return l10n.issuesFilterPeriodLast7;
        case _PeriodFilter.last30Days: return l10n.issuesFilterPeriodLast30;
        default:                       return l10n.issuesFilterPeriodAll;
      }
    }

    Widget statusChips() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((s) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            selected: _statusFilter == s,
            label: Text(statusLabel(s), style: const TextStyle(fontSize: 12)),
            onSelected: (_) => setState(() => _statusFilter = s),
            selectedColor: AppColors.primaryLight,
            checkmarkColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        )).toList(),
      ),
    );

    Widget urgencyChips() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: urgencies.map((u) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            selected: _urgencyFilter == u,
            label:
                Text(urgencyLabel(u), style: const TextStyle(fontSize: 12)),
            onSelected: (_) => setState(() => _urgencyFilter = u),
            selectedColor: AppColors.primaryLight,
            checkmarkColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        )).toList(),
      ),
    );

    Widget periodChips() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((p) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            selected: _periodFilter == p,
            label:
                Text(periodLabel(p), style: const TextStyle(fontSize: 12)),
            onSelected: (_) => setState(() => _periodFilter = p),
            selectedColor: AppColors.primaryLight,
            checkmarkColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        )).toList(),
      ),
    );

    Widget groupChips() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <String?>[null, ...groups].map((g) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            selected: _groupFilter == g,
            label: Text(groupLabel(g), style: const TextStyle(fontSize: 12)),
            onSelected: (_) => setState(() => _groupFilter = g),
            selectedColor: AppColors.primaryLight,
            checkmarkColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        )).toList(),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filterRow(l10n.issuesFilterByStatus, statusChips(),  isMobile),
            const SizedBox(height: 6),
            _filterRow(l10n.issuesFilterUrgency,  urgencyChips(), isMobile),
            const SizedBox(height: 6),
            _filterRow(l10n.issuesFilterPeriod,   periodChips(),  isMobile),
            const SizedBox(height: 6),
            _filterRow(l10n.issuesFilterGroup,    groupChips(),   isMobile),
            const Divider(height: 16),
            // Footer : compteur + actions
            Row(children: [
              Text(l10n.issuesCount(_filteredIssues.length),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const Spacer(),
              if (isDesktop) ...[
                _buildViewToggle(l10n),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: () => _exportCsv(l10n),
                icon: const Icon(Icons.download, size: 16),
                label: Text(l10n.issuesExportCsv,
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _filterRow(String label, Widget chips, bool isMobile) {
    if (isMobile) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        chips,
      ]);
    }
    return Row(children: [
      SizedBox(
        width: 92,
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: AppColors.textSecondary)),
      ),
      const SizedBox(width: 8),
      Expanded(child: chips),
    ]);
  }

  // ── Toggle Liste / Kanban ───────────────────────────────────────────────────

  Widget _buildViewToggle(AppLocalizations l10n) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _toggleOption(Icons.view_list,   l10n.issuesViewList,   !_isKanban,
          () => setState(() => _isKanban = false)),
      const SizedBox(width: 4),
      _toggleOption(Icons.view_column, l10n.issuesViewKanban,  _isKanban,
          () => setState(() => _isKanban = true)),
    ]);
  }

  Widget _toggleOption(
      IconData icon, String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.transparent,
          border:
              Border.all(color: selected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 15,
              color: selected ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ]),
      ),
    );
  }

  // ── Bannière filtre rapide ──────────────────────────────────────────────────

  Widget _buildActiveFilterBanner(AppLocalizations l10n) {
    final filterLabel = _showOnlyMyIssues
        ? l10n.issuesActiveFilterMyIssues
        : l10n.issuesActiveFilterDeptIssues;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.filter_alt, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${l10n.issuesActiveFilterLabel} $filterLabel',
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: _clearQuickFilter,
          child: Text(l10n.issuesClearFilter,
              style: const TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }

  // ── Export CSV ─────────────────────────────────────────────────────────────

  void _exportCsv(AppLocalizations l10n) {
    final list   = _filteredIssues;
    final buffer = StringBuffer();
    buffer.write('﻿'); // BOM UTF-8
    buffer.writeln([
      'ID', 'Équipement', 'Département', 'Statut', 'Urgence',
      'Groupe', 'Déclarant', 'Date de signalement', 'Description',
    ].map(_csvEsc).join(';'));

    for (final issue in list) {
      buffer.writeln([
        issue.id,
        issue.equipmentName ?? issue.locationId ?? '',
        issue.department,
        issue.status.displayName,
        issue.urgency.displayName,
        issue.assignedGroup ?? '',
        issue.reporter,
        issue.createdAt,
        issue.description,
      ].map(_csvEsc).join(';'));
    }

    final filename =
        'incidents_${DateTime.now().toIso8601String().substring(0, 10)}.csv';
    if (kIsWeb) {
      downloadCsv(buffer.toString(), filename);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.issuesCsvWebOnly),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  static String _csvEsc(String v) {
    if (v.contains(';') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  // ── Onglet "À valider" ──────────────────────────────────────────────────────

  Widget _buildValidationTab(BuildContext context) {
    final l10n     = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final issues   = _openIssuesForValidation;
    final isAdmin  = _authService.currentRoles.contains(UserRole.admin);
    final dept     = _authService.currentUser?.department ?? '';

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
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
                            ]),
                      )
                    : Column(
                        children: issues
                            .map((issue) =>
                                _buildValidationIssueItem(issue, isMobile))
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(issue.department,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
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
              Builder(
                builder: (ctx) => Text(
                  AppLocalizations.of(ctx)!.issueValidationSignaledBy(
                      issue.reporter, issue.createdAt),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ),
              if (issue.assignedGroup != null) ...[
                const SizedBox(height: 6),
                _buildGroupChip(issue.assignedGroup!),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showIssueDetail(issue),
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: Builder(
                      builder: (ctx) => Text(
                          AppLocalizations.of(ctx)!.issueValidationDetails),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isValidating ? null : () => _showValidateDialog(issue),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Builder(
                      builder: (ctx) => Text(
                          AppLocalizations.of(ctx)!.issueValidationValidate),
                    ),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white),
                  ),
                ),
              ]),
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
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
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
                      Builder(
                        builder: (ctx) => Text(
                          AppLocalizations.of(ctx)!
                              .issueValidationSignaledBy(
                                  issue.reporter, issue.createdAt),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ),
                    ]),
              ),
              const SizedBox(width: 16),
              IssueStatusBadge(status: issue.status.displayName),
              if (issue.assignedGroup != null) ...[
                const SizedBox(width: 8),
                _buildGroupChip(issue.assignedGroup!),
              ],
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _showIssueDetail(issue),
                icon: const Icon(Icons.info_outline, size: 16),
                label: Builder(
                  builder: (ctx) => Text(
                      AppLocalizations.of(ctx)!.issueValidationDetails),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed:
                    _isValidating ? null : () => _showValidateDialog(issue),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Builder(
                  builder: (ctx) => Text(
                      AppLocalizations.of(ctx)!.issueValidationValidate),
                ),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white),
              ),
            ]),
    );
  }

  void _showValidateDialog(Issue issue) {
    final l10n = AppLocalizations.of(context)!;
    IssueUrgency selectedUrgency = issue.urgency;
    String? selectedGroup = issue.assignedGroup;
    const groups = ['Biomédical', 'IT', 'Infrastructure'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.issueValidationConfirmTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.issueValidationConfirmContent),
                const SizedBox(height: 8),
                Text(issue.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(issue.description,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),

                // Groupe technique
                Text(l10n.issueValidationGroupLabel,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedGroup,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: groups.map((g) {
                    final meta = _groupMeta(g, l10n);
                    return DropdownMenuItem<String>(
                      value: g,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(meta.icon, size: 16, color: meta.color),
                        const SizedBox(width: 8),
                        Text(meta.label),
                      ]),
                    );
                  }).toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedGroup = v),
                ),
                if (selectedGroup != null &&
                    selectedGroup != issue.assignedGroup)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(l10n.issueValidationRedirectLabel,
                          style: const TextStyle(
                              color: AppColors.warning, fontSize: 12)),
                    ]),
                  ),

                const SizedBox(height: 16),
                // Urgence
                Text(l10n.issueValidationUrgencyLabel,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: IssueUrgency.values.map((u) {
                    final sel = selectedUrgency == u;
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedUrgency = u),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? _urgencyColorFor(u).withValues(alpha: 0.15)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: sel
                                ? _urgencyColorFor(u)
                                : AppColors.border,
                            width: sel ? 2 : 1,
                          ),
                        ),
                        child: UrgencyBadge(urgency: u, isCompact: true),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.issueValidationConfirmMessage,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _validateIssue(issue,
                    urgency: selectedUrgency, newGroup: selectedGroup);
              },
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(l10n.commonSave),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Color _urgencyColorFor(IssueUrgency u) {
    switch (u) {
      case IssueUrgency.faible:   return AppColors.textSecondary;
      case IssueUrgency.moyen:    return AppColors.warning;
      case IssueUrgency.urgent:   return AppColors.error;
      case IssueUrgency.critique: return AppColors.critical;
    }
  }

  ({Color color, IconData icon, String label}) _groupMeta(
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

  Widget _buildGroupChip(String group) {
    final l10n = AppLocalizations.of(context)!;
    final meta = _groupMeta(group, l10n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: meta.color.withValues(alpha: 0.4)),
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

  Future<void> _validateIssue(Issue issue,
      {IssueUrgency? urgency, String? newGroup}) async {
    setState(() => _isValidating = true);
    try {
      await DbApiService.instance.updateIssue(issue.id, {
        'status': 'Acknowledged',
        if (urgency != null) 'urgency': urgency.displayName,
        if (newGroup != null && newGroup != issue.assignedGroup)
          'assigned_group': newGroup,
      });
      await DataService().reloadIssues();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.issueValidationSuccess(issue.displayName)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              l10n.issueValidationError(l10n.commonApiError)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  // ── Encadré "Mes incidents" ─────────────────────────────────────────────────

  Widget _buildPersonalCard(AppLocalizations l10n) {
    final myIssues   = _myIssues;
    const maxVisible = 3;

    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.person_outline,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.issuesMyIssues,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary)),
                    Text(l10n.issuesMyIssuesSubtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Text('${myIssues.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ),
          ]),
        ),
        const Divider(height: 1),
        if (myIssues.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text(l10n.issuesNoMyIssues,
                  style:
                      const TextStyle(color: AppColors.textSecondary)),
            ]),
          )
        else ...[
          ...myIssues.take(maxVisible).map(_buildCompactIssueRow),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              if (myIssues.length > maxVisible)
                Text(
                  l10n.issuesAndMore(myIssues.length - maxVisible),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setState(() {
                  _showOnlyMyIssues   = true;
                  _showOnlyDeptIssues = false;
                }),
                icon: const Icon(Icons.chevron_right, size: 14),
                label: Text(l10n.issuesViewSeeAll,
                    style: const TextStyle(fontSize: 12)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── Encadré "Incidents de mon département" ──────────────────────────────────

  Widget _buildDeptCard(AppLocalizations l10n) {
    final deptIssues = _deptIssues;
    final dept       = _authService.currentUser?.department ?? '';
    const maxVisible = 3;

    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.business_outlined,
                  color: AppColors.warning, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.issuesDeptIssues,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary)),
                    Text(
                      dept.isNotEmpty
                          ? l10n.issuesDeptIssuesSubtitle(dept)
                          : l10n.issuesNoDeptIssues,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Text('${deptIssues.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning)),
            ),
          ]),
        ),
        const Divider(height: 1),
        if (deptIssues.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text(l10n.issuesNoDeptIssues,
                  style:
                      const TextStyle(color: AppColors.textSecondary)),
            ]),
          )
        else ...[
          ...deptIssues.take(maxVisible).map(_buildCompactIssueRow),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              if (deptIssues.length > maxVisible)
                Text(
                  l10n.issuesAndMore(deptIssues.length - maxVisible),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setState(() {
                  _showOnlyDeptIssues = true;
                  _showOnlyMyIssues   = false;
                }),
                icon: const Icon(Icons.chevron_right, size: 14),
                label: Text(l10n.issuesViewSeeAll,
                    style: const TextStyle(fontSize: 12)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── Ligne compacte dans les encadrés ──────────────────────────────────────

  Widget _buildCompactIssueRow(Issue issue) {
    final isSelected = issue.id == _selectedIssueId;
    return InkWell(
      onTap: () => _showIssueDetail(issue),
      child: Container(
        color: isSelected ? AppColors.primaryLight : null,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: _getStatusColor(issue.status),
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(issue.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13)),
                  Text(
                    issue.description,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IssueStatusBadge(status: issue.status.displayName),
            const SizedBox(height: 2),
            UrgencyBadge(urgency: issue.urgency, isCompact: true),
          ]),
        ]),
      ),
    );
  }

  // ── Ligne complète dans la liste principale ────────────────────────────────

  Widget _buildMiniStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$count',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildIssueItem(Issue issue) {
    final l10n       = AppLocalizations.of(context)!;
    final isSelected = issue.id == _selectedIssueId;
    return InkWell(
      onTap: () => _showIssueDetail(issue),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : null,
          border:
              const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getStatusColor(issue.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.warning_amber_rounded,
                color: _getStatusColor(issue.status), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(issue.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(issue.description,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    l10n.issuesReportedByDate(
                        issue.reporter, issue.createdAt),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ]),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IssueStatusBadge(status: issue.status.displayName),
            const SizedBox(height: 4),
            UrgencyBadge(urgency: issue.urgency, isCompact: true),
          ]),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textMuted),
        ]),
      ),
    );
  }

  Color _getStatusColor(IssueStatus status) {
    switch (status) {
      case IssueStatus.reported:         return AppColors.error;
      case IssueStatus.acknowledged:     return AppColors.primary;
      case IssueStatus.assigned:         return AppColors.primary;
      case IssueStatus.inProgress:       return AppColors.warning;
      case IssueStatus.waitingMaterials: return AppColors.warning;
      case IssueStatus.completed:        return AppColors.success;
      case IssueStatus.verified:         return AppColors.success;
      case IssueStatus.closed:           return AppColors.textSecondary;
      case IssueStatus.redirected:       return AppColors.primary;
    }
  }

  // ── Navigation vers le détail ──────────────────────────────────────────────

  void _showIssueDetail(Issue issue) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    if (isDesktop) {
      // Mode Split View : mise à jour du panneau droit
      setState(() => _selectedIssueId = issue.id);
    } else {
      // Mode Mobile : navigation plein écran
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IssueDetailScreen(
            issueId:    issue.id,
            onNavigate: widget.onNavigate,
          ),
        ),
      );
    }
  }
}
