import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/equipment_document.dart';
import '../theme/app_theme.dart';
import '../utils/intervention_document_grouping.dart';

/// Tuile dépliable d'un groupe de documents d'intervention (par incident, ou
/// groupe orphelin `issueId == null`). Partagée entre l'onglet Documents d'un
/// équipement et l'onglet Documents technicien (cross-équipement).
///
/// Quand `issueId` est renseigné, les documents sont répartis en deux
/// sous-sections libellées (Intervention / Annexe), chacune masquée si vide.
/// Les groupes orphelins (`issueId == null`, documents non rattachés à un
/// incident) conservent l'affichage à plat existant.
class DocGroupTile extends StatelessWidget {
  final String? issueId;
  final List<EquipmentDocument> groupDocs;
  final bool initiallyExpanded;
  final Widget Function(EquipmentDocument doc) rowBuilder;
  final Widget? trailing;

  const DocGroupTile({
    super.key,
    required this.issueId,
    required this.groupDocs,
    required this.initiallyExpanded,
    required this.rowBuilder,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final issueId = this.issueId;
    final title = issueId != null
        ? l10n.docInterventionGroupTitle(issueId, groupDocs.length)
        : l10n.docOtherDocuments(groupDocs.length);
    final subtitle = issueId != null
        ? '${groupDocs.first.issueStatus ?? "—"} · ${formatDocDate(groupDocs.first.issueCreatedAt ?? "")}'
        : null;
    final titleText = Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));

    return ExpansionTile(
      key: ValueKey(issueId ?? '__orphans__'),
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: trailing == null
          ? titleText
          : Row(children: [Expanded(child: titleText), trailing!]),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))
          : null,
      children: issueId == null
          ? _flatChildren()
          : buildAnnexeGroupedChildren(l10n, groupDocs, rowBuilder),
    );
  }

  List<Widget> _flatChildren() => groupDocs.map(rowBuilder).toList();
}
