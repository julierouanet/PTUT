import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/detail_breadcrumb.dart';
import 'model_detail_screen.dart';
import 'subcategory_detail_screen.dart';

/// Page de détail d'un fabricant, dans le contexte d'une sous-catégorie.
///
/// Affiche les modèles du fabricant (rattachés à la sous-catégorie) avec leur
/// nombre d'équipements. Chaque modèle ouvre sa fiche [ModelDetailScreen].
/// Avec la permission [Permission.manageCategories] : renommer le fabricant,
/// ajouter / renommer / supprimer un modèle (suppression bloquée si équipements).
class BrandDetailScreen extends StatefulWidget {
  final int brandId;
  final String brandName;
  final int subcategoryId;
  final String subcategoryName;

  const BrandDetailScreen({
    super.key,
    required this.brandId,
    required this.brandName,
    required this.subcategoryId,
    required this.subcategoryName,
  });

  @override
  State<BrandDetailScreen> createState() => _BrandDetailScreenState();
}

class _BrandDetailScreenState extends State<BrandDetailScreen> {
  bool _loading = true;
  String? _error;
  late String _brandName;
  List<Map<String, dynamic>> _models = [];

  bool get _canManage => AuthService().hasPermission(Permission.manageCategories);

  @override
  void initState() {
    super.initState();
    _brandName = widget.brandName;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await DbApiService.instance
          .getBrandDetail(widget.brandId, subcategoryId: widget.subcategoryId);
      if (mounted) setState(() {
        _brandName = detail['name'] as String? ?? _brandName;
        _models = List<Map<String, dynamic>>.from((detail['models'] as List?) ?? const []);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.brandDetailTitle),
        actions: [
          if (_canManage)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: l10n.catalogRenameBrand,
              onPressed: () => _showRenameBrandDialog(l10n),
            ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showModelDialog(l10n),
              icon: const Icon(Icons.add),
              label: Text(l10n.catalogAddModel),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error))))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Fil d'Ariane : Sous-catégorie (cliquable) › Fabricant courant.
                    DetailBreadcrumb(
                      padding: const EdgeInsets.only(bottom: 8),
                      segments: [
                        BreadcrumbSegment(widget.subcategoryName, onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubcategoryDetailScreen(
                              subcategoryId: widget.subcategoryId,
                              subcategoryName: widget.subcategoryName,
                            ),
                          ),
                        )),
                        BreadcrumbSegment(_brandName),
                      ],
                    ),
                    Text(_brandName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(widget.subcategoryName,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(children: [
                      const Icon(Icons.devices_other, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(l10n.brandModelsSection,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    _buildModels(l10n),
                  ],
                ),
    );
  }

  Widget _buildModels(AppLocalizations l10n) {
    if (_models.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.brandNoModels,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
      );
    }
    return Card(
      child: Column(
        children: _models.map((m) {
          final eqCount = (m['equipment_count'] as int?) ?? 0;
          return ListTile(
            dense: true,
            leading: const Icon(Icons.devices_other, size: 18, color: AppColors.textSecondary),
            title: Text(m['name'] as String? ?? '—', style: const TextStyle(fontSize: 14)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ModelDetailScreen(
                  modelId: m['id'] as int,
                  modelName: m['name'] as String? ?? '—',
                  brandName: _brandName,
                  subcategoryId: widget.subcategoryId,
                  subcategoryName: widget.subcategoryName,
                ),
              ),
            ).then((_) => _load()),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eqCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                    child: Text('$eqCount',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                  ),
                if (_canManage) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    color: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.commonEdit,
                    onPressed: () => _showModelDialog(l10n, model: m),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 16),
                    color: eqCount > 0 ? AppColors.textMuted : AppColors.error,
                    visualDensity: VisualDensity.compact,
                    tooltip: eqCount > 0 ? l10n.catalogDeleteBlockedTooltip : l10n.commonDelete,
                    onPressed: eqCount > 0 ? null : () => _confirmDeleteModel(l10n, m),
                  ),
                ] else
                  const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Renommer le fabricant ───────────────────────────────────────────────────
  void _showRenameBrandDialog(AppLocalizations l10n) {
    final ctrl = TextEditingController(text: _brandName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.catalogRenameBrand),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.catalogBrandName,
            prefixIcon: const Icon(Icons.factory_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await DbApiService.instance.updateBrand(widget.brandId, name);
                await _load();
                _snack(l10n.catalogBrandRenamed);
              } on ApiException catch (e) {
                _snack(e.message, error: true);
              }
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }

  // ── Ajouter / renommer un modèle ────────────────────────────────────────────
  void _showModelDialog(AppLocalizations l10n, {Map<String, dynamic>? model}) {
    final isEdit = model != null;
    final ctrl = TextEditingController(text: isEdit ? model['name'] as String? : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? l10n.catalogRenameModel : l10n.catalogAddModel),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.catalogModelName,
            prefixIcon: const Icon(Icons.devices_other),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                if (isEdit) {
                  await DbApiService.instance.updateModel(model['id'] as int, name: name);
                  _snack(l10n.catalogModelRenamed);
                } else {
                  await DbApiService.instance.createModel(
                    brandId: widget.brandId,
                    subcategoryId: widget.subcategoryId,
                    name: name,
                  );
                  _snack(l10n.catalogModelAdded);
                }
                await _load();
              } on ApiException catch (e) {
                _snack(e.message, error: true);
              }
            },
            child: Text(isEdit ? l10n.commonSave : l10n.commonAdd),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteModel(AppLocalizations l10n, Map<String, dynamic> model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.catalogDeleteModel),
        content: Text(l10n.settingsDeleteConfirm(model['name'] as String? ?? '')),
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
      await DbApiService.instance.deleteModel(model['id'] as int);
      await _load();
      _snack(l10n.catalogModelDeleted);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }
}
