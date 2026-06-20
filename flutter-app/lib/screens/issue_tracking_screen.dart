import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../models/issue.dart';
import '../models/user_role.dart';
import '../widgets/status_badge.dart';
import '../widgets/urgency_badge.dart';
import '../widgets/issue_category_selector.dart';
import '../utils/csv_export.dart';
import 'issue_detail_screen.dart';
import 'issue_staff_detail_screen.dart';

// Filtre période
enum _PeriodFilter { all, last7Days, last30Days }

/// Écran de suivi des incidents en 3 onglets (Mes signalements / Tous les
/// incidents actifs / Terminés) avec recherche globale, filtres avancés,
/// tri par urgence et export CSV. Un clic sur un incident ouvre toujours la
/// page de détail en plein écran (lecture seule staff ou édition technicien).
class IssueTrackingScreen extends StatefulWidget {
  final Function(int, {String? issueId}) onNavigate;

  const IssueTrackingScreen({super.key, required this.onNavigate});

  @override
  State<IssueTrackingScreen> createState() => _IssueTrackingScreenState();
}

class _IssueTrackingScreenState extends State<IssueTrackingScreen>
    with TickerProviderStateMixin {

  // ── Services ───────────────────────────────────────────────────────────────
  final AuthService _authService = AuthService();

  // ── Onglets ────────────────────────────────────────────────────────────────
  late final TabController _tabController;

  // ── Filtres avancés (appliqués à l'onglet actif) ───────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  IssueUrgency? _urgencyFilter;
  String? _groupFilter;
  _PeriodFilter _periodFilter = _PeriodFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Rebuild du footer (compteur + export) une fois l'onglet stabilisé —
    // le garde indexIsChanging évite un setState à chaque frame du swipe.
    _tabController.addListener(() {
      if (mounted && !_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Sources des onglets ────────────────────────────────────────────────────

  /// Onglet 0 — signalements de l'utilisateur courant.
  List<Issue> get _tabMine {
    final user = _authService.currentUser;
    if (user == null) return [];
    return DataService().issues.where((i) {
      if (i.reporterId != null && i.reporterId!.isNotEmpty) {
        return i.reporterId == user.id;
      }
      return i.reporter == user.name;
    }).toList();
  }

  /// Onglet 1 — tous les incidents SAUF les terminés.
  List<Issue> get _tabAll =>
      DataService().issues.where((i) => i.status != IssueStatus.completed).toList();

  /// Onglet 2 — incidents terminés uniquement.
  List<Issue> get _tabCompleted =>
      DataService().issues.where((i) => i.status == IssueStatus.completed).toList();

  // ── Application des filtres + tri sur la liste de base d'un onglet ──────────

  List<Issue> _applyFilters(List<Issue> base) {
    var source = List<Issue>.from(base);

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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n      = AppLocalizations.of(context)!;
    final isMobile  = MediaQuery.of(context).size.width < AppBreakpoints.tablet;

    // Listes filtrées de chaque onglet (recherche + filtres appliqués).
    final mine      = _applyFilters(_tabMine);
    final all       = _applyFilters(_tabAll);
    final completed = _applyFilters(_tabCompleted);
    final tabLists  = [mine, all, completed];
    final active    = tabLists[_tabController.index];

    final pad = isMobile ? 16.0 : 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête + recherche + filtres ──────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(l10n, isMobile),
              const SizedBox(height: 16),
              _buildSearchBar(l10n),
              const SizedBox(height: 12),
              _buildFilterCard(l10n, isMobile, active),
            ],
          ),
        ),

        // ── Onglets ─────────────────────────────────────────────────────
        TabBar(
          controller: _tabController,
          isScrollable: isMobile,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: '${l10n.issuesTabMine} (${mine.length})'),
            Tab(text: '${l10n.issuesTabAll} (${all.length})'),
            Tab(text: '${l10n.issuesTabCompleted} (${completed.length})'),
          ],
        ),

        // ── Contenu des onglets ─────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildIssueList(mine,      l10n, isMobile),
              _buildIssueList(all,       l10n, isMobile),
              _buildIssueList(completed, l10n, isMobile),
            ],
          ),
        ),
      ],
    );
  }

  // ── En-tête : titre + bouton « Signaler un incident » ──────────────────────

  Widget _buildHeader(AppLocalizations l10n, bool isMobile) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.issuesTitle,
            style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(l10n.issuesSubtitle,
            style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );

    final reportButton = ElevatedButton.icon(
      onPressed: () => showIssueCategorySelector(context),
      icon: const Icon(Icons.add, size: 18),
      label: Text(l10n.issuesReport),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBlock,
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: reportButton),
        ],
      );
    }

    return Row(children: [
      Expanded(child: titleBlock),
      reportButton,
    ]);
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

  // ── Carte de filtres avancés (urgence / période / groupe) ────────────────────

  Widget _buildFilterCard(
      AppLocalizations l10n, bool isMobile, List<Issue> exportList) {
    final urgencies = <IssueUrgency?>[null, ...IssueUrgency.values];
    const groups    = <String?>['Biomédical', 'IT', 'Infrastructure'];
    const periods   = <_PeriodFilter>[
      _PeriodFilter.all,
      _PeriodFilter.last7Days,
      _PeriodFilter.last30Days
    ];

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
            _filterRow(l10n.issuesFilterUrgency, urgencyChips(), isMobile),
            const SizedBox(height: 6),
            _filterRow(l10n.issuesFilterPeriod,  periodChips(),  isMobile),
            const SizedBox(height: 6),
            _filterRow(l10n.issuesFilterGroup,   groupChips(),   isMobile),
            const Divider(height: 16),
            // Footer : compteur de l'onglet actif + export CSV
            Row(children: [
              Text(l10n.issuesCount(exportList.length),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _exportCsv(l10n, exportList),
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

  // ── Liste d'incidents (fonction unique réutilisée par les 3 onglets) ─────────

  Widget _buildIssueList(
      List<Issue> issues, AppLocalizations l10n, bool isMobile) {
    final pad = isMobile ? 16.0 : 24.0;

    if (issues.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Text(l10n.issuesNoMyIssues,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, pad),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: issues.length,
          itemBuilder: (_, i) => _buildIssueItem(issues[i], l10n),
        ),
      ),
    );
  }

  // ── Export CSV ─────────────────────────────────────────────────────────────

  void _exportCsv(AppLocalizations l10n, List<Issue> list) {
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

  // ── Ligne d'incident dans la liste ──────────────────────────────────────────

  Widget _buildIssueItem(Issue issue, AppLocalizations l10n) {
    final isCompleted = issue.status == IssueStatus.completed;
    // Onglet Terminés : afficher la date de résolution plutôt que le signalement.
    final dateLine = isCompleted
        ? l10n.issuesResolvedOn(_resolutionDate(issue))
        : l10n.issuesReportedByDate(issue.reporter, issue.createdAt);

    return InkWell(
      onTap: () => _showIssueDetail(issue),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
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
                    dateLine,
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
          const Icon(Icons.chevron_right,
              size: 18, color: AppColors.textMuted),
        ]),
      ),
    );
  }

  /// Date affichée sur l'onglet Terminés : la date de résolution si elle existe,
  /// sinon repli sur la date de création (incidents antérieurs à la migration
  /// `resolved_at`). Jamais une chaîne vide ni « null ».
  String _resolutionDate(Issue issue) {
    final r = issue.resolvedAt;
    if (r != null && r.isNotEmpty) return r;
    return issue.createdAt;
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

  // ── Navigation vers le détail (plein écran, RBAC conservé) ──────────────────

  void _showIssueDetail(Issue issue) {
    // Techniciens / superviseurs / admins → vue complète éditable.
    final canEdit = _authService.hasPermission(Permission.updateRepairs) ||
                    _authService.hasPermission(Permission.approveRequests) ||
                    _authService.hasPermission(Permission.manageEquipment);

    if (!canEdit) {
      // hospitalStaff → vue lecture seule.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IssueStaffDetailScreen(issue: issue),
        ),
      );
    } else {
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
