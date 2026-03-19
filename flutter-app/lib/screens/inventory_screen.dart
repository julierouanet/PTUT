import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../models/inventory_item.dart';

/// Inventory screen - manage consumables and stock
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _categoryFilter = 'Tous';

  List<InventoryItem> get _filteredItems {
    if (_categoryFilter == 'Tous') return DataService().inventory;
    return DataService().inventory.where((item) => item.category.displayName == _categoryFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lowStock = DataService().inventory.where((i) => i.status == StockStatus.low).length;
    final outOfStock = DataService().inventory.where((i) => i.status == StockStatus.outOfStock).length;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Inventaire',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gestion des stocks de consommables',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // Alerts for low stock
            if (outOfStock > 0 || lowStock > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Attention: Stock critique',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                          Text(
                            '$outOfStock article(s) en rupture, $lowStock article(s) en stock bas',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Filter
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text('Filtrer: ', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    _buildFilterChip('Tous', DataService().inventory.length),
                    _buildFilterChip('Consommable médical', DataService().inventory.where((i) => i.category == InventoryCategory.consommableMedical).length),
                    _buildFilterChip('Hygiène', DataService().inventory.where((i) => i.category == InventoryCategory.hygiene).length),
                    _buildFilterChip('Bureautique', DataService().inventory.where((i) => i.category == InventoryCategory.bureautique).length),
                    const Spacer(),
                    Text('${_filteredItems.length} articles', style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Inventory table - FULL WIDTH
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
                        DataColumn(label: Text('Article')),
                        DataColumn(label: Text('Catégorie')),
                        DataColumn(label: Text('Stock actuel'), numeric: true),
                        DataColumn(label: Text('Stock min'), numeric: true),
                        DataColumn(label: Text('Unité')),
                        DataColumn(label: Text('Statut')),
                        DataColumn(label: Text('Dernier réappro')),
                      ],
                      rows: _filteredItems.map((item) => DataRow(
                        cells: [
                          DataCell(Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(Text(item.category.displayName)),
                          DataCell(Text(
                            '${item.currentStock}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: item.status == StockStatus.outOfStock 
                                ? AppColors.error 
                                : item.status == StockStatus.low 
                                  ? AppColors.warning 
                                  : AppColors.textPrimary,
                            ),
                          )),
                          DataCell(Text('${item.minStock}')),
                          DataCell(Text(item.unit)),
                          DataCell(_buildStockStatusBadge(item.status)),
                          DataCell(Text(item.lastRestocked)),
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

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _categoryFilter == label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        selected: isSelected,
        label: Text('$label ($count)'),
        onSelected: (_) => setState(() => _categoryFilter = label),
        selectedColor: AppColors.primaryLight,
        checkmarkColor: AppColors.primary,
      ),
    );
  }

  Widget _buildStockStatusBadge(StockStatus status) {
    Color color;
    Color bgColor;
    switch (status) {
      case StockStatus.normal:
        color = AppColors.success;
        bgColor = AppColors.successLight;
        break;
      case StockStatus.low:
        color = AppColors.warning;
        bgColor = AppColors.warningLight;
        break;
      case StockStatus.outOfStock:
        color = AppColors.error;
        bgColor = AppColors.errorLight;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
