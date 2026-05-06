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
  /// Accepts both English (canonical) and French (legacy) display names.
  String get _canonical {
    switch (status) {
      case 'Ouvert':
      case 'Open':
        return 'open';
      case 'Approuvé':
      case 'Approved':
        return 'approved';
      case 'En cours':
      case 'In Progress':
        return 'inProgress';
      case 'Résolu':
      case 'Resolved':
        return 'resolved';
      default:
        return status.toLowerCase();
    }
  }

  Color get _color {
    switch (_canonical) {
      case 'open':
        return AppColors.error;
      case 'approved':
        return AppColors.primary;
      case 'inprogress':
      case 'inProgress':
        return AppColors.warning;
      case 'resolved':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  Color get _bgColor {
    switch (_canonical) {
      case 'open':
        return AppColors.errorLight;
      case 'approved':
        return AppColors.primaryLight;
      case 'inprogress':
      case 'inProgress':
        return AppColors.warningLight;
      case 'resolved':
        return AppColors.successLight;
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
