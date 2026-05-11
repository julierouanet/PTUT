/// Lieu physique de l'hôpital (infrastructure, réseau, électricité…).
class Location {
  final String id;
  final String name;
  final String building;
  final String department;

  const Location({
    required this.id,
    required this.name,
    required this.building,
    required this.department,
  });

  factory Location.fromApiJson(Map<String, dynamic> json) {
    return Location(
      id:         json['id']         as String? ?? '',
      name:       json['name']       as String? ?? '',
      building:   json['building']   as String? ?? '',
      department: json['department'] as String? ?? '',
    );
  }

  /// Étiquette affichée dans les menus déroulants.
  String get label => '$name — $building';
}
