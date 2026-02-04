import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Alert severity levels
enum AlertSeverity { critical, warning, info }

/// Alert card widget for urgent notifications
class AlertCard extends StatelessWidget {
  final String title;
  final String message;
  final AlertSeverity severity;
  final VoidCallback? onTap;

  const AlertCard({
    super.key,
    required this.title,
    required this.message,
    this.severity = AlertSeverity.warning,
    this.onTap,
  });

  Color get _color {
    switch (severity) {
      case AlertSeverity.critical:
        return AppColors.error;
      case AlertSeverity.warning:
        return AppColors.warning;
      case AlertSeverity.info:
        return AppColors.primary;
    }
  }

  Color get _bgColor {
    switch (severity) {
      case AlertSeverity.critical:
        return AppColors.errorLight;
      case AlertSeverity.warning:
        return AppColors.warningLight;
      case AlertSeverity.info:
        return AppColors.primaryLight;
    }
  }

  IconData get _icon {
    switch (severity) {
      case AlertSeverity.critical:
        return Icons.error;
      case AlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case AlertSeverity.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_icon, color: _color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
