import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../screens/account_settings_screen.dart';
import '../notification_bell.dart';

/// Barre de titre horizontale en haut du contenu principal.
/// Affiche : bouton menu (mobile), bouton retour aux modules (desktop),
/// bouton retour historique, titre de l'écran actif, compte et cloche notifs.
class AppTopBar extends StatelessWidget {
  final String title;
  final bool canGoBack;
  final VoidCallback onBack;
  final bool isWide;
  final VoidCallback? onBackToHub;
  final VoidCallback onOpenDrawer;
  final void Function(int index, {String? equipmentId, String? issueId}) onNavigate;

  const AppTopBar({
    super.key,
    required this.title,
    required this.canGoBack,
    required this.onBack,
    required this.isWide,
    required this.onOpenDrawer,
    required this.onNavigate,
    this.onBackToHub,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (!isWide) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textSecondary),
              onPressed: onOpenDrawer,
              tooltip: l10n.tooltipMenu,
            ),
          ],
          if (isWide && onBackToHub != null) ...[
            IconButton(
              icon: const Icon(Icons.grid_view_rounded, color: AppColors.primary),
              onPressed: onBackToHub,
              tooltip: l10n.backToModulesLabel,
            ),
          ],
          if (canGoBack) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
              onPressed: onBack,
              tooltip: l10n.tooltipBack,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined, color: AppColors.textSecondary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen())),
            tooltip: l10n.tooltipAccountSettings,
          ),
          const SizedBox(width: 8),
          NotificationBell(onNavigate: onNavigate),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
