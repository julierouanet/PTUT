class InterventionTechnician {
  final String id;
  final String name;

  const InterventionTechnician({required this.id, required this.name});

  factory InterventionTechnician.fromJson(Map<String, dynamic> j) => InterventionTechnician(
    id:   j['uploaded_by'] as String,
    name: j['uploader_name'] as String,
  );
}
