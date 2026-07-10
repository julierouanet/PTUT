import 'dart:convert';

/// Statut d'un équipement médical
enum EquipmentStatus {
  operational,
  maintenance,
  outOfService,
  toBeDisposal,
  disposed;

  /// Valeur canonique anglaise (correspond à la valeur stockée en DB)
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

  /// Nom localisé — à utiliser dans l'UI
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

/// Criticité selon la matrice ABC (norme GMAO)
enum EquipmentCriticality {
  a, // Critique — panne = arrêt immédiat de la production de soins
  b, // Important — impact significatif mais palliatif possible
  c; // Courant — peu d'impact sur la continuité des soins

  String get displayName {
    switch (this) {
      case EquipmentCriticality.a:
        return 'A';
      case EquipmentCriticality.b:
        return 'B';
      case EquipmentCriticality.c:
        return 'C';
    }
  }

  String localizedLabel(dynamic l10n) {
    switch (this) {
      case EquipmentCriticality.a:
        return l10n.criticalityA as String;
      case EquipmentCriticality.b:
        return l10n.criticalityB as String;
      case EquipmentCriticality.c:
        return l10n.criticalityC as String;
    }
  }

  static EquipmentCriticality? fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'A':
        return EquipmentCriticality.a;
      case 'B':
        return EquipmentCriticality.b;
      case 'C':
        return EquipmentCriticality.c;
      default:
        return null;
    }
  }
}

/// Enregistrement de maintenance
class MaintenanceRecord {
  final String date;
  final String intervention;
  final String technician;
  final String? technicianId;
  final String? maintenanceType;
  final int? durationMinutes;
  final int? recordId;
  final List<Map<String, dynamic>> checklistSnapshot;

  const MaintenanceRecord({
    required this.date,
    required this.intervention,
    required this.technician,
    this.technicianId,
    this.maintenanceType,
    this.durationMinutes,
    this.recordId,
    this.checklistSnapshot = const [],
  });
}

/// Modèle principal d'un équipement médical
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

  // ── Rattachement catalogue (Fabricant → Modèle) ────────────────────────
  /// ID du modèle catalogue (table equipment_models) — null si non rattaché
  final int? modelId;
  /// ID du fabricant catalogue (résolu via le modèle) — null si non rattaché
  final int? brandId;
  /// Nom du fabricant catalogue (dénormalisé depuis le JOIN API)
  final String? brandName;

  // ── Maintenance préventive (dates ISO YYYY-MM-DD) ──────────────────────
  final String? lastPreventiveMaintenance;
  final String? nextPreventiveMaintenance;

  // ── GMAO Phase 2 : Hiérarchie & Matrice ABC ───────────────────────────
  /// ID de la sous-catégorie (table equipment_subcategories)
  final int? subcategoryId;
  /// Nom de la sous-catégorie (champ dénormalisé depuis le JOIN API)
  final String? subcategoryName;
  /// Description métier de la sous-catégorie (lecture seule, dénormalisée depuis le JOIN API)
  final String? subcategoryDescription;
  /// ID de la macro-catégorie (Biomedical=1, Infrastructure=2, IT=3)
  final int? macroCategoryId;
  /// Nom de la macro-catégorie ('Biomedical' | 'Infrastructure' | 'IT')
  final String? macroCategory;
  /// Date de fin de garantie (ISO YYYY-MM-DD)
  final String? warrantyEndDate;
  /// Criticité selon la matrice ABC
  final EquipmentCriticality? criticality;

  // ── Cycle de vie : réforme / décommissionnement ───────────────────────
  /// Date/heure ISO de la réforme (NULL si actif)
  final String? decommissionedAt;
  /// Motif de réforme (whitelist serveur : irreparable, obsolete, replaced, lost, donated_out)
  final String? decommissionReason;
  /// Méthode d'élimination (whitelist serveur : destroyed, sold, donated, returned, cannibalized)
  final String? disposalMethod;
  /// Nom de l'agent ayant réformé l'équipement
  final String? decommissionedByName;
  /// Notes libres saisies à la réforme
  final String? decommissionNotes;
  /// ID de l'équipement remplaçant (lien « remplacé par → »)
  final String? replacedById;
  /// Nom du remplaçant (dénormalisé depuis le JOIN API)
  final String? replacedByName;
  /// ID de l'équipement réformé que CET équipement remplace (lien inverse « remplace → »)
  final String? replacesId;
  /// Nom de l'équipement réformé que CET équipement remplace
  final String? replacesName;

  // ── Localisation physique étendue ─────────────────────────────────────
  /// Bâtiment / aile de l'hôpital (texte libre, ex : « Bloc A »)
  final String? building;

  // ── Métadonnées système (lecture seule) ───────────────────────────────
  final String? createdAt;
  final String? updatedAt;
  /// ID Keycloak de l'utilisateur ayant créé l'équipement (null si inconnu — seed/import XLSX)
  final String? createdById;
  /// Nom de l'utilisateur ayant créé l'équipement (null si inconnu)
  final String? createdByName;

  // ── Tags d'inventaire (table equipment_tags) ──────────────────────────
  final List<String> tags;

  // ── Maintenance ───────────────────────────────────────────────────────
  final List<MaintenanceRecord> maintenanceHistory;
  final List<MaintenanceRecord> futureMaintenance;

  // ── Protocoles PM (depuis pm_protocols via sous-catégorie) ────────────
  final List<Map<String, dynamic>> pmProtocols;

  // ── Plan PM actif (depuis preventive_maintenance_plans) ───────────────
  final int? pmFrequencyMonths;

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
    this.modelId,
    this.brandId,
    this.brandName,
    this.lastPreventiveMaintenance,
    this.nextPreventiveMaintenance,
    this.subcategoryId,
    this.subcategoryName,
    this.subcategoryDescription,
    this.macroCategoryId,
    this.macroCategory,
    this.warrantyEndDate,
    this.criticality,
    this.decommissionedAt,
    this.decommissionReason,
    this.disposalMethod,
    this.decommissionedByName,
    this.decommissionNotes,
    this.replacedById,
    this.replacedByName,
    this.replacesId,
    this.replacesName,
    this.building,
    this.createdAt,
    this.updatedAt,
    this.createdById,
    this.createdByName,
    this.tags = const [],
    this.maintenanceHistory = const [],
    this.futureMaintenance = const [],
    this.pmProtocols = const [],
    this.pmFrequencyMonths,
  });

  factory Equipment.fromApiJson(Map<String, dynamic> json) {
    MaintenanceRecord _parseRecord(dynamic m) {
      final map = m as Map<String, dynamic>;
      final rawId = map['id'];
      return MaintenanceRecord(
        date: map['date'] as String? ?? '',
        intervention: map['intervention'] as String? ?? '',
        technician: map['technician'] as String? ?? '',
        technicianId: map['technician_id'] as String?,
        maintenanceType: map['maintenance_type'] as String?,
        durationMinutes: map['duration_minutes'] as int?,
        recordId: rawId is int ? rawId : (rawId is String ? int.tryParse(rawId) : null),
        checklistSnapshot: (() {
          final raw = map['checklist_snapshot'];
          if (raw is String && raw.isNotEmpty) {
            try {
              final decoded = jsonDecode(raw);
              if (decoded is List) {
                return decoded.whereType<Map<String, dynamic>>().toList();
              }
            } catch (_) {}
          }
          return <Map<String, dynamic>>[];
        })(),
      );
    }

    final history = (json['maintenanceHistory'] as List? ?? [])
        .map(_parseRecord)
        .toList();
    final future = (json['futureMaintenance'] as List? ?? [])
        .map(_parseRecord)
        .toList();

    // manuf_year peut être INTEGER ou STRING (typage faible SQLite)
    final rawYear = json['manuf_year'];
    final manufYear = rawYear is int
        ? rawYear
        : (rawYear is String ? int.tryParse(rawYear) : null);

    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags.map((t) => t.toString()).toList()
        : <String>[];

    // pmProtocols : liste de protocoles avec checklist désérialisée
    final rawProtocols = json['pmProtocols'] as List? ?? [];
    final pmProtocols = rawProtocols
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();

    // pmFrequencyMonths depuis pmPlan retourné par GET /api/equipment/:id
    final pmPlanMap = json['pmPlan'] as Map<String, dynamic>?;
    final rawPmFreq = pmPlanMap?['frequency_months'];
    final pmFrequencyMonths = rawPmFreq is int
        ? rawPmFreq
        : (rawPmFreq is String ? int.tryParse(rawPmFreq) : null);

    // subcategory_id et macro_category_id peuvent être int ou null
    final rawSubId = json['subcategory_id'];
    final subcategoryId = rawSubId is int ? rawSubId : (rawSubId is String ? int.tryParse(rawSubId) : null);

    // model_id / brand_id : int ou String (typage faible SQLite), null si non rattaché
    final rawModelId = json['model_id'];
    final modelId = rawModelId is int ? rawModelId : (rawModelId is String ? int.tryParse(rawModelId) : null);
    final rawBrandId = json['brand_id'];
    final brandId = rawBrandId is int ? rawBrandId : (rawBrandId is String ? int.tryParse(rawBrandId) : null);

    final rawMacroId = json['macro_category_id'] ?? json['macro_category_id_resolved'];
    final macroCategoryId = rawMacroId is int ? rawMacroId : (rawMacroId is String ? int.tryParse(rawMacroId) : null);

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
      modelId:            modelId,
      brandId:            brandId,
      brandName:          json['brand_name']           as String?,
      lastPreventiveMaintenance: json['last_preventive_maintenance'] as String?,
      nextPreventiveMaintenance: json['next_preventive_maintenance'] as String?,
      subcategoryId:      subcategoryId,
      subcategoryName:    json['subcategory_name']     as String?,
      subcategoryDescription: json['subcategory_description'] as String?,
      macroCategoryId:    macroCategoryId,
      macroCategory:      json['macro_category']       as String?,
      warrantyEndDate:    json['warranty_end_date']    as String?,
      criticality:        EquipmentCriticality.fromString(json['criticality'] as String?),
      decommissionedAt:    json['decommissioned_at']      as String?,
      decommissionReason:  json['decommission_reason']    as String?,
      disposalMethod:      json['disposal_method']        as String?,
      decommissionedByName:json['decommissioned_by_name'] as String?,
      decommissionNotes:   json['decommission_notes']     as String?,
      replacedById:        json['replaced_by_id']         as String?,
      replacedByName:      json['replaced_by_name']       as String?,
      replacesId:          json['replaces_id']            as String?,
      replacesName:        json['replaces_name']          as String?,
      building:            json['building']               as String?,
      createdAt:          json['created_at']           as String?,
      updatedAt:          json['updated_at']           as String?,
      createdById:        json['created_by_id']        as String?,
      createdByName:      json['created_by_name']      as String?,
      tags:               tags,
      maintenanceHistory: history,
      futureMaintenance:  future,
      pmProtocols:        pmProtocols,
      pmFrequencyMonths:  pmFrequencyMonths,
    );
  }

  /// Indique si la garantie est expirée ou expirera dans les 30 prochains jours.
  /// Retourne null si aucune date de garantie n'est définie.
  String? get warrantyAlertLevel {
    final iso = warrantyEndDate;
    if (iso == null || iso.isEmpty || iso.length < 10) return null;
    try {
      final date = DateTime.parse(iso.substring(0, 10));
      final today = DateTime.now();
      final today0 = DateTime(today.year, today.month, today.day);
      final diff = date.difference(today0).inDays;
      if (diff < 0) return 'expired';
      if (diff <= 30) return 'expiring_soon';
      return 'ok';
    } catch (_) {
      return null;
    }
  }

  /// Niveau d'alerte pour la maintenance préventive.
  /// Retourne null si aucune date n'est planifiée.
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

  /// Retourne true si l'équipement appartient à la macro-catégorie donnée.
  bool hasMacroCategory(String name) =>
      (macroCategory ?? '').toLowerCase() == name.toLowerCase();

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
    int? modelId,
    int? brandId,
    String? brandName,
    String? lastPreventiveMaintenance,
    String? nextPreventiveMaintenance,
    int? subcategoryId,
    String? subcategoryName,
    String? subcategoryDescription,
    int? macroCategoryId,
    String? macroCategory,
    String? warrantyEndDate,
    EquipmentCriticality? criticality,
    String? decommissionedAt,
    String? decommissionReason,
    String? disposalMethod,
    String? decommissionedByName,
    String? decommissionNotes,
    String? replacedById,
    String? replacedByName,
    String? replacesId,
    String? replacesName,
    String? building,
    String? createdAt,
    String? updatedAt,
    List<String>? tags,
    List<MaintenanceRecord>? maintenanceHistory,
    List<MaintenanceRecord>? futureMaintenance,
    List<Map<String, dynamic>>? pmProtocols,
    int? pmFrequencyMonths,
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
      modelId: modelId ?? this.modelId,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      lastPreventiveMaintenance: lastPreventiveMaintenance ?? this.lastPreventiveMaintenance,
      nextPreventiveMaintenance: nextPreventiveMaintenance ?? this.nextPreventiveMaintenance,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      subcategoryDescription: subcategoryDescription ?? this.subcategoryDescription,
      macroCategoryId: macroCategoryId ?? this.macroCategoryId,
      macroCategory: macroCategory ?? this.macroCategory,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      criticality: criticality ?? this.criticality,
      decommissionedAt: decommissionedAt ?? this.decommissionedAt,
      decommissionReason: decommissionReason ?? this.decommissionReason,
      disposalMethod: disposalMethod ?? this.disposalMethod,
      decommissionedByName: decommissionedByName ?? this.decommissionedByName,
      decommissionNotes: decommissionNotes ?? this.decommissionNotes,
      replacedById: replacedById ?? this.replacedById,
      replacedByName: replacedByName ?? this.replacedByName,
      replacesId: replacesId ?? this.replacesId,
      replacesName: replacesName ?? this.replacesName,
      building: building ?? this.building,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      maintenanceHistory: maintenanceHistory ?? this.maintenanceHistory,
      futureMaintenance: futureMaintenance ?? this.futureMaintenance,
      pmProtocols: pmProtocols ?? this.pmProtocols,
      pmFrequencyMonths: pmFrequencyMonths ?? this.pmFrequencyMonths,
    );
  }
}
