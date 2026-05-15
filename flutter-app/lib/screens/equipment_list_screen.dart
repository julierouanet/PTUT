import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../models/equipment.dart';
import '../widgets/status_badge.dart';
import 'equipment_detail_screen.dart';
import '../services/config_service.dart';
import '../services/auth_service.dart';

/// Equipment list screen with search and filters
class EquipmentListScreen extends StatefulWidget {
  final Function(int, {String? equipmentId}) onNavigate;

  const EquipmentListScreen({super.key, required this.onNavigate});

  @override
  State<EquipmentListScreen> createState() => _EquipmentListScreenState();
}

class _EquipmentListScreenState extends State<EquipmentListScreen> {
  String _searchTerm = '';
  String _departmentFilter = 'Tous';
  String _statusFilter = 'Tous';
  String _categoryFilter = 'Tous';
  final ConfigService _configService = ConfigService();
  final AuthService _authService = AuthService();

  List<String> _departments(String allLabel) => [allLabel, ...DataService().equipment.map((e) => e.department).toSet()];
  List<String> _statuses(String allLabel) => [
        allLabel,
        ...EquipmentStatus.values.map((s) => s.displayName),
      ];
  List<String> _categories(String allLabel) => [allLabel, ...DataService().equipment.map((e) => e.category).toSet()];

  List<Equipment> get _filteredEquipment {
    final l10n = AppLocalizations.of(context)!;
    final term = _searchTerm.toLowerCase();
    return DataService().equipment.where((eq) {
      final matchesSearch = term.isEmpty ||
          eq.name.toLowerCase().contains(term) ||
          eq.serialNumber.toLowerCase().contains(term) ||
          (eq.manufacturer?.toLowerCase().contains(term) ?? false) ||
          (eq.model?.toLowerCase().contains(term) ?? false);
      final matchesDepartment = _departmentFilter == l10n.commonAll || eq.department == _departmentFilter;
      final matchesStatus = _statusFilter == l10n.commonAll || eq.status.displayName == _statusFilter;
      final matchesCategory = _categoryFilter == l10n.commonAll || eq.category == _categoryFilter;
      return matchesSearch && matchesDepartment && matchesStatus && matchesCategory;
    }).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    if (_departmentFilter == 'Tous') _departmentFilter = l10n.commonAll;
    if (_statusFilter == 'Tous') _statusFilter = l10n.commonAll;
    if (_categoryFilter == 'Tous') _categoryFilter = l10n.commonAll;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isAdmin = _authService.canManageEquipment;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Add button
            if (isMobile) ...[
              Text(l10n.equipmentTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(l10n.equipmentSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
              if (isAdmin) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showAddEquipmentDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.equipmentNew),
                  ),
                ),
              ],
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.equipmentTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(l10n.equipmentSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  if (isAdmin)
                    ElevatedButton.icon(
                      onPressed: _showAddEquipmentDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.equipmentNew),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                    ),
                ],
              ),
            const SizedBox(height: 16),

            // Quick filter - My department
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: Text(_authService.currentUser?.department ?? l10n.commonDepartment),
                  avatar: const Icon(Icons.business, size: 16),
                  selected: _departmentFilter == (_authService.currentUser?.department ?? ''),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  onSelected: (selected) {
                    setState(() {
                      _departmentFilter = selected
                          ? (_authService.currentUser?.department ?? l10n.commonAll)
                          : l10n.commonAll;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search and Filters - FULL WIDTH
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMobile) ...[
                      _buildSearchField(),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _buildDropdown(l10n.commonDepartment, _departmentFilter, _departments(l10n.commonAll), (v) => setState(() => _departmentFilter = v!))),
                        const SizedBox(width: 10),
                        Expanded(child: _buildDropdown(l10n.commonStatus, _statusFilter, _statuses(l10n.commonAll), (v) => setState(() => _statusFilter = v!))),
                      ]),
                      const SizedBox(height: 10),
                      _buildDropdown(l10n.commonCategory, _categoryFilter, _categories(l10n.commonAll), (v) => setState(() => _categoryFilter = v!)),
                    ] else
                      Row(
                        children: [
                          Expanded(child: _buildSearchField()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDropdown(l10n.commonDepartment, _departmentFilter, _departments(l10n.commonAll), (v) => setState(() => _departmentFilter = v!))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDropdown(l10n.commonStatus, _statusFilter, _statuses(l10n.commonAll), (v) => setState(() => _statusFilter = v!))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDropdown(l10n.commonCategory, _categoryFilter, _categories(l10n.commonAll), (v) => setState(() => _categoryFilter = v!))),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.equipmentFound(_filteredEquipment.length),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Equipment list — tableau unifié avec scroll horizontal anti-overflow
            _buildUnifiedTable(l10n),
          ],
        ),
      ),
    );
  }

  // ── DataTable unifié (toutes tailles d'écran) ────────────────────────────

  Widget _buildUnifiedTable(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.background),
            columns: [
              DataColumn(label: Text(l10n.equipmentName,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text(l10n.issueFormTagNumber,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text(l10n.commonStatus,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text(l10n.commonActions,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
            rows: _filteredEquipment.map((eq) {
              final pmBadge = _preventiveBadge(eq, l10n);
              return DataRow(cells: [
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pmBadge != null) ...[pmBadge, const SizedBox(width: 6)],
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        eq.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )),
                DataCell(Text(
                  eq.tags.isNotEmpty ? eq.tags.join(', ') : '—',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                )),
                DataCell(StatusBadge(
                    status: eq.status.displayName, isCompact: true)),
                DataCell(IconButton(
                  icon: const Icon(Icons.visibility, size: 18),
                  color: AppColors.primary,
                  onPressed: () => _showEquipmentDetail(eq),
                  tooltip: l10n.commonDetails,
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildSearchField() {
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      onChanged: (value) => setState(() => _searchTerm = value),
      decoration: InputDecoration(
        hintText: l10n.commonSearch,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }

  void _showAddEquipmentDialog() {
    _showEquipmentFormDialog(null);
  }

  void _showEditEquipmentDialog(Equipment eq) {
    _showEquipmentFormDialog(eq);
  }

  void _showEquipmentFormDialog(Equipment? existingEquipment) {
    final isEdit = existingEquipment != null;
    final l10n = AppLocalizations.of(context)!;

    final nameController = TextEditingController(text: existingEquipment?.name ?? '');
    final serialController = TextEditingController(text: existingEquipment?.serialNumber ?? '');
    final locationController = TextEditingController(text: existingEquipment?.location ?? '');
    final manufacturerController = TextEditingController(text: existingEquipment?.manufacturer ?? '');
    final modelController = TextEditingController(text: existingEquipment?.model ?? '');
    final manufYearController = TextEditingController(
      text: existingEquipment?.manufYear?.toString() ?? '',
    );

    String selectedDepartment = existingEquipment?.department ?? _configService.departmentNames.first;
    String selectedCategory = existingEquipment?.category ?? _configService.categoryNames.first;
    EquipmentStatus selectedStatus = existingEquipment?.status ?? EquipmentStatus.operational;
    String? selectedRevisionDate = existingEquipment?.nextRevisionDate;
    String? selectedInstallDate = existingEquipment?.installDate;
    String? selectedLastPreventiveDate = existingEquipment?.lastPreventiveMaintenance;
    String? selectedNextPreventiveDate = existingEquipment?.nextPreventiveMaintenance;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(isEdit ? Icons.edit : Icons.add_circle, color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            isEdit ? l10n.equipmentEditTitle : l10n.equipmentNewTitle,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Form
                Flexible(
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          TextFormField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: l10n.equipmentNameLabel,
                              hintText: l10n.equipmentNameHint,
                              prefixIcon: const Icon(Icons.inventory_2),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? l10n.commonFillRequiredFields : null,
                          ),
                          const SizedBox(height: 16),

                          // Serial number
                          TextFormField(
                            controller: serialController,
                            decoration: InputDecoration(
                              labelText: l10n.equipmentSerialLabel,
                              hintText: l10n.equipmentSerialHint,
                              prefixIcon: const Icon(Icons.qr_code),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? l10n.commonFillRequiredFields : null,
                          ),
                          const SizedBox(height: 16),

                          // Department and Category
                          DropdownButtonFormField<String>(
                            value: selectedDepartment,
                            decoration: InputDecoration(labelText: l10n.equipmentDepartmentLabel, prefixIcon: const Icon(Icons.business)),
                            items: _configService.departmentNames.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                            onChanged: (v) => setDialogState(() => selectedDepartment = v!),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: InputDecoration(labelText: l10n.equipmentCategoryLabel, prefixIcon: const Icon(Icons.category)),
                            items: _configService.categoryNames.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setDialogState(() => selectedCategory = v!),
                          ),
                          const SizedBox(height: 16),

                          // Location
                          TextField(
                            controller: locationController,
                            decoration: InputDecoration(
                              labelText: l10n.equipmentLocation,
                              hintText: l10n.equipmentLocationHint,
                              prefixIcon: const Icon(Icons.location_on),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Manufacturer
                          TextField(
                            controller: manufacturerController,
                            decoration: InputDecoration(
                              labelText: l10n.equipmentManufacturer,
                              hintText: l10n.equipmentManufacturerHint,
                              prefixIcon: const Icon(Icons.precision_manufacturing),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Model
                          TextField(
                            controller: modelController,
                            decoration: InputDecoration(
                              labelText: l10n.equipmentModel,
                              hintText: l10n.equipmentModelHint,
                              prefixIcon: const Icon(Icons.developer_board),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Manuf year
                          TextFormField(
                            controller: manufYearController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.equipmentManufYear,
                              hintText: l10n.equipmentManufYearHint,
                              prefixIcon: const Icon(Icons.date_range),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final n = int.tryParse(v);
                              if (n == null || n < 1900 || n > 2100) {
                                return '1900 - 2100';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Install date
                          InkWell(
                            onTap: () async {
                              final now = DateTime.now();
                              final initial = selectedInstallDate != null
                                  ? DateTime.tryParse(selectedInstallDate!) ?? now
                                  : now;
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: initial,
                                firstDate: DateTime(1980),
                                lastDate: now,
                                locale: const Locale('fr'),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedInstallDate = picked.toIso8601String().substring(0, 10));
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.equipmentInstallDate,
                                prefixIcon: const Icon(Icons.event_available),
                                suffixIcon: const Icon(Icons.calendar_today, size: 18),
                              ),
                              child: Text(
                                selectedInstallDate != null && selectedInstallDate!.isNotEmpty
                                    ? _formatDateDisplay(selectedInstallDate!)
                                    : l10n.equipmentInstallDateHint,
                                style: TextStyle(
                                  color: selectedInstallDate != null && selectedInstallDate!.isNotEmpty
                                      ? null
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          if (selectedInstallDate != null && selectedInstallDate!.isNotEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => setDialogState(() => selectedInstallDate = null),
                                icon: const Icon(Icons.clear, size: 14),
                                label: const Text('Supprimer la date'),
                                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                              ),
                            ),
                          const SizedBox(height: 16),

                          // Status
                          DropdownButtonFormField<EquipmentStatus>(
                            value: selectedStatus,
                            decoration: InputDecoration(
                              labelText: l10n.commonStatus,
                              prefixIcon: const Icon(Icons.info_outline),
                            ),
                            items: EquipmentStatus.values.map((s) => DropdownMenuItem(
                              value: s,
                              child: Row(
                                children: [
                                  _getStatusIcon(s),
                                  const SizedBox(width: 8),
                                  Text(s.displayName),
                                ],
                              ),
                            )).toList(),
                            onChanged: (v) => setDialogState(() => selectedStatus = v!),
                          ),
                          const SizedBox(height: 16),

                          // Date de prochaine révision
                          InkWell(
                            onTap: () async {
                              final now = DateTime.now();
                              final initial = selectedRevisionDate != null
                                  ? DateTime.tryParse(selectedRevisionDate!) ?? now
                                  : now;
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: initial.isAfter(now) ? initial : now.add(const Duration(days: 30)),
                                firstDate: now,
                                lastDate: DateTime(now.year + 10),
                                locale: const Locale('fr'),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedRevisionDate = picked.toIso8601String().substring(0, 10));
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Prochaine révision',
                                prefixIcon: Icon(Icons.event),
                                suffixIcon: Icon(Icons.calendar_today, size: 18),
                              ),
                              child: Text(
                                selectedRevisionDate != null && selectedRevisionDate!.isNotEmpty
                                    ? _formatDateDisplay(selectedRevisionDate!)
                                    : 'Sélectionner une date (optionnel)',
                                style: TextStyle(
                                  color: selectedRevisionDate != null && selectedRevisionDate!.isNotEmpty
                                      ? null
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          if (selectedRevisionDate != null && selectedRevisionDate!.isNotEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => setDialogState(() => selectedRevisionDate = null),
                                icon: const Icon(Icons.clear, size: 14),
                                label: const Text('Supprimer la date'),
                                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                              ),
                            ),

                          const SizedBox(height: 16),
                          // Dernière maintenance préventive (passé uniquement)
                          _buildDatePickerField(
                            context: context,
                            label: l10n.lastPreventiveDate,
                            iso: selectedLastPreventiveDate,
                            onPicked: (iso) => setDialogState(() => selectedLastPreventiveDate = iso),
                            icon: Icons.history,
                            firstDate: DateTime(1980),
                            lastDate: DateTime.now(),
                          ),

                          const SizedBox(height: 16),
                          // Prochaine maintenance préventive (futur uniquement)
                          _buildDatePickerField(
                            context: context,
                            label: l10n.nextPreventiveDate,
                            iso: selectedNextPreventiveDate,
                            onPicked: (iso) => setDialogState(() => selectedNextPreventiveDate = iso),
                            icon: Icons.event_available,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(DateTime.now().year + 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.commonCancel),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final data = {
                              'id':                 isEdit ? existingEquipment.id : 'eq-${DateTime.now().millisecondsSinceEpoch}',
                              'name':               nameController.text,
                              'serial_number':      serialController.text,
                              'department':         selectedDepartment,
                              'category':           selectedCategory,
                              'location':           locationController.text.isNotEmpty ? locationController.text : null,
                              'status':             selectedStatus.displayName,
                              'next_revision_date': selectedRevisionDate,
                              'manufacturer':       manufacturerController.text.isNotEmpty ? manufacturerController.text : null,
                              'model':              modelController.text.isNotEmpty ? modelController.text : null,
                              'manuf_year':         int.tryParse(manufYearController.text),
                              'install_date':       selectedInstallDate,
                              'last_preventive_maintenance': selectedLastPreventiveDate,
                              'next_preventive_maintenance': selectedNextPreventiveDate,
                            };

                            try {
                              if (isEdit) {
                                await DbApiService.instance.updateEquipment(existingEquipment.id, data);
                              } else {
                                await DbApiService.instance.createEquipment(data);
                              }
                              await DataService().reloadEquipment();
                              if (mounted) setState(() {});
                              if (context.mounted) Navigator.pop(context);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Row(children: [
                                    const Icon(Icons.check_circle, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Text(isEdit ? l10n.equipmentModified : l10n.equipmentAdded),
                                  ]),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(AppLocalizations.of(context)!.commonApiError),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                ));
                              }
                            }
                          },
                          icon: Icon(isEdit ? Icons.save : Icons.add),
                          label: Text(isEdit ? l10n.equipmentSaveChanges : l10n.equipmentAddButton),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getStatusIcon(EquipmentStatus status) {
    IconData icon;
    Color color;
    switch (status) {
      case EquipmentStatus.operational:
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case EquipmentStatus.maintenance:
        icon = Icons.build_circle;
        color = AppColors.warning;
        break;
      case EquipmentStatus.outOfService:
        icon = Icons.cancel;
        color = AppColors.error;
        break;
      case EquipmentStatus.toBeDisposal:
        icon = Icons.delete_outline;
        color = AppColors.warning;
        break;
      case EquipmentStatus.disposed:
        icon = Icons.delete_forever;
        color = AppColors.textSecondary;
        break;
    }
    return Icon(icon, color: color, size: 18);
  }

  /// Champ date picker générique réutilisable dans le formulaire de l'équipement.
  /// Affiche la date au format DD/MM/YYYY ou un placeholder si null. Permet
  /// d'effacer la date via un bouton secondaire.
  Widget _buildDatePickerField({
    required BuildContext context,
    required String label,
    required String? iso,
    required ValueChanged<String?> onPicked,
    required IconData icon,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () async {
            final initial = iso != null
                ? DateTime.tryParse(iso) ?? firstDate
                : firstDate;
            final picked = await showDatePicker(
              context: context,
              initialDate: initial.isBefore(firstDate) ? firstDate : (initial.isAfter(lastDate) ? lastDate : initial),
              firstDate: firstDate,
              lastDate: lastDate,
              locale: const Locale('fr'),
            );
            if (picked != null) {
              onPicked(picked.toIso8601String().substring(0, 10));
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(
              iso != null && iso.isNotEmpty
                  ? _formatDateDisplay(iso)
                  : l10n.equipmentInstallDateHint,
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
              label: const Text('Supprimer la date'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  /// Badge compact "PM" coloré quand la maintenance préventive est échue ou
  /// imminente. Retourne null si tout va bien (date OK ou non renseignée).
  Widget? _preventiveBadge(Equipment eq, AppLocalizations l10n) {
    final level = eq.preventiveMaintenanceAlertLevel;
    if (level != 'due' && level != 'soon') return null;
    final isOverdue = level == 'due';
    final color = isOverdue ? AppColors.error : AppColors.warning;
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
          Icon(isOverdue ? Icons.error_outline : Icons.schedule, size: 11, color: color),
          const SizedBox(width: 3),
          Text('PM',
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  /// Formate une date ISO (2025-12-31) → "31/12/2025"
  String _formatDateDisplay(String iso) {
    if (iso.length < 10) return iso;
    final parts = iso.substring(0, 10).split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  void _showEquipmentDetail(Equipment eq) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EquipmentDetailScreen(
          equipmentId: eq.id,
          initialEquipment: eq,
          onEdit: _authService.canManageEquipment
              ? () => _showEditEquipmentDialog(eq)
              : null,
          onReport: () => widget.onNavigate(3, equipmentId: eq.id),
        ),
      ),
    );
  }
}
