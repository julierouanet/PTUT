/// Equipment status enumeration
enum EquipmentStatus {
  operational,
  maintenance,
  outOfService,
  toBeDisposal,
  disposed;

  /// Canonical English name (matches the value stored in the DB)
  String get displayName {
    switch (this) {
      case EquipmentStatus.operational:
        return 'Operational';
      case EquipmentStatus.maintenance:
        return 'Maintenance';
      case EquipmentStatus.outOfService:
        return 'Out of service';
      case EquipmentStatus.toBeDisposal:
        return 'To be disposal';
      case EquipmentStatus.disposed:
        return 'Disposed';
    }
  }

  /// Localized display name — use this in the UI
  String localizedName(dynamic l10n) {
    switch (this) {
      case EquipmentStatus.operational:
        return l10n.equipStatusOperational as String;
      case EquipmentStatus.maintenance:
        return l10n.equipStatusInMaintenance as String;
      case EquipmentStatus.outOfService:
        return l10n.equipStatusOutOfService as String;
      case EquipmentStatus.toBeDisposal:
        return l10n.equipStatusToBeDisposal as String;
      case EquipmentStatus.disposed:
        return l10n.equipStatusDisposed as String;
    }
  }

  static EquipmentStatus fromString(String value) {
    switch (value) {
      case 'Operational':
        return EquipmentStatus.operational;
      case 'Maintenance':
        return EquipmentStatus.maintenance;
      case 'Out of service':
        return EquipmentStatus.outOfService;
      case 'To be disposal':
        return EquipmentStatus.toBeDisposal;
      case 'Disposed':
        return EquipmentStatus.disposed;
      default:
        return EquipmentStatus.operational;
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
  final String location;
  final String? nextRevisionDate;

  // ── Inventaire physique 2025-2026 ──────────────────────────────────────
  final String? manufacturer;
  final String? model;
  final int? manufYear;
  final String? installDate;

  // ── Maintenance préventive (dates ISO YYYY-MM-DD) ──────────────────────
  final String? lastPreventiveMaintenance;
  final String? nextPreventiveMaintenance;

  // ── Métadonnées système (lecture seule, fournies par l'API) ────────────
  final String? createdAt;
  final String? updatedAt;

  // ── Tags d'inventaire (table equipment_tags, relation N↔1) ─────────────
  final List<String> tags;

  // ── Maintenance (déjà présent) ─────────────────────────────────────────
  final List<MaintenanceRecord> maintenanceHistory;
  final List<MaintenanceRecord> futureMaintenance;

  const Equipment({
    required this.id,
    required this.name,
    required this.department,
    required this.category,
    required this.serialNumber,
    required this.status,
    required this.location,
    this.nextRevisionDate,
    this.manufacturer,
    this.model,
    this.manufYear,
    this.installDate,
    this.lastPreventiveMaintenance,
    this.nextPreventiveMaintenance,
    this.createdAt,
    this.updatedAt,
    this.tags = const [],
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

    // L'API peut renvoyer manuf_year en INTEGER ou en STRING (cf. SQLite typage faible)
    final rawYear = json['manuf_year'];
    final manufYear = rawYear is int
        ? rawYear
        : (rawYear is String ? int.tryParse(rawYear) : null);

    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags.map((t) => t.toString()).toList()
        : <String>[];

    return Equipment(
      id:                 json['id']                   as String? ?? '',
      name:               json['name']                 as String? ?? '',
      department:         json['department']           as String? ?? '',
      category:           json['category']             as String? ?? '',
      serialNumber:       json['serial_number']        as String? ?? '',
      status:             EquipmentStatus.fromString(json['status'] as String? ?? ''),
      location:           json['location']             as String? ?? '',
      nextRevisionDate:   json['next_revision_date']   as String?,
      manufacturer:       json['manufacturer']         as String?,
      model:              json['model']                as String?,
      manufYear:          manufYear,
      installDate:        json['install_date']         as String?,
      lastPreventiveMaintenance: json['last_preventive_maintenance'] as String?,
      nextPreventiveMaintenance: json['next_preventive_maintenance'] as String?,
      createdAt:          json['created_at']           as String?,
      updatedAt:          json['updated_at']           as String?,
      tags:               tags,
      maintenanceHistory: history,
      futureMaintenance:  future,
    );
  }

  /// Indique si la maintenance préventive est échue ou à effectuer dans les 7
  /// prochains jours. Retourne null si aucune date n'est planifiée.
  /// Codomaine : null | 'due' (en retard) | 'soon' (≤ 7 jours) | 'ok'.
  String? get preventiveMaintenanceAlertLevel {
    final iso = nextPreventiveMaintenance;
    if (iso == null || iso.isEmpty || iso.length < 10) return null;
    try {
      final date = DateTime.parse(iso.substring(0, 10));
      final today = DateTime.now();
      final today0 = DateTime(today.year, today.month, today.day);
      final diff = date.difference(today0).inDays;
      if (diff < 0) return 'due';
      if (diff <= 7) return 'soon';
      return 'ok';
    } catch (_) {
      return null;
    }
  }

  Equipment copyWith({
    String? id,
    String? name,
    String? department,
    String? category,
    String? serialNumber,
    EquipmentStatus? status,
    String? location,
    String? nextRevisionDate,
    String? manufacturer,
    String? model,
    int? manufYear,
    String? installDate,
    String? lastPreventiveMaintenance,
    String? nextPreventiveMaintenance,
    String? createdAt,
    String? updatedAt,
    List<String>? tags,
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
      location: location ?? this.location,
      nextRevisionDate: nextRevisionDate ?? this.nextRevisionDate,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      manufYear: manufYear ?? this.manufYear,
      installDate: installDate ?? this.installDate,
      lastPreventiveMaintenance: lastPreventiveMaintenance ?? this.lastPreventiveMaintenance,
      nextPreventiveMaintenance: nextPreventiveMaintenance ?? this.nextPreventiveMaintenance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      maintenanceHistory: maintenanceHistory ?? this.maintenanceHistory,
      futureMaintenance: futureMaintenance ?? this.futureMaintenance,
    );
  }
}
