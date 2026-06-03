// ── Modal de configuration des préférences email (1ère connexion ou Settings) ─

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/notification_preferences.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Affiche la modal de configuration des préférences email.
/// [isFirstSetup] = true → contexte 1ère connexion (fond rouge, pas de bouton Annuler).
Future<void> showNotificationPreferencesDialog(
  BuildContext context, {
  bool isFirstSetup = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !isFirstSetup,
    builder: (_) => _NotificationPreferencesDialog(isFirstSetup: isFirstSetup),
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
    _prefs =
        AuthService().notificationPreferences ?? NotificationPreferences.defaults;
  }

  // ── Helpers de rôle ─────────────────────────────────────────────────────────

  bool _hasRole(Set<UserRole> roles) {
    final user = AuthService().currentUser;
    return user?.roles.any(roles.contains) ?? false;
  }

  bool get _isTechnician => _hasRole({
        UserRole.technician,
        UserRole.technicianBiomedical,
        UserRole.technicianIt,
        UserRole.technicianInfra,
      });

  bool get _isSupervisorOrAdmin =>
      _hasRole({UserRole.supervisor, UserRole.admin});

  bool get _isAdmin => _hasRole({UserRole.admin});

  // ── Sauvegarde ──────────────────────────────────────────────────────────────

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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Bandeau d'en-tête ────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.notifPrefsTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.isFirstSetup
                              ? l10n.notifPrefsFirstSetupSubtitle
                              : l10n.notifPrefsScope,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isFirstSetup)
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                ],
              ),
            ),

            // ── Corps ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.notifPrefsSubtitle,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4),
                  ),
                  const SizedBox(height: 14),

                  // ── Groupe Techniciens ──────────────────────────────────
                  if (_isTechnician || _isAdmin) ...[
                    _SectionHeader(
                      icon: Icons.build_outlined,
                      label: l10n.notifPrefsSectionTechnician,
                    ),
                    _PrefTile(
                      icon: Icons.report_problem,
                      iconColor: AppColors.error,
                      title: l10n.notifPrefsCriticalNewIssue,
                      subtitle: l10n.notifPrefsCriticalNewIssueDesc,
                      value: _prefs.notifyCriticalNewIssue,
                      onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(notifyCriticalNewIssue: v)),
                    ),
                    _PrefTile(
                      icon: Icons.engineering_outlined,
                      iconColor: AppColors.warning,
                      title: l10n.notifPrefsPmDue,
                      subtitle: l10n.notifPrefsPmDueDesc,
                      value: _prefs.notifyPmDue,
                      onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(notifyPmDue: v)),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Groupe Superviseurs ─────────────────────────────────
                  if (_isSupervisorOrAdmin) ...[
                    _SectionHeader(
                      icon: Icons.supervisor_account_outlined,
                      label: l10n.notifPrefsSectionSupervisor,
                    ),
                    _PrefTile(
                      icon: Icons.handyman_outlined,
                      iconColor: AppColors.primary,
                      title: l10n.notifPrefsCriticalAcknowledged,
                      subtitle: l10n.notifPrefsCriticalAcknowledgedDesc,
                      value: _prefs.notifyCriticalAcknowledged,
                      onChanged: (v) => setState(() =>
                          _prefs = _prefs.copyWith(notifyCriticalAcknowledged: v)),
                    ),
                    _PrefTile(
                      icon: Icons.manage_search_outlined,
                      iconColor: AppColors.primary,
                      title: l10n.notifPrefsCriticalDiagnosed,
                      subtitle: l10n.notifPrefsCriticalDiagnosedDesc,
                      value: _prefs.notifyCriticalDiagnosed,
                      onChanged: (v) => setState(() =>
                          _prefs = _prefs.copyWith(notifyCriticalDiagnosed: v)),
                    ),
                    _PrefTile(
                      icon: Icons.verified_outlined,
                      iconColor: AppColors.success,
                      title: l10n.notifPrefsCriticalResolved,
                      subtitle: l10n.notifPrefsCriticalResolvedDesc,
                      value: _prefs.notifyCriticalResolved,
                      onChanged: (v) => setState(() =>
                          _prefs = _prefs.copyWith(notifyCriticalResolved: v)),
                    ),
                    if (!_isTechnician) ...[
                      const SizedBox(height: 4),
                      _PrefTile(
                        icon: Icons.engineering_outlined,
                        iconColor: AppColors.warning,
                        title: l10n.notifPrefsPmDue,
                        subtitle: l10n.notifPrefsPmDueDesc,
                        value: _prefs.notifyPmDue,
                        onChanged: (v) => setState(
                            () => _prefs = _prefs.copyWith(notifyPmDue: v)),
                      ),
                    ],
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),

            // ── Actions ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  if (widget.isFirstSetup) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () {
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
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(l10n.commonSave),
                    ),
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

// ── Widgets internes ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (value ? iconColor : AppColors.textMuted)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon,
                size: 16, color: value ? iconColor : AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color:
                        value ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.3),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: iconColor,
            activeTrackColor: iconColor.withValues(alpha: 0.2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
