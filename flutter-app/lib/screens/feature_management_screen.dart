import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/feature_flag.dart';
import '../models/user_role.dart';
import '../services/feature_service.dart';
import '../theme/app_theme.dart';

class FeatureManagementScreen extends StatelessWidget {
  const FeatureManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n    = AppLocalizations.of(context)!;
    final service = FeatureService();

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (service.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.featureMgmtLoading,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        if (service.features.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.toggle_off_outlined,
                    size: 80, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text(l10n.featureMgmtNoFeatures,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête ────────────────────────────────────────────────────
              Text(
                l10n.featureMgmtTitle,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.featureMgmtSubtitle,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              // ── Liste des features ────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  itemCount: service.features.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final feature = service.features[i];
                    return _FeatureFlagCard(
                      feature: feature,
                      onToggleGlobal: (newValue) =>
                          _toggleGlobal(context, l10n, service, feature, newValue),
                      onManageRoles: () =>
                          _showRoleOverridesDialog(context, l10n, service, feature),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _toggleGlobal(
    BuildContext context,
    AppLocalizations l10n,
    FeatureService service,
    FeatureFlag feature,
    bool newValue,
  ) async {
    final ok = await service.updateFeature(
      feature.id,
      isGlobalActive: newValue,
      roleOverrides:  feature.roleOverrides,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? l10n.featureMgmtSaveSuccess
          : l10n.featureMgmtSaveError(service.lastError ?? '')),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _showRoleOverridesDialog(
    BuildContext context,
    AppLocalizations l10n,
    FeatureService service,
    FeatureFlag feature,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _RoleOverridesDialog(
        feature: feature,
        onSave: (newOverrides) async {
          final ok = await service.updateFeature(
            feature.id,
            isGlobalActive: feature.isGlobalActive,
            roleOverrides:  newOverrides,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok
                ? l10n.featureMgmtSaveSuccess
                : l10n.featureMgmtSaveError(service.lastError ?? '')),
            backgroundColor: ok ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ));
        },
      ),
    );
  }
}

// ── Carte d'une feature ───────────────────────────────────────────────────────

class _FeatureFlagCard extends StatelessWidget {
  final FeatureFlag  feature;
  final ValueChanged<bool> onToggleGlobal;
  final VoidCallback onManageRoles;

  const _FeatureFlagCard({
    required this.feature,
    required this.onToggleGlobal,
    required this.onManageRoles,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final overrideCount = feature.roleOverrides.length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: feature.isGlobalActive
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ligne principale : nom + switch global ──────────────────────
            Row(
              children: [
                Icon(
                  feature.isGlobalActive
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  color: feature.isGlobalActive
                      ? AppColors.success
                      : AppColors.error,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        feature.id,
                        style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Chip statut global
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: feature.isGlobalActive
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    feature.isGlobalActive
                        ? l10n.featureMgmtGlobalActive
                        : l10n.featureMgmtGlobalInactive,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: feature.isGlobalActive
                            ? AppColors.success
                            : AppColors.error),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: feature.isGlobalActive,
                  activeColor: AppColors.success,
                  onChanged: onToggleGlobal,
                ),
              ],
            ),
            // ── Description ─────────────────────────────────────────────────
            if (feature.description != null && feature.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                feature.description!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // ── Bouton exceptions par rôle ───────────────────────────────────
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onManageRoles,
                  icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                  label: Text(l10n.featureMgmtRoleOverridesBtn),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (overrideCount > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$overrideCount exception${overrideCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog exceptions par rôle ────────────────────────────────────────────────

class _RoleOverridesDialog extends StatefulWidget {
  final FeatureFlag feature;
  final Future<void> Function(Map<String, bool> overrides) onSave;

  const _RoleOverridesDialog({
    required this.feature,
    required this.onSave,
  });

  @override
  State<_RoleOverridesDialog> createState() => _RoleOverridesDialogState();
}

class _RoleOverridesDialogState extends State<_RoleOverridesDialog> {
  // null = aucune exception, true = forcé actif, false = forcé inactif
  late Map<String, bool?> _overrides;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Initialiser depuis le feature existant
    _overrides = {};
    for (final role in kAssignableRoles) {
      final key = role.apiName;
      _overrides[key] = widget.feature.roleOverrides[key]; // null si pas d'override
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Ne conserver que les overrides non-null
    final toSave = <String, bool>{};
    for (final entry in _overrides.entries) {
      if (entry.value != null) toSave[entry.key] = entry.value!;
    }
    await widget.onSave(toSave);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.manage_accounts, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.featureMgmtRoleDialogTitle(widget.feature.name),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.featureMgmtRoleDialogHint,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Lignes par rôle ──────────────────────────────────────────────
            ...kAssignableRoles.map((role) {
              final key = role.apiName;
              final currentVal = _overrides[key];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        role.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<bool?>(
                        value: currentVal,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          DropdownMenuItem<bool?>(
                            value: null,
                            child: Text(
                              l10n.featureMgmtRoleNoOverride,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DropdownMenuItem<bool?>(
                            value: true,
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 14, color: AppColors.success),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.featureMgmtRoleForceActive,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.success),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem<bool?>(
                            value: false,
                            child: Row(
                              children: [
                                const Icon(Icons.cancel_outlined,
                                    size: 14, color: AppColors.error),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.featureMgmtRoleForceInactive,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _overrides[key] = v),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(l10n.commonSave),
        ),
      ],
    );
  }
}
