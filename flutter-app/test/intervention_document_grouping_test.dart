import 'package:flutter_test/flutter_test.dart';
import 'package:equipment_management/models/equipment_document.dart';
import 'package:equipment_management/utils/intervention_document_grouping.dart';

EquipmentDocument _doc({
  required int id,
  String? issueId,
  String? issueCreatedAt,
  String uploadedAt = '2026-01-01T00:00:00',
  String documentType = 'intervention',
  int? annexNumber,
  String kind = 'document',
}) =>
    EquipmentDocument(
      id: id,
      documentType: documentType,
      originalName: 'f$id.pdf',
      mimeType: 'application/pdf',
      fileSizeKb: 5,
      uploaderName: 'T',
      uploadedAt: uploadedAt,
      issueId: issueId,
      issueCreatedAt: issueCreatedAt,
      annexNumber: annexNumber,
      kind: kind,
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

  test('splitInterventionAnnexe sépare intervention/completion et trie l\'annexe par annexNumber', () {
    final docs = [
      _doc(id: 1, documentType: 'intervention'),
      _doc(id: 2, documentType: 'completion', annexNumber: 2),
      _doc(id: 3, documentType: 'completion', annexNumber: null), // hérité
      _doc(id: 4, documentType: 'completion', annexNumber: 1),
      _doc(id: 5, documentType: 'intervention'),
      _doc(id: 6, documentType: 'completion', annexNumber: 3, kind: 'photo'),
    ];

    final result = splitInterventionAnnexe(docs);

    expect(result.intervention.map((d) => d.id).toList(), [1, 5]);
    // Ordre : annexNumber croissant (2, 1, 3 → 1, 2, 3), hérité (null) en fin
    expect(result.annexe.map((d) => d.id).toList(), [4, 2, 6, 3]);
  });

  test('splitInterventionAnnexe : sections vides restent des listes vides', () {
    final docs = [_doc(id: 1, documentType: 'intervention')];
    final result = splitInterventionAnnexe(docs);
    expect(result.intervention, hasLength(1));
    expect(result.annexe, isEmpty);
  });
}
