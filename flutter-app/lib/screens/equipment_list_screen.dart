import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../models/equipment.dart';
import '../widgets/status_badge.dart';
import '../services/config_service.dart';

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

  List<String> get _departments => ['Tous', ...mockEquipment.map((e) => e.department).toSet()];
  List<String> get _statuses => ['Tous', 'Disponible', 'En usage', 'En maintenance', 'Hors service'];
  List<String> get _categories => ['Tous', ...mockEquipment.map((e) => e.category).toSet()];

  List<Equipment> get _filteredEquipment {
    return mockEquipment.where((eq) {
      final matchesSearch = eq.name.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          eq.serialNumber.toLowerCase().contains(_searchTerm.toLowerCase());
      final matchesDepartment = _departmentFilter == 'Tous' || eq.department == _departmentFilter;
      final matchesStatus = _statusFilter == 'Tous' || eq.status.displayName == _statusFilter;
      final matchesCategory = _categoryFilter == 'Tous' || eq.category == _categoryFilter;
      return matchesSearch && matchesDepartment && matchesStatus && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Add button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liste des équipements',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gestion et suivi de tous les équipements',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showAddEquipmentDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvel équipement'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search and Filters - FULL WIDTH
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildSearchField()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDropdown('Département', _departmentFilter, _departments, (v) => setState(() => _departmentFilter = v!))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDropdown('Statut', _statusFilter, _statuses, (v) => setState(() => _statusFilter = v!))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDropdown('Catégorie', _categoryFilter, _categories, (v) => setState(() => _categoryFilter = v!))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_filteredEquipment.length} équipement(s) trouvé(s)',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Equipment Table - FULL WIDTH
            SizedBox(
              width: double.infinity,
              child: Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 340),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppColors.background),
                      columns: const [
                        DataColumn(label: Text("Nom de l'équipement")),
                        DataColumn(label: Text('Département')),
                        DataColumn(label: Text('Catégorie')),
                        DataColumn(label: Text('Numéro de série')),
                        DataColumn(label: Text('Statut')),
                        DataColumn(label: Text('Actions')),
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
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 18),
                                color: AppColors.primary,
                                onPressed: () => _showEquipmentDetail(eq),
                                tooltip: 'Détails',
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                color: AppColors.warning,
                                onPressed: () => _showEditEquipmentDialog(eq),
                                tooltip: 'Modifier',
                              ),
                              IconButton(
                                icon: const Icon(Icons.report_problem_outlined, size: 18),
                                color: AppColors.error,
                                onPressed: () => widget.onNavigate(3, equipmentId: eq.id),
                                tooltip: 'Signaler',
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
    return TextField(
      onChanged: (value) => setState(() => _searchTerm = value),
      decoration: const InputDecoration(
        hintText: 'Rechercher...',
        prefixIcon: Icon(Icons.search),
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
    
    final nameController = TextEditingController(text: existingEquipment?.name ?? '');
    final serialController = TextEditingController(text: existingEquipment?.serialNumber ?? '');
    final supplierController = TextEditingController(text: existingEquipment?.supplier ?? '');
    final locationController = TextEditingController(text: existingEquipment?.location ?? '');
    
    String selectedDepartment = existingEquipment?.department ?? _configService.departmentNames.first;
    String selectedCategory = existingEquipment?.category ?? _configService.categoryNames.first;
    EquipmentStatus selectedStatus = existingEquipment?.status ?? EquipmentStatus.disponible;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 700),
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
                            isEdit ? 'Modifier l\'équipement' : 'Nouvel équipement',
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom de l\'équipement *',
                            hintText: 'Ex: Scanner IRM Siemens',
                            prefixIcon: Icon(Icons.inventory_2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Serial number
                        TextField(
                          controller: serialController,
                          decoration: const InputDecoration(
                            labelText: 'Numéro de série *',
                            hintText: 'Ex: SN-2023-001',
                            prefixIcon: Icon(Icons.qr_code),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Department and Category row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedDepartment,
                                decoration: const InputDecoration(
                                  labelText: 'Département *',
                                  prefixIcon: Icon(Icons.business),
                                ),
                                items: _configService.departmentNames.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                onChanged: (v) => setDialogState(() => selectedDepartment = v!),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Catégorie *',
                                  prefixIcon: Icon(Icons.category),
                                ),
                                items: _configService.categoryNames.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                onChanged: (v) => setDialogState(() => selectedCategory = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Supplier
                        TextField(
                          controller: supplierController,
                          decoration: const InputDecoration(
                            labelText: 'Fournisseur',
                            hintText: 'Ex: Siemens Healthineers',
                            prefixIcon: Icon(Icons.local_shipping),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Location
                        TextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: 'Localisation',
                            hintText: 'Ex: Bâtiment A, Salle 101',
                            prefixIcon: Icon(Icons.location_on),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Status
                        DropdownButtonFormField<EquipmentStatus>(
                          value: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Statut',
                            prefixIcon: Icon(Icons.info_outline),
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
                      ],
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
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (nameController.text.isEmpty || serialController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Veuillez remplir les champs obligatoires'),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            
                            // Create new equipment
                            final newEquipment = Equipment(
                              id: isEdit ? existingEquipment.id : 'eq-${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text,
                              serialNumber: serialController.text,
                              department: selectedDepartment,
                              category: selectedCategory,
                              supplier: supplierController.text.isNotEmpty ? supplierController.text : 'Non spécifié',
                              location: locationController.text.isNotEmpty ? locationController.text : 'Non spécifié',
                              status: selectedStatus,
                            );
                            
                            // Add or update in mock data
                            setState(() {
                              if (isEdit) {
                                final index = mockEquipment.indexWhere((e) => e.id == existingEquipment.id);
                                if (index != -1) {
                                  mockEquipment[index] = newEquipment;
                                }
                              } else {
                                mockEquipment.add(newEquipment);
                              }
                            });
                            
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Text(isEdit ? 'Équipement modifié avec succès' : 'Équipement ajouté avec succès'),
                                  ],
                                ),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: Icon(isEdit ? Icons.save : Icons.add),
                          label: Text(isEdit ? 'Enregistrer les modifications' : 'Ajouter l\'équipement'),
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

  void _showEquipmentDetail(Equipment eq) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(eq.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditEquipmentDialog(eq);
                          },
                          icon: const Icon(Icons.edit, color: AppColors.primary),
                          tooltip: 'Modifier',
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                StatusBadge(status: eq.status.displayName),
                const SizedBox(height: 24),
                _buildDetailRow('Département', eq.department),
                _buildDetailRow('Catégorie', eq.category),
                _buildDetailRow('Numéro de série', eq.serialNumber),
                _buildDetailRow('Fournisseur', eq.supplier),
                _buildDetailRow('Localisation', eq.location),
                const SizedBox(height: 24),
                if (eq.maintenanceHistory.isNotEmpty) ...[
                  const Text('Historique de maintenance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...eq.maintenanceHistory.map((m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.build, color: AppColors.warning),
                    title: Text(m.intervention),
                    subtitle: Text('${m.date} - ${m.technician}'),
                  )),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onNavigate(3, equipmentId: eq.id);
                        },
                        icon: const Icon(Icons.report_problem_outlined),
                        label: const Text('Signaler un problème'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
