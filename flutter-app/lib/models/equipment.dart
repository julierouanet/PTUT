/// Equipment status enumeration
enum EquipmentStatus {
  disponible,
  enUsage,
  enMaintenance,
  horsService;

  /// Canonical English name (used for storage/API)
  String get displayName {
    switch (this) {
      case EquipmentStatus.disponible:
        return 'Available';
      case EquipmentStatus.enUsage:
        return 'In Use';
      case EquipmentStatus.enMaintenance:
        return 'In Maintenance';
      case EquipmentStatus.horsService:
        return 'Out of Service';
    }
  }

  /// Localized display name — use this in the UI
  String localizedName(dynamic l10n) {
    switch (this) {
      case EquipmentStatus.disponible:
        return l10n.equipStatusAvailable as String;
      case EquipmentStatus.enUsage:
        return l10n.equipStatusInUse as String;
      case EquipmentStatus.enMaintenance:
        return l10n.equipStatusInMaintenance as String;
      case EquipmentStatus.horsService:
        return l10n.equipStatusOutOfService as String;
    }
  }

  static EquipmentStatus fromString(String value) {
    switch (value) {
      case 'Disponible':
      case 'Available':
        return EquipmentStatus.disponible;
      case 'En usage':
      case 'In Use':
        return EquipmentStatus.enUsage;
      case 'En maintenance':
      case 'In Maintenance':
        return EquipmentStatus.enMaintenance;
      case 'Hors service':
      case 'Out of Service':
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
  final String? nextRevisionDate;
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
    this.nextRevisionDate,
    this.maintenanceHistory = const [],
    this.futureMaintenance = const [],
  });

  factory Equipment.fromApiJson(Map<String, dynamic> json) {
    final history = (json['maintenanceHistory'] as List? ?? [])
        .map((m) => MaintenanceRecord(
              date: m['date'] as String? ?? '',
              intervention: m['intervention'] as String? ?? '',
              technician: m['technician'] as String? ?? '',
            ))
        .toList();
    final future = (json['futureMaintenance'] as List? ?? [])
        .map((m) => MaintenanceRecord(
              date: m['date'] as String? ?? '',
              intervention: m['intervention'] as String? ?? '',
              technician: m['technician'] as String? ?? '',
            ))
        .toList();
    return Equipment(
      id:                 json['id']                   as String? ?? '',
      name:               json['name']                 as String? ?? '',
      department:         json['department']           as String? ?? '',
      category:           json['category']             as String? ?? '',
      serialNumber:       json['serial_number']        as String? ?? '',
      status:             EquipmentStatus.fromString(json['status'] as String? ?? ''),
      supplier:           json['supplier']             as String? ?? '',
      location:           json['location']             as String? ?? '',
      nextRevisionDate:   json['next_revision_date']   as String?,
      maintenanceHistory: history,
      futureMaintenance:  future,
    );
  }

  Equipment copyWith({
    String? id,
    String? name,
    String? department,
    String? category,
    String? serialNumber,
    EquipmentStatus? status,
    String? supplier,
    String? location,
    String? nextRevisionDate,
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
      nextRevisionDate: nextRevisionDate ?? this.nextRevisionDate,
      maintenanceHistory: maintenanceHistory ?? this.maintenanceHistory,
      futureMaintenance: futureMaintenance ?? this.futureMaintenance,
    );
  }
}
