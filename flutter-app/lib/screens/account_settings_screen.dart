import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../providers/locale_provider.dart';

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
    final isMobile = MediaQuery.of(context).size.width < 600;

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
                          Text(currentUser?.role.displayName ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
    if (confirmed == true && mounted) await _authService.logoutApi();
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
