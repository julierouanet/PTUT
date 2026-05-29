/// Protocole de maintenance préventive lié à un type d'équipement (sous-catégorie).
/// Distinct de `preventive_maintenance_plans` qui est par équipement individuel.
class PmProtocol {
  final int id;
  final int subcategoryId;
  final String name;
  final int frequencyMonths;
  final double? estimatedDurationHours;
  final List<String> checklist;
  final String? subcategoryName;
  final String? macroCategoryName;
  final String? createdAt;
  final String? updatedAt;

  const PmProtocol({
    required this.id,
    required this.subcategoryId,
    required this.name,
    required this.frequencyMonths,
    this.estimatedDurationHours,
    this.checklist = const [],
    this.subcategoryName,
    this.macroCategoryName,
    this.createdAt,
    this.updatedAt,
  });

  factory PmProtocol.fromApiJson(Map<String, dynamic> json) {
    final rawChecklist = json['checklist'];
    final List<String> checklist;
    if (rawChecklist is List) {
      checklist = rawChecklist.map((e) => e.toString()).toList();
    } else {
      checklist = const [];
    }

    final rawFreq = json['frequency_months'];
    final frequencyMonths = rawFreq is int ? rawFreq : int.tryParse(rawFreq?.toString() ?? '') ?? 0;

    final rawDur = json['estimated_duration_hours'];
    final double? estimatedDurationHours;
    if (rawDur is num) {
      estimatedDurationHours = rawDur.toDouble();
    } else if (rawDur is String) {
      estimatedDurationHours = double.tryParse(rawDur);
    } else {
      estimatedDurationHours = null;
    }

    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;

    final rawSubId = json['subcategory_id'];
    final subcategoryId = rawSubId is int ? rawSubId : int.tryParse(rawSubId?.toString() ?? '') ?? 0;

    return PmProtocol(
      id:                     id,
      subcategoryId:          subcategoryId,
      name:                   json['name']                as String? ?? '',
      frequencyMonths:        frequencyMonths,
      estimatedDurationHours: estimatedDurationHours,
      checklist:              checklist,
      subcategoryName:        json['subcategory_name']    as String?,
      macroCategoryName:      json['macro_category_name'] as String?,
      createdAt:              json['created_at']          as String?,
      updatedAt:              json['updated_at']          as String?,
    );
  }

  /// Libellé de fréquence lisible : "3 mois", "12 mois", etc.
  String get frequencyLabel {
    if (frequencyMonths == 1) return '1 mois';
    if (frequencyMonths == 12) return '1 an';
    if (frequencyMonths == 24) return '2 ans';
    return '$frequencyMonths mois';
  }

  PmProtocol copyWith({
    int? id,
    int? subcategoryId,
    String? name,
    int? frequencyMonths,
    double? estimatedDurationHours,
    List<String>? checklist,
    String? subcategoryName,
    String? macroCategoryName,
    String? createdAt,
    String? updatedAt,
  }) {
    return PmProtocol(
      id:                     id ?? this.id,
      subcategoryId:          subcategoryId ?? this.subcategoryId,
      name:                   name ?? this.name,
      frequencyMonths:        frequencyMonths ?? this.frequencyMonths,
      estimatedDurationHours: estimatedDurationHours ?? this.estimatedDurationHours,
      checklist:              checklist ?? this.checklist,
      subcategoryName:        subcategoryName ?? this.subcategoryName,
      macroCategoryName:      macroCategoryName ?? this.macroCategoryName,
      createdAt:              createdAt ?? this.createdAt,
      updatedAt:              updatedAt ?? this.updatedAt,
    );
  }
}
