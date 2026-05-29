import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/equipment.dart';
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
  final _manufacturerController = TextEditingController();
  final _modelController = TextEditingController();
  final _manufYearController = TextEditingController();
  final _locationController = TextEditingController();
  final _step2Key = GlobalKey<FormState>();

  // ── Étape 3 : GMAO & Maintenance ─────────────────────────────────────────
  EquipmentCriticality? _selectedCriticality;
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
      _manufacturerController.text = eq.manufacturer ?? '';
      _modelController.text = eq.model ?? '';
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
    }
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
    _manufacturerController.dispose();
    _modelController.dispose();
    _manufYearController.dispose();
    _locationController.dispose();
    super.dispose();
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

    final manufacturer = _manufacturerController.text.trim();
    final model        = _modelController.text.trim();
    final location     = _locationController.text.trim();
    final manufYear    = int.tryParse(_manufYearController.text);

    if (manufacturer.isNotEmpty) data['manufacturer'] = manufacturer;
    if (model.isNotEmpty)        data['model'] = model;
    if (location.isNotEmpty)     data['location'] = location;
    if (manufYear != null)       data['manuf_year'] = manufYear;
    if (_installDate != null)    data['install_date'] = _installDate;
    if (_lastPmDate != null)     data['last_preventive_maintenance'] = _lastPmDate;
    if (_nextPmDate != null)     data['next_preventive_maintenance'] = _nextPmDate;
    if (_nextRevisionDate != null) data['next_revision_date'] = _nextRevisionDate;
    if (_selectedCriticality != null) data['criticality'] = _selectedCriticality!.displayName;

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

  // ── Étape 2 : Infos techniques ────────────────────────────────────────────

  Widget _buildStep2(AppLocalizations l10n) {
    return Column(
      children: [
        TextFormField(
          controller: _manufacturerController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.equipmentManufacturer,
            hintText: l10n.equipmentManufacturerHint,
            prefixIcon: const Icon(Icons.precision_manufacturing),
          ),
        ),
        const SizedBox(height: 16),
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
        TextField(
          controller: _modelController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.equipmentModel,
            hintText: l10n.equipmentModelHint,
            prefixIcon: const Icon(Icons.developer_board),
          ),
        ),
        const SizedBox(height: 16),
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

  // ── Étape 3 : GMAO & Maintenance ─────────────────────────────────────────

  Widget _buildStep3(AppLocalizations l10n) {
    return Column(
      children: [
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
