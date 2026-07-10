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
            CatalogSearchField(
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
            const SizedBox(height: 16),
            CatalogSearchField(
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
