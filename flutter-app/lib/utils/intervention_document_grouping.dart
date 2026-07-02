import 'package:intl/intl.dart';
import '../models/equipment_document.dart';

/// Un groupe de documents d'intervention rattachés au même incident (`issueId`).
typedef DocGroup = MapEntry<String?, List<EquipmentDocument>>;

/// Groupe [docs] par issueId et trie les groupes nommés par issueCreatedAt desc.
/// Le groupe null (documents orphelins, sans incident) est toujours le dernier.
({List<DocGroup> named, List<EquipmentDocument>? orphans}) groupInterventionDocs(
    List<EquipmentDocument> docs) {
  final Map<String?, List<EquipmentDocument>> grouped = {};
  for (final d in docs) {
    grouped.putIfAbsent(d.issueId, () => []).add(d);
  }

  // Pré-calcul du max uploadedAt par groupe (évite un reduce dans le comparateur)
  String maxUpload(List<EquipmentDocument> g) =>
      g.map((d) => d.uploadedAt).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);

  final named = grouped.entries.where((e) => e.key != null).toList();
  // Associer la date de tri en avance pour ne pas recalculer dans le comparateur
  final withSortKey = named.map((e) {
    final dateIssue = e.value.first.issueCreatedAt ?? ''; // liste tjrs non vide (putIfAbsent+add)
    final sortKey = dateIssue.isNotEmpty ? dateIssue : maxUpload(e.value);
    return (entry: e, sortKey: sortKey, hasIssueDate: dateIssue.isNotEmpty);
  }).toList()
    ..sort((a, b) {
      // Groupes avec date d'incident connue avant ceux en repli uploadedAt
      if (a.hasIssueDate != b.hasIssueDate) return a.hasIssueDate ? -1 : 1;
      return b.sortKey.compareTo(a.sortKey);
    });

  return (
    named: withSortKey.map((x) => x.entry).toList(),
    orphans: grouped[null],
  );
}

String formatDocDate(String raw) {
  if (raw.isEmpty) return '—';
  try {
    return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw).toLocal());
  } catch (_) {
    return raw;
  }
}
