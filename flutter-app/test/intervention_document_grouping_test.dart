import 'package:flutter_test/flutter_test.dart';
import 'package:equipment_management/models/equipment_document.dart';
import 'package:equipment_management/utils/intervention_document_grouping.dart';

EquipmentDocument _doc({
  required int id,
  String? issueId,
  String? issueCreatedAt,
  String uploadedAt = '2026-01-01T00:00:00',
}) =>
    EquipmentDocument(
      id: id,
      documentType: 'intervention',
      originalName: 'f$id.pdf',
      mimeType: 'application/pdf',
      fileSizeKb: 5,
      uploaderName: 'T',
      uploadedAt: uploadedAt,
      issueId: issueId,
      issueCreatedAt: issueCreatedAt,
    );

void main() {
  test('groupInterventionDocs trie par issueCreatedAt desc et isole les orphelins', () {
    final docs = [
      _doc(id: 1, issueId: 'iss-a', issueCreatedAt: '2026-01-01T00:00:00'),
      _doc(id: 2, issueId: 'iss-b', issueCreatedAt: '2026-01-05T00:00:00'),
      _doc(id: 3, issueId: null),
      _doc(id: 4, issueId: 'iss-a', issueCreatedAt: '2026-01-01T00:00:00'),
    ];

    final result = groupInterventionDocs(docs);

    expect(result.named.map((e) => e.key).toList(), ['iss-b', 'iss-a']);
    expect(result.named.map((e) => e.value.length).toList(), [1, 2]);
    expect(result.orphans?.map((d) => d.id).toList(), [3]);
  });

  test('formatDocDate formate en dd/MM/yyyy', () {
    expect(formatDocDate('2026-01-05T00:00:00'), '05/01/2026');
    expect(formatDocDate(''), '—');
  });
}
