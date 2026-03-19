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

  factory InventoryItem.fromApiJson(Map<String, dynamic> json) {
    return InventoryItem(
      id:           json['id']             as String? ?? '',
      name:         json['name']           as String? ?? '',
      category:     _categoryFromString(json['category'] as String? ?? ''),
      currentStock: json['current_stock']  as int? ?? 0,
      minStock:     json['min_stock']      as int? ?? 0,
      unit:         json['unit']           as String? ?? '',
      status:       _stockStatusFromString(json['status'] as String? ?? ''),
      lastRestocked: json['last_restocked'] as String? ?? '',
    );
  }

  static InventoryCategory _categoryFromString(String v) {
    switch (v) {
      case 'Consommable médical': return InventoryCategory.consommableMedical;
      case 'Hygiène':             return InventoryCategory.hygiene;
      case 'Bureautique':         return InventoryCategory.bureautique;
      default:                    return InventoryCategory.consommableMedical;
    }
  }

  static StockStatus _stockStatusFromString(String v) {
    switch (v) {
      case 'Normal':  return StockStatus.normal;
      case 'Bas':     return StockStatus.low;
      case 'Rupture': return StockStatus.outOfStock;
      default:        return StockStatus.normal;
    }
  }

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
