import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Étiquette d'onglet responsive : icône seule + Tooltip sur mobile, icône + texte sur desktop.
///
/// [isMobile]    — vrai si la largeur < [AppBreakpoints.tablet]
/// [icon]        — icône à afficher
/// [label]       — texte affiché sur desktop et dans le Tooltip mobile
/// [badgeCount]  — si non null, affiche un badge avec ce nombre sur l'icône
class TabLabel extends StatelessWidget {
  final bool isMobile;
  final IconData icon;
  final String label;
  final int? badgeCount;

  const TabLabel({
    super.key,
    required this.isMobile,
    required this.icon,
    required this.label,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = badgeCount != null
        ? Badge(
            isLabelVisible: badgeCount! > 0,
            label: Text('$badgeCount', style: const TextStyle(fontSize: 10)),
            child: Icon(icon, size: isMobile ? 18 : 16),
          )
        : Icon(icon, size: isMobile ? 18 : 16);

    if (isMobile) {
      return Tooltip(message: label, child: iconWidget);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
