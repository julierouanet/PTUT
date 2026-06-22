import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/detail_breadcrumb.dart';
import '../widgets/replacement_badge.dart';
import '../widgets/status_badge.dart';
import 'brand_detail_screen.dart';
import 'detail_screen_helpers.dart';

/// Page de détail d'une sous-catégorie.
///
/// Pour **toutes** les sous-catégories : liste des équipements + liste des
/// fabricants présents (catalogue). Pour les sous-catégories **biomédicales**
/// uniquement (RA3 S5) : durée de vie de référence + alertes de remplacement.
/// Ouverte via [MaterialPageRoute] depuis la gestion des sous-catégories.
class SubcategoryDetailScreen extends StatefulWidget {
  final int subcategoryId;
  final String subcategoryName;
  final int? expectedLifespanYears;

  /// Active les sections durée de vie / alertes de remplacement (biomédical).
  final bool isBiomedical;

  const SubcategoryDetailScreen({
    super.key,
    required this.subcategoryId,
    required this.subcategoryName,
    this.expectedLifespanYears,
    this.isBiomedical = true,
  });

  @override
  State<SubcategoryDetailScreen> createState() =>
      _SubcategoryDetailScreenState();
}

class _SubcategoryDetailScreenState extends State<SubcategoryDetailScreen> {
  bool _loading = true;
  String? _error;

  // Nom et macro-catégorie courants, mis à jour après modification sans
  // quitter l'écran (calque de _brandName dans BrandDetailScreen).
  late String _name;
  int? _macroCategoryId;
  List<Map<String, dynamic>> _macroCategories = [];

  // Équipements et fabricants de la sous-catégorie (catalogue).
  List<Map<String, dynamic>> _equipment = [];
  List<Map<String, dynamic>> _brands = [];

  // Items du plan de remplacement appartenant à cette sous-catégorie
  // et porteurs d'une alerte (badge non nul) — biomédical uniquement.
  List<Map<String, dynamic>> _alerts = [];

  // Description métier de la sous-catégorie (éditable par l'admin uniquement).
  final TextEditingController _descriptionController = TextEditingController();
  bool _savingDescription = false;

  // Seul l'admin peut éditer la description (miroir RBAC PUT /sub/:id).
  bool get _isAdmin => AuthService().primaryRole == UserRole.admin;

  // Modifier/Supprimer la sous-catégorie : gardé côté client par la permission
  // de gestion des catégories (le serveur impose requireRole('admin')).
  bool get _canManage => AuthService().hasPermission(Permission.manageCategories);

  @override
  void initState() {
    super.initState();
    _name = widget.subcategoryName;
    _load();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Détail sous-catégorie : équipements + fabricants.
      final detail = await DbApiService.instance.getSubCategoryDetail(widget.subcategoryId);
      _name = detail['name'] as String? ?? _name;
      _macroCategoryId = detail['macro_category_id'] as int?;
      _equipment = List<Map<String, dynamic>>.from((detail['equipment'] as List?) ?? const []);
      _brands = List<Map<String, dynamic>>.from((detail['brands'] as List?) ?? const []);
      _descriptionController.text = (detail['description'] as String?) ?? '';

      // Macro-catégories (dialogue d'édition, chargées une fois) + alertes de
      // remplacement (biomédical) : indépendantes, lancées en parallèle.
      final results = await Future.wait([
        _macroCategories.isEmpty
            ? DbApiService.instance.getMacroCategories()
            : Future.value(_macroCategories),
        widget.isBiomedical
            ? DbApiService.instance.getReplacementPlan()
            : Future.value(<String, dynamic>{}),
      ]);
      _macroCategories = results[0] as List<Map<String, dynamic>>;

      if (widget.isBiomedical) {
        final plan  = results[1] as Map<String, dynamic>;
        final items = (plan['items'] as List?) ?? const [];
        final alerts = <Map<String, dynamic>>[];
        for (final it in items) {
          final m = it as Map<String, dynamic>;
          if (m['subcategory'] == _name) {
            final status = m['status_replacement'] as String? ?? 'ok';
            if (ReplacementBadge.colorFor(status) != null) alerts.add(m);
          }
        }
        _alerts = alerts;
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.subcategoryDetailTitle),
        actions: [
          if (_canManage)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: l10n.commonEdit,
              onPressed: () => _showEditDialog(l10n),
            ),
          if (_canManage)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: _equipment.isNotEmpty
                  ? l10n.settingsDeptDeleteDisabledTooltip
                  : l10n.commonDelete,
              onPressed: _equipment.isNotEmpty ? null : () => _confirmDelete(l10n),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Fil d'Ariane (la macro-catégorie parente n'est pas chargée
                    // ici → segment unique masqué par DetailBreadcrumb).
                    DetailBreadcrumb(
                      padding: const EdgeInsets.only(bottom: 8),
                      segments: [BreadcrumbSegment(_name)],
                    ),
                    // ── En-tête sous-catégorie ──────────────────────────────
                    Text(_name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 16),

                    // ── Description métier (édition admin) ──────────────────
                    _buildDescriptionCard(l10n),
                    const SizedBox(height: 16),

                    // ── Durée de vie de référence (biomédical) ──────────────
                    if (widget.isBiomedical) ...[
                      _buildLifespanCard(l10n),
                      const SizedBox(height: 16),
                      _buildAlertsSection(l10n),
                      const SizedBox(height: 16),
                    ],

                    // ── Équipements (toutes macro-catégories) ───────────────
                    _buildSectionHeader(
                        Icons.inventory_2_outlined, l10n.subcategoryEquipmentSection),
                    const SizedBox(height: 8),
                    _buildEquipmentList(l10n),
                    const SizedBox(height: 16),

                    // ── Fabricants (catalogue) ──────────────────────────────
                    _buildSectionHeader(Icons.factory_outlined, l10n.subcategoryBrandsSection),
                    const SizedBox(height: 8),
                    _buildBrandsList(l10n),
                  ],
                ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: AppColors.error)),
        ),
      );

  Widget _buildSectionHeader(IconData icon, String label) =>
      detailSectionHeader(icon, label);

  /// Carte description : édition multi-lignes pour l'admin, lecture seule sinon.
  /// Masquée pour les non-admins si aucune description n'est saisie.
  Widget _buildDescriptionCard(AppLocalizations l10n) {
    if (!_isAdmin && _descriptionController.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.description_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(l10n.subcategoryDescriptionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            if (_isAdmin) ...[
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: l10n.subcategoryDescriptionHint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: _savingDescription
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : ElevatedButton(
                        onPressed: () => _saveDescription(l10n),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(l10n.commonSave),
                      ),
              ),
            ] else
              Text(_descriptionController.text.trim(),
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDescription(AppLocalizations l10n) async {
    setState(() => _savingDescription = true);
    try {
      // PUT /sub/:id exige le name : on le renvoie inchangé avec la description.
      await DbApiService.instance.updateSubCategory(widget.subcategoryId, {
        'name': _name,
        'description': _descriptionController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.subcategoryDescriptionSaved),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _savingDescription = false);
    }
  }

  Widget _buildLifespanCard(AppLocalizations l10n) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.timelapse, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l10n.subcategoryDetailLifespanSection,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (widget.expectedLifespanYears == null)
              ReplacementBadge(
                status: 'donnee_manquante',
                tooltip: l10n.subcategoryLifespanUndefinedTooltip,
              )
            else
              Text('${widget.expectedLifespanYears} ${l10n.subcategoryLifespanHint}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),
      );

  Widget _buildAlertsSection(AppLocalizations l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              Icons.notifications_outlined, l10n.subcategoryDetailAlertsSection),
          const SizedBox(height: 8),
          if (_alerts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(l10n.subcategoryDetailNoAlerts,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ]),
              ),
            )
          else
            Card(
              child: Column(
                children: _alerts.map((m) {
                  final status   = m['status_replacement'] as String? ?? 'ok';
                  final age      = (m['age'] as num?)?.toInt();
                  final lifespan = (m['lifespan'] as num?)?.toInt();
                  final crit     = m['criticality'] as String?;
                  final tooltip  = ReplacementBadge.tooltipFor(l10n, status, age, lifespan, crit);
                  return ListTile(
                    dense: true,
                    leading: ReplacementBadge(status: status, tooltip: tooltip),
                    title: Text(m['name'] as String? ?? '—',
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(tooltip.isEmpty
                        ? l10n.replacementStatusUnknown
                        : tooltip),
                  );
                }).toList(),
              ),
            ),
        ],
      );

  Widget _buildEquipmentList(AppLocalizations l10n) {
    if (_equipment.isEmpty) {
      return _emptyCard(l10n.settingsEmptyList);
    }
    return Card(
      child: Column(
        children: _equipment.map((e) {
          final status = e['status'] as String? ?? '';
          return ListTile(
            dense: true,
            leading: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.textSecondary),
            title: Text(e['name'] as String? ?? '—', style: const TextStyle(fontSize: 14)),
            trailing: status.isEmpty ? null : StatusBadge(status: status, isCompact: true),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBrandsList(AppLocalizations l10n) {
    if (_brands.isEmpty) {
      return _emptyCard(l10n.subcategoryNoBrands);
    }
    return Card(
      child: Column(
        children: _brands.map((b) {
          final modelCount = (b['model_count'] as int?) ?? 0;
          final eqCount = (b['equipment_count'] as int?) ?? 0;
          return ListTile(
            dense: true,
            leading: const Icon(Icons.factory_outlined, size: 18, color: AppColors.primary),
            title: Text(b['name'] as String? ?? '—', style: const TextStyle(fontSize: 14)),
            subtitle: Text(l10n.catalogBrandCounts(modelCount, eqCount),
                style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BrandDetailScreen(
                  brandId: b['id'] as int,
                  brandName: b['name'] as String? ?? '—',
                  subcategoryId: widget.subcategoryId,
                  subcategoryName: _name,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Modifier la sous-catégorie (nom + macro-catégorie) ──────────────────────
  void _showEditDialog(AppLocalizations l10n) {
    final nameCtrl = TextEditingController(text: _name);
    int? selectedMacroId = _macroCategoryId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.settingsEditCategory,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.settingsCategoryName,
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedMacroId,
                  decoration: InputDecoration(
                    labelText: l10n.settingsCatSelectMacro,
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: _macroCategories.map((m) => DropdownMenuItem<int>(
                    value: m['id'] as int,
                    child: Text(m['name'] as String),
                  )).toList(),
                  onChanged: (v) { if (v != null) setDialog(() => selectedMacroId = v); },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.commonCancel),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty || selectedMacroId == null) return;
                        Navigator.pop(ctx);
                        try {
                          await DbApiService.instance.updateSubCategory(widget.subcategoryId, {
                            'name': nameCtrl.text.trim(),
                            'macro_category_id': selectedMacroId,
                          });
                          await _load();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(l10n.settingsCategoryModified),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ));
                        } on ApiException catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(e.message),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                      child: Text(l10n.commonSave),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Supprimer la sous-catégorie ──────────────────────────────────────────────
  Future<void> _confirmDelete(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsDeleteCategory),
        content: Text(l10n.settingsDeleteConfirm(_name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DbApiService.instance.deleteSubCategory(widget.subcategoryId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.settingsDeletedFeminine(l10n.settingsDeleteCategory)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _emptyCard(String message) => detailEmptyCard(message);
}
