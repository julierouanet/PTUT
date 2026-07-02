import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/notification.dart';
import '../models/nav_item.dart';
import '../services/notification_service.dart';
import 'count_badge.dart';

/// Cloche de notifications avec badge et panneau déroulant
class NotificationBell extends StatefulWidget {
  /// Callback pour naviguer vers un écran (index ScreenType)
  final Function(int screenIndex, {String? issueId}) onNavigate;

  const NotificationBell({super.key, required this.onNavigate});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (context) => _NotificationOverlay(
        layerLink: _layerLink,
        onClose: _removeOverlay,
        onNavigate: widget.onNavigate,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CompositedTransformTarget(
      link: _layerLink,
      child: ListenableBuilder(
        listenable: NotificationService(),
        builder: (context, _) {
          final count = NotificationService().unreadCount;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(
                  _overlayEntry != null
                      ? Icons.notifications
                      : Icons.notifications_outlined,
                  color: _overlayEntry != null
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                onPressed: _toggleOverlay,
                tooltip: l10n.tooltipNotifications,
              ),
              if (count > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: IgnorePointer(
                    child: CountBadge(count: count, maxDisplay: 9),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Overlay (positionnement + contenu)
// ─────────────────────────────────────────────────────────────

class _NotificationOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final VoidCallback onClose;
  final Function(int, {String? issueId}) onNavigate;

  const _NotificationOverlay({
    required this.layerLink,
    required this.onClose,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Zone de clic externe pour fermer
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onClose,
          ),
        ),
        // Panneau ancré sous la cloche
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 4),
          child: GestureDetector(
            // Absorbe les taps sur le panneau pour ne pas déclencher le close
            onTap: () {},
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: SizedBox(
                width: 320,
                child: ListenableBuilder(
                  listenable: NotificationService(),
                  builder: (context, _) => _NotificationPanel(
                    onClose: onClose,
                    onNavigate: onNavigate,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Contenu du panneau
// ─────────────────────────────────────────────────────────────

class _NotificationPanel extends StatelessWidget {
  final VoidCallback onClose;
  final Function(int, {String? issueId}) onNavigate;

  const _NotificationPanel({required this.onClose, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final svc   = NotificationService();
    final notifs = svc.all;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── En-tête ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.notifications, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.notifTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (svc.unreadCount > 0)
                  TextButton(
                    onPressed: svc.markAllAsRead,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l10n.notifMarkAllRead,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // ── Liste ou état vide ──
          if (notifs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  const Icon(Icons.notifications_none, size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    l10n.notifEmpty,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: notifs.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  final notif = notifs[index];
                  return _NotifTile(
                    notif: notif,
                    l10n: l10n,
                    onTap: () {
                      NotificationService().markAsRead(notif.id);
                      onClose();
                      final screen = notif.type.targetScreen;
                      if (screen != null) {
                        onNavigate(ScreenType.values.indexOf(screen));
                      } else if (notif.linkedIssueId != null) {
                        onNavigate(2, issueId: notif.linkedIssueId);
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tuile individuelle
// ─────────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final AppNotification notif;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _NotifTile({
    required this.notif,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (Color iconColor, IconData iconData) = switch (notif.type) {
      NotificationType.newIssue        => (AppColors.warning, Icons.warning_amber_rounded),
      NotificationType.issueInProgress => (AppColors.primary, Icons.build_rounded),
      NotificationType.issueResolved   => (AppColors.success, Icons.check_circle_rounded),
      NotificationType.deptRequest     => (AppColors.warning, Icons.swap_horiz_rounded),
      NotificationType.roleRequest     => (AppColors.warning, Icons.badge_outlined),
    };

    final String title = switch (notif.type) {
      NotificationType.newIssue        => l10n.notifNewIssue,
      NotificationType.issueInProgress => l10n.notifInProgress,
      NotificationType.issueResolved   => l10n.notifResolved,
      NotificationType.deptRequest     => 'Demande de changement de département',
      NotificationType.roleRequest     => l10n.notifRoleRequest,
    };

    final String body = switch (notif.type) {
      NotificationType.newIssue =>
        l10n.notifNewIssueBody(notif.equipmentName, notif.department),
      NotificationType.issueInProgress =>
        l10n.notifInProgressBody(notif.equipmentName),
      NotificationType.issueResolved =>
        l10n.notifResolvedBody(notif.equipmentName),
      NotificationType.deptRequest =>
        '${notif.userName ?? 'Utilisateur'} : ${notif.department} → ${notif.equipmentName}',
      NotificationType.roleRequest =>
        '${notif.userName ?? 'Utilisateur'} → ${notif.equipmentName}',
    };

    return InkWell(
      onTap: onTap,
      child: ColoredBox(
        color: notif.read ? Colors.transparent : AppColors.primaryLight.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône colorée
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 16),
              ),
              const SizedBox(width: 12),

              // Texte
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: notif.read ? FontWeight.normal : FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(notif.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              // Point bleu si non lue
              if (!notif.read)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4, left: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return l10n.notifTimeJustNow;
    if (diff.inHours < 1)    return l10n.notifTimeMinutes(diff.inMinutes);
    if (diff.inDays < 1)     return l10n.notifTimeHours(diff.inHours);
    return l10n.notifTimeDays(diff.inDays);
  }
}
