import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/auth_api_service.dart';
import '../services/api_config.dart';
import '../services/data_service.dart';
import '../services/notification_service.dart';
import '../providers/locale_provider.dart';
import '../models/user.dart';
import '../data/mock_data.dart';

// signup supprimé — accès uniquement via demande validée par un admin
enum _AuthMode { login, forgotPassword }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Bouton compact coloré pour la connexion rapide DEV.
class _DevLoginButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _DevLoginButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginScreenState extends State<LoginScreen> {
  // Contrôleurs communs
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  _AuthMode _mode          = _AuthMode.login;
  bool      _obscure       = true;
  bool      _loading       = false;
  String?   _error;
  bool      _requestSuccess = false;

  // ── Santé des services ─────────────────────────────────────────────────────
  final Map<String, String?> _health = {
    'auth': null, 'db': null, 'iam': null, 'mail': null,
  };
  DateTime? _lastCheckTime;

  bool get _hasCriticalAlert =>
      _health['auth'] == 'ko' || _health['iam'] == 'ko';

  @override
  void initState() {
    super.initState();
    final sessionMsg = AuthService().sessionExpiredMessage;
    if (sessionMsg != null) {
      _error = sessionMsg;
      AuthService().clearSessionExpiredMessage();
    }
    _fetchHealth();
  }

  Future<void> _fetchHealth() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse(ApiConfig.healthAuthUrl)).timeout(const Duration(seconds: 5)),
        http.get(Uri.parse(ApiConfig.healthDbUrl)).timeout(const Duration(seconds: 5)),
      ]);
      if (!mounted) return;

      final authBody = jsonDecode(responses[0].body) as Map<String, dynamic>;
      final dbBody   = jsonDecode(responses[1].body) as Map<String, dynamic>;
      final checks   = authBody['checks'] as Map<String, dynamic>? ?? {};

      setState(() {
        _health['auth'] = authBody['status'] as String? ?? 'ko';
        _health['db']   = dbBody['status']   as String? ?? 'ko';
        _health['iam']  = checks['keycloak'] as String? ?? 'ko';
        _health['mail'] = checks['brevo']    as String?;
        _lastCheckTime  = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _health['auth'] = 'ko';
        _health['db']   = 'ko';
        _health['iam']  = 'ko';
        _health['mail'] = 'ko';
        _lastCheckTime  = DateTime.now();
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode           = mode;
      _error          = null;
      _requestSuccess = false;
    });
  }

  // ── Connexion ──────────────────────────────────────────────────────────────

  Future<void> _quickLogin(User user) async {
    setState(() { _loading = true; _error = null; });
    AuthService().switchUser(user);
    await DataService().loadAll();
    NotificationService().generateFromLoadedData();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final ok = await AuthService().loginWithApi(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;

    if (ok) {
      await DataService().loadAll();
    } else {
      setState(() {
        _loading = false;
        _error   = AuthService().lastError ??
            AppLocalizations.of(context)!.loginInvalidCredentials;
      });
    }
  }

  // ── Mot de passe oublié ────────────────────────────────────────────────────

  Future<void> _submitForgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AuthApiService.instance.forgotPassword(_emailCtrl.text.trim());
    } catch (_) {
      // Le backend répond toujours 200 — succès systématique côté client
    }
    setState(() { _loading = false; _requestSuccess = true; });
  }

  // ── Dialogue / bottom-sheet : Demande d'accès ─────────────────────────────

  void _showAccessRequestSheet(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _AccessRequestContent(onSuccess: _onAccessRequestSuccess),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: _AccessRequestContent(onSuccess: _onAccessRequestSuccess),
        ),
      );
    }
  }

  // Appelé par _AccessRequestContent après création réussie du compte
  void _onAccessRequestSuccess(String email, String password) {
    if (!mounted) return;
    _emailCtrl.text    = email;
    _passwordCtrl.text = password;
    _switchMode(_AuthMode.login);
    _submitLogin();
  }

  // ── Construction UI principale ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Bannière d'alerte critique — visible en haut quelle que soit la taille d'écran
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _hasCriticalAlert
                ? _buildAlertBanner(l10n)
                : const SizedBox.shrink(key: ValueKey('no-banner')),
          ),

          // Mise en page responsive : bureau ≥ 800px / mobile < 800px
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 800;
                return isDesktop
                    ? _buildDesktopLayout(l10n, constraints)
                    : _buildMobileLayout(l10n, constraints);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Mise en page bureau (≥ 800px) ─────────────────────────────────────────

  Widget _buildDesktopLayout(AppLocalizations l10n, BoxConstraints constraints) {
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Panneau gauche : identité visuelle de l'hôpital
            Expanded(
              flex: 2,
              child: _buildDesktopLeftPanel(l10n),
            ),

            // Panneau droit : formulaire d'authentification
            Expanded(
              flex: 3,
              child: _buildDesktopRightPanel(l10n, constraints),
            ),
          ],
        ),

        // Bouton langue — coin supérieur droit
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _buildLanguageToggle(),
            ),
          ),
        ),

        // Indicateur de santé des services — coin inférieur droit
        Positioned(
          bottom: 14,
          right: 16,
          child: _buildHealthDot(l10n),
        ),
      ],
    );
  }

  /// Panneau gauche desktop : logo + nom de l'hôpital centré verticalement.
  Widget _buildDesktopLeftPanel(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.07),
            AppColors.primary.withValues(alpha: 0.02),
          ],
        ),
        border: Border(
          right: BorderSide(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLogoContainer(size: 96, cornerRadius: 24),
              const SizedBox(height: 28),
              Text(
                l10n.hospitalName,
                style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.hospitalSubtitleLong,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
                ),
                child: Text(
                  'GMAO',
                  style: TextStyle(
                    fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Panneau droit desktop : formulaire centré verticalement, scroll uniquement si débordement.
  Widget _buildDesktopRightPanel(AppLocalizations l10n, BoxConstraints outerConstraints) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _buildCurrentForm(l10n),
                          ),
                        ),
                      ),

                      // Raccourcis DEV — compilés uniquement en mode debug (absents en release)
                      if (kDebugMode && _mode == _AuthMode.login) ...[
                        const SizedBox(height: 20),
                        _buildDevShortcuts(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Mise en page mobile (< 800px) ─────────────────────────────────────────

  Widget _buildMobileLayout(AppLocalizations l10n, BoxConstraints constraints) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 72, 24, 48),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 120),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                _buildLogoContainer(size: 88, cornerRadius: 20),
                const SizedBox(height: 24),

                Text(
                  l10n.hospitalName,
                  style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  l10n.hospitalSubtitleLong,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 40),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _buildCurrentForm(l10n),
                    ),
                  ),
                ),

                // Raccourcis DEV — compilés uniquement en mode debug (absents en release)
                if (kDebugMode && _mode == _AuthMode.login) ...[
                  const SizedBox(height: 16),
                  _buildDevShortcuts(),
                ],
              ],
            ),
          ),
        ),

        // Bouton langue — coin supérieur droit
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildLanguageToggle(),
            ),
          ),
        ),

        // Indicateur de santé des services — coin inférieur droit
        Positioned(
          bottom: 12,
          right: 12,
          child: _buildHealthDot(l10n),
        ),
      ],
    );
  }

  // ── Widgets partagés ──────────────────────────────────────────────────────

  /// Formulaire actif (connexion / réinitialisation mot de passe).
  Widget _buildCurrentForm(AppLocalizations l10n) {
    return _mode == _AuthMode.login
        ? _buildLoginForm(l10n)
        : _buildForgotPasswordForm(l10n);
  }

  /// Conteneur du logo avec ombre et bord primaire.
  Widget _buildLogoContainer({required double size, required double cornerRadius}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/logo_hopital.png',
        height: size, width: size, fit: BoxFit.contain,
      ),
    );
  }

  // ── Bannière d'alerte service critique ────────────────────────────────────

  Widget _buildAlertBanner(AppLocalizations l10n) {
    final message = (_health['auth'] == 'ko' || _health['iam'] == 'ko')
        ? l10n.systemAlertBannerAuth
        : l10n.systemAlertBannerGeneral;

    return SafeArea(
      bottom: false,
      key: const ValueKey('banner'),
      child: Material(
        color: AppColors.error,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                onPressed: _fetchHealth,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Réessayer',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Indicateur de santé discret — point coloré avec tooltip ───────────────

  Widget _buildHealthDot(AppLocalizations l10n) {
    final isChecking = _health['auth'] == null;
    final hasCritical = _health['auth'] == 'ko' || _health['iam'] == 'ko';
    final hasDegraded = _health.values.any((v) => v == 'ko');

    final Color dotColor;
    if (isChecking) {
      dotColor = Colors.grey.shade400;
    } else if (hasCritical) {
      dotColor = AppColors.error;
    } else if (hasDegraded) {
      dotColor = AppColors.warning;
    } else {
      dotColor = AppColors.success;
    }

    // Construire le message multi-ligne du tooltip
    final buffer = StringBuffer(l10n.healthTooltipTitle);
    if (isChecking) {
      buffer.write('\n${l10n.healthTooltipNoCheck}');
    } else {
      final services = <String, String?>{
        l10n.healthAuth: _health['auth'],
        l10n.healthDb:   _health['db'],
        l10n.healthIam:  _health['iam'],
      };
      for (final entry in services.entries) {
        final bullet = entry.value == 'ok' ? '●' : '○';
        final status = entry.value == 'ok'
            ? l10n.healthStatusOk
            : entry.value == 'ko'
                ? l10n.healthStatusKo
                : '…';
        buffer.write('\n$bullet ${entry.key} : $status');
      }
      if (_lastCheckTime != null) {
        final h = _lastCheckTime!.hour.toString().padLeft(2, '0');
        final m = _lastCheckTime!.minute.toString().padLeft(2, '0');
        buffer.write('\n${l10n.healthTooltipLastCheck('$h:$m')}');
      }
    }

    return Tooltip(
      message: buffer.toString(),
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: _fetchHealth,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dotColor.withValues(alpha: 0.45),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bouton de changement de langue ────────────────────────────────────────

  Widget _buildLanguageToggle() {
    return ListenableBuilder(
      listenable: LocaleProvider(),
      builder: (context, _) {
        final isFr = LocaleProvider().locale.languageCode == 'fr';
        return Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => LocaleProvider().setLocale(Locale(isFr ? 'en' : 'fr')),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isFr ? '🇫🇷' : '🇬🇧', style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    isFr ? 'FR' : 'EN',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.primary, letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Formulaire de connexion ────────────────────────────────────────────────

  Widget _buildLoginForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('login'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.loginTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),

          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: l10n.loginEmail,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (v) => (v == null || v.isEmpty) ? l10n.loginEmailRequired : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: l10n.loginPassword,
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? l10n.loginPasswordRequired : null,
            onFieldSubmitted: (_) => _submitLogin(),
          ),
          const SizedBox(height: 6),

          // Bouton "Mot de passe oublié ?" — proéminent pour le personnel médical pressé
          _buildForgotPasswordButton(l10n),

          // Contact urgence — aide le personnel de nuit en cas de compte bloqué
          _buildEmergencyContact(l10n),

          _buildErrorBox(),
          const SizedBox(height: 8),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _submitLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(l10n.loginSubmit, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),

          // Lien "Demande d'accès" — remplace le signup auto-déclaratif
          Center(
            child: TextButton(
              onPressed: () => _showAccessRequestSheet(context),
              child: Text(
                l10n.accessRequestLink,
                style: const TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton "Mot de passe oublié ?" mis en avant — icône + texte gras orange.
  Widget _buildForgotPasswordButton(AppLocalizations l10n) {
    return InkWell(
      onTap: () => _switchMode(_AuthMode.forgotPassword),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_reset, size: 18, color: AppColors.warning),
            const SizedBox(width: 6),
            Text(
              l10n.forgotPasswordLink,
              style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: AppColors.warning, letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bandeau de contact d'urgence — visible sous "Mot de passe oublié ?" pour le personnel de nuit.
  Widget _buildEmergencyContact(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.support_agent, size: 15, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.emergencyContactTitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    l10n.emergencyContactInfo,
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Formulaire de réinitialisation du mot de passe ─────────────────────────

  Widget _buildForgotPasswordForm(AppLocalizations l10n) {
    if (_requestSuccess) {
      return Column(
        key: const ValueKey('forgot_success'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 64, color: AppColors.success),
          const SizedBox(height: 16),
          Text(l10n.forgotPasswordSuccess,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.5)),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => _switchMode(_AuthMode.login),
            child: Text(l10n.registerHaveAccount, style: const TextStyle(color: AppColors.primary)),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('forgot'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBackToLoginLink(l10n),
          const SizedBox(height: 12),

          const Icon(Icons.lock_reset, size: 48, color: AppColors.primary),
          const SizedBox(height: 8),

          Text(l10n.forgotPasswordTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            l10n.forgotPasswordHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: l10n.loginEmail,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (v) => (v == null || v.isEmpty) ? l10n.loginEmailRequired : null,
            onFieldSubmitted: (_) => _submitForgotPassword(),
          ),

          _buildErrorBox(),
          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _submitForgotPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(l10n.forgotPasswordSubmit, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),

          Center(
            child: TextButton(
              onPressed: () => _switchMode(_AuthMode.login),
              child: Text(l10n.registerHaveAccount,
                  style: const TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets utilitaires ────────────────────────────────────────────────────

  /// Lien "← Retour à la connexion" placé en en-tête des sous-formulaires.
  Widget _buildBackToLoginLink(AppLocalizations l10n) {
    return InkWell(
      onTap: () => _switchMode(_AuthMode.login),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_ios_new, size: 13, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              l10n.loginBackToLogin,
              style: const TextStyle(
                fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBox() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ]),
      ),
    );
  }

  // Bloc DEV — compilé uniquement en kDebugMode (constante de compilation = false en release)
  Widget _buildDevShortcuts() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.shade50,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.developer_mode, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 6),
            Text(
              'DEV — Connexion rapide',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: Colors.orange.shade800, letterSpacing: 0.5,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3.2,
            children: [
              _DevLoginButton(
                label: 'Admin', icon: Icons.admin_panel_settings, color: AppColors.error,
                onTap: _loading ? null : () => _quickLogin(mockUsers[0]),
              ),
              _DevLoginButton(
                label: 'Superviseur', icon: Icons.supervisor_account, color: AppColors.primary,
                onTap: _loading ? null : () => _quickLogin(mockUsers[1]),
              ),
              _DevLoginButton(
                label: 'Technicien', icon: Icons.build, color: AppColors.warning,
                onTap: _loading ? null : () => _quickLogin(mockUsers[3]),
              ),
              _DevLoginButton(
                label: 'Hospitalier', icon: Icons.local_hospital, color: AppColors.success,
                onTap: _loading ? null : () => _quickLogin(mockUsers[5]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Widget Demande d'accès ────────────────────────────────────────────────────
// Contenu partagé entre la dialog desktop et le bottom-sheet mobile.

class _AccessRequestContent extends StatefulWidget {
  final void Function(String email, String password) onSuccess;

  const _AccessRequestContent({required this.onSuccess});

  @override
  State<_AccessRequestContent> createState() => _AccessRequestContentState();
}

class _AccessRequestContentState extends State<_AccessRequestContent> {
  final _formKey      = GlobalKey<FormState>();
  final _firstCtrl    = TextEditingController();
  final _lastCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  String? _selectedDept;
  bool    _obscurePassword = true;
  bool    _obscureConfirm  = true;

  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n  = AppLocalizations.of(context)!;
    final email = _emailCtrl.text.trim();
    final pwd   = _passwordCtrl.text;
    setState(() { _loading = true; _error = null; });
    try {
      await AuthApiService.instance.accessRequest(
        firstName:  _firstCtrl.text.trim(),
        lastName:   _lastCtrl.text.trim(),
        email:      email,
        password:   pwd,
        department: _selectedDept,
      );
      // Fermer le dialog/sheet et lancer l'auto-login dans le parent
      if (mounted) Navigator.of(context).pop();
      widget.onSuccess(email, pwd);
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _loading = false;
        _error   = msg.contains('déjà associé') || msg.contains('already associated')
            ? l10n.accessRequestAccountExists
            : l10n.accessRequestError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildForm(l10n),
    );
  }

  List<DropdownMenuItem<String>> _buildDeptItems(AppLocalizations l10n) {
    final depts = [
      l10n.deptAdministration,
      l10n.deptOpd,
      l10n.deptInternalMedicine,
      l10n.deptPediatrics,
      l10n.deptEmergency,
      l10n.deptLaboratory,
      l10n.deptStomatology,
      l10n.deptPhysiotherapy,
      l10n.deptNeonatology,
      l10n.deptMaternity,
      l10n.deptSurgery,
      l10n.deptOperatingTheater,
      l10n.deptOphthalmology,
      l10n.deptTbMr,
      l10n.deptGbv,
      l10n.deptMentalHealth,
      l10n.deptArv,
      l10n.deptPharmacy,
      l10n.accessRequestOtherOption,
    ];
    return depts
        .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
        .toList();
  }

  Widget _buildForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.accessRequestTitle,
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: _loading ? null : () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.accessRequestSubtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Prénom + Nom côte à côte
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _firstCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.accessRequestFirstName,
                  prefixIcon: const Icon(Icons.person_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.loginEmailRequired.replaceAll('Email', l10n.commonName) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lastCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.accessRequestLastName),
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.commonFillRequiredFields : null,
              ),
            ),
          ]),
          const SizedBox(height: 12),

          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n.accessRequestEmail,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.loginEmailRequired;
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) {
                return l10n.loginEmailRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: _selectedDept,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.accessRequestDepartment,
              prefixIcon: const Icon(Icons.apartment_outlined),
            ),
            items: _buildDeptItems(l10n),
            onChanged: (v) => setState(() => _selectedDept = v),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: l10n.accessRequestPassword,
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.loginPasswordRequired;
              if (v.length < 8) return l10n.accessRequestPasswordTooShort;
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: l10n.accessRequestPasswordConfirm,
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.loginPasswordRequired;
              if (v != _passwordCtrl.text) return l10n.accessRequestPasswordMismatch;
              return null;
            },
          ),

          // Boîte d'erreur
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(l10n.accessRequestSubmit, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
