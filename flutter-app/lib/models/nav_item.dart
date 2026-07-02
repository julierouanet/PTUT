import 'package:flutter/material.dart';
import 'user_role.dart';

/// Identifiant unique de chaque écran de l'application.
enum ScreenType {
  dashboard,
  equipment,
  issueTracking,
  issueForm,
  technician,
  inventory,
  reports,
  users,
  settings,
  logs,
  analytics,
  backupManagement,
  debugTest,
}

/// Descripteur d'un item de navigation (sidebar, bottom nav, drawer).
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String shortLabel;
  final ScreenType screenType;
  final Permission? requiredPermission;
  // Permission alternative : l'item est visible si l'utilisateur a l'une OU l'autre
  final Permission? alternativePermission;
  // Compteur affiché en badge rouge sur l'item (null = pas de badge)
  final int? badgeCount;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.shortLabel,
    required this.screenType,
    this.requiredPermission,
    this.alternativePermission,
    this.badgeCount,
  });
}
