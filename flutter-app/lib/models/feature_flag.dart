/// Représente un feature flag avec son statut global et ses exceptions par rôle.
class FeatureFlag {
  final String id;
  final String name;
  final String? description;
  final bool isGlobalActive;
  // Clé = nom de rôle API (ex: 'admin'), valeur = override (true=forcé actif, false=forcé inactif)
  final Map<String, bool> roleOverrides;

  const FeatureFlag({
    required this.id,
    required this.name,
    this.description,
    required this.isGlobalActive,
    required this.roleOverrides,
  });

  factory FeatureFlag.fromApiJson(Map<String, dynamic> json) {
    final rawOverrides = json['role_overrides'] as Map<String, dynamic>? ?? {};
    return FeatureFlag(
      id:             json['id'] as String,
      name:           json['name'] as String,
      description:    json['description'] as String?,
      isGlobalActive: json['is_global_active'] as bool? ?? true,
      roleOverrides:  rawOverrides.map((k, v) => MapEntry(k, v as bool? ?? true)),
    );
  }

  FeatureFlag copyWith({
    bool? isGlobalActive,
    Map<String, bool>? roleOverrides,
  }) => FeatureFlag(
    id:             id,
    name:           name,
    description:    description,
    isGlobalActive: isGlobalActive ?? this.isGlobalActive,
    roleOverrides:  roleOverrides ?? this.roleOverrides,
  );
}
