import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Indicateur « triangle » du plan de remplacement biomédical (RA3 S5).
///
/// Affiche une petite icône triangle colorée selon le statut de remplacement :
///   • orange = `a_remplacer`, jaune = `bientot`, gris = `donnee_manquante`.
///   • aucun badge si `ok` (ou statut inconnu) → retourne [SizedBox.shrink].
///
/// Survol / appui long = [Tooltip] résumé. Clic = [onTap] (navigation détail).
class ReplacementBadge extends StatelessWidget {
  /// Statut de remplacement calculé côté serveur :
  /// `a_remplacer` | `bientot` | `donnee_manquante` | `ok`.
  final String status;

  /// Texte du tooltip (résumé court), construit par l'appelant via l10n.
  final String tooltip;

  /// Action au clic (typiquement : ouvrir la page de détail concernée).
  final VoidCallback? onTap;

  /// Taille de l'icône (par défaut 14).
  final double size;

  const ReplacementBadge({
    super.key,
    required this.status,
    required this.tooltip,
    this.onTap,
    this.size = 14,
  });

  /// Couleur associée à un statut de remplacement. `ok` → null (pas de badge).
  static Color? colorFor(String status) {
    switch (status) {
      case 'a_remplacer':     return AppColors.replacementDue;
      case 'bientot':         return AppColors.replacementSoon;
      case 'donnee_manquante': return AppColors.replacementUnknown;
      default:                return null;
    }
  }

  /// Construit le tooltip localisé à partir des données d'un équipement.
  /// [age] / [lifespan] peuvent être null (donnée manquante).
  static String tooltipFor(
    AppLocalizations l10n,
    String status,
    int? age,
    int? lifespan,
    String? criticality,
  ) {
    final crit = (criticality == null || criticality.isEmpty) ? '—' : criticality;
    switch (status) {
      case 'a_remplacer':
        return l10n.replacementTooltipDue(age ?? '—', lifespan ?? '—', crit);
      case 'bientot':
        return l10n.replacementTooltipSoon(age ?? '—', lifespan ?? '—', crit);
      case 'donnee_manquante':
        return l10n.replacementTooltipUnknown;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    if (color == null) return const SizedBox.shrink();

    final icon = Icon(Icons.warning, size: size, color: color);

    return Tooltip(
      message: tooltip,
      child: onTap == null
          ? icon
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(size),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: icon,
              ),
            ),
    );
  }
}
