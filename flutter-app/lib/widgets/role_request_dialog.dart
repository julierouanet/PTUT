// ── Dialog : demande de rôle supplémentaire ──────────────────────────────────

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/user_role.dart';
import '../services/auth_api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

const _kKeepCurrentRoleValue = '__keep_current__';

const _kRequestableRoles = [
  UserRole.supervisor,
  UserRole.technicianBiomedical,
  UserRole.technicianIt,
  UserRole.technicianInfra,
];

/// Rôles que l'utilisateur connecté peut encore demander (ceux qu'il ne
/// possède pas déjà). Source unique de vérité — réutilisée par l'appelant
/// pour décider s'il faut afficher la dialog ou un message "déjà tous obtenus".
List<UserRole> availableRequestableRoles() {
  final existingRoles = AuthService().currentUser?.roles ?? const [];
  return _kRequestableRoles.where((r) => !existingRoles.contains(r)).toList();
}

/// Affiche la dialog de demande de rôle.
/// [isFirstSetup] = true → contexte post-création de compte : pas de bouton
/// Annuler/X, et une option "Garder mon rôle actuel" qui ferme la dialog sans
/// appel réseau.
Future<void> showRoleRequestDialog(BuildContext context, {bool isFirstSetup = false}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !isFirstSetup,
    builder: (_) => _RoleRequestDialog(isFirstSetup: isFirstSetup),
  );
}

class _RoleRequestDialog extends StatefulWidget {
  final bool isFirstSetup;
  const _RoleRequestDialog({required this.isFirstSetup});

  @override
  State<_RoleRequestDialog> createState() => _RoleRequestDialogState();
}

class _RoleRequestDialogState extends State<_RoleRequestDialog> {
  late final List<UserRole> _available;
  String? _selectedRole;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _available = availableRequestableRoles();
    _selectedRole = widget.isFirstSetup
        ? _kKeepCurrentRoleValue
        : (_available.isNotEmpty ? _available.first.apiName : null);
  }

  Future<void> _submit() async {
    if (_selectedRole == _kKeepCurrentRoleValue) {
      Navigator.pop(context);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    try {
      await AuthApiService.instance.requestRole(_selectedRole!);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.roleRequestSuccess),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      if (widget.isFirstSetup)
        DropdownMenuItem(value: _kKeepCurrentRoleValue, child: Text(l10n.roleRequestKeepCurrent)),
      ..._available.map((r) => DropdownMenuItem(value: r.apiName, child: Text(r.localizedName(l10n)))),
    ];

    return Dialog(
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
                Expanded(
                  child: Text(l10n.roleRequestTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (!widget.isFirstSetup)
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.roleRequestDescription,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                labelText: l10n.roleRequestLabel,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              items: items,
              onChanged: (v) => setState(() => _selectedRole = v),
            ),
            const SizedBox(height: 24),
            Row(children: [
              if (!widget.isFirstSetup) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading || _selectedRole == null ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(l10n.roleRequestSubmit),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
