import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../screens/issue_form_screen.dart';

class _CategoryOption {
  final List<String>? categoryFilter;
  final IconData icon;
  final Color color;
  final String Function(AppLocalizations) label;

  const _CategoryOption({
    required this.categoryFilter,
    required this.icon,
    required this.color,
    required this.label,
  });
}

// Les 4 choix avec les valeurs exactes de Equipment.category en base
final _kOptions = <_CategoryOption>[
  _CategoryOption(
    categoryFilter: ['Imagerie', 'Laboratoire', 'Chirurgie', 'Monitoring', 'Therapeutique'],
    icon: CupertinoIcons.heart_circle,
    color: AppColors.primary,
    label: (l) => l.issueCategoryBiomedical,
  ),
  _CategoryOption(
    categoryFilter: ['Mobilier', 'Autre'],
    icon: CupertinoIcons.building_2_fill,
    color: AppColors.warning,
    label: (l) => l.issueCategoryInfrastructure,
  ),
  _CategoryOption(
    categoryFilter: ['Informatique'],
    icon: CupertinoIcons.device_desktop,
    color: AppColors.textSecondary,
    label: (l) => l.issueCategoryIT,
  ),
  _CategoryOption(
    categoryFilter: null,
    icon: CupertinoIcons.question_circle,
    color: AppColors.textMuted,
    label: (l) => l.issueCategoryOther,
  ),
];

/// Affiche le sélecteur de catégorie d'incident avant [IssueFormScreen].
/// < 800 px → ModalBottomSheet avec coins arrondis en haut.
/// >= 800 px → Dialog centré, largeur max 500 px.
void showIssueCategorySelector(BuildContext context) {
  final isWide = MediaQuery.of(context).size.width >= 800;
  if (isWide) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: _SelectorContent(parentContext: context),
        ),
      ),
    );
  } else {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SelectorContent(parentContext: context),
    );
  }
}

class _SelectorContent extends StatelessWidget {
  // parentContext = contexte de l'écran appelant.
  // Nécessaire pour que Navigator.push cible le navigator racine,
  // pas celui interne au dialog/bottom-sheet.
  final BuildContext parentContext;

  const _SelectorContent({required this.parentContext});

  void _onSelected(BuildContext sheetCtx, _CategoryOption option) {
    Navigator.of(sheetCtx).pop();
    if (!parentContext.mounted) return;
    Navigator.of(parentContext).push(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          body: IssueFormScreen(
            categoryFilter: option.categoryFilter,
            onCancel: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.issueCategorySelectorTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ..._kOptions.map((option) => _buildTile(context, l10n, option)),
        ],
      ),
    );
  }

  Widget _buildTile(
      BuildContext context, AppLocalizations l10n, _CategoryOption option) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _onSelected(context, option),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surface,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: option.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(option.icon, color: option.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  option.label(l10n),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
