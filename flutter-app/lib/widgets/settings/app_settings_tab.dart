import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_settings.dart';
import '../../services/app_settings_service.dart';
import '../../theme/app_theme.dart';

/// Onglet « Paramètres généraux » de SettingsScreen.
/// Deux sections : contact de connexion + configuration email Brevo.
class AppSettingsTab extends StatefulWidget {
  const AppSettingsTab({super.key});

  @override
  State<AppSettingsTab> createState() => _AppSettingsTabState();
}

class _AppSettingsTabState extends State<AppSettingsTab> {
  final _formKey    = GlobalKey<FormState>();
  final _service    = AppSettingsService();
  bool  _isSaving   = false;

  // Contrôleurs pour les champs du formulaire
  final _contactTitleCtrl   = TextEditingController();
  final _contactEmailCtrl   = TextEditingController();
  final _contactPhoneCtrl   = TextEditingController();
  final _brevoApiKeyCtrl    = TextEditingController();
  final _brevoSenderEmailCtrl = TextEditingController();
  final _brevoSenderNameCtrl  = TextEditingController();

  bool _populated = false;

  @override
  void dispose() {
    _contactTitleCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _brevoApiKeyCtrl.dispose();
    _brevoSenderEmailCtrl.dispose();
    _brevoSenderNameCtrl.dispose();
    super.dispose();
  }

  // Remplit les champs depuis le modèle chargé (une seule fois)
  void _populateFrom(AppSettings s) {
    if (_populated) return;
    _contactTitleCtrl.text    = s.loginContactTitle;
    _contactEmailCtrl.text    = s.loginContactEmail;
    _contactPhoneCtrl.text    = s.loginContactPhone;
    _brevoSenderEmailCtrl.text = s.brevoSenderEmail;
    _brevoSenderNameCtrl.text  = s.brevoSenderName;
    // La clé API n'est jamais pré-remplie (masquée côté serveur)
    _populated = true;
  }

  Future<void> _save(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final updates = <String, String>{
      'login_contact_title': _contactTitleCtrl.text.trim(),
      'login_contact_email': _contactEmailCtrl.text.trim(),
      'login_contact_phone': _contactPhoneCtrl.text.trim(),
      'brevo_api_key':       _brevoApiKeyCtrl.text,
      'brevo_sender_email':  _brevoSenderEmailCtrl.text.trim(),
      'brevo_sender_name':   _brevoSenderNameCtrl.text.trim(),
    };

    final ok = await _service.save(updates);
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? l10n.appSettingsSaveSuccess
          : l10n.appSettingsSaveError(_service.lastError ?? '')),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));

    if (ok) {
      // Vider le champ clé API après sauvegarde réussie
      _brevoApiKeyCtrl.clear();
    }
  }

  Future<void> _clearBrevoKey(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.appSettingsBrevoApiKeyClearLabel)),
        ]),
        content: Text(l10n.appSettingsBrevoClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning, foregroundColor: Colors.white),
            child: Text(l10n.appSettingsBrevoApiKeyClearLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final ok = await _service.save({'brevo_api_key': '__CLEAR__'});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? l10n.appSettingsSaveSuccess
          : l10n.appSettingsSaveError(_service.lastError ?? '')),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _showTestEmailDialog(AppLocalizations l10n) async {
    final emailCtrl = TextEditingController();
    final formKey   = GlobalKey<FormState>();
    bool  sending   = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.email_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(l10n.appSettingsTestEmailDialogTitle),
          ]),
          content: SizedBox(
            width: 360,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.appSettingsTestEmailDialogHint,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.appSettingsTestEmailDialogLabel,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.alternate_email),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return l10n.commonRequired;
                      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
                        return l10n.validationEmailInvalid;
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: sending
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => sending = true);
                      final toEmail   = emailCtrl.text.trim();
                      final messenger = ScaffoldMessenger.of(context);
                      final result    = await _service.sendTestEmail(toEmail);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      messenger.showSnackBar(SnackBar(
                        content: Text(result.sent
                            ? l10n.appSettingsTestEmailSuccess(toEmail)
                            : l10n.appSettingsTestEmailError(result.error ?? '')),
                        backgroundColor:
                            result.sent ? AppColors.success : AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ));
                    },
              icon: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_outlined, size: 18),
              label: Text(l10n.appSettingsTestEmailSend),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );

    emailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n    = AppLocalizations.of(context)!;
    final isWide  = MediaQuery.of(context).size.width >= AppBreakpoints.desktop;

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        if (_service.isLoading && _service.settings == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_service.settings != null) _populateFrom(_service.settings!);

        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24.0 : 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section Contact connexion ──────────────────────────────
                _SectionCard(
                  icon: Icons.contact_phone_outlined,
                  title: l10n.appSettingsContactSection,
                  child: _responsiveFields(isWide, [
                    _contactTitleField(l10n),
                    _contactEmailField(l10n),
                    _contactPhoneField(l10n),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Section Brevo ──────────────────────────────────────────
                _SectionCard(
                  icon: Icons.email_outlined,
                  title: l10n.appSettingsBrevoSection,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge état de la clé
                      _BrevoKeyBadge(
                        configured: _service.settings?.brevoKeyConfigured ?? false,
                        hint: _service.settings?.brevoKeyHint,
                      ),
                      const SizedBox(height: 12),
                      // Champ clé API (obscurci)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _brevoApiKeyCtrl,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: l10n.appSettingsBrevoApiKey,
                                hintText: _service.settings?.brevoKeyConfigured == true
                                    ? l10n.appSettingsBrevoApiKeyHint(
                                        _service.settings!.brevoKeyHint ?? '????')
                                    : l10n.appSettingsBrevoApiKeyHintNone,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                prefixIcon: const Icon(Icons.key_outlined),
                              ),
                            ),
                          ),
                          // Bouton effacer clé (si configurée)
                          if (_service.settings?.brevoKeyConfigured == true) ...[
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: OutlinedButton.icon(
                                onPressed: () => _clearBrevoKey(l10n),
                                icon: const Icon(Icons.delete_outline, size: 16),
                                label: Text(l10n.appSettingsBrevoApiKeyClearLabel),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Expéditeur email + nom
                      _responsiveFields(isWide, [
                        _brevoSenderEmailField(l10n),
                        _brevoSenderNameField(l10n),
                      ]),
                      const SizedBox(height: 16),
                      // Bouton email de test
                      OutlinedButton.icon(
                        onPressed: () => _showTestEmailDialog(l10n),
                        icon: const Icon(Icons.send_outlined, size: 18),
                        label: Text(l10n.appSettingsTestEmailBtn),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Bouton Enregistrer ─────────────────────────────────────
                SizedBox(
                  width: isWide ? 200 : double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _save(l10n),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(l10n.appSettingsSave),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Champs ────────────────────────────────────────────────────────────────

  Widget _contactTitleField(AppLocalizations l10n) => TextFormField(
        controller: _contactTitleCtrl,
        decoration: InputDecoration(
          labelText: l10n.appSettingsContactTitle,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.label_outline),
        ),
      );

  Widget _contactEmailField(AppLocalizations l10n) => TextFormField(
        controller: _contactEmailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: l10n.appSettingsContactEmail,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.alternate_email),
        ),
      );

  Widget _contactPhoneField(AppLocalizations l10n) => TextFormField(
        controller: _contactPhoneCtrl,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: l10n.appSettingsContactPhone,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.phone_outlined),
        ),
      );

  Widget _brevoSenderEmailField(AppLocalizations l10n) => TextFormField(
        controller: _brevoSenderEmailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: l10n.appSettingsBrevoSenderEmail,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.alternate_email),
        ),
      );

  Widget _brevoSenderNameField(AppLocalizations l10n) => TextFormField(
        controller: _brevoSenderNameCtrl,
        decoration: InputDecoration(
          labelText: l10n.appSettingsBrevoSenderName,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.person_outline),
        ),
      );
}

// ── Helper responsive ─────────────────────────────────────────────────────────

/// Affiche [fields] en Row (desktop ≥ 800px) ou Column (mobile).
Widget _responsiveFields(bool isWide, List<Widget> fields) {
  if (isWide) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: fields[i]),
        ],
      ],
    );
  }
  return Column(
    children: [
      for (int i = 0; i < fields.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        fields[i],
      ],
    ],
  );
}

// ── Widget carte de section ───────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String   title;
  final Widget   child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Badge état clé Brevo ──────────────────────────────────────────────────────

class _BrevoKeyBadge extends StatelessWidget {
  final bool    configured;
  final String? hint;

  const _BrevoKeyBadge({
    required this.configured,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: configured
            ? AppColors.successLight
            : AppColors.errorLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            configured ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            size: 16,
            color: configured ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Text(
            configured
                ? '${l10n.appSettingsBrevoConfigured}${hint != null ? ' (●●●● $hint)' : ''}'
                : l10n.appSettingsBrevoNotConfigured,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: configured ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
