import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Badge widget to display equipment or issue status
class StatusBadge extends StatelessWidget {
  final String status;
  final bool isCompact;

  const StatusBadge({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = getStatusColor(status);
    final bgColor = getStatusBackgroundColor(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: isCompact ? 12 : 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Issue status badge with different color scheme
class IssueStatusBadge extends StatelessWidget {
  final String status;

  const IssueStatusBadge({super.key, required this.status});

  /// Normalize status to a canonical key for color mapping.
  /// Accepts English canonical names and legacy French names.
  String get _canonical {
    switch (status) {
      case 'Reported':
      case 'Ouvert':
        return 'reported';
      case 'Acknowledged':
      case 'Approuvé':
        return 'acknowledged';
      case 'Assigned':
        return 'assigned';
      case 'In Progress':
      case 'En cours':
        return 'inProgress';
      case 'Waiting Materials':
        return 'waitingMaterials';
      case 'Completed':
      case 'Résolu':
        return 'completed';
      case 'Verified':
        return 'verified';
      case 'Closed':
      case 'Annulé':
        return 'closed';
      case 'Redirected':
        return 'redirected';
      default:
        return status.toLowerCase();
    }
  }

  Color get _color {
    switch (_canonical) {
      case 'reported':
        return AppColors.error;
      case 'acknowledged':
        return AppColors.primary;
      case 'assigned':
        return AppColors.primary;
      case 'inProgress':
        return AppColors.warning;
      case 'waitingMaterials':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      case 'verified':
        return AppColors.success;
      case 'closed':
        return AppColors.textSecondary;
      case 'redirected':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  Color get _bgColor {
    switch (_canonical) {
      case 'reported':
        return AppColors.errorLight;
      case 'acknowledged':
        return AppColors.primaryLight;
      case 'assigned':
        return AppColors.primaryLight;
      case 'inProgress':
        return AppColors.warningLight;
      case 'waitingMaterials':
        return AppColors.warningLight;
      case 'completed':
        return AppColors.successLight;
      case 'verified':
        return AppColors.successLight;
      case 'closed':
        return AppColors.background;
      case 'redirected':
        return AppColors.primaryLight;
      default:
        return AppColors.background;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
