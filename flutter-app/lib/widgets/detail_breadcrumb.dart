import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Un segment de fil d'Ariane. [onTap] null = page courante (non cliquable).
class BreadcrumbSegment {
  final String label;
  final VoidCallback? onTap;

  const BreadcrumbSegment(this.label, {this.onTap});
}

/// Fil d'Ariane générique posé en tête des fiches de détail.
///
/// Rendu : segments séparés par « › ». Un segment avec [onTap] est cliquable
/// (style primary) ; le dernier segment (page courante) est en texte simple.
/// Les segments dont le parent est inconnu doivent être **omis** par l'appelant
/// (jamais de segment vide). N'affiche rien si moins de 2 segments.
class DetailBreadcrumb extends StatelessWidget {
  final List<BreadcrumbSegment> segments;

  /// Marge externe. Par défaut adaptée à un placement direct dans un `body` ;
  /// passer `EdgeInsets.only(bottom: ...)` quand le widget est déjà dans une
  /// liste avec padding horizontal.
  final EdgeInsetsGeometry padding;

  const DetailBreadcrumb({
    super.key,
    required this.segments,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 0),
  });

  @override
  Widget build(BuildContext context) {
    // Un seul segment (ou aucun) = pas de navigation à afficher.
    if (segments.length < 2) return const SizedBox.shrink();

    final children = <Widget>[];
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final isLast = i == segments.length - 1;

      if (seg.onTap != null && !isLast) {
        children.add(InkWell(
          onTap: seg.onTap,
          child: Text(
            seg.label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ));
      } else {
        children.add(Text(
          seg.label,
          style: TextStyle(
            fontSize: 12,
            color: isLast ? AppColors.textSecondary : AppColors.textPrimary,
            fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
          ),
        ));
      }

      if (!isLast) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('›',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ));
      }
    }

    return Padding(
      padding: padding,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}
