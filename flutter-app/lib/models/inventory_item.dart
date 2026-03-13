/// Inventory item category enumeration
enum InventoryCategory {
  consommableMedical,
  hygiene,
  bureautique;

  String get displayName {
    switch (this) {
      case InventoryCategory.consommableMedical:
        return 'Consommable médical';
      case InventoryCategory.hygiene:
        return 'Hygiène';
      case InventoryCategory.bureautique:
        return 'Bureautique';
    }
  }
}

/// Inventory stock status enumeration
enum StockStatus {
  normal,
  low,
  outOfStock;

  String get displayName {
    switch (this) {
      case StockStatus.normal:
        return 'Normal';
      case StockStatus.low:
        return 'Bas';
      case StockStatus.outOfStock:
        return 'Rupture';
    }
  }
}

/// Inventory item model for consumables management
class InventoryItem {
  final String id;
  final String name;
  final InventoryCategory category;
  final int currentStock;
  final int minStock;
  final String unit;
  final StockStatus status;
  final String lastRestocked;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.currentStock,
    required this.minStock,
    required this.unit,
    required this.status,
    required this.lastRestocked,
  });

  InventoryItem copyWith({
    String? id,
    String? name,
    InventoryCategory? category,
    int? currentStock,
    int? minStock,
    String? unit,
    StockStatus? status,
    String? lastRestocked,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      currentStock: currentStock ?? this.currentStock,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      lastRestocked: lastRestocked ?? this.lastRestocked,
    );
  }
}
