import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import '../l10n/app_localizations.dart';
import '../models/equipment.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/equipment_filter_state.dart';
import '../theme/app_theme.dart';
import '../utils/csv_export.dart';
import '../widgets/status_badge.dart';
import '../widgets/replacement_badge.dart';
import '../widgets/pagination_footer.dart';
import 'equipment_detail_screen.dart';
import 'equipment_form_screen.dart';

// ── Colonnes triables ──────────────────────────────────────────────────────
enum _SortCol { name, status, department, installDate }

// ══════════════════════════════════════════════════════════════════════════════
// Widget de scan QR (bottom-sheet, toutes plateformes via mobile_scanner)
// ══════════════════════════════════════════════════════════════════════════════

class _QrScanSheet extends StatefulWidget {
  const _QrScanSheet();

  @override
  State<_QrScanSheet> createState() => _QrScanSheetState();
}

class _QrScanSheetState extends State<_QrScanSheet> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final height = MediaQuery.of(context).size.height * 0.6;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
            child: Row(children: [
              const Icon(Icons.qr_code_scanner, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.equipmentScanQrTitle,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Expanded(
            child: ClipRRect(
              child: MobileScanner(
                onDetect: (capture) {
                  if (_done) return;
                  final raw = capture.barcodes.firstOrNull?.rawValue;
                  if (raw != null && raw.isNotEmpty) {
                    _done = true;
                    Navigator.pop(context, raw);
                  }
                },
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ''),
            icon: const Icon(Icons.keyboard, color: Colors.white70, size: 18),
            label: Text(AppLocalizations.of(context)!.equipmentScanQrManualTitle,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dialog de saisie manuelle d'identifiant (fallback QR)
// ══════════════════════════════════════════════════════════════════════════════

class _ManualIdDialog extends StatefulWidget {
  const _ManualIdDialog();

  @override
  State<_ManualIdDialog> createState() => _ManualIdDialogState();
}

class _ManualIdDialogState extends State<_ManualIdDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.equipmentScanQrManualTitle),
      content: TextField(
        controller: _ctrl,
        decoration: InputDecoration(hintText: l10n.equipmentScanQrManualHint),
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Écran principal
// ══════════════════════════════════════════════════════════════════════════════

/// Écran principal de liste des équipements.
///
/// Filtres persistants via [EquipmentFilterState], vue grille/liste adaptative,
/// colonnes RBAC, alertes PM inline, export CSV mobile (share_plus), scan QR.
class EquipmentListScreen extends StatefulWidget {
  final Function(int, {String? equipmentId}) onNavigate;

  // Filtres pré-appliqués depuis le dashboard (prioritaires sur l'état sauvegardé)
  final EquipmentStatus? initialStatus;
  final bool initialPmOverdue;
  final String? initialMacroCategory;

  const EquipmentListScreen({
    super.key,
    required this.onNavigate,
    this.initialStatus,
    this.initialPmOverdue = false,
    this.initialMacroCategory,
  });

  @override
  State<EquipmentListScreen> createState() => _EquipmentListScreenState();
}

class _EquipmentListScreenState extends State<EquipmentListScreen> {
  // ── Filtres textuels / dropdown ────────────────────────────────────────
  String  _searchTerm       = '';
  String  _departmentFilter = '';
  String  _statusFilter     = '';
  String  _categoryFilter   = '';
  String? _macroCategoryFilter;
  String? _locationFilter;

  // ── Filtres PM ─────────────────────────────────────────────────────────
  bool _filterPmOverdue = false;
  bool _filterPmSoon    = false;

  // ── Cycle de vie : affichage des équipements réformés (Disposed) ─────────
  // Exclus du serveur par défaut ; ?include_disposed=true lève l'exclusion
  // sur la page courante (pagination serveur, pas de fusion client).
  bool _showDisposed = false;

  // ── Tri ────────────────────────────────────────────────────────────────
  _SortCol _sortCol = _SortCol.name;
  bool     _sortAsc = true;

  // ── Mode d'affichage ───────────────────────────────────────────────────
  bool _isGridView = false;

  // ── Pagination serveur ─────────────────────────────────────────────────
  static const int _pageSize = 20;
  int _currentPage = 1;
  PagedResult<Equipment>? _pagedResult;
  bool _isLoadingPage = false;

  // ── Contrôleur de recherche (restaure le texte après rebuild) ─────────
  late final TextEditingController _searchCtrl;

  // ── Plan de remplacement biomédical (RA3 S5) ─────────────────────────────
  // Map equipment.id → item du plan (status_replacement, age, lifespan, …).
  // Chargé uniquement pour les rôles autorisés (admin/supervisor) ; les badges
  // n'apparaissent donc que pour ces rôles.
  Map<String, Map<String, dynamic>> _replacementByEqId = {};

  final _auth = AuthService();

  // ── RBAC ───────────────────────────────────────────────────────────────

  /// true → admin ou tout technicien (vue technique enrichie)
  bool get _showTechnicalView =>
      _auth.canManageEquipment || _auth.canUpdateRepairs;

  /// true → technicien pur (pas admin) → colonnes PM spécifiques
  bool get _isTechnician =>
      _auth.canUpdateRepairs && !_auth.canManageEquipment;

  /// true → peut accéder au formulaire d'édition (admin + techniciens) ;
  /// même périmètre pour l'import CSV en masse.
  bool get _canEdit =>
      _auth.canManageEquipment || _auth.canUpdateRepairs;

  // ── Cycle de vie ───────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // 1. Restaurer l'état sauvegardé en session
    final s = EquipmentFilterState();
    _searchTerm          = s.searchTerm;
    _departmentFilter    = s.departmentFilter;
    _statusFilter        = s.statusFilter;
    _categoryFilter      = s.categoryFilter;
    _macroCategoryFilter = s.macroCategoryFilter;
    _locationFilter      = s.locationFilter;
    _filterPmOverdue     = s.filterPmOverdue;
    _filterPmSoon        = s.filterPmSoon;
    _sortCol = _SortCol.values[s.sortColIndex.clamp(0, _SortCol.values.length - 1)];
    _sortAsc             = s.sortAsc;
    _isGridView          = s.isGridView;
    _searchCtrl          = TextEditingController(text: _searchTerm);

    // 2. Les params widget (navigation depuis dashboard) écrasent le state
    if (widget.initialStatus != null) {
      _statusFilter = widget.initialStatus!.displayName;
    }
    if (widget.initialPmOverdue) _filterPmOverdue = true;
    if (widget.initialMacroCategory != null) {
      _macroCategoryFilter = widget.initialMacroCategory;
    }

    // 3. Charger le plan de remplacement (badges triangle) — admin/supervisor.
    if (_auth.canGenerateReports) {
      _loadReplacementPlan();
    }

    // 4. Première page (pagination serveur)
    _fetchPage();
  }

  /// Mappe la colonne de tri UI vers le paramètre `sort_by` serveur.
  String get _sortByParam {
    switch (_sortCol) {
      case _SortCol.name:        return 'name';
      case _SortCol.status:      return 'status';
      case _SortCol.department:  return 'department';
      case _SortCol.installDate: return 'install_date';
    }
  }

  /// Récupère la page courante depuis le serveur avec les filtres actifs.
  /// [resetPage] : remet la pagination à la page 1 (changement de filtre/tri).
  Future<void> _fetchPage({bool resetPage = false}) async {
    if (resetPage) _currentPage = 1;
    final l10n = AppLocalizations.of(context)!;
    final all  = l10n.commonAll;

    setState(() => _isLoadingPage = true);
    try {
      final result = await DbApiService.instance.getEquipmentPaged(
        page: _currentPage,
        limit: _pageSize,
        search: _searchTerm.isEmpty ? null : _searchTerm,
        sortBy: _sortByParam,
        sortDir: _sortAsc ? 'asc' : 'desc',
        department: _departmentFilter == all ? null : _departmentFilter,
        status: _statusFilter == all ? null : _statusFilter,
        category: _categoryFilter == all ? null : _categoryFilter,
        macroCategory: _macroCategoryFilter,
        includeDisposed: _showDisposed,
      );
      if (mounted) {
        setState(() {
          _pagedResult  = result;
          _isLoadingPage = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPage = false);
    }
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page);
    _fetchPage();
  }

  /// Récupère le plan de remplacement et indexe les items par equipment.id.
  /// Échec silencieux : les badges sont une aide, pas une fonction bloquante.
  Future<void> _loadReplacementPlan() async {
    try {
      final plan  = await DbApiService.instance.getReplacementPlan();
      final items = (plan['items'] as List?) ?? const [];
      final map = <String, Map<String, dynamic>>{};
      for (final it in items) {
        final m = it as Map<String, dynamic>;
        map[m['id'] as String] = m;
      }
      if (mounted) setState(() => _replacementByEqId = map);
    } catch (_) {
      // Ignoré : pas de badge si le plan n'est pas disponible.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    // Résout '' → valeur par défaut localisée (uniquement au premier appel)
    if (_departmentFilter.isEmpty) _departmentFilter = l10n.commonAll;
    if (_statusFilter.isEmpty)     _statusFilter     = l10n.commonAll;
    if (_categoryFilter.isEmpty)   _categoryFilter   = l10n.commonAll;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Persistance session ────────────────────────────────────────────────

  void _saveFilters({bool resetPage = false}) {
    final s = EquipmentFilterState();
    s.searchTerm          = _searchTerm;
    s.departmentFilter    = _departmentFilter;
    s.statusFilter        = _statusFilter;
    s.categoryFilter      = _categoryFilter;
    s.macroCategoryFilter = _macroCategoryFilter;
    s.locationFilter      = _locationFilter;
    s.filterPmOverdue     = _filterPmOverdue;
    s.filterPmSoon        = _filterPmSoon;
    s.sortColIndex        = _sortCol.index;
    s.sortAsc             = _sortAsc;
    s.isGridView          = _isGridView;
    // Tout changement de filtre/tri/recherche réinitialise la pagination serveur à la page 1.
    if (resetPage) _fetchPage(resetPage: true);
  }

  // ── Sources de données pour les dropdowns ──────────────────────────────

  List<String> _departments(String all) =>
      [all, ...DataService().equipment.map((e) => e.department).toSet()];

  List<String> _statuses(String all) =>
      [all, ...EquipmentStatus.values.map((s) => s.displayName)];

  List<String> _categories(String all) =>
      [all, ...DataService().equipment.map((e) => e.category).toSet()];

  /// Localisations distinctes du département courant (filtre "Mon unité")
  List<String> _availableUnits(String all) {
    final dept = _departmentFilter;
    final allLabel = AppLocalizations.of(context)!.commonAll;
    final data = DataService().equipment;
    final src = (dept == allLabel || dept.isEmpty)
        ? data
        : data.where((e) => e.department == dept);
    final units = src
        .map((e) => e.location)
        .where((loc) => loc.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return [all, ...units];
  }

  // ── Liste de la page courante (serveur) + filtres client-only ───────────
  //
  // department/status/category/macroCategory/search/tri sont appliqués côté
  // serveur (getEquipmentPaged). filterPmOverdue/filterPmSoon et locationFilter
  // (réservé hospitalStaff) restent appliqués côté client UNIQUEMENT sur la
  // page reçue, car non supportés par l'API — ils ne filtrent donc que les
  // 20 éléments de la page courante, pas l'ensemble du parc (limitation
  // documentée, hors scope d'ajouter ces filtres serveur).
  List<Equipment> get _filteredEquipment {
    final source = _pagedResult?.items ?? const <Equipment>[];

    return source.where((eq) {
      bool matchPm = true;
      if (_filterPmOverdue || _filterPmSoon) {
        final level = eq.preventiveMaintenanceAlertLevel;
        matchPm = (_filterPmOverdue && level == 'due') ||
                  (_filterPmSoon    && level == 'soon');
      }

      final matchLocation = _locationFilter == null ||
          eq.location.toLowerCase() == _locationFilter!.toLowerCase();

      return matchPm && matchLocation;
    }).toList();
  }

  /// Liste complète filtrée pour l'export CSV (indépendante de la pagination
  /// serveur — l'export doit couvrir tout le parc correspondant aux filtres,
  /// pas seulement la page de 20 affichée à l'écran). S'appuie sur le cache
  /// complet [DataService] avec la même logique de filtrage que l'écran.
  List<Equipment> get _filteredEquipmentForExport {
    final l10n = AppLocalizations.of(context)!;
    final term = _searchTerm.toLowerCase();
    final all  = l10n.commonAll;

    var list = DataService().equipment.where((eq) {
      final matchSearch = term.isEmpty ||
          eq.name.toLowerCase().contains(term) ||
          eq.serialNumber.toLowerCase().contains(term) ||
          (eq.manufacturer?.toLowerCase().contains(term) ?? false) ||
          (eq.model?.toLowerCase().contains(term) ?? false);

      final matchDept   = _departmentFilter == all || eq.department == _departmentFilter;
      final matchStatus = _statusFilter     == all || eq.status.displayName == _statusFilter;
      final matchCat    = _categoryFilter   == all || eq.category == _categoryFilter;

      bool matchPm = true;
      if (_filterPmOverdue || _filterPmSoon) {
        final level = eq.preventiveMaintenanceAlertLevel;
        matchPm = (_filterPmOverdue && level == 'due') ||
                  (_filterPmSoon    && level == 'soon');
      }

      final matchMacro = _macroCategoryFilter == null ||
          (eq.macroCategory?.toLowerCase() == _macroCategoryFilter!.toLowerCase());

      final matchLocation = _locationFilter == null ||
          eq.location.toLowerCase() == _locationFilter!.toLowerCase();

      return matchSearch && matchDept && matchStatus && matchCat &&
             matchPm && matchMacro && matchLocation;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case _SortCol.name:        cmp = a.name.compareTo(b.name);
        case _SortCol.status:      cmp = a.status.index.compareTo(b.status.index);
        case _SortCol.department:  cmp = a.department.compareTo(b.department);
        case _SortCol.installDate: cmp = (a.installDate ?? '').compareTo(b.installDate ?? '');
      }
      return _sortAsc ? cmp : -cmp;
    });

    return list;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build principal
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n     = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < AppBreakpoints.tablet;
    final visible  = _filteredEquipment;
    final total    = _pagedResult?.total ?? 0;
    final totalPages = _pagedResult?.totalPages ?? 1;

    return CustomScrollView(
      slivers: [
        // En-tête
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, isMobile ? 16 : 24, isMobile ? 16 : 24, 0),
          sliver: SliverToBoxAdapter(child: _buildHeader(l10n, isMobile)),
        ),

        // Chips de filtres rapides
        SliverPadding(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24, vertical: 12),
          sliver: SliverToBoxAdapter(child: _buildFilterChips(l10n)),
        ),

        // Barre recherche + dropdowns
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
          sliver: SliverToBoxAdapter(child: _buildSearchBar(l10n, isMobile)),
        ),

        // Compteur (total serveur) + sélecteur de tri (mobile)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 0),
          sliver: SliverToBoxAdapter(
              child: _buildCountAndSort(l10n, total, isMobile)),
        ),

        // En-têtes de colonnes triables (desktop, vue liste uniquement)
        if (!isMobile && !_isGridView)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            sliver: SliverToBoxAdapter(child: _buildTableHeader(l10n)),
          ),

        // Lignes virtualisées (liste ou grille) — page courante (serveur)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, isMobile ? 8 : 4,
              isMobile ? 16 : 24, 0),
          sliver: _isLoadingPage && visible.isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              : visible.isEmpty
                  ? SliverToBoxAdapter(child: _buildEmptyState(l10n))
                  : (!isMobile && _isGridView)
                      ? SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            mainAxisExtent: 185,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildGridCard(visible[i], l10n),
                            childCount: visible.length,
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => isMobile
                                ? _buildMobileCard(visible[i], l10n)
                                : _buildDesktopRow(visible[i], l10n),
                            childCount: visible.length,
                          ),
                        ),
        ),

        // Pied de pagination serveur : Précédent / Page X sur Y / Suivant
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, 8, isMobile ? 16 : 24, isMobile ? 16 : 24),
          sliver: SliverToBoxAdapter(
            child: total == 0
                ? const SizedBox.shrink()
                : Center(
                    child: PaginationFooter(
                      currentPage: _currentPage,
                      totalPages: totalPages,
                      isLoading: _isLoadingPage,
                      onPageChange: _goToPage,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // En-tête
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(AppLocalizations l10n, bool isMobile) {
    final canExportCsv = _auth.canManageOperations;
    final exportBtn = canExportCsv
        ? OutlinedButton.icon(
            onPressed: () => _exportCsv(l10n),
            icon: const Icon(Icons.download, size: 18),
            label: Text(l10n.equipmentExportCsv),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          )
        : null;

    final addBtn = _auth.canManageEquipment
        ? ElevatedButton.icon(
            onPressed: _addEquipment,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.equipmentNew),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          )
        : null;

    final importCsvBtn = _canEdit
        ? OutlinedButton.icon(
            onPressed: _openImportCsvDialog,
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(l10n.equipmentImportCsvButton),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          )
        : null;

    final qrBtn = IconButton(
      icon: const Icon(Icons.qr_code_scanner),
      onPressed: _scanQr,
      tooltip: l10n.equipmentScanQrTooltip,
      color: AppColors.textSecondary,
    );

    // Actualiser : recharge la page courante (sans la remettre à 1).
    final refreshBtn = IconButton(
      icon: _isLoadingPage
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh),
      onPressed: _isLoadingPage ? null : () => _fetchPage(),
      tooltip: l10n.dashboardRefreshTooltip,
      color: AppColors.textSecondary,
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(l10n.equipmentTitle,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ),
            refreshBtn,
            qrBtn,
          ]),
          const SizedBox(height: 2),
          Text(l10n.equipmentSubtitle,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            if (addBtn != null) ...[Expanded(child: addBtn), const SizedBox(width: 8)],
            if (exportBtn != null) Expanded(child: exportBtn),
          ]),
          if (importCsvBtn != null) ...[
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: importCsvBtn),
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.equipmentTitle,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(l10n.equipmentSubtitle,
              style: const TextStyle(color: AppColors.textSecondary)),
        ]),
        Row(children: [
          if (exportBtn != null) ...[exportBtn, const SizedBox(width: 4)],
          // Toggle vue grille / liste (desktop seulement)
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() {
              _isGridView = !_isGridView;
              _saveFilters();
            }),
            tooltip: _isGridView ? l10n.equipmentViewList : l10n.equipmentViewGrid,
            color: AppColors.textSecondary,
          ),
          refreshBtn,
          qrBtn,
          if (importCsvBtn != null) ...[const SizedBox(width: 4), importCsvBtn],
          if (addBtn != null) ...[const SizedBox(width: 4), addBtn],
        ]),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Chips de filtres rapides
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFilterChips(AppLocalizations l10n) {
    final myDept      = _auth.currentUser?.department ?? '';
    final deptSelected = _departmentFilter == myDept && myDept.isNotEmpty;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        // Mon département
        FilterChip(
          label: Text(myDept.isNotEmpty ? myDept : l10n.commonDepartment),
          avatar: const Icon(Icons.business, size: 16),
          selected: deptSelected,
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          checkmarkColor: AppColors.primary,
          onSelected: (v) => setState(() {
            _departmentFilter = v ? myDept : l10n.commonAll;
            _saveFilters(resetPage: true);
          }),
        ),

        // Filtre macroCategory actif (effaçable)
        if (_macroCategoryFilter != null)
          FilterChip(
            label: Text(_macroCategoryFilter!),
            avatar: const Icon(Icons.category_outlined, size: 16),
            selected: true,
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            checkmarkColor: AppColors.primary,
            deleteIcon: const Icon(Icons.close, size: 14),
            onDeleted: () => setState(() {
              _macroCategoryFilter = null;
              _saveFilters(resetPage: true);
            }),
            onSelected: (_) {},
          ),

        // Filtre unité actif (hospitalStaff — effaçable)
        if (_locationFilter != null)
          FilterChip(
            label: Text(_locationFilter!),
            avatar: const Icon(Icons.room_outlined, size: 16),
            selected: true,
            selectedColor: AppColors.success.withValues(alpha: 0.15),
            checkmarkColor: AppColors.success,
            deleteIcon: const Icon(Icons.close, size: 14),
            // Filtre unité client-only : appliqué sur la page courante (non supporté serveur).
            onDeleted: () => setState(() {
              _locationFilter = null;
              _saveFilters();
            }),
            onSelected: (_) {},
          ),

        // Filtres PM (techniciens / superviseurs)
        if (_showTechnicalView) ...[
          FilterChip(
            label: Text(l10n.equipmentFilterPmOverdueChip),
            avatar: const Icon(Icons.error_outline, size: 16),
            selected: _filterPmOverdue,
            selectedColor: AppColors.error.withValues(alpha: 0.15),
            checkmarkColor: AppColors.error,
            // Filtre PM client-only : appliqué sur la page courante uniquement
            // (non supporté côté serveur, cf. CLAUDE.md/spec — pas de refetch).
            onSelected: (v) => setState(() {
              _filterPmOverdue = v;
              _saveFilters();
            }),
          ),
          FilterChip(
            label: Text(l10n.equipmentFilterPmSoonChip),
            avatar: const Icon(Icons.schedule, size: 16),
            selected: _filterPmSoon,
            selectedColor: AppColors.warning.withValues(alpha: 0.15),
            checkmarkColor: AppColors.warning,
            // Filtre PM client-only : appliqué sur la page courante uniquement.
            onSelected: (v) => setState(() {
              _filterPmSoon = v;
              _saveFilters();
            }),
          ),
          // Afficher les équipements réformés : lève l'exclusion par défaut
          // côté serveur sur la page courante (?include_disposed=true).
          FilterChip(
            label: Text(l10n.equipmentFilterShowDisposed),
            avatar: const Icon(Icons.delete_sweep_outlined, size: 16),
            selected: _showDisposed,
            selectedColor: AppColors.textMuted.withValues(alpha: 0.2),
            checkmarkColor: AppColors.textSecondary,
            onSelected: (v) => setState(() {
              _showDisposed = v;
              _saveFilters(resetPage: true);
            }),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Barre de recherche + dropdowns
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSearchBar(AppLocalizations l10n, bool isMobile) {
    final all = l10n.commonAll;

    // Dropdown "Mon unité / Ma salle" — réservé au personnel hospitalier
    final unitDropdown = !_showTechnicalView
        ? _dropdown(
            l10n.equipmentFilterUnit,
            _locationFilter ?? all,
            _availableUnits(all),
            // Filtre unité client-only : appliqué sur la page courante (non supporté serveur).
            (v) => setState(() {
              _locationFilter = (v == all) ? null : v;
              _saveFilters();
            }),
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isMobile
            ? Column(children: [
                _searchField(l10n),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _dropdown(l10n.commonDepartment, _departmentFilter,
                          _departments(all), (v) => setState(() {
                            _departmentFilter = v!;
                            _saveFilters(resetPage: true);
                          }))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _dropdown(l10n.commonStatus, _statusFilter,
                          _statuses(all), (v) => setState(() {
                            _statusFilter = v!;
                            _saveFilters(resetPage: true);
                          }))),
                ]),
                const SizedBox(height: 10),
                _dropdown(l10n.commonCategory, _categoryFilter,
                    _categories(all), (v) => setState(() {
                      _categoryFilter = v!;
                      _saveFilters(resetPage: true);
                    })),
                if (unitDropdown != null) ...[
                  const SizedBox(height: 10),
                  unitDropdown,
                ],
              ])
            : Row(children: [
                Expanded(child: _searchField(l10n)),
                const SizedBox(width: 12),
                Expanded(
                    child: _dropdown(l10n.commonDepartment, _departmentFilter,
                        _departments(all), (v) => setState(() {
                          _departmentFilter = v!;
                          _saveFilters(resetPage: true);
                        }))),
                const SizedBox(width: 12),
                Expanded(
                    child: _dropdown(l10n.commonStatus, _statusFilter,
                        _statuses(all), (v) => setState(() {
                          _statusFilter = v!;
                          _saveFilters(resetPage: true);
                        }))),
                const SizedBox(width: 12),
                Expanded(
                    child: _dropdown(l10n.commonCategory, _categoryFilter,
                        _categories(all), (v) => setState(() {
                          _categoryFilter = v!;
                          _saveFilters(resetPage: true);
                        }))),
                if (unitDropdown != null) ...[
                  const SizedBox(width: 12),
                  Expanded(child: unitDropdown),
                ],
              ]),
      ),
    );
  }

  Widget _searchField(AppLocalizations l10n) => TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() {
          _searchTerm = v;
          _saveFilters(resetPage: true);
        }),
        decoration: InputDecoration(
          hintText: l10n.commonSearch,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
        ),
      );

  Widget _dropdown(
          String label, String value, List<String> items, ValueChanged<String?> cb) =>
      DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: cb,
      );

  // ══════════════════════════════════════════════════════════════════════════
  // Compteur + sélecteur de tri (mobile)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCountAndSort(AppLocalizations l10n, int count, bool isMobile) {
    return Row(
      children: [
        Text(l10n.equipmentFound(count),
            style: const TextStyle(color: AppColors.textSecondary)),
        const Spacer(),
        if (isMobile)
          PopupMenuButton<_SortCol>(
            tooltip: l10n.equipmentSortBy,
            icon: const Icon(Icons.sort, color: AppColors.textSecondary),
            onSelected: (col) => setState(() {
              if (_sortCol == col) {
                _sortAsc = !_sortAsc;
              } else {
                _sortCol = col;
                _sortAsc = true;
              }
              _saveFilters(resetPage: true);
            }),
            itemBuilder: (_) => [
              _sortMenuItem(l10n.equipmentName, _SortCol.name),
              _sortMenuItem(l10n.commonStatus, _SortCol.status),
              _sortMenuItem(l10n.commonDepartment, _SortCol.department),
              _sortMenuItem(l10n.equipmentColumnInstallDate, _SortCol.installDate),
            ],
          ),
      ],
    );
  }

  PopupMenuItem<_SortCol> _sortMenuItem(String label, _SortCol col) {
    final active = _sortCol == col;
    return PopupMenuItem(
      value: col,
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: active ? FontWeight.bold : FontWeight.normal))),
        if (active)
          Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14, color: AppColors.primary),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // En-têtes de colonnes desktop (triables)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTableHeader(AppLocalizations l10n) {
    return Card(
      color: AppColors.background,
      margin: const EdgeInsets.only(bottom: 2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _sortHeader(l10n.equipmentName, _SortCol.name, flex: 3),
          _sortHeader(l10n.commonDepartment, _SortCol.department, flex: 2),
          _sortHeader(l10n.commonStatus, _SortCol.status, flex: 2),
          if (_showTechnicalView) ...[
            _staticHeader(l10n.commonCategory, flex: 2),
            // Techniciens : Dernière PM | Admin/superviseur : Date installation
            if (_isTechnician)
              _staticHeader(l10n.equipmentColumnLastPm, flex: 2)
            else
              _sortHeader(l10n.equipmentColumnInstallDate, _SortCol.installDate, flex: 2),
            _staticHeader(l10n.criticalityLabel, flex: 1),
          ],
          _staticHeader(l10n.commonActions, flex: _showTechnicalView ? 3 : 2),
        ]),
      ),
    );
  }

  Widget _sortHeader(String label, _SortCol col, {int flex = 1}) {
    final active = _sortCol == col;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => setState(() {
          if (_sortCol == col) {
            _sortAsc = !_sortAsc;
          } else {
            _sortCol = col;
            _sortAsc = true;
          }
          _saveFilters(resetPage: true);
        }),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : AppColors.textPrimary,
                  fontSize: 13)),
          const SizedBox(width: 2),
          Icon(
            active
                ? (_sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 14,
            color: active ? AppColors.primary : AppColors.textMuted,
          ),
        ]),
      ),
    );
  }

  Widget _staticHeader(String label, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 13)),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // Ligne desktop (vue liste)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopRow(Equipment eq, AppLocalizations l10n) {
    final pmBadge = _pmBadge(eq, l10n);
    final replacementBadge = _replacementBadge(eq, l10n);
    return Card(
      margin: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => _openDetail(eq),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            // Nom + badges (PM + remplacement) inline
            Expanded(
              flex: 3,
              child: Row(children: [
                if (pmBadge != null) ...[pmBadge, const SizedBox(width: 6)],
                if (replacementBadge != null) ...[replacementBadge, const SizedBox(width: 6)],
                Flexible(
                  child: Text(eq.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
            Expanded(
                flex: 2,
                child: Text(eq.department,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                    overflow: TextOverflow.ellipsis)),
            Expanded(
                flex: 2,
                child: StatusBadge(
                    status: eq.status.displayName, isCompact: true)),
            if (_showTechnicalView) ...[
              Expanded(
                  flex: 2,
                  child: Text(eq.category,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      overflow: TextOverflow.ellipsis)),
              // Techniciens : Dernière PM | Admin : Date installation
              if (_isTechnician)
                Expanded(
                    flex: 2,
                    child: Text(
                      eq.lastPreventiveMaintenance != null
                          ? _fmtDate(eq.lastPreventiveMaintenance!)
                          : '—',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ))
              else
                Expanded(
                    flex: 2,
                    child: Text(
                      eq.installDate != null ? _fmtDate(eq.installDate!) : '—',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    )),
              Expanded(
                  flex: 1,
                  child: eq.criticality != null
                      ? _criticalityChip(eq.criticality!)
                      : const Text('—',
                          style: TextStyle(color: AppColors.textMuted))),
            ],
            Expanded(
              flex: _showTechnicalView ? 3 : 2,
              child: _buildRowActions(eq, l10n),
            ),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Carte grille (desktop, vue grille)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGridCard(Equipment eq, AppLocalizations l10n) {
    final pmBadge  = _pmBadge(eq, l10n);
    final replacementBadge = _replacementBadge(eq, l10n);
    final level    = eq.preventiveMaintenanceAlertLevel;
    final hasPm    = level == 'due' || level == 'soon';

    return Card(
      child: InkWell(
        onTap: () => _openDetail(eq),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône + badge PM + nom
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.medical_services_outlined,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (pmBadge != null) ...[pmBadge, const SizedBox(width: 4)],
                        if (replacementBadge != null) ...[replacementBadge, const SizedBox(width: 4)],
                        Expanded(
                          child: Text(eq.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      Text(eq.department,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              StatusBadge(status: eq.status.displayName, isCompact: true),
              if (_showTechnicalView && eq.criticality != null) ...[
                const SizedBox(height: 4),
                _criticalityChip(eq.criticality!),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // PM imminente : bouton planifier (techniciens)
                  if (_showTechnicalView && hasPm)
                    SizedBox(
                      height: 28,
                      child: TextButton.icon(
                        onPressed: () => _schedulePm(eq),
                        icon: const Icon(Icons.event_available, size: 12),
                        label: Text(l10n.equipmentSchedulePm,
                            style: const TextStyle(fontSize: 10)),
                        style: TextButton.styleFrom(
                          foregroundColor: level == 'due'
                              ? AppColors.error
                              : AppColors.warning,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 16),
                      onPressed: () => _openDetail(eq),
                      color: AppColors.primary,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: l10n.commonDetails,
                    ),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Carte mobile
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileCard(Equipment eq, AppLocalizations l10n) {
    final pmBadge  = _pmBadge(eq, l10n);
    final replacementBadge = _replacementBadge(eq, l10n);
    final level    = eq.preventiveMaintenanceAlertLevel;
    final hasPmAlert = level == 'due' || level == 'soon';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openDetail(eq),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (pmBadge != null) ...[pmBadge, const SizedBox(width: 6)],
              if (replacementBadge != null) ...[replacementBadge, const SizedBox(width: 6)],
              Expanded(
                child: Text(eq.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: eq.status.displayName, isCompact: true),
            ]),
            const SizedBox(height: 4),
            Text(eq.department,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            if (_showTechnicalView) ...[
              const SizedBox(height: 2),
              Row(children: [
                Text(eq.category,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                if (eq.criticality != null) ...[
                  const SizedBox(width: 8),
                  _criticalityChip(eq.criticality!),
                ],
              ]),
            ],
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (!_showTechnicalView)
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _reportBreakdown(eq),
                    icon: const Icon(Icons.warning_amber, size: 14),
                    label: Text(l10n.equipmentReportBreakdown,
                        style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 0),
                    ),
                  ),
                ),
              if (_showTechnicalView && hasPmAlert)
                SizedBox(
                  height: 32,
                  child: TextButton.icon(
                    onPressed: () => _schedulePm(eq),
                    icon: const Icon(Icons.event_available, size: 14),
                    label: Text(l10n.equipmentSchedulePm,
                        style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          level == 'due' ? AppColors.error : AppColors.warning,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _openDetail(eq),
                color: AppColors.primary,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Actions desktop par ligne
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRowActions(Equipment eq, AppLocalizations l10n) {
    final level      = eq.preventiveMaintenanceAlertLevel;
    final hasPmAlert = level == 'due' || level == 'soon';

    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 4,
      runSpacing: 4,
      children: [
        if (!_showTechnicalView)
          SizedBox(
            height: 32,
            child: ElevatedButton.icon(
              onPressed: () => _reportBreakdown(eq),
              icon: const Icon(Icons.warning_amber, size: 14),
              label: Text(l10n.equipmentReportBreakdown,
                  style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              ),
            ),
          ),
        if (_showTechnicalView && hasPmAlert)
          SizedBox(
            height: 30,
            child: TextButton.icon(
              onPressed: () => _schedulePm(eq),
              icon: const Icon(Icons.event_available, size: 14),
              label: Text(l10n.equipmentSchedulePm,
                  style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor:
                    level == 'due' ? AppColors.error : AppColors.warning,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.visibility, size: 18),
          onPressed: () => _openDetail(eq),
          tooltip: l10n.commonDetails,
          color: AppColors.primary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // État vide
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inventory_2_outlined,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(l10n.equipmentFound(0),
              style: const TextStyle(color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Actions utilisateur
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _addEquipment() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EquipmentFormScreen()),
    );
    if (ok == true && mounted) setState(() {});
  }

  Future<void> _editEquipment(Equipment eq) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EquipmentFormScreen(existing: eq)),
    );
    if (ok == true && mounted) setState(() {});
  }

  void _openDetail(Equipment eq) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EquipmentDetailScreen(
          equipmentId: eq.id,
          initialEquipment: eq,
          // Techniciens + admin peuvent accéder au formulaire d'édition.
          // fullEq = équipement complet rechargé par EquipmentDetailScreen
          // (pas le `eq` léger capturé ici) — évite un formulaire pré-rempli
          // avec un tag vide (cf. data_service.dart en mode ?light=true).
          onEdit: _canEdit ? (fullEq) => _editEquipment(fullEq) : null,
          onReport: () => widget.onNavigate(3, equipmentId: eq.id),
        ),
      ),
    );
  }

  /// Signaler une panne directement depuis la liste (exception CLAUDE.md —
  /// pas de passage par le sélecteur de catégorie).
  void _reportBreakdown(Equipment eq) {
    widget.onNavigate(3, equipmentId: eq.id);
  }

  /// Planifier une maintenance préventive : date picker + PATCH API.
  Future<void> _schedulePm(Equipment eq) async {
    final l10n = AppLocalizations.of(context)!;
    final now  = DateTime.now();
    final initial = eq.nextPreventiveMaintenance != null
        ? DateTime.tryParse(eq.nextPreventiveMaintenance!) ??
            now.add(const Duration(days: 30))
        : now.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now)
          ? now.add(const Duration(days: 1))
          : initial,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      locale: const Locale('fr'),
    );
    if (picked == null || !mounted) return;

    final iso = picked.toIso8601String().substring(0, 10);
    try {
      await DbApiService.instance
          .updateEquipment(eq.id, {'next_preventive_maintenance': iso});
      await DataService().reloadEquipment();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(l10n.equipmentSchedulePmSuccess),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Export CSV
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _exportCsv(AppLocalizations l10n) async {
    final list = _filteredEquipmentForExport;

    // DataService().equipment est chargé en mode léger (tags vides) — on
    // récupère les tags réels en une requête dédiée à l'export (full payload),
    // déclenchée uniquement à la demande, pas au login.
    Map<String, List<String>> tagsById = {};
    try {
      final fullRaw = await DbApiService.instance.getEquipment(includeDisposed: true);
      tagsById = {
        for (final m in fullRaw)
          m['id'] as String: List<String>.from(m['tags'] as List? ?? []),
      };
    } catch (_) {
      // En cas d'échec, la colonne Tags sera simplement vide dans l'export.
    }

    final buffer = StringBuffer();

    // BOM UTF-8 pour compatibilité Excel français
    buffer.write('﻿');
    buffer.writeln([
      'ID', 'Nom', 'Département', 'Catégorie', 'Statut',
      'Fabricant', 'Modèle', 'N° Série', 'Année fab.',
      'Date install.', 'Dernière PM', 'Prochaine PM', 'Criticité', 'Tags',
      'Sous-catégorie', 'Macro-catégorie', 'Créé le', 'Créé par',
    ].map(_csvEsc).join(';'));

    for (final eq in list) {
      buffer.writeln([
        eq.id,
        eq.name,
        eq.department,
        eq.category,
        eq.status.displayName,
        eq.manufacturer ?? '',
        eq.model ?? '',
        eq.serialNumber,
        eq.manufYear?.toString() ?? '',
        eq.installDate ?? '',
        eq.lastPreventiveMaintenance ?? '',
        eq.nextPreventiveMaintenance ?? '',
        eq.criticality?.displayName ?? '',
        (tagsById[eq.id] ?? eq.tags).join(' | '),
        eq.subcategoryName ?? '',
        eq.macroCategory ?? '',
        eq.createdAt ?? '',
        eq.createdByName ?? '',
      ].map(_csvEsc).join(';'));
    }

    final content  = buffer.toString();
    final filename = 'equipements_${DateTime.now().toIso8601String().substring(0, 10)}.csv';

    if (kIsWeb) {
      _deliverTextFile(content, filename, 'text/csv');
      return;
    }
    final shared = await _deliverTextFile(content, filename, 'text/csv');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(shared ? l10n.equipmentCsvShared : l10n.equipmentCsvShareError),
        backgroundColor: shared ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Déclenche le téléchargement (web) ou le partage natif (mobile/desktop)
  /// d'un contenu texte. Retourne `false` si le partage natif a échoué
  /// (le web ne peut pas échouer silencieusement — `downloadCsv` renvoie déjà
  /// un booléen).
  Future<bool> _deliverTextFile(String content, String filename, String mimeType) async {
    if (kIsWeb) return downloadCsv(content, filename);
    try {
      final bytes = Uint8List.fromList(utf8.encode(content));
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: mimeType)],
        subject: filename,
        fileNameOverrides: [filename],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Import CSV en masse
  // ══════════════════════════════════════════════════════════════════════════

  void _downloadCsvTemplate() {
    const header = 'name,department,category,serial_number,status,location,'
        'manufacturer,model,manuf_year,install_date,building,tag_number,criticality';
    const example = 'Moniteur cardiaque exemple,OPD,Monitoring,SN-EXEMPLE-001,'
        'Operational,Salle 3,GE Healthcare,Dash 3000,2020,2021-05-10,Bloc A,TAG-001,B';
    const content = '$header\n$example\n';
    const filename = 'modele_import_equipements.csv';
    _deliverTextFile(content, filename, 'text/csv');
  }

  void _downloadImportErrorReport(List<Map<String, dynamic>> errors) {
    final content = errors.map((e) => 'Ligne ${e['line']}: ${e['reason']}').join('\n');
    final filename = 'import_csv_erreurs_${DateTime.now().toIso8601String().substring(0, 10)}.txt';
    _deliverTextFile(content, filename, 'text/plain');
  }

  Future<void> _showImportResultDialog(
    AppLocalizations l10n, {
    required bool isDryRun,
    required int count,
    required List<Map<String, dynamic>> errors,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.equipmentImportCsvResultTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isDryRun
                  ? l10n.equipmentImportCsvResultWouldInsert(count, errors.length)
                  : l10n.equipmentImportCsvResultInserted(count, errors.length)),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...errors.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Ligne ${e['line']}: ${e['reason']}',
                        style: const TextStyle(fontSize: 13, color: AppColors.error),
                      ),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          if (errors.isNotEmpty)
            TextButton(
              onPressed: () => _downloadImportErrorReport(errors),
              child: Text(l10n.equipmentImportCsvDownloadReport),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.equipmentImportCsvClose),
          ),
        ],
      ),
    );
  }

  Future<void> _openImportCsvDialog() async {
    final l10n = AppLocalizations.of(context)!;
    PlatformFile? pickedFile;
    bool isProcessing = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          Future<void> runImport(bool dryRun) async {
            if (pickedFile?.bytes == null) return;
            setDialogState(() => isProcessing = true);
            try {
              final response = await DbApiService.instance.importEquipmentCsv(
                Uint8List.fromList(pickedFile!.bytes!),
                pickedFile!.name,
                dryRun: dryRun,
              );
              if (dialogCtx.mounted) Navigator.pop(dialogCtx, response);
            } catch (e) {
              setDialogState(() => isProcessing = false);
              if (dialogCtx.mounted) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(SnackBar(
                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            }
          }

          return AlertDialog(
            title: Text(l10n.equipmentImportCsvDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _downloadCsvTemplate,
                    icon: const Icon(Icons.description_outlined),
                    label: Text(l10n.equipmentImportCsvDownloadTemplate),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            final picked = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['csv'],
                              withData: true,
                            );
                            if (picked != null && picked.files.isNotEmpty) {
                              setDialogState(() => pickedFile = picked.files.first);
                            }
                          },
                    icon: const Icon(Icons.attach_file),
                    label: Text(pickedFile?.name ?? l10n.equipmentImportCsvPickFile),
                  ),
                  if (pickedFile == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.equipmentImportCsvNoFileSelected,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                  if (isProcessing) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(dialogCtx),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: (pickedFile == null || isProcessing) ? null : () => runImport(true),
                child: Text(l10n.equipmentImportCsvVerifyOnly),
              ),
              ElevatedButton(
                onPressed: (pickedFile == null || isProcessing) ? null : () => runImport(false),
                child: Text(l10n.equipmentImportCsvImport),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || !mounted) return;

    final isDryRun = result['dry_run'] == true;
    final count = isDryRun
        ? (result['would_insert'] as int? ?? 0)
        : (result['inserted'] as int? ?? 0);
    final errors = List<Map<String, dynamic>>.from(result['errors'] as List? ?? []);

    if (!isDryRun && count > 0) {
      await DataService().reloadEquipment();
      if (mounted) setState(() {});
    }

    if (!mounted) return;
    await _showImportResultDialog(l10n, isDryRun: isDryRun, count: count, errors: errors);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Scan QR
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _scanQr() async {
    String? result;

    if (kIsWeb) {
      // Web : on ne lance pas la caméra, on passe directement à la saisie
      result = '';
    } else {
      result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _QrScanSheet(),
      );
    }

    if (!mounted) return;

    // '' = l'utilisateur a demandé la saisie manuelle ou est sur web
    if (result == '') {
      result = await showDialog<String>(
        context: context,
        builder: (_) => const _ManualIdDialog(),
      );
    }

    if (result == null || result.isEmpty || !mounted) return;

    final eq = DataService()
        .equipment
        .where((e) => e.id == result || e.serialNumber == result)
        .firstOrNull;

    if (eq != null) {
      _openDetail(eq);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.equipmentScanQrNotFound),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Helpers visuels
  // ══════════════════════════════════════════════════════════════════════════

  static String _csvEsc(String v) {
    if (v.contains(';') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  /// Badge PM compact coloré — affiché inline sur chaque ligne, sans filtre requis.
  Widget? _pmBadge(Equipment eq, AppLocalizations l10n) {
    final level = eq.preventiveMaintenanceAlertLevel;
    if (level != 'due' && level != 'soon') return null;
    final isOverdue = level == 'due';
    final color = isOverdue ? AppColors.error   : AppColors.warning;
    final bg    = isOverdue ? AppColors.errorLight : AppColors.warningLight;
    return Tooltip(
      message: isOverdue
          ? l10n.preventiveAlertOverdue
          : l10n.preventiveAlertSoon,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isOverdue ? Icons.error_outline : Icons.schedule,
              size: 11, color: color),
          const SizedBox(width: 3),
          Text('PM',
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  /// Badge triangle du plan de remplacement (RA3 S5) — affiché inline.
  /// Retourne null si pas de plan chargé, équipement non biomédical, ou statut `ok`.
  Widget? _replacementBadge(Equipment eq, AppLocalizations l10n) {
    final item = _replacementByEqId[eq.id];
    if (item == null) return null;
    final status = item['status_replacement'] as String? ?? 'ok';
    if (ReplacementBadge.colorFor(status) == null) return null;

    final age      = (item['age'] as num?)?.toInt();
    final lifespan = (item['lifespan'] as num?)?.toInt();
    final crit     = item['criticality'] as String?;

    return ReplacementBadge(
      status: status,
      tooltip: ReplacementBadge.tooltipFor(l10n, status, age, lifespan, crit),
      onTap: () => _openDetail(eq),
    );
  }

  Widget _criticalityChip(EquipmentCriticality c) {
    Color color;
    switch (c) {
      case EquipmentCriticality.a: color = AppColors.error;
      case EquipmentCriticality.b: color = AppColors.warning;
      case EquipmentCriticality.c: color = AppColors.success;
    }
    return Tooltip(
      message: AppLocalizations.of(context)!.criticalityLabel,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(c.displayName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// Formate une date ISO (YYYY-MM-DD) → "DD/MM/YYYY".
  String _fmtDate(String iso) {
    if (iso.length < 10) return iso;
    final p = iso.substring(0, 10).split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
  }
}
