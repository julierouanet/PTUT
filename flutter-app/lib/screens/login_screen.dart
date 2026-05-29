import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/auth_api_service.dart';
import '../services/api_config.dart';
import '../services/config_service.dart';
import '../services/data_service.dart';
import '../services/notification_service.dart';
import '../providers/locale_provider.dart';
import '../models/user.dart';
import '../data/mock_data.dart';

enum _AuthMode { login, signup, forgotPassword }

// Comptes récemment utilisés — placeholder statique (future: SharedPreferences)
class _RecentAccount {
  final String name;
  final String role;
  final IconData icon;
  const _RecentAccount(this.name, this.role, this.icon);
}

const _kRecentAccounts = [
  _RecentAccount('Dr. Kamana J.', 'Médecin', Icons.medical_services_outlined),
  _RecentAccount('Tech. Mugisha', 'Technicien', Icons.build_outlined),
  _RecentAccount('Inf. Uwase A.', 'Infirmière', Icons.local_hospital_outlined),
];

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

  // Contrôleurs spécifiques à l'inscription
  final _firstNameCtrl       = TextEditingController();
  final _lastNameCtrl        = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();
  final _phoneCtrl           = TextEditingController();

  _AuthMode _mode             = _AuthMode.login;
  bool      _obscure          = true;
  bool      _obscureConfirm   = true;
  bool      _loading          = false;
  String?   _error;
  bool      _signupSuccess    = false;
  String?   _selectedDepartment;

  // ── Santé des services ─────────────────────────────────────────────────────
  final Map<String, String?> _health = {
    'auth': null, 'db': null, 'iam': null, 'mail': null,
  };
  DateTime? _lastCheckTime;

  bool get _hasCriticalAlert =>
      _health['auth'] == 'ko' || _health['iam'] == 'ko';

  bool get _hasAnyAlert =>
      _health.values.any((v) => v == 'ko');

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
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode               = mode;
      _error              = null;
      _signupSuccess      = false;
      _selectedDepartment = null;
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

  // ── Inscription ────────────────────────────────────────────────────────────

  Future<void> _submitRegister() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _passwordConfirmCtrl.text) {
      setState(() => _error = l10n.registerPasswordMismatch);
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      await AuthApiService.instance.register(
        firstName:  _firstNameCtrl.text.trim(),
        lastName:   _lastNameCtrl.text.trim(),
        email:      _emailCtrl.text.trim(),
        password:   _passwordCtrl.text,
        department: _selectedDepartment ?? '',
        phone:      _phoneCtrl.text.trim(),
      );
      setState(() { _loading = false; _signupSuccess = true; });
    } catch (e) {
      setState(() {
        _loading = false;
        _error   = e.toString().replaceFirst('Exception: ', '');
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
      // Le backend répond toujours 200 — on traite systématiquement comme succès côté client
    }
    setState(() { _loading = false; _signupSuccess = true; });
  }

  // ── Construction UI principale ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Bannière d'alerte critique — n'apparaît que si un service essentiel est KO
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _hasCriticalAlert
                ? _buildAlertBanner(l10n)
                : const SizedBox.shrink(key: ValueKey('no-banner')),
          ),

          // Contenu principal
          Expanded(
            child: Stack(
              children: [
                // Formulaire centré avec scroll
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 72, 24, 48),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo hôpital
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                              boxShadow: [BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.18),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              )],
                            ),
                            child: Image.asset(
                              'assets/images/logo_hopital.png',
                              height: 88, width: 88, fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 24),

                          Text(l10n.hospitalName,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text(l10n.hospitalSubtitleLong,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          const SizedBox(height: 40),

                          // Carte principale avec transition fluide entre les modes
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: _mode == _AuthMode.login
                                    ? _buildLoginForm(l10n)
                                    : _mode == _AuthMode.signup
                                        ? _buildSignupForm(l10n)
                                        : _buildForgotPasswordForm(l10n),
                              ),
                            ),
                          ),

                          // Comptes récemment utilisés — visible uniquement en mode connexion
                          if (_mode == _AuthMode.login) ...[
                            const SizedBox(height: 20),
                            _buildRecentAccounts(l10n),
                          ],

                          // Raccourcis DEV — jamais inclus dans un build Release
                          if (kDebugMode && _mode == _AuthMode.login) ...[
                            const SizedBox(height: 16),
                            _buildDevShortcuts(),
                          ],
                        ],
                      ),
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

                // Footer statut système temps réel
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: _buildSystemStatusFooter(l10n),
                ),
              ],
            ),
          ),
        ],
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

  // ── Footer statut système discret ─────────────────────────────────────────

  Widget _buildSystemStatusFooter(AppLocalizations l10n) {
    final isChecking = _health['auth'] == null;
    final isOk       = !_hasAnyAlert && !isChecking;
    final color      = isChecking
        ? Colors.grey
        : (isOk ? AppColors.success : AppColors.error);
    final icon       = isChecking
        ? Icons.sync
        : (isOk ? Icons.check_circle_outline : Icons.error_outline);

    final statusLabel = isChecking
        ? l10n.systemStatusChecking
        : (isOk ? l10n.systemStatusOperational : l10n.systemStatusDegraded);

    String suffix = '';
    if (_lastCheckTime != null) {
      final h = _lastCheckTime!.hour.toString().padLeft(2, '0');
      final m = _lastCheckTime!.minute.toString().padLeft(2, '0');
      suffix = '  •  ${l10n.systemStatusLastCheck('$h:$m')}';
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color.withValues(alpha: 0.65)),
          const SizedBox(width: 4),
          Text(
            '$statusLabel$suffix',
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }

  // ── Section comptes récemment utilisés (placeholder statique) ─────────────

  Widget _buildRecentAccounts(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            l10n.loginRecentSessionsTitle,
            style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _kRecentAccounts.map((a) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  // Placeholder : dans une future version, pré-remplit l'email
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Icon(a.icon, size: 14, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(a.name,
                              style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                              )),
                          Text(a.role,
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )).toList(),
          ),
        ),
      ],
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
                    isFr ? 'EN' : 'FR',
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

          // ── Bouton "Mot de passe oublié ?" — fortement mis en évidence ───────
          // Taille, icône et couleur distinctes pour être visible d'un médecin pressé
          _buildForgotPasswordButton(l10n),

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

          Center(
            child: TextButton(
              onPressed: () => _switchMode(_AuthMode.signup),
              child: Text(l10n.registerNoAccount,
                  style: const TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton "Mot de passe oublié ?" proéminent — accessible en urgence médicale.
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
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Formulaire d'inscription ───────────────────────────────────────────────

  Widget _buildSignupForm(AppLocalizations l10n) {
    if (_signupSuccess) {
      return Column(
        key: const ValueKey('signup_success'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 64, color: AppColors.success),
          const SizedBox(height: 16),
          Text(l10n.registerSuccess,
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

    final departments = ConfigService().departmentNames;

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('signup'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête avec lien de retour explicite
          _buildBackToLoginLink(l10n),
          const SizedBox(height: 12),

          Text(l10n.registerTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),

          // Prénom + Nom côte à côte
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.registerFirstName,
                  prefixIcon: const Icon(Icons.person_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? '${l10n.registerFirstName} requis'
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lastNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.registerLastName),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? '${l10n.registerLastName} requis'
                    : null,
              ),
            ),
          ]),
          const SizedBox(height: 12),

          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n.loginEmail,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (v) => (v == null || v.isEmpty) ? l10n.loginEmailRequired : null,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: l10n.loginPassword,
              prefixIcon: const Icon(Icons.lock_outlined),
              helperText: l10n.registerPasswordMinLength,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.loginPasswordRequired;
              if (v.length < 8) return l10n.registerPasswordMinLength;
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _passwordConfirmCtrl,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: l10n.registerPasswordConfirm,
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.loginPasswordRequired;
              if (v != _passwordCtrl.text) return l10n.registerPasswordMismatch;
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Département obligatoire — le rôle est attribué par un admin après inscription
          DropdownButtonFormField<String>(
            value: _selectedDepartment,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.registerDepartment,
              prefixIcon: const Icon(Icons.apartment_outlined),
            ),
            hint: Text(
              'Sélectionner un département',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            items: departments
                .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _selectedDepartment = v),
            validator: (_) => _selectedDepartment == null
                ? '${l10n.registerDepartment} requis'
                : null,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.registerPhone,
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),

          _buildErrorBox(),
          const SizedBox(height: 16),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _submitRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(l10n.registerSubmit, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  // ── Formulaire de réinitialisation du mot de passe ─────────────────────────

  Widget _buildForgotPasswordForm(AppLocalizations l10n) {
    if (_signupSuccess) {
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
          // En-tête avec lien de retour explicite
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

  /// Lien "← Retour à la connexion" placé en en-tête des sous-écrans.
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

  // Bloc DEV — compilé uniquement en mode debug (kDebugMode est une constante de compilation)
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
