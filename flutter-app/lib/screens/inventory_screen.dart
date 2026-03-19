import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventaire',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gestion des stocks de consommables',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showItemDialog(null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvel article'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
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
                        DataColumn(label: Text('Actions')),
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
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                color: AppColors.warning,
                                tooltip: 'Modifier',
                                onPressed: () => _showItemDialog(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                color: AppColors.error,
                                tooltip: 'Supprimer',
                                onPressed: () => _confirmDeleteItem(item),
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

  void _showItemDialog(InventoryItem? existing) {
    final isEdit = existing != null;
    final nameCtrl     = TextEditingController(text: existing?.name ?? '');
    final stockCtrl    = TextEditingController(text: existing != null ? '${existing.currentStock}' : '');
    final minStockCtrl = TextEditingController(text: existing != null ? '${existing.minStock}' : '');
    final unitCtrl     = TextEditingController(text: existing?.unit ?? '');
    InventoryCategory selectedCategory = existing?.category ?? InventoryCategory.consommableMedical;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Modifier l\'article' : 'Nouvel article'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl,     decoration: const InputDecoration(labelText: 'Nom *')),
                const SizedBox(height: 12),
                DropdownButtonFormField<InventoryCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Catégorie *'),
                  items: InventoryCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.displayName))).toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v!),
                ),
                const SizedBox(height: 12),
                TextField(controller: stockCtrl,    keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock actuel *')),
                const SizedBox(height: 12),
                TextField(controller: minStockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock minimum *')),
                const SizedBox(height: 12),
                TextField(controller: unitCtrl,     decoration: const InputDecoration(labelText: 'Unité (ex: boîtes) *')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || stockCtrl.text.isEmpty || minStockCtrl.text.isEmpty || unitCtrl.text.isEmpty) return;
                final data = {
                  'id':            isEdit ? existing.id : 'inv-${DateTime.now().millisecondsSinceEpoch}',
                  'name':          nameCtrl.text,
                  'category':      selectedCategory.displayName,
                  'current_stock': int.tryParse(stockCtrl.text) ?? 0,
                  'min_stock':     int.tryParse(minStockCtrl.text) ?? 0,
                  'unit':          unitCtrl.text,
                };
                try {
                  if (isEdit) {
                    await DbApiService.instance.updateInventoryItem(existing.id, data);
                  } else {
                    await DbApiService.instance.createInventoryItem(data);
                  }
                  await DataService().reloadInventory();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isEdit ? 'Article modifié' : 'Article ajouté'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } catch (e) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                }
              },
              child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteItem(InventoryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'article'),
        content: Text('Supprimer "${item.name}" de l\'inventaire ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await DbApiService.instance.deleteInventoryItem(item.id);
                await DataService().reloadInventory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Article supprimé'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Erreur: $e'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
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
