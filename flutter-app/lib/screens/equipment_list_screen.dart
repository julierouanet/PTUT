import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../models/equipment.dart';
import '../widgets/status_badge.dart';
import 'equipment_detail_screen.dart';
import 'equipment_form_screen.dart';
import '../services/auth_service.dart';
import '../utils/csv_export.dart';

// Colonnes triables
enum _SortCol { name, status, department, installDate }

/// Écran principal de liste des équipements.
///
/// Améliorations vs. l'ancienne version :
/// - Virtualisation via SliverList (O(visible) au lieu de O(total)).
/// - Tri par clic sur les en-têtes (Nom, Statut, Département, Date install.).
/// - Vues conditionnelles par rôle (RBAC) : staff médical vs. techniciens.
/// - Filtre rapide "PM en retard / imminente" réservé aux techniciens.
/// - Export CSV de la liste filtrée courante.
/// - Formulaire créa/édition délégué à EquipmentFormScreen (Stepper 3 étapes).
class EquipmentListScreen extends StatefulWidget {
  final Function(int, {String? equipmentId}) onNavigate;

  const EquipmentListScreen({super.key, required this.onNavigate});

  @override
  State<EquipmentListScreen> createState() => _EquipmentListScreenState();
}

class _EquipmentListScreenState extends State<EquipmentListScreen> {
  // ── Filtres textuels / dropdown ────────────────────────────────────────
  String _searchTerm       = '';
  String _departmentFilter = 'Tous';
  String _statusFilter     = 'Tous';
  String _categoryFilter   = 'Tous';

  // ── Filtres PM (techniciens/superviseurs) ──────────────────────────────
  bool _filterPmOverdue = false;
  bool _filterPmSoon    = false;

  // ── Tri ────────────────────────────────────────────────────────────────
  _SortCol _sortCol = _SortCol.name;
  bool _sortAsc = true;

  final _authService = AuthService();

  // ── RBAC ───────────────────────────────────────────────────────────────

  /// true pour admin, superviseur et tout technicien.
  /// false pour hospitalStaff → vue simplifiée.
  bool get _showTechnicalView =>
      _authService.canManageEquipment || _authService.canUpdateRepairs;

  // ── Données filtrées + triées ──────────────────────────────────────────

  List<String> _departments(String allLabel) =>
      [allLabel, ...DataService().equipment.map((e) => e.department).toSet()];

  List<String> _statuses(String allLabel) =>
      [allLabel, ...EquipmentStatus.values.map((s) => s.displayName)];

  List<String> _categories(String allLabel) =>
      [allLabel, ...DataService().equipment.map((e) => e.category).toSet()];

  List<Equipment> get _filteredEquipment {
    final l10n = AppLocalizations.of(context)!;
    final term = _searchTerm.toLowerCase();
    final all  = l10n.commonAll;

    var list = DataService().equipment.where((eq) {
      // Recherche textuelle
      final matchSearch = term.isEmpty ||
          eq.name.toLowerCase().contains(term) ||
          eq.serialNumber.toLowerCase().contains(term) ||
          (eq.manufacturer?.toLowerCase().contains(term) ?? false) ||
          (eq.model?.toLowerCase().contains(term) ?? false);

      // Filtres dropdown
      final matchDept   = _departmentFilter == all || eq.department == _departmentFilter;
      final matchStatus = _statusFilter     == all || eq.status.displayName == _statusFilter;
      final matchCat    = _categoryFilter   == all || eq.category == _categoryFilter;

      // Filtre PM (OR logique entre les deux chips)
      bool matchPm = true;
      if (_filterPmOverdue || _filterPmSoon) {
        final level = eq.preventiveMaintenanceAlertLevel;
        matchPm = (_filterPmOverdue && level == 'due') ||
                  (_filterPmSoon    && level == 'soon');
      }

      return matchSearch && matchDept && matchStatus && matchCat && matchPm;
    }).toList();

    // Tri
    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case _SortCol.name:
          cmp = a.name.compareTo(b.name);
        case _SortCol.status:
          cmp = a.status.index.compareTo(b.status.index);
        case _SortCol.department:
          cmp = a.department.compareTo(b.department);
        case _SortCol.installDate:
          cmp = (a.installDate ?? '').compareTo(b.installDate ?? '');
      }
      return _sortAsc ? cmp : -cmp;
    });

    return list;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    if (_departmentFilter == 'Tous') _departmentFilter = l10n.commonAll;
    if (_statusFilter     == 'Tous') _statusFilter     = l10n.commonAll;
    if (_categoryFilter   == 'Tous') _categoryFilter   = l10n.commonAll;
  }

  // ── Build principal ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n    = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final filtered = _filteredEquipment;

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
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
          sliver: SliverToBoxAdapter(child: _buildFilterChips(l10n)),
        ),

        // Barre recherche + dropdowns
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
          sliver: SliverToBoxAdapter(child: _buildSearchBar(l10n, isMobile)),
        ),

        // Compteur + barre de tri (desktop)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 0),
          sliver: SliverToBoxAdapter(
              child: _buildCountAndSort(l10n, filtered.length, isMobile)),
        ),

        // En-têtes de colonnes triables (desktop uniquement)
        if (!isMobile)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            sliver: SliverToBoxAdapter(child: _buildTableHeader(l10n)),
          ),

        // Lignes virtualisées
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, isMobile ? 8 : 4,
              isMobile ? 16 : 24, isMobile ? 16 : 24),
          sliver: filtered.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyState(l10n))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => isMobile
                        ? _buildMobileCard(filtered[i], l10n)
                        : _buildDesktopRow(filtered[i], l10n),
                    childCount: filtered.length,
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
    final exportBtn = OutlinedButton.icon(
      onPressed: () => _exportCsv(l10n),
      icon: const Icon(Icons.download, size: 18),
      label: Text(l10n.equipmentExportCsv),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
    final addBtn = _authService.canManageEquipment
        ? ElevatedButton.icon(
            onPressed: _addEquipment,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.equipmentNew),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          )
        : null;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.equipmentTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(l10n.equipmentSubtitle,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            if (addBtn != null) ...[Expanded(child: addBtn), const SizedBox(width: 8)],
            Expanded(child: exportBtn),
          ]),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.equipmentTitle,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(l10n.equipmentSubtitle,
              style: const TextStyle(color: AppColors.textSecondary)),
        ]),
        Row(children: [
          exportBtn,
          if (addBtn != null) ...[const SizedBox(width: 12), addBtn],
        ]),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Chips de filtres rapides
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFilterChips(AppLocalizations l10n) {
    final myDept   = _authService.currentUser?.department ?? '';
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
          }),
        ),

        // Filtres PM (réservés aux techniciens/superviseurs)
        if (_showTechnicalView) ...[
          FilterChip(
            label: Text(l10n.equipmentFilterPmOverdueChip),
            avatar: const Icon(Icons.error_outline, size: 16),
            selected: _filterPmOverdue,
            selectedColor: AppColors.error.withValues(alpha: 0.15),
            checkmarkColor: AppColors.error,
            onSelected: (v) => setState(() => _filterPmOverdue = v),
          ),
          FilterChip(
            label: Text(l10n.equipmentFilterPmSoonChip),
            avatar: const Icon(Icons.schedule, size: 16),
            selected: _filterPmSoon,
            selectedColor: AppColors.warning.withValues(alpha: 0.15),
            checkmarkColor: AppColors.warning,
            onSelected: (v) => setState(() => _filterPmSoon = v),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Barre de recherche + dropdowns
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSearchBar(AppLocalizations l10n, bool isMobile) {
    final allLabel = l10n.commonAll;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isMobile
            ? Column(children: [
                _searchField(l10n),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _dropdown(l10n.commonDepartment, _departmentFilter,
                      _departments(allLabel), (v) => setState(() => _departmentFilter = v!))),
                  const SizedBox(width: 10),
                  Expanded(child: _dropdown(l10n.commonStatus, _statusFilter,
                      _statuses(allLabel), (v) => setState(() => _statusFilter = v!))),
                ]),
                const SizedBox(height: 10),
                _dropdown(l10n.commonCategory, _categoryFilter,
                    _categories(allLabel), (v) => setState(() => _categoryFilter = v!)),
              ])
            : Row(children: [
                Expanded(child: _searchField(l10n)),
                const SizedBox(width: 12),
                Expanded(child: _dropdown(l10n.commonDepartment, _departmentFilter,
                    _departments(allLabel), (v) => setState(() => _departmentFilter = v!))),
                const SizedBox(width: 12),
                Expanded(child: _dropdown(l10n.commonStatus, _statusFilter,
                    _statuses(allLabel), (v) => setState(() => _statusFilter = v!))),
                const SizedBox(width: 12),
                Expanded(child: _dropdown(l10n.commonCategory, _categoryFilter,
                    _categories(allLabel), (v) => setState(() => _categoryFilter = v!))),
              ]),
      ),
    );
  }

  Widget _searchField(AppLocalizations l10n) => TextField(
        onChanged: (v) => setState(() => _searchTerm = v),
        decoration: InputDecoration(
          hintText: l10n.commonSearch,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
        ),
      );

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String?> cb) =>
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
    final isActive = _sortCol == col;
    return PopupMenuItem(
      value: col,
      child: Row(children: [
        Expanded(child: Text(label,
            style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal))),
        if (isActive)
          Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14, color: AppColors.primary),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // En-têtes de colonnes desktop (cliquables → tri)
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
            _sortHeader(l10n.equipmentColumnInstallDate, _SortCol.installDate, flex: 2),
            _staticHeader(l10n.criticalityLabel, flex: 1),
          ],
          _staticHeader(l10n.commonActions, flex: _showTechnicalView ? 3 : 2),
        ]),
      ),
    );
  }

  Widget _sortHeader(String label, _SortCol col, {int flex = 1}) {
    final isActive = _sortCol == col;
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
        }),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.primary : AppColors.textPrimary,
                  fontSize: 13)),
          const SizedBox(width: 2),
          Icon(
            isActive
                ? (_sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 14,
            color: isActive ? AppColors.primary : AppColors.textMuted,
          ),
        ]),
      ),
    );
  }

  Widget _staticHeader(String label, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600,
                color: AppColors.textPrimary, fontSize: 13)),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // Ligne desktop
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopRow(Equipment eq, AppLocalizations l10n) {
    final pmBadge = _pmBadge(eq, l10n);
    return Card(
      margin: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => _openDetail(eq),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            // Nom + badge PM
            Expanded(
              flex: 3,
              child: Row(children: [
                if (pmBadge != null) ...[pmBadge, const SizedBox(width: 6)],
                Flexible(
                  child: Text(eq.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
            // Département
            Expanded(flex: 2,
                child: Text(eq.department,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    overflow: TextOverflow.ellipsis)),
            // Statut
            Expanded(flex: 2,
                child: StatusBadge(status: eq.status.displayName, isCompact: true)),
            // Colonnes techniques (techniciens/superviseurs)
            if (_showTechnicalView) ...[
              Expanded(flex: 2,
                  child: Text(eq.category,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      overflow: TextOverflow.ellipsis)),
              Expanded(flex: 2,
                  child: Text(
                      eq.installDate != null ? _fmtDate(eq.installDate!) : '—',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
              Expanded(flex: 1,
                  child: eq.criticality != null
                      ? _criticalityChip(eq.criticality!)
                      : const Text('—', style: TextStyle(color: AppColors.textMuted))),
            ],
            // Actions
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
  // Carte mobile
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileCard(Equipment eq, AppLocalizations l10n) {
    final pmBadge = _pmBadge(eq, l10n);
    final level   = eq.preventiveMaintenanceAlertLevel;
    final hasPmAlert = level == 'due' || level == 'soon';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openDetail(eq),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Ligne titre : nom + statut
            Row(children: [
              if (pmBadge != null) ...[pmBadge, const SizedBox(width: 6)],
              Expanded(
                child: Text(eq.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: eq.status.displayName, isCompact: true),
            ]),
            const SizedBox(height: 4),
            // Département
            Text(eq.department,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            // Informations techniques
            if (_showTechnicalView) ...[
              const SizedBox(height: 2),
              Row(children: [
                Text(eq.category,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                if (eq.criticality != null) ...[
                  const SizedBox(width: 8),
                  _criticalityChip(eq.criticality!),
                ],
              ]),
            ],
            const SizedBox(height: 8),
            // Actions contextuelles
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              // Staff médical → gros bouton "Signaler une panne"
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                  ),
                ),
              // Techniciens → "Planifier PM" si alerte active
              if (_showTechnicalView && hasPmAlert)
                SizedBox(
                  height: 32,
                  child: TextButton.icon(
                    onPressed: () => _schedulePm(eq),
                    icon: const Icon(Icons.event_available, size: 14),
                    label: Text(l10n.equipmentSchedulePm,
                        style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: level == 'due' ? AppColors.error : AppColors.warning,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    ),
                  ),
                ),
              // Modifier (admin/superviseur)
              if (_authService.canManageEquipment)
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _editEquipment(eq),
                  tooltip: AppLocalizations.of(context)!.commonEdit,
                  color: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              // Voir détails
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _openDetail(eq),
                color: AppColors.primary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
        // Staff médical → bouton "Signaler une panne" proéminent
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              ),
            ),
          ),

        // Techniciens → "Planifier PM" si alerte PM
        if (_showTechnicalView && hasPmAlert)
          SizedBox(
            height: 30,
            child: TextButton.icon(
              onPressed: () => _schedulePm(eq),
              icon: const Icon(Icons.event_available, size: 14),
              label: Text(l10n.equipmentSchedulePm,
                  style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: level == 'due' ? AppColors.error : AppColors.warning,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              ),
            ),
          ),

        // Voir détails
        IconButton(
          icon: const Icon(Icons.visibility, size: 18),
          onPressed: () => _openDetail(eq),
          tooltip: l10n.commonDetails,
          color: AppColors.primary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),

        // Modifier (admin/superviseur)
        if (_authService.canManageEquipment)
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => _editEquipment(eq),
            tooltip: l10n.commonEdit,
            color: AppColors.textSecondary,
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
          onEdit: _authService.canManageEquipment ? () => _editEquipment(eq) : null,
          onReport: () => widget.onNavigate(3, equipmentId: eq.id),
        ),
      ),
    );
  }

  /// Signaler une panne depuis une ligne de la liste : navigation directe
  /// sans passer par le sélecteur de catégorie (exception CLAUDE.md).
  void _reportBreakdown(Equipment eq) {
    widget.onNavigate(3, equipmentId: eq.id);
  }

  /// Planifier une maintenance préventive : date picker + PATCH API.
  Future<void> _schedulePm(Equipment eq) async {
    final l10n = AppLocalizations.of(context)!;
    final now  = DateTime.now();
    final initial = eq.nextPreventiveMaintenance != null
        ? DateTime.tryParse(eq.nextPreventiveMaintenance!) ?? now.add(const Duration(days: 30))
        : now.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now.add(const Duration(days: 1)) : initial,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      locale: const Locale('fr'),
    );
    if (picked == null || !mounted) return;

    final iso = picked.toIso8601String().substring(0, 10);
    try {
      await DbApiService.instance.updateEquipment(
          eq.id, {'next_preventive_maintenance': iso});
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

  void _exportCsv(AppLocalizations l10n) {
    final list = _filteredEquipment;

    final buffer = StringBuffer();
    // BOM UTF-8 pour compatibilité Excel français
    buffer.write('﻿');
    // En-têtes — séparateur point-virgule (locale française d'Excel)
    buffer.writeln([
      'ID', 'Nom', 'Département', 'Catégorie', 'Statut',
      'Fabricant', 'Modèle', 'N° Série', 'Année fab.',
      'Date install.', 'Dernière MP', 'Prochaine MP', 'Criticité', 'Tags',
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
        eq.tags.join(' | '),
      ].map(_csvEsc).join(';'));
    }

    final filename =
        'equipements_${DateTime.now().toIso8601String().substring(0, 10)}.csv';

    if (kIsWeb) {
      downloadCsv(buffer.toString(), filename);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.equipmentCsvWebOnly),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Échappe les valeurs pour CSV : guillemets si nécessaire.
  static String _csvEsc(String v) {
    if (v.contains(';') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Helpers visuels
  // ══════════════════════════════════════════════════════════════════════════

  /// Badge PM compact coloré (rouge = retard, orange = imminente).
  Widget? _pmBadge(Equipment eq, AppLocalizations l10n) {
    final level = eq.preventiveMaintenanceAlertLevel;
    if (level != 'due' && level != 'soon') return null;
    final isOverdue = level == 'due';
    final color = isOverdue ? AppColors.error   : AppColors.warning;
    final bg    = isOverdue ? AppColors.errorLight : AppColors.warningLight;
    return Tooltip(
      message: isOverdue ? l10n.preventiveAlertOverdue : l10n.preventiveAlertSoon,
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
                  fontSize: 10, color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  /// Pastille criticité A/B/C.
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
        width: 22, height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(c.displayName,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
