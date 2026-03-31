import 'package:flutter/material.dart';
import '../models/issue.dart';
import '../theme/app_theme.dart';

/// Badge coloré affichant le niveau d'urgence d'un incident.
///
/// - Faible  → gris/neutre
/// - Moyen   → orange/warning
/// - Urgent  → rouge/error avec icône
class UrgencyBadge extends StatelessWidget {
  final IssueUrgency urgency;
  final bool isCompact;

  const UrgencyBadge({
    super.key,
    required this.urgency,
    this.isCompact = false,
  });

  Color get _color {
    switch (urgency) {
      case IssueUrgency.faible:
        return AppColors.textSecondary;
      case IssueUrgency.moyen:
        return AppColors.warning;
      case IssueUrgency.urgent:
        return AppColors.error;
    }
  }

  Color get _bgColor {
    switch (urgency) {
      case IssueUrgency.faible:
        return AppColors.background;
      case IssueUrgency.moyen:
        return AppColors.warningLight;
      case IssueUrgency.urgent:
        return AppColors.errorLight;
    }
  }

  IconData get _icon {
    switch (urgency) {
      case IssueUrgency.faible:
        return Icons.arrow_downward;
      case IssueUrgency.moyen:
        return Icons.remove;
      case IssueUrgency.urgent:
        return Icons.arrow_upward;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = isCompact ? 11.0 : 12.0;
    final iconSize = isCompact ? 12.0 : 14.0;
    final hPad    = isCompact ? 8.0  : 10.0;
    final vPad    = isCompact ? 3.0  : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: iconSize, color: _color),
          SizedBox(width: isCompact ? 3 : 4),
          Text(
            urgency.displayName,
            style: TextStyle(
              color: _color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
