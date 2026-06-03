// ── Modal de configuration des préférences email (1ère connexion ou Settings) ─

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/notification_preferences.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Affiche la modal de configuration des préférences email de l'utilisateur.
/// [isFirstSetup] = true → contexte de 1ère connexion (pas de bouton "Annuler").
Future<void> showNotificationPreferencesDialog(
  BuildContext context, {
  bool isFirstSetup = false,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: !isFirstSetup,
    builder: (ctx) => _NotificationPreferencesDialog(isFirstSetup: isFirstSetup),
  );
}

class _NotificationPreferencesDialog extends StatefulWidget {
  final bool isFirstSetup;

  const _NotificationPreferencesDialog({required this.isFirstSetup});

  @override
  State<_NotificationPreferencesDialog> createState() =>
      _NotificationPreferencesDialogState();
}

class _NotificationPreferencesDialogState
    extends State<_NotificationPreferencesDialog> {
  late NotificationPreferences _prefs;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _prefs = AuthService().notificationPreferences ?? NotificationPreferences.defaults;
  }

  bool _isEligible(Set<UserRole> roles) {
    final userRoles = AuthService().currentUser?.roles ?? const [];
    return userRoles.any(roles.contains);
  }

  bool get _isSupervisorOrAdmin => _isEligible({UserRole.supervisor, UserRole.admin});
  bool get _isTechOrAdmin =>
      _isEligible({UserRole.technician, UserRole.technicianBiomedical, UserRole.technicianIt, UserRole.technicianInfra, UserRole.admin});

  Future<void> _save() async {
    setState(() => _loading = true);
    final ok = await AuthService().updateNotificationPreferences(_prefs);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pop(context);
      if (!widget.isFirstSetup) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.notifPrefsUpdated),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.commonSaveError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ────────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.email_outlined, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.notifPrefsTitle,
                        style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.isFirstSetup) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.notifPrefsFirstSetupSubtitle,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!widget.isFirstSetup)
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.notifPrefsSubtitle,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // ── Préférences ────────────────────────────────────────────────
            _PrefTile(
              icon: Icons.report_problem_outlined,
              title: l10n.notifPrefsNewIssue,
              subtitle: l10n.notifPrefsNewIssueDesc,
              value: _prefs.notifyNewIssue,
              visible: _isSupervisorOrAdmin,
              onChanged: (v) => setState(() => _prefs = _prefs.copyWith(notifyNewIssue: v)),
            ),
            _PrefTile(
              icon: Icons.assignment_outlined,
              title: l10n.notifPrefsIssueAssigned,
              subtitle: l10n.notifPrefsIssueAssignedDesc,
              value: _prefs.notifyIssueAssigned,
              visible: _isTechOrAdmin,
              onChanged: (v) => setState(() => _prefs = _prefs.copyWith(notifyIssueAssigned: v)),
            ),
            _PrefTile(
              icon: Icons.check_circle_outline,
              title: l10n.notifPrefsIssueResolved,
              subtitle: l10n.notifPrefsIssueResolvedDesc,
              value: _prefs.notifyIssueResolved,
              visible: true,
              onChanged: (v) => setState(() => _prefs = _prefs.copyWith(notifyIssueResolved: v)),
            ),
            _PrefTile(
              icon: Icons.update_outlined,
              title: l10n.notifPrefsIssueStatusUpdate,
              subtitle: l10n.notifPrefsIssueStatusUpdateDesc,
              value: _prefs.notifyIssueStatusUpdate,
              visible: true,
              onChanged: (v) => setState(() => _prefs = _prefs.copyWith(notifyIssueStatusUpdate: v)),
            ),
            _PrefTile(
              icon: Icons.build_circle_outlined,
              title: l10n.notifPrefsPmDue,
              subtitle: l10n.notifPrefsPmDueDesc,
              value: _prefs.notifyPmDue,
              visible: _isTechOrAdmin,
              onChanged: (v) => setState(() => _prefs = _prefs.copyWith(notifyPmDue: v)),
            ),

            const SizedBox(height: 16),
            // ── Actions ────────────────────────────────────────────────────
            Row(
              children: [
                if (widget.isFirstSetup) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () {
                        // Passer en ignorant — marque quand même comme configuré
                        AuthService().clearPreferencesSetupFlag();
                        Navigator.pop(context);
                      },
                      child: Text(l10n.notifPrefsSkip),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.commonSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool visible;
  final ValueChanged<bool> onChanged;

  const _PrefTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.visible,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: value ? AppColors.primary : AppColors.textMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: value ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryLight,
          ),
        ],
      ),
    );
  }
}
