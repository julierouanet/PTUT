import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../models/equipment.dart';
import '../widgets/status_badge.dart';
import '../widgets/equipment_detail_dialog.dart';
import '../widgets/equipment_history_dialog.dart';
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
  List<String> _statuses(String allLabel) => [allLabel, 'Disponible', 'En usage', 'En maintenance', 'Hors service'];
  List<String> _categories(String allLabel) => [allLabel, ...DataService().equipment.map((e) => e.category).toSet()];

  List<Equipment> get _filteredEquipment {
    final l10n = AppLocalizations.of(context)!;
    return DataService().equipment.where((eq) {
      final matchesSearch = eq.name.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          eq.serialNumber.toLowerCase().contains(_searchTerm.toLowerCase());
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

            // Equipment list — cards on mobile, table on desktop
            if (isMobile)
              Column(
                children: _filteredEquipment.map((eq) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(eq.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            ),
                            StatusBadge(status: eq.status.displayName, isCompact: true),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildCardRow(l10n.commonDepartment, eq.department),
                        _buildCardRow(l10n.commonCategory, eq.category),
                        _buildCardRow(l10n.equipmentSerialNumber, eq.serialNumber),
                        if (eq.nextRevisionDate != null && eq.nextRevisionDate!.isNotEmpty)
                          _buildCardRow(l10n.equipmentRevisionColumn, _formatDateDisplay(eq.nextRevisionDate!)),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, size: 20),
                              color: AppColors.primary,
                              onPressed: () => _showEquipmentDetail(eq),
                              tooltip: l10n.commonDetails,
                            ),
                            IconButton(
                              icon: const Icon(Icons.history, size: 20),
                              color: AppColors.warning,
                              onPressed: () => EquipmentHistoryDialog.show(context, eq),
                              tooltip: 'Historique',
                            ),
                            if (isAdmin)
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                color: AppColors.warning,
                                onPressed: () => _showEditEquipmentDialog(eq),
                                tooltip: l10n.commonEdit,
                              ),
                            IconButton(
                              icon: const Icon(Icons.report_problem_outlined, size: 20),
                              color: AppColors.error,
                              onPressed: () => widget.onNavigate(3, equipmentId: eq.id),
                              tooltip: l10n.commonReport,
                            ),
                            if (isAdmin)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: AppColors.error,
                                onPressed: () => _confirmDelete(eq),
                                tooltip: l10n.commonDelete,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )).toList(),
              )
            else
              SizedBox(
                width: double.infinity,
                child: Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 340),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.background),
                        columns: [
                          DataColumn(label: Text(l10n.equipmentName)),
                          DataColumn(label: Text(l10n.commonDepartment)),
                          DataColumn(label: Text(l10n.commonCategory)),
                          DataColumn(label: Text(l10n.equipmentSerialNumber)),
                          DataColumn(label: Text(l10n.commonStatus)),
                          DataColumn(label: Text(l10n.equipmentRevisionColumn)),
                          DataColumn(label: Text(l10n.commonActions)),
                        ],
                        rows: _filteredEquipment.map((eq) => DataRow(
                          cells: [
                            DataCell(Text(eq.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Text(eq.department)),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(eq.category, style: const TextStyle(fontSize: 13)),
                            )),
                            DataCell(Text(eq.serialNumber)),
                            DataCell(StatusBadge(status: eq.status.displayName, isCompact: true)),
                            DataCell(_buildRevisionCell(eq.nextRevisionDate)),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility, size: 18),
                                  color: AppColors.primary,
                                  onPressed: () => _showEquipmentDetail(eq),
                                  tooltip: l10n.commonDetails,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.history, size: 18),
                                  color: AppColors.warning,
                                  onPressed: () => EquipmentHistoryDialog.show(context, eq),
                                  tooltip: 'Historique',
                                ),
                                if (isAdmin)
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    color: AppColors.warning,
                                    onPressed: () => _showEditEquipmentDialog(eq),
                                    tooltip: l10n.commonEdit,
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.report_problem_outlined, size: 18),
                                  color: AppColors.error,
                                  onPressed: () => widget.onNavigate(3, equipmentId: eq.id),
                                  tooltip: l10n.commonReport,
                                ),
                                if (isAdmin)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    color: AppColors.error,
                                    onPressed: () => _confirmDelete(eq),
                                    tooltip: l10n.commonDelete,
                                  ),
                              ],
                            )),
                          ],
                        )).toList(),
                      ),
                    ),
                  ),
                ),
              ),
          ],
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

  Widget _buildCardRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
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
    final supplierController = TextEditingController(text: existingEquipment?.supplier ?? '');
    final locationController = TextEditingController(text: existingEquipment?.location ?? '');

    String selectedDepartment = existingEquipment?.department ?? _configService.departmentNames.first;
    String selectedCategory = existingEquipment?.category ?? _configService.categoryNames.first;
    EquipmentStatus selectedStatus = existingEquipment?.status ?? EquipmentStatus.disponible;
    String? selectedRevisionDate = existingEquipment?.nextRevisionDate;
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

                          // Supplier
                          TextField(
                            controller: supplierController,
                            decoration: InputDecoration(
                              labelText: l10n.equipmentSupplier,
                              hintText: l10n.equipmentSupplierHint,
                              prefixIcon: const Icon(Icons.local_shipping),
                            ),
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
                              'supplier':           supplierController.text.isNotEmpty ? supplierController.text : null,
                              'location':           locationController.text.isNotEmpty ? locationController.text : null,
                              'status':             selectedStatus.displayName,
                              'next_revision_date': selectedRevisionDate,
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

  void _confirmDelete(Equipment eq) {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.equipmentDeleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.equipmentDeleteConfirm(eq.name)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Raison de la suppression (optionnel)',
                hintText: 'Ex : Hors service, remplacé…',
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(ctx);
              try {
                await DbApiService.instance.deleteEquipment(eq.id, reason: reason.isEmpty ? null : reason);
                await DataService().reloadEquipment();
                if (mounted) setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.equipmentDeleted),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(AppLocalizations.of(context)!.commonApiError),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  Widget _getStatusIcon(EquipmentStatus status) {
    IconData icon;
    Color color;
    switch (status) {
      case EquipmentStatus.disponible:
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case EquipmentStatus.enUsage:
        icon = Icons.play_circle;
        color = AppColors.primary;
        break;
      case EquipmentStatus.enMaintenance:
        icon = Icons.build_circle;
        color = AppColors.warning;
        break;
      case EquipmentStatus.horsService:
        icon = Icons.cancel;
        color = AppColors.error;
        break;
    }
    return Icon(icon, color: color, size: 18);
  }

  /// Cellule date de révision — colorée selon la proximité
  Widget _buildRevisionCell(String? iso) {
    if (iso == null || iso.isEmpty) {
      return const Text('—', style: TextStyle(color: AppColors.textSecondary));
    }
    Color color = AppColors.textSecondary;
    try {
      final date = DateTime.parse(iso.substring(0, 10));
      final diff = date.difference(DateTime.now()).inDays;
      if (diff < 0)    color = AppColors.error;
      else if (diff <= 30) color = AppColors.warning;
      else                 color = AppColors.success;
    } catch (_) {}
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.event, size: 13, color: color),
      const SizedBox(width: 4),
      Text(_formatDateDisplay(iso), style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    ]);
  }

  /// Formate une date ISO (2025-12-31) → "31/12/2025"
  String _formatDateDisplay(String iso) {
    if (iso.length < 10) return iso;
    final parts = iso.substring(0, 10).split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  void _showEquipmentDetail(Equipment eq) {
    EquipmentDetailDialog.show(
      context,
      eq,
      onEdit: _authService.canManageEquipment ? () => _showEditEquipmentDialog(eq) : null,
      onReport: () => widget.onNavigate(3, equipmentId: eq.id),
    );
  }
}
