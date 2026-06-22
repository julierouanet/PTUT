import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/auth_api_service.dart';
import '../services/config_service.dart';
import '../providers/locale_provider.dart';
import '../models/user_role.dart';
import '../widgets/notification_preferences_dialog.dart';
import '../widgets/role_request_dialog.dart';

/// Paramètres du compte utilisateur — accessible à tous via l'icône engrenage.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = _authService.currentUser;
    final isMobile = MediaQuery.of(context).size.width < AppBreakpoints.tablet;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.settingsAccountSection),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Carte utilisateur ──────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        (currentUser?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(currentUser?.fullName ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(currentUser?.roles.map((r) => r.displayName).join(', ') ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          if (currentUser?.department != null && currentUser!.department.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(currentUser.department, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildAlertBanners(l10n, currentUser),

            // ── Paramètres du compte ───────────────────────────────────────
            Text(l10n.settingsAccountSection, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  // Langue
                  ListenableBuilder(
                    listenable: LocaleProvider(),
                    builder: (context, _) => ListTile(
                      leading: const Icon(Icons.language, color: AppColors.primary),
                      title: Text(l10n.settingsLanguage, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(l10n.settingsLanguageSubtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      trailing: DropdownButton<String>(
                        value: LocaleProvider().locale.languageCode,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(value: 'fr', child: Text(l10n.settingsFrench)),
                          DropdownMenuItem(value: 'en', child: Text(l10n.settingsEnglish)),
                        ],
                        onChanged: (value) {
                          if (value != null) LocaleProvider().setLocale(Locale(value));
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  // Informations personnelles
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: AppColors.primary),
                    title: Text(l10n.settingsPersonalInfo, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(currentUser?.fullName ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () => _showPersonalInfoDialog(l10n),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  // Changer mot de passe
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: AppColors.primary),
                    title: Text(l10n.settingsChangePassword, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(l10n.settingsChangePasswordSubtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () => _showChangePasswordDialog(l10n),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  // Changement de département (direct ou par demande selon permission)
                  Builder(builder: (context) {
                    final canChangeDirect = currentUser?.hasPermission(Permission.changeDepartment) == true;
                    return ListTile(
                      leading: Icon(
                        canChangeDirect ? Icons.swap_horiz : Icons.swap_horiz,
                        color: canChangeDirect ? AppColors.primary : AppColors.warning,
                      ),
                      title: Text(
                        canChangeDirect ? 'Changer de département' : l10n.accountDepartmentChange,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        canChangeDirect
                            ? (currentUser?.department ?? '')
                            : currentUser?.department ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canChangeDirect)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Direct', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                        ],
                      ),
                      onTap: canChangeDirect
                          ? () => _showDirectDepartmentDialog()
                          : () => _showDepartmentRequestDialog(),
                    );
                  }),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  // Préférences de notifications email (supervisor, technician*, admin)
                  if (_hasNotificationPreferences(currentUser)) ...[
                    ListenableBuilder(
                      listenable: _authService,
                      builder: (context, _) {
                        final prefs = _authService.notificationPreferences;
                        // Liste des flags pertinents selon le rôle
                        final flags = prefs == null
                            ? const <bool>[]
                            : [
                                prefs.notifyCriticalNewIssue,
                                prefs.notifyCriticalAcknowledged,
                                prefs.notifyCriticalDiagnosed,
                                prefs.notifyCriticalResolved,
                                prefs.notifyPmDue,
                              ];
                        final allEnabled  = prefs == null || flags.every((v) => v);
                        final someEnabled = prefs != null && flags.any((v) => v);
                        return ListTile(
                          leading: Icon(
                            Icons.email_outlined,
                            color: someEnabled ? AppColors.primary : AppColors.textMuted,
                          ),
                          title: Text(
                            l10n.notifPrefsTitle,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            allEnabled
                                ? l10n.notifPrefsAllEnabled
                                : someEnabled
                                    ? l10n.notifPrefsSomeEnabled
                                    : l10n.notifPrefsAllDisabled,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          onTap: () => showNotificationPreferencesDialog(context),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                  // Demande de rôle supplémentaire
                  ListTile(
                    leading: const Icon(Icons.badge_outlined, color: AppColors.primary),
                    title: Text(l10n.roleRequestTitle,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      currentUser?.roles.map((r) => r.displayName).join(', ') ?? '',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () => _showRoleRequestDialog(l10n),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Déconnexion ────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(l10n),
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: Text(l10n.logout, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Éligibilité aux préférences email ─────────────────────────────────────

  /// Retourne true si l'utilisateur peut configurer des préférences email
  /// (supervisor, technician*, admin uniquement).
  bool _hasNotificationPreferences(dynamic user) {
    if (user == null) return false;
    const eligible = {
      UserRole.supervisor, UserRole.technician,
      UserRole.technicianBiomedical, UserRole.technicianIt,
      UserRole.technicianInfra, UserRole.admin,
    };
    final roles = (user.roles as List<UserRole>?) ?? const [];
    return roles.any(eligible.contains);
  }

  // ── Bannières d'alerte compte ──────────────────────────────────────────────

  Widget _buildAlertBanners(AppLocalizations l10n, dynamic user) {
    if (user == null) return const SizedBox.shrink();
    final banners = <Widget>[];

    if (user.isEmailVerified == false) {
      banners.add(_buildAlertBanner(
        icon: Icons.mark_email_unread_outlined,
        color: AppColors.error,
        bgColor: AppColors.errorLight,
        title: l10n.accountAlertEmailNotVerifiedTitle,
        subtitle: l10n.accountAlertEmailNotVerifiedSubtitle,
      ));
    }

    if (user.phone == null || (user.phone as String).isEmpty) {
      banners.add(_buildAlertBanner(
        icon: Icons.phone_missed_outlined,
        color: AppColors.warning,
        bgColor: AppColors.warningLight,
        title: l10n.accountAlertPhoneMissingTitle,
        subtitle: l10n.accountAlertPhoneMissingSubtitle,
      ));
    }

    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final banner in banners) ...[
          banner,
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildAlertBanner({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: AppColors.error),
            const SizedBox(width: 12),
            Text(l10n.logoutConfirmTitle),
          ],
        ),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _authService.logoutApi();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // ── Dialog : informations personnelles ─────────────────────────────────────

  void _showPersonalInfoDialog(AppLocalizations l10n) {
    final user = _authService.currentUser;
    final firstNameCtrl = TextEditingController(text: user?.firstName ?? '');
    final lastNameCtrl  = TextEditingController(text: user?.lastName ?? '');
    final emailCtrl     = TextEditingController(text: user?.email ?? '');
    final phoneCtrl     = TextEditingController(text: user?.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.settingsPersonalInfo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: firstNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Prénom',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: lastNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.commonEmail,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.settingsPhoneLabel,
                  hintText: l10n.settingsPhoneHint,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ok = await _authService.updateProfile(
                        firstName:  firstNameCtrl.text.trim(),
                        lastName:   lastNameCtrl.text.trim(),
                        email:      emailCtrl.text.trim(),
                        phone:      phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      );
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? l10n.settingsProfileUpdated : l10n.commonError),
                          backgroundColor: ok ? AppColors.success : AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
                    child: Text(l10n.commonSave),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialog : changement direct de département (si permission) ─────────────

  void _showDirectDepartmentDialog() {
    final user = _authService.currentUser;
    final departments = ConfigService().departmentNames;
    String selectedDept = (user?.department != null && departments.contains(user!.department))
        ? user.department
        : departments.first;
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Changer de département', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Votre département sera modifié immédiatement.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  const Icon(Icons.business, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  const Text('Actuel : ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  Text(user?.department ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedDept,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau département',
                    prefixIcon: Icon(Icons.swap_horiz),
                  ),
                  items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setDialogState(() => selectedDept = v!),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading ? null : () => Navigator.pop(ctx),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading || selectedDept == user?.department ? null : () async {
                        setDialogState(() => loading = true);
                        try {
                          await AuthApiService.instance.changeDepartmentDirect(selectedDept);
                          await _authService.refreshCurrentUser();
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Département mis à jour'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        } catch (e) {
                          setDialogState(() => loading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(AppLocalizations.of(context)!.commonApiError),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        }
                      },
                      child: loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Confirmer'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Dialog : demande de changement de département ─────────────────────────

  void _showDepartmentRequestDialog() {
    final l10n = AppLocalizations.of(context)!;
    final user = _authService.currentUser;
    final departments = ConfigService().departmentNames;
    String selectedDept = (user?.department != null && departments.contains(user!.department))
        ? user.department
        : departments.first;
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.accountDepartmentChangeTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.accountDepartmentChangeSubtitle,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  const Icon(Icons.business, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(l10n.accountDepartmentCurrent, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  Text(user?.department ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedDept,
                  decoration: InputDecoration(
                    labelText: l10n.accountDepartmentNew,
                    prefixIcon: const Icon(Icons.swap_horiz),
                  ),
                  items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setDialogState(() => selectedDept = v!),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading ? null : () => Navigator.pop(ctx),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading || selectedDept == user?.department ? null : () async {
                        setDialogState(() => loading = true);
                        try {
                          await AuthApiService.instance.requestDepartmentChange(selectedDept);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(l10n.accountDepartmentRequestSent),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        } catch (e) {
                          setDialogState(() => loading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(AppLocalizations.of(context)!.commonApiError),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        }
                      },
                      child: loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(l10n.accountDepartmentRequestSend),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Dialog : demande de rôle supplémentaire ───────────────────────────────

  void _showRoleRequestDialog(AppLocalizations l10n) {
    if (availableRequestableRoles().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.roleRequestAllRolesHeld),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    showRoleRequestDialog(context);
  }

  // ── Dialog : changer mot de passe ──────────────────────────────────────────

  void _showChangePasswordDialog(AppLocalizations l10n) {
    final newPassCtrl   = TextEditingController();
    final confirmCtrl   = TextEditingController();
    bool obscureNew     = true;
    bool obscureConfirm = true;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.settingsChangePassword, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: l10n.settingsNewPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: l10n.settingsConfirmPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final newPass = newPassCtrl.text;
                        final confirm = confirmCtrl.text;
                        if (newPass.length < 6) {
                          setDialogState(() => errorMsg = l10n.settingsPasswordMinLength);
                          return;
                        }
                        if (newPass != confirm) {
                          setDialogState(() => errorMsg = l10n.settingsPasswordMismatch);
                          return;
                        }
                        Navigator.pop(ctx);
                        final ok = await _authService.changePassword(newPass);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ok ? l10n.settingsPasswordChanged : l10n.commonError),
                            backgroundColor: ok ? AppColors.success : AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                      child: Text(l10n.commonSave),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
