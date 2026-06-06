import 'package:flutter/material.dart';
import '../../models/nav_item.dart';
import '../issue_category_selector.dart';

/// Barre de navigation en bas de l'écran (mobile uniquement).
/// Affiche les 5 premiers items de navigation.
class AppBottomNav extends StatelessWidget {
  final List<NavItem> navItems;
  final int currentIndex;
  final void Function(BuildContext ctx, NavItem item, int index) onTap;

  const AppBottomNav({
    super.key,
    required this.navItems,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = navItems.take(5).toList();
    if (visibleItems.length < 2) return const SizedBox.shrink();

    return NavigationBar(
      selectedIndex: currentIndex < visibleItems.length ? currentIndex : 0,
      onDestinationSelected: (index) {
        final item = visibleItems[index];
        if (item.screenType == ScreenType.issueForm) {
          showIssueCategorySelector(context);
        } else {
          onTap(context, item, index);
        }
      },
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: visibleItems.map((item) => NavigationDestination(
        icon: Icon(item.icon),
        selectedIcon: Icon(item.activeIcon),
        label: item.shortLabel,
      )).toList(),
    );
  }
}
