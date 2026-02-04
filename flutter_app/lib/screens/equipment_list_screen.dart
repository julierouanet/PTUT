import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../models/equipment.dart';
import '../widgets/status_badge.dart';

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
            // Header
            const Text(
              'Liste des équipements',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gestion et suivi de tous les équipements',
              style: TextStyle(color: AppColors.textSecondary),
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
                              ElevatedButton.icon(
                                onPressed: () => _showEquipmentDetail(eq),
                                icon: const Icon(Icons.visibility, size: 16),
                                label: const Text('Détails'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => widget.onNavigate(3, equipmentId: eq.id),
                                icon: const Icon(Icons.report_problem_outlined, size: 16),
                                label: const Text('Signaler'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.warning,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
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
                    Text(eq.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
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
