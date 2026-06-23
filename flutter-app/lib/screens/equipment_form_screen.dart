import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/equipment.dart';
import '../services/auth_service.dart';
import '../services/config_service.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';

/// Écran dédié création / édition d'un équipement.
/// Remplace le dialog mono-bloc par un Stepper 3 étapes mobile-first.
///
/// Retourne `true` via Navigator.pop si l'enregistrement a réussi.
class EquipmentFormScreen extends StatefulWidget {
  /// null → création, non-null → édition de l'équipement existant.
  final Equipment? existing;

  const EquipmentFormScreen({super.key, this.existing});

  @override
  State<EquipmentFormScreen> createState() => _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends State<EquipmentFormScreen> {
  int _currentStep = 0;
  bool _isSaving = false;

  // ── Étape 1 : Infos essentielles ────────────────────────────────────────
  final _nameController = TextEditingController();
  String _selectedDepartment = '';
  String _selectedCategory = '';
  EquipmentStatus _selectedStatus = EquipmentStatus.operational;
  final _step1Key = GlobalKey<FormState>();

  // ── Étape 2 : Infos techniques ───────────────────────────────────────────
  final _serialController = TextEditingController();
  final _manufYearController = TextEditingController();
  final _locationController = TextEditingController();
  final _step2Key = GlobalKey<FormState>();

  // ── Catalogue fabricant / modèle (FEAT-065) ───────────────────────────
  int? _selectedBrandId;
  int? _selectedModelId;
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _models = [];
  bool _brandsLoading = false;

  // ── Nouveaux champs texte ──────────────────────────────────────────────
  final _tagController = TextEditingController();
  final _buildingController = TextEditingController();

  // ── Sous-catégorie pré-remplie depuis le modèle sélectionné ───────────
  int? _subcategoryId;

  // ── Fréquence PM pré-remplie depuis le protocole du modèle sélectionné
  int? _pmFrequencyFromModel;

  // ── Étape 3 : GMAO & Maintenance ─────────────────────────────────────────
  EquipmentCriticality? _selectedCriticality;
  bool _pmRequired = false;
  String? _installDate;
  String? _lastPmDate;
  String? _nextPmDate;
  String? _nextRevisionDate;

  final _configService = ConfigService();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final eq = widget.existing;
    if (eq != null) {
      _nameController.text = eq.name;
      _serialController.text = eq.serialNumber;
      _manufYearController.text = eq.manufYear?.toString() ?? '';
      _locationController.text = eq.location;
      _selectedDepartment = eq.department;
      _selectedCategory = eq.category;
      _selectedStatus = eq.status;
      _selectedCriticality = eq.criticality;
      _installDate = eq.installDate;
      _lastPmDate = eq.lastPreventiveMaintenance;
      _nextPmDate = eq.nextPreventiveMaintenance;
      _nextRevisionDate = eq.nextRevisionDate;
      _buildingController.text = eq.building ?? '';
      _tagController.text = eq.tags.isNotEmpty ? eq.tags.first : '';
      _selectedBrandId = eq.brandId;
      _selectedModelId = eq.modelId;
      _subcategoryId = eq.subcategoryId;
      if (eq.nextPreventiveMaintenance != null || eq.lastPreventiveMaintenance != null) {
        _pmRequired = true;
      }
    }
    // Charge la liste des fabricants (et les modèles du brand si édition)
    _loadBrands();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialise les menus déroulants avec la première valeur disponible
    // (uniquement à la création, pour éviter d'écraser les valeurs d'édition).
    if (!_isEdit) {
      if (_selectedDepartment.isEmpty && _configService.departmentNames.isNotEmpty) {
        _selectedDepartment = _configService.departmentNames.first;
      }
      if (_selectedCategory.isEmpty && _configService.categoryNames.isNotEmpty) {
        _selectedCategory = _configService.categoryNames.first;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serialController.dispose();
    _manufYearController.dispose();
    _locationController.dispose();
    _tagController.dispose();
    _buildingController.dispose();
    super.dispose();
  }

  // ── Chargement catalogue fabricant/modèle ─────────────────────────────

  Future<void> _loadBrands() async {
    if (mounted) setState(() => _brandsLoading = true);
    try {
      // Paralléliser les deux requêtes indépendantes
      final modelsF = _selectedBrandId != null
          ? DbApiService.instance.getModels(brandId: _selectedBrandId!)
          : Future.value(<Map<String, dynamic>>[]);
      final results = await Future.wait([DbApiService.instance.getBrands(), modelsF]);
      if (mounted) setState(() {
        _brands = results[0];
        _models = results[1];
        _brandsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _brandsLoading = false);
    }
  }

  Future<void> _onBrandSelected(int? brandId) async {
    setState(() {
      _selectedBrandId = brandId;
      _selectedModelId = null;
      _models = [];
      _pmFrequencyFromModel = null;
    });
    if (brandId == null) return;
    try {
      final list = await DbApiService.instance.getModels(brandId: brandId);
      if (mounted) setState(() => _models = list);
    } catch (_) {}
  }

  Future<void> _onModelSelected(int? modelId) async {
    setState(() { _selectedModelId = modelId; _pmFrequencyFromModel = null; });
    if (modelId == null) return;
    try {
      final detail = await DbApiService.instance.getModelDetail(modelId);
      // Pré-remplir la sous-catégorie depuis le modèle
      final rawSubId = detail['subcategory_id'];
      if (rawSubId != null) {
        final subId = rawSubId is int ? rawSubId : int.tryParse(rawSubId.toString());
        if (subId != null && mounted) setState(() => _subcategoryId = subId);
      }
      // Pré-remplir la fréquence PM depuis le 1er protocole du modèle
      final protocols = detail['protocols'] as List? ?? [];
      if (protocols.isNotEmpty) {
        final freq = (protocols.first as Map)['frequency_months'];
        final freqInt = freq is int ? freq : int.tryParse(freq?.toString() ?? '');
        if (freqInt != null && mounted) setState(() => _pmFrequencyFromModel = freqInt);
      }
    } catch (_) {}
  }

  // ── Navigation entre étapes ───────────────────────────────────────────────

  void _onStepContinue() {
    if (_currentStep == 0) {
      if (_step1Key.currentState?.validate() ?? false) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      if (_step2Key.currentState?.validate() ?? false) {
        setState(() => _currentStep = 2);
      }
    } else {
      _submit();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context, false);
    }
  }

  /// Interdit de sauter en avant par clic — on peut revenir en arrière.
  void _onStepTapped(int step) {
    if (step < _currentStep) setState(() => _currentStep = step);
  }

  // ── Soumission API ────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _isSaving = true);

    final data = <String, dynamic>{
      'id':        _isEdit ? widget.existing!.id : 'eq-${DateTime.now().millisecondsSinceEpoch}',
      'name':      _nameController.text.trim(),
      'department': _selectedDepartment,
      'category':  _selectedCategory,
      'status':    _selectedStatus.displayName,
      'serial_number': _serialController.text.trim(),
    };

    final location  = _locationController.text.trim();
    final manufYear = int.tryParse(_manufYearController.text);
    final building  = _buildingController.text.trim();
    final tagNumber = _tagController.text.trim();

    if (location.isNotEmpty)   data['location']    = location;
    if (manufYear != null)     data['manuf_year']  = manufYear;
    if (_installDate != null)  data['install_date'] = _installDate;
    if (_nextRevisionDate != null) data['next_revision_date'] = _nextRevisionDate;
    if (_selectedCriticality != null) data['criticality'] = _selectedCriticality!.displayName;
    if (building.isNotEmpty)   data['building']    = building;
    if (tagNumber.isNotEmpty)  data['tag_number']  = tagNumber;
    if (_selectedModelId != null) data['model_id'] = _selectedModelId;
    if (_subcategoryId != null)   data['subcategory_id'] = _subcategoryId;

    // Dates PM : visibles et sauvegardées uniquement si PM requise
    if (_pmRequired) {
      if (_lastPmDate != null) data['last_preventive_maintenance'] = _lastPmDate;
      if (_nextPmDate != null) data['next_preventive_maintenance'] = _nextPmDate;
    } else {
      // Effacer les dates PM existantes si le toggle est désactivé
      data['last_preventive_maintenance'] = null;
      data['next_preventive_maintenance'] = null;
    }

    try {
      if (_isEdit) {
        await DbApiService.instance.updateEquipment(widget.existing!.id, data);
      } else {
        await DbApiService.instance.createEquipment(data);
      }
      await DataService().reloadEquipment();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.commonApiError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.equipmentEditTitle : l10n.equipmentNewTitle,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        onStepTapped: _onStepTapped,
        controlsBuilder: _buildControls,
        steps: [
          Step(
            title: Text(l10n.equipmentFormStep1,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(l10n.equipmentFormStep1Subtitle,
                style: const TextStyle(fontSize: 12)),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: Form(key: _step1Key, child: _buildStep1(l10n)),
          ),
          Step(
            title: Text(l10n.equipmentFormStep2,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(l10n.equipmentFormStep2Subtitle,
                style: const TextStyle(fontSize: 12)),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Form(key: _step2Key, child: _buildStep2(l10n)),
          ),
          Step(
            title: Text(l10n.equipmentFormStep3,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(l10n.equipmentFormStep3Subtitle,
                style: const TextStyle(fontSize: 12)),
            isActive: _currentStep >= 2,
            state: StepState.indexed,
            content: _buildStep3(l10n),
          ),
        ],
      ),
    );
  }

  // ── Boutons de navigation du Stepper ─────────────────────────────────────

  Widget _buildControls(BuildContext context, ControlsDetails details) {
    final l10n = AppLocalizations.of(context)!;
    final isLast = _currentStep == 2;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          ElevatedButton(
            onPressed: _isSaving ? null : details.onStepContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isLast ? l10n.commonSave : l10n.commonNext),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: details.onStepCancel,
            child: Text(_currentStep == 0 ? l10n.commonCancel : l10n.commonBack),
          ),
        ],
      ),
    );
  }

  // ── Étape 1 : Infos essentielles ─────────────────────────────────────────

  Widget _buildStep1(AppLocalizations l10n) {
    final departments = _configService.departmentNames;
    final categories  = _configService.categoryNames;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nameController,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.equipmentNameLabel,
            hintText: l10n.equipmentNameHint,
            prefixIcon: const Icon(Icons.inventory_2),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? l10n.commonFillRequiredFields : null,
        ),
        const SizedBox(height: 16),
        if (categories.isNotEmpty)
          DropdownButtonFormField<String>(
            value: categories.contains(_selectedCategory) ? _selectedCategory : categories.first,
            decoration: InputDecoration(
              labelText: l10n.equipmentCategoryLabel,
              prefixIcon: const Icon(Icons.category),
            ),
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCategory = v!),
          ),
        const SizedBox(height: 16),
        if (departments.isNotEmpty)
          DropdownButtonFormField<String>(
            value: departments.contains(_selectedDepartment) ? _selectedDepartment : departments.first,
            decoration: InputDecoration(
              labelText: l10n.equipmentDepartmentLabel,
              prefixIcon: const Icon(Icons.business),
            ),
            items: departments
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setState(() => _selectedDepartment = v!),
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<EquipmentStatus>(
          value: _selectedStatus,
          decoration: InputDecoration(
            labelText: l10n.commonStatus,
            prefixIcon: const Icon(Icons.info_outline),
          ),
          items: EquipmentStatus.values
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Row(children: [
                      _statusIcon(s),
                      const SizedBox(width: 8),
                      Text(s.localizedName(l10n)),
                    ]),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedStatus = v!),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Dropdown avec bouton + inline (fabricant ou modèle) ──────────────────

  Widget _buildDropdownWithAdd({
    required Widget dropdown,
    required bool canAdd,
    required String tooltip,
    required VoidCallback? onAdd,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: dropdown),
        if (canAdd)
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: tooltip,
            onPressed: onAdd,
          ),
      ],
    );
  }

  // ── Étape 2 : Infos techniques ────────────────────────────────────────────

  Widget _buildStep2(AppLocalizations l10n) {
    final canManage = AuthService().canManageEquipment;
    return Column(
      children: [
        // ── Fabricant (dropdown catalogue) ───────────────────────────────
        _buildDropdownWithAdd(
          canAdd: canManage,
          tooltip: l10n.equipmentAddBrand,
          onAdd: () => _showCreateBrandDialog(l10n),
          dropdown: _brandsLoading
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<int?>(
                  value: _brands.any((b) => b['id'] == _selectedBrandId)
                      ? _selectedBrandId
                      : null,
                  decoration: InputDecoration(
                    labelText: l10n.equipmentBrandLabel,
                    prefixIcon: const Icon(Icons.precision_manufacturing),
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                        value: null, child: Text('— ${l10n.equipmentNoBrand} —')),
                    ..._brands.map((b) => DropdownMenuItem<int?>(
                          value: b['id'] as int,
                          child: Text(b['name'] as String),
                        )),
                  ],
                  onChanged: (v) => _onBrandSelected(v),
                ),
        ),
        const SizedBox(height: 16),
        // ── Modèle (dropdown cascade, activé après sélection d'un fabricant)
        _buildDropdownWithAdd(
          canAdd: canManage,
          tooltip: l10n.equipmentAddModel,
          onAdd: _selectedBrandId == null ? null : () => _showCreateModelDialog(l10n),
          dropdown: DropdownButtonFormField<int?>(
            value: _models.any((m) => m['id'] == _selectedModelId)
                ? _selectedModelId
                : null,
            decoration: InputDecoration(
              labelText: l10n.equipmentModelLabel,
              prefixIcon: const Icon(Icons.developer_board),
            ),
            items: [
              DropdownMenuItem<int?>(
                  value: null, child: Text('— ${l10n.equipmentNoModel} —')),
              ..._models.map((m) => DropdownMenuItem<int?>(
                    value: m['id'] as int,
                    child: Text(m['name'] as String),
                  )),
            ],
            onChanged: _selectedBrandId == null ? null : (v) => _onModelSelected(v),
          ),
        ),
        const SizedBox(height: 16),
        // ── Tag physique ──────────────────────────────────────────────────
        TextFormField(
          controller: _tagController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.equipmentTagNumber,
            hintText: l10n.equipmentTagHint,
            prefixIcon: const Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 16),
        // ── Bâtiment ─────────────────────────────────────────────────────
        TextField(
          controller: _buildingController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.equipmentBuilding,
            hintText: l10n.equipmentBuildingHint,
            prefixIcon: const Icon(Icons.apartment),
          ),
        ),
        const SizedBox(height: 16),
        // ── Numéro de série ───────────────────────────────────────────────
        TextFormField(
          controller: _serialController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.equipmentSerialLabel,
            hintText: l10n.equipmentSerialHint,
            prefixIcon: const Icon(Icons.qr_code),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? l10n.commonFillRequiredFields : null,
        ),
        const SizedBox(height: 16),
        // ── Localisation (salle / pièce) ──────────────────────────────────
        TextField(
          controller: _locationController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.equipmentLocation,
            hintText: l10n.equipmentLocationHint,
            prefixIcon: const Icon(Icons.location_on),
          ),
        ),
        const SizedBox(height: 16),
        // ── Année de fabrication ──────────────────────────────────────────
        TextFormField(
          controller: _manufYearController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.equipmentManufYear,
            hintText: l10n.equipmentManufYearHint,
            prefixIcon: const Icon(Icons.date_range),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            final n = int.tryParse(v);
            if (n == null || n < 1900 || n > 2100) return '1900–2100';
            return null;
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Dialog générique de création catalogue (brand ou model) ──────────────

  Future<void> _showCreateCatalogDialog({
    required AppLocalizations l10n,
    required String title,
    required String labelText,
    required Future<void> Function(String name) onCreate,
  }) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(labelText: labelText),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.commonFillRequiredFields : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              try {
                await onCreate(ctrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(l10n.commonApiError),
                    backgroundColor: AppColors.error,
                  ));
                }
              }
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  // Crée un fabricant, l'ajoute localement et le sélectionne sans re-fetcher la liste.
  Future<void> _showCreateBrandDialog(AppLocalizations l10n) => _showCreateCatalogDialog(
    l10n: l10n,
    title: l10n.equipmentAddBrand,
    labelText: l10n.equipmentBrandLabel,
    onCreate: (name) async {
      final created = await DbApiService.instance.createBrand(name);
      final newId = created['id'] as int;
      if (mounted) setState(() {
        _brands = [..._brands, {'id': newId, 'name': name}];
        _selectedBrandId = newId;
        _selectedModelId = null;
        _models = [];
        _pmFrequencyFromModel = null;
      });
    },
  );

  // Crée un modèle, l'ajoute localement puis charge son protocole via _onModelSelected.
  Future<void> _showCreateModelDialog(AppLocalizations l10n) {
    if (_selectedBrandId == null) return Future.value();
    return _showCreateCatalogDialog(
      l10n: l10n,
      title: l10n.equipmentAddModel,
      labelText: l10n.equipmentModelLabel,
      onCreate: (name) async {
        final created = await DbApiService.instance.createModel(
          brandId: _selectedBrandId!,
          name: name,
        );
        final newId = created['id'] as int;
        if (mounted) setState(() => _models = [..._models, {'id': newId, 'name': name}]);
        await _onModelSelected(newId);
      },
    );
  }

  // ── Étape 3 : GMAO & Maintenance ─────────────────────────────────────────

  Widget _buildStep3(AppLocalizations l10n) {
    return Column(
      children: [
        // ── Criticité ABC ─────────────────────────────────────────────────
        DropdownButtonFormField<EquipmentCriticality?>(
          value: _selectedCriticality,
          decoration: InputDecoration(
            labelText: l10n.criticalityLabel,
            prefixIcon: const Icon(Icons.priority_high),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('—')),
            ...EquipmentCriticality.values.map((c) => DropdownMenuItem(
                  value: c,
                  child: Row(children: [
                    _criticalityIcon(c),
                    const SizedBox(width: 8),
                    Text(c.localizedLabel(l10n)),
                  ]),
                )),
          ],
          onChanged: (v) => setState(() => _selectedCriticality = v),
        ),
        const SizedBox(height: 16),
        // ── Toggle maintenance préventive ─────────────────────────────────
        SwitchListTile(
          title: Text(l10n.equipmentPmRequired),
          value: _pmRequired,
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _pmRequired = v),
        ),
        // Chip fréquence recommandée (depuis le protocole du modèle sélectionné)
        if (_pmRequired && _pmFrequencyFromModel != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Chip(
              avatar: const Icon(Icons.info_outline, size: 16),
              label: Text(l10n.equipmentPmFreqRecommended(_pmFrequencyFromModel!)),
              backgroundColor: AppColors.primary.withOpacity(0.08),
            ),
          ),
        // Les 4 champs de dates sont masqués si PM non requise
        Visibility(
          visible: _pmRequired,
          maintainState: true,
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildDateField(
                label: l10n.equipmentInstallDate,
                iso: _installDate,
                onPicked: (v) => setState(() => _installDate = v),
                icon: Icons.event_available,
                firstDate: DateTime(1980),
                lastDate: DateTime.now(),
                l10n: l10n,
              ),
              const SizedBox(height: 16),
              _buildDateField(
                label: l10n.lastPreventiveDate,
                iso: _lastPmDate,
                onPicked: (v) => setState(() => _lastPmDate = v),
                icon: Icons.history,
                firstDate: DateTime(1980),
                lastDate: DateTime.now(),
                l10n: l10n,
              ),
              const SizedBox(height: 16),
              _buildDateField(
                label: l10n.nextPreventiveDate,
                iso: _nextPmDate,
                onPicked: (v) => setState(() => _nextPmDate = v),
                icon: Icons.event_available,
                firstDate: DateTime.now(),
                lastDate: DateTime(DateTime.now().year + 10),
                l10n: l10n,
              ),
              const SizedBox(height: 16),
              _buildDateField(
                label: l10n.equipmentNextRevision,
                iso: _nextRevisionDate,
                onPicked: (v) => setState(() => _nextRevisionDate = v),
                icon: Icons.event,
                firstDate: DateTime.now(),
                lastDate: DateTime(DateTime.now().year + 10),
                l10n: l10n,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Champ date picker réutilisable ────────────────────────────────────────

  Widget _buildDateField({
    required String label,
    required String? iso,
    required ValueChanged<String?> onPicked,
    required IconData icon,
    required DateTime firstDate,
    required DateTime lastDate,
    required AppLocalizations l10n,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () async {
            final initial = iso != null ? DateTime.tryParse(iso) ?? firstDate : firstDate;
            final clamped = initial.isBefore(firstDate)
                ? firstDate
                : (initial.isAfter(lastDate) ? lastDate : initial);
            final picked = await showDatePicker(
              context: context,
              initialDate: clamped,
              firstDate: firstDate,
              lastDate: lastDate,
              locale: const Locale('fr'),
            );
            if (picked != null) onPicked(picked.toIso8601String().substring(0, 10));
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(
              iso != null && iso.isNotEmpty
                  ? _fmtDate(iso)
                  : l10n.equipmentSelectDate,
              style: TextStyle(
                color: iso != null && iso.isNotEmpty ? null : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        if (iso != null && iso.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onPicked(null),
              icon: const Icon(Icons.clear, size: 14),
              label: Text(l10n.equipmentRemoveDate),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  // ── Helpers visuels ───────────────────────────────────────────────────────

  Widget _statusIcon(EquipmentStatus s) {
    IconData icon;
    Color color;
    switch (s) {
      case EquipmentStatus.operational:
        icon = Icons.check_circle; color = AppColors.success;
      case EquipmentStatus.maintenance:
        icon = Icons.build_circle; color = AppColors.warning;
      case EquipmentStatus.outOfService:
        icon = Icons.cancel; color = AppColors.error;
      case EquipmentStatus.toBeDisposal:
        icon = Icons.delete_outline; color = AppColors.warning;
      case EquipmentStatus.disposed:
        icon = Icons.delete_forever; color = AppColors.textSecondary;
    }
    return Icon(icon, color: color, size: 18);
  }

  Widget _criticalityIcon(EquipmentCriticality c) {
    Color color;
    switch (c) {
      case EquipmentCriticality.a: color = AppColors.error;
      case EquipmentCriticality.b: color = AppColors.warning;
      case EquipmentCriticality.c: color = AppColors.success;
    }
    return Container(
      width: 20, height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(c.displayName,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  /// Formate une date ISO (YYYY-MM-DD) → "DD/MM/YYYY".
  String _fmtDate(String iso) {
    if (iso.length < 10) return iso;
    final p = iso.substring(0, 10).split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
  }
}
