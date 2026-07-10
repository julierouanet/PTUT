import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../services/db_api_service.dart';
import '../../theme/app_theme.dart';
import '../catalog_search_field.dart';

/// Ouvre un dialog dédié pour rattacher/changer le fabricant ET le modèle
/// catalogue d'un équipement (2 champs recherche+dropdown+ajouter en
/// cascade, même logique que l'étape 2 du formulaire de création). Contrairement
/// à `showEquipmentFieldEditDialog` (édition texte libre d'UN champ), ce
/// dialog gère 2 champs liés avec chargement réseau asynchrone.
///
/// Sauvegarde `model_id` + les colonnes texte legacy `manufacturer`/`model`
/// (nom du fabricant/modèle choisi) via `DbApiService.updateEquipment`.
/// Retourne `true` si la sauvegarde a réussi (l'appelant recharge la fiche).
Future<bool> showEquipmentCatalogEditDialog({
  required BuildContext context,
  required Equipment equipment,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _EquipmentCatalogEditDialog(equipment: equipment),
  );
  return result ?? false;
}

class _EquipmentCatalogEditDialog extends StatefulWidget {
  final Equipment equipment;
  const _EquipmentCatalogEditDialog({required this.equipment});

  @override
  State<_EquipmentCatalogEditDialog> createState() =>
      _EquipmentCatalogEditDialogState();
}

class _EquipmentCatalogEditDialogState
    extends State<_EquipmentCatalogEditDialog> {
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _models = [];
  int? _selectedBrandId;
  int? _selectedModelId;
  bool _loadingBrands = true;
  bool _loadingModels = false;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedBrandId = widget.equipment.brandId;
    _selectedModelId = widget.equipment.modelId;
    _load();
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loadingBrands = true;
      _errorMessage = null;
    });
    try {
      final modelsF = _selectedBrandId != null
          ? DbApiService.instance.getModels(brandId: _selectedBrandId!)
          : Future.value(<Map<String, dynamic>>[]);
      final results =
          await Future.wait([DbApiService.instance.getBrands(), modelsF]);
      if (mounted) {
        setState(() {
          _brands = results[0];
          _models = results[1];
          _loadingBrands = false;
        });
      }
    } catch (_) {
      // Échec réseau au chargement initial (offline, API indisponible) :
      // les listes restent vides, l'utilisateur doit le savoir explicitement
      // plutôt que de voir un dialog silencieusement inutilisable.
      if (mounted) {
        setState(() {
          _loadingBrands = false;
          _errorMessage = l10n.commonApiError;
        });
      }
    }
  }

  Future<void> _onBrandSelected(int? brandId) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _selectedBrandId = brandId;
      _selectedModelId = null;
      _models = [];
      _errorMessage = null;
    });
    if (brandId == null) return;
    setState(() => _loadingModels = true);
    try {
      final list = await DbApiService.instance.getModels(brandId: brandId);
      if (mounted) {
        setState(() {
          _models = list;
          _loadingModels = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingModels = false;
          _errorMessage = l10n.commonApiError;
        });
      }
    }
  }

  Future<int> _createBrand(String name) async {
    final created = await DbApiService.instance.createBrand(name);
    final newId = created['id'] as int;
    if (mounted) setState(() => _brands = [..._brands, {'id': newId, 'name': name}]);
    return newId;
  }

  Future<int> _createModel(String name) async {
    final created = await DbApiService.instance
        .createModel(brandId: _selectedBrandId!, name: name);
    final newId = created['id'] as int;
    if (mounted) setState(() => _models = [..._models, {'id': newId, 'name': name}]);
    return newId;
  }

  // ── Dialog générique de création catalogue (fabricant ou modèle) ─────────
  Future<void> _showCreateCatalogDialog({
    required AppLocalizations l10n,
    required String title,
    required String labelText,
    required Future<void> Function(String name) onCreate,
  }) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;
    String? errorMessage;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: ctrl,
                  autofocus: true,
                  enabled: !saving,
                  decoration: InputDecoration(labelText: labelText),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.commonFillRequiredFields
                      : null,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() {
                        saving = true;
                        errorMessage = null;
                      });
                      try {
                        await onCreate(ctrl.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                      } on ApiException catch (e) {
                        // Ex. 409 "Un fabricant avec ce nom existe déjà" (catalog.js:113/143)
                        setDialogState(() {
                          saving = false;
                          errorMessage = e.message;
                        });
                      } catch (_) {
                        setDialogState(() {
                          saving = false;
                          errorMessage = l10n.commonApiError;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _openAddBrandDialog(AppLocalizations l10n) => _showCreateCatalogDialog(
        l10n: l10n,
        title: l10n.equipmentAddBrand,
        labelText: l10n.equipmentBrandLabel,
        onCreate: (name) async {
          final newId = await _createBrand(name);
          if (mounted) await _onBrandSelected(newId);
        },
      );

  Future<void> _openAddModelDialog(AppLocalizations l10n) {
    if (_selectedBrandId == null) return Future.value();
    return _showCreateCatalogDialog(
      l10n: l10n,
      title: l10n.equipmentAddModel,
      labelText: l10n.equipmentModelLabel,
      onCreate: (name) async {
        final newId = await _createModel(name);
        if (mounted) setState(() => _selectedModelId = newId);
      },
    );
  }

  Future<void> _save(AppLocalizations l10n) async {
    if (_selectedModelId == null) {
      setState(() => _errorMessage = l10n.equipmentSelectModelRequired);
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    final brandMatch = _brands.where((b) => b['id'] == _selectedBrandId);
    final modelMatch = _models.where((m) => m['id'] == _selectedModelId);
    final brandName = brandMatch.isNotEmpty ? brandMatch.first['name'] as String : '';
    final modelName = modelMatch.isNotEmpty ? modelMatch.first['name'] as String : '';
    try {
      await DbApiService.instance.updateEquipment(widget.equipment.id, {
        'model_id': _selectedModelId,
        'manufacturer': brandName,
        'model': modelName,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = l10n.commonApiError;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.equipmentEditBrandModelTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CatalogSearchField(
                    label: l10n.equipmentBrandLabel,
                    icon: Icons.precision_manufacturing,
                    items: _brands,
                    selectedId: _selectedBrandId,
                    loading: _loadingBrands,
                    apiErrorLabel: l10n.commonApiError,
                    addOptionLabel: (q) => l10n.equipmentCatalogAddOption(q),
                    onCreate: _createBrand,
                    onSelected: (id) => _onBrandSelected(id),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: l10n.equipmentAddBrand,
                  onPressed: () => _openAddBrandDialog(l10n),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CatalogSearchField(
                    label: l10n.equipmentModelLabel,
                    icon: Icons.developer_board,
                    items: _models,
                    selectedId: _selectedModelId,
                    enabled: _selectedBrandId != null,
                    disabledHint: l10n.equipmentSelectBrandFirst,
                    loading: _loadingModels,
                    apiErrorLabel: l10n.commonApiError,
                    addOptionLabel: (q) => l10n.equipmentCatalogAddOption(q),
                    onCreate: _createModel,
                    onSelected: (id) => setState(() => _selectedModelId = id),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: l10n.equipmentAddModel,
                  onPressed: _selectedBrandId == null ? null : () => _openAddModelDialog(l10n),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: _saving ? null : () => _save(l10n),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(l10n.commonSave),
        ),
      ],
    );
  }
}
