import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../models/nav_item.dart';
import '../../models/user_role.dart';
import '../../screens/account_settings_screen.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../issue_category_selector.dart';

/// Sidebar desktop animée (expandable/collapsible).
/// Gère son propre état collapsed/expanded pour ne pas polluer _MainScaffoldState.
class AppSidebar extends StatefulWidget {
  final List<NavItem> navItems;
  final int currentIndex;
  final String subtitle;
  final void Function(BuildContext ctx, NavItem item, int index) onNavTap;
  final VoidCallback? onBackToHub;
  final VoidCallback onLogout;

  const AppSidebar({
    super.key,
    required this.navItems,
    required this.currentIndex,
    required this.subtitle,
    required this.onNavTap,
    required this.onLogout,
    this.onBackToHub,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final l10n        = AppLocalizations.of(context)!;
    final authService = AuthService();
    final currentUser = authService.currentUser;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _isCollapsed ? 70.0 : 260.0,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          _buildHeader(l10n),
          const Divider(height: 1),
          if (widget.onBackToHub != null) ...[
            _buildBackToHubButton(l10n),
            const Divider(height: 1),
          ],
          Expanded(child: _buildNavList(l10n)),
          _buildNotificationsBadge(l10n),
          _buildLogoutButton(l10n),
          const Divider(height: 1),
          _buildUserFooter(l10n, currentUser, authService.primaryRole),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: _isCollapsed
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.all(20),
      child: _isCollapsed
          ? Column(children: [
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                tooltip: l10n.tooltipMenu,
                onPressed: () => setState(() => _isCollapsed = false),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Image.asset('assets/images/logo_hopital.png', height: 36, width: 36, fit: BoxFit.contain),
              ),
            ])
          : Row(children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Image.asset('assets/images/logo_hopital.png', height: 36, width: 36, fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.hospitalName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                    Text(widget.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
                tooltip: l10n.tooltipMenu,
                onPressed: () => setState(() => _isCollapsed = true),
              ),
            ]),
    );
  }

  Widget _buildBackToHubButton(AppLocalizations l10n) {
    return Padding(
      padding: EdgeInsets.fromLTRB(_isCollapsed ? 4 : 12, 8, _isCollapsed ? 4 : 12, 4),
      child: _isCollapsed
          ? Tooltip(
              message: l10n.backToModules,
              child: Material(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: widget.onBackToHub,
                  borderRadius: BorderRadius.circular(8),
                  child: const SizedBox(height: 44, child: Center(child: Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 20))),
                ),
              ),
            )
          : ListTile(
              leading: const Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 20),
              title: Text(l10n.backToModules, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              tileColor: AppColors.primaryLight,
              onTap: widget.onBackToHub,
            ),
    );
  }

  Widget _buildNavList(AppLocalizations l10n) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.navItems.length,
      itemBuilder: (context, index) {
        final item = widget.navItems[index];
        final isSelected = widget.currentIndex == index;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 4 : 12, vertical: 2),
          child: _isCollapsed
              ? Tooltip(
                  message: item.label,
                  child: Material(
                    color: isSelected ? AppColors.primaryLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () {
                        if (item.screenType == ScreenType.issueForm) {
                          showIssueCategorySelector(context);
                        } else {
                          widget.onNavTap(context, item, index);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: Icon(isSelected ? item.activeIcon : item.icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                )
              : ListTile(
                  leading: Icon(isSelected ? item.activeIcon : item.icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                  title: Text(item.label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                  selected: isSelected,
                  selectedTileColor: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    if (item.screenType == ScreenType.issueForm) {
                      showIssueCategorySelector(context);
                    } else {
                      widget.onNavTap(context, item, index);
                    }
                  },
                ),
        );
      },
    );
  }

  Widget _buildNotificationsBadge(AppLocalizations l10n) {
    return ListenableBuilder(
      listenable: NotificationService(),
      builder: (context, _) {
        final unread = NotificationService().unreadCount;
        if (unread == 0) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 4 : 12, vertical: 2),
          child: _isCollapsed
              ? Tooltip(
                  message: '${l10n.tooltipNotifications} ($unread)',
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                )
              : ListTile(
                  leading: Stack(children: [
                    const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ]),
                  title: Text(l10n.tooltipNotifications, style: const TextStyle(fontSize: 14)),
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () {},
                ),
        );
      },
    );
  }

  Widget _buildLogoutButton(AppLocalizations l10n) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 4 : 12, vertical: 4),
      child: _isCollapsed
          ? Tooltip(
              message: l10n.logout,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: widget.onLogout,
                  borderRadius: BorderRadius.circular(8),
                  child: const SizedBox(height: 48, child: Center(child: Icon(Icons.logout, color: AppColors.error))),
                ),
              ),
            )
          : ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: Text(l10n.logout, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: widget.onLogout,
            ),
    );
  }

  Widget _buildUserFooter(AppLocalizations l10n, dynamic currentUser, UserRole? primaryRole) {
    final role = primaryRole ?? UserRole.hospitalStaff;
    return Padding(
      padding: EdgeInsets.fromLTRB(_isCollapsed ? 0 : 16, 8, _isCollapsed ? 0 : 8, 8),
      child: _isCollapsed
          ? Center(
              child: Tooltip(
                message: currentUser?.fullName ?? l10n.user,
                child: CircleAvatar(
                  backgroundColor: _roleColor(role).withValues(alpha: 0.2),
                  child: Icon(_roleIcon(role), color: _roleColor(role)),
                ),
              ),
            )
          : Row(children: [
              CircleAvatar(
                backgroundColor: _roleColor(role).withValues(alpha: 0.2),
                child: Icon(_roleIcon(role), color: _roleColor(role)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currentUser?.fullName ?? l10n.user, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      currentUser?.roles.map((r) => r.displayName).join(', ') ?? '',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 20),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen())),
                tooltip: l10n.tooltipAccountSettings,
              ),
            ]),
    );
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin: return Icons.admin_panel_settings;
      case UserRole.supervisor: return Icons.supervisor_account;
      case UserRole.technician:
      case UserRole.technicianBiomedical:
      case UserRole.technicianIt:
      case UserRole.technicianInfra:
        return Icons.build;
      case UserRole.hospitalStaff: return Icons.medical_services;
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin: return AppColors.error;
      case UserRole.supervisor: return AppColors.warning;
      case UserRole.technician: return AppColors.success;
      case UserRole.technicianBiomedical: return AppColors.success;
      case UserRole.technicianIt: return AppColors.primary;
      case UserRole.technicianInfra: return AppColors.warning;
      case UserRole.hospitalStaff: return AppColors.primary;
    }
  }
}
