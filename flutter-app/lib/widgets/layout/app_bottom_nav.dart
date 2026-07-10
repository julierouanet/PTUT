import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/nav_item.dart';
import '../issue_category_selector.dart';

/// Barre de navigation en bas de l'écran (mobile uniquement).
/// Affiche les 4 premiers items de navigation + un item "Plus" ouvrant le
/// drawer complet si plus de 5 items sont disponibles (sinon les 5 tiennent).
class AppBottomNav extends StatelessWidget {
  final List<NavItem> navItems;
  final int currentIndex;
  final void Function(BuildContext ctx, NavItem item, int index) onTap;
  final VoidCallback onOpenDrawer;

  const AppBottomNav({
    super.key,
    required this.navItems,
    required this.currentIndex,
    required this.onTap,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasMore = navItems.length > 5;
    final visibleItems = navItems.take(hasMore ? 4 : 5).toList();
    if (visibleItems.length < 2) return const SizedBox.shrink();

    return NavigationBar(
      selectedIndex: currentIndex < visibleItems.length ? currentIndex : 0,
      onDestinationSelected: (index) {
        if (hasMore && index == visibleItems.length) {
          onOpenDrawer();
          return;
        }
        final item = visibleItems[index];
        if (item.screenType == ScreenType.issueForm) {
          showIssueCategorySelector(context);
        } else {
          onTap(context, item, index);
        }
      },
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: [
        ...visibleItems.map((item) => NavigationDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.activeIcon),
          label: item.shortLabel,
        )),
        if (hasMore)
          NavigationDestination(
            icon: const Icon(Icons.more_horiz_outlined),
            selectedIcon: const Icon(Icons.more_horiz),
            label: l10n.navMore,
          ),
      ],
    );
  }
}
