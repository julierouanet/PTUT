import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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
  String _categoryFilter = 'all'; // internal key, not displayed

  List<InventoryItem> get _filteredItems {
    if (_categoryFilter == 'all') return DataService().inventory;
    return DataService().inventory.where((item) => item.category.displayName == _categoryFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lowStock = DataService().inventory.where((i) => i.status == StockStatus.low).length;
    final outOfStock = DataService().inventory.where((i) => i.status == StockStatus.outOfStock).length;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            if (isMobile) ...[
              Text(l10n.inventoryTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(l10n.inventorySubtitle, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showItemDialog(null),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.inventoryNewItem),
                ),
              ),
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.inventoryTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(l10n.inventorySubtitle, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showItemDialog(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.inventoryNewItem),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
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
                          Text(
                            l10n.inventoryCriticalStock,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                          Text(
                            '${l10n.inventoryOutOfStockCount(outOfStock)}, ${l10n.inventoryLowStockCount(lowStock)}',
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
                child: isMobile
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${l10n.inventoryFilter}: ', style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            _buildFilterChip('all', l10n.commonAll, DataService().inventory.length),
                            _buildFilterChip('Consommable médical', l10n.inventoryMedicalConsumable, DataService().inventory.where((i) => i.category == InventoryCategory.consommableMedical).length),
                            _buildFilterChip('Hygiène', l10n.inventoryHygiene, DataService().inventory.where((i) => i.category == InventoryCategory.hygiene).length),
                            _buildFilterChip('Bureautique', l10n.inventoryOffice, DataService().inventory.where((i) => i.category == InventoryCategory.bureautique).length),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.inventoryItemCount(_filteredItems.length), style: const TextStyle(color: AppColors.textSecondary)),
                      ])
                    : Row(children: [
                        Text('${l10n.inventoryFilter}: ', style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 12),
                        _buildFilterChip('all', l10n.commonAll, DataService().inventory.length),
                        _buildFilterChip('Consommable médical', l10n.inventoryMedicalConsumable, DataService().inventory.where((i) => i.category == InventoryCategory.consommableMedical).length),
                        _buildFilterChip('Hygiène', l10n.inventoryHygiene, DataService().inventory.where((i) => i.category == InventoryCategory.hygiene).length),
                        _buildFilterChip('Bureautique', l10n.inventoryOffice, DataService().inventory.where((i) => i.category == InventoryCategory.bureautique).length),
                        const Spacer(),
                        Text(l10n.inventoryItemCount(_filteredItems.length), style: const TextStyle(color: AppColors.textSecondary)),
                      ]),
              ),
            ),
            const SizedBox(height: 20),

            // Inventory list — cards on mobile, table on desktop
            if (isMobile)
              Column(
                children: _filteredItems.map((item) {
                  final stockColor = item.status == StockStatus.outOfStock
                      ? AppColors.error
                      : item.status == StockStatus.low
                          ? AppColors.warning
                          : AppColors.textPrimary;
                  return Card(
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
                                child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              ),
                              _buildStockStatusBadge(item.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l10n.commonCategory, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    Text(item.category.displayName, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l10n.inventoryCurrentStock, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    Text('${item.currentStock} ${item.unit}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: stockColor)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l10n.inventoryMinStock, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    Text('${item.minStock} ${item.unit}', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item.lastRestocked, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    color: AppColors.warning,
                                    tooltip: l10n.commonEdit,
                                    onPressed: () => _showItemDialog(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    color: AppColors.error,
                                    tooltip: l10n.commonDelete,
                                    onPressed: () => _confirmDeleteItem(item),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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
                          DataColumn(label: Text(l10n.inventoryItem)),
                          DataColumn(label: Text(l10n.commonCategory)),
                          DataColumn(label: Text(l10n.inventoryCurrentStock), numeric: true),
                          DataColumn(label: Text(l10n.inventoryMinStock), numeric: true),
                          DataColumn(label: Text(l10n.inventoryUnit)),
                          DataColumn(label: Text(l10n.commonStatus)),
                          DataColumn(label: Text(l10n.inventoryLastRestocked)),
                          DataColumn(label: Text(l10n.commonActions)),
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
                                  tooltip: l10n.commonEdit,
                                  onPressed: () => _showItemDialog(item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  color: AppColors.error,
                                  tooltip: l10n.commonDelete,
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
    final l10n = AppLocalizations.of(context)!;
    final isEdit = existing != null;
    final nameCtrl     = TextEditingController(text: existing?.name ?? '');
    final stockCtrl    = TextEditingController(text: existing != null ? '${existing.currentStock}' : '');
    final minStockCtrl = TextEditingController(text: existing != null ? '${existing.minStock}' : '');
    final unitCtrl     = TextEditingController(text: existing?.unit ?? '');
    InventoryCategory selectedCategory = existing?.category ?? InventoryCategory.consommableMedical;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? l10n.inventoryEditItem : l10n.inventoryNewItemTitle),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: l10n.inventoryNameLabel),
                    validator: (v) => (v == null || v.isEmpty) ? l10n.commonFillRequiredFields : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<InventoryCategory>(
                    value: selectedCategory,
                    decoration: InputDecoration(labelText: l10n.inventoryCategoryLabel),
                    items: InventoryCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.displayName))).toList(),
                    onChanged: (v) => setDialogState(() => selectedCategory = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.inventoryCurrentStockLabel),
                    validator: (v) => (v == null || v.isEmpty) ? l10n.commonFillRequiredFields : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: minStockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.inventoryMinStockLabel),
                    validator: (v) => (v == null || v.isEmpty) ? l10n.commonFillRequiredFields : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: unitCtrl,
                    decoration: InputDecoration(labelText: l10n.inventoryUnitLabel),
                    validator: (v) => (v == null || v.isEmpty) ? l10n.commonFillRequiredFields : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
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
                  if (mounted) setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isEdit ? l10n.inventoryItemModified : l10n.inventoryItemAdded),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } catch (e) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(AppLocalizations.of(context)!.commonApiError),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                }
              },
              child: Text(isEdit ? l10n.commonEdit : l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteItem(InventoryItem item) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inventoryDeleteItem),
        content: Text(l10n.inventoryDeleteConfirm(item.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await DbApiService.instance.deleteInventoryItem(item.id);
                await DataService().reloadInventory();
                if (mounted) setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.inventoryItemDeleted),
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

  Widget _buildFilterChip(String filterKey, String label, int count) {
    final isSelected = _categoryFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        selected: isSelected,
        label: Text('$label ($count)'),
        onSelected: (_) => setState(() => _categoryFilter = filterKey),
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
