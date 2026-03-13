/// Equipment status enumeration
enum EquipmentStatus {
  disponible,
  enUsage,
  enMaintenance,
  horsService;

  String get displayName {
    switch (this) {
      case EquipmentStatus.disponible:
        return 'Disponible';
      case EquipmentStatus.enUsage:
        return 'En usage';
      case EquipmentStatus.enMaintenance:
        return 'En maintenance';
      case EquipmentStatus.horsService:
        return 'Hors service';
    }
  }

  static EquipmentStatus fromString(String value) {
    switch (value) {
      case 'Disponible':
        return EquipmentStatus.disponible;
      case 'En usage':
        return EquipmentStatus.enUsage;
      case 'En maintenance':
        return EquipmentStatus.enMaintenance;
      case 'Hors service':
        return EquipmentStatus.horsService;
      default:
        return EquipmentStatus.disponible;
    }
  }
}

/// Maintenance record model
class MaintenanceRecord {
  final String date;
  final String intervention;
  final String technician;

  const MaintenanceRecord({
    required this.date,
    required this.intervention,
    required this.technician,
  });
}

/// Equipment model for hospital equipment management
class Equipment {
  final String id;
  final String name;
  final String department;
  final String category;
  final String serialNumber;
  final EquipmentStatus status;
  final String supplier;
  final String location;
  final List<MaintenanceRecord> maintenanceHistory;
  final List<MaintenanceRecord> futureMaintenance;

  const Equipment({
    required this.id,
    required this.name,
    required this.department,
    required this.category,
    required this.serialNumber,
    required this.status,
    required this.supplier,
    required this.location,
    this.maintenanceHistory = const [],
    this.futureMaintenance = const [],
  });

  Equipment copyWith({
    String? id,
    String? name,
    String? department,
    String? category,
    String? serialNumber,
    EquipmentStatus? status,
    String? supplier,
    String? location,
    List<MaintenanceRecord>? maintenanceHistory,
    List<MaintenanceRecord>? futureMaintenance,
  }) {
    return Equipment(
      id: id ?? this.id,
      name: name ?? this.name,
      department: department ?? this.department,
      category: category ?? this.category,
      serialNumber: serialNumber ?? this.serialNumber,
      status: status ?? this.status,
      supplier: supplier ?? this.supplier,
      location: location ?? this.location,
      maintenanceHistory: maintenanceHistory ?? this.maintenanceHistory,
      futureMaintenance: futureMaintenance ?? this.futureMaintenance,
    );
  }
}
