import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Pied de pagination serveur générique (Précédent / Page X sur Y / Suivant).
/// Partagé par tous les écrans utilisant la pagination serveur (équipements,
/// suivi des incidents, interventions technicien).
class PaginationFooter extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final ValueChanged<int> onPageChange;

  const PaginationFooter({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.isLoading,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: currentPage > 1 && !isLoading
              ? () => onPageChange(currentPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          label: Text(l10n.commonPrevious),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            l10n.commonPageOf(currentPage, totalPages),
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        TextButton.icon(
          onPressed: currentPage < totalPages && !isLoading
              ? () => onPageChange(currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: Text(l10n.commonNext),
        ),
      ],
    );
  }
}
