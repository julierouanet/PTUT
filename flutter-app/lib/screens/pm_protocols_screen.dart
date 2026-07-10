import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/pm_protocol.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import 'pm_protocol_form_screen.dart';

/// Écran de gestion des protocoles PM d'une sous-catégorie d'équipement
/// (créer/éditer/supprimer). Accessible depuis l'onglet Maintenance d'une
/// fiche équipement — les protocoles s'appliquent à TOUS les équipements
/// du même type, pas seulement à celui consulté.
class PmProtocolsScreen extends StatefulWidget {
  final int subcategoryId;
  final String subcategoryName;

  const PmProtocolsScreen({
    super.key,
    required this.subcategoryId,
    required this.subcategoryName,
  });

  @override
  State<PmProtocolsScreen> createState() => _PmProtocolsScreenState();
}

class _PmProtocolsScreenState extends State<PmProtocolsScreen> {
  bool _loading = true;
  List<PmProtocol> _protocols = const [];
  bool _changed = false;

  bool get _isAdmin =>
      AuthService().currentUser?.hasRole(UserRole.admin) ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final protocols = await DbApiService.instance
          .getPmProtocols(subcategoryId: widget.subcategoryId);
      if (mounted) setState(() => _protocols = protocols);
    } catch (_) {
      // Liste vide en cas d'échec — l'utilisateur peut réessayer.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({PmProtocol? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PmProtocolFormScreen(
          subcategoryId: widget.subcategoryId,
          existing: existing,
        ),
      ),
    );
    if (saved == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _confirmDelete(PmProtocol protocol, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.pmProtocolDelete),
        content: Text(l10n.pmProtocolDeleteConfirm(protocol.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text(l10n.pmProtocolDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DbApiService.instance.deletePmProtocol(protocol.id);
      _changed = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.pmProtocolDeleted),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.pmProtocolsTitle)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      widget.subcategoryName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildScopeWarning(l10n),
                    const SizedBox(height: 16),
                    if (_protocols.isEmpty)
                      _buildEmptyState(l10n)
                    else
                      ..._protocols.map((p) => _buildProtocolCard(p, l10n)),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: Text(l10n.pmProtocolAdd),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildScopeWarning(AppLocalizations l10n) {
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.pmProtocolScopeWarning(widget.subcategoryName),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.checklist_outlined, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                l10n.pmProtocolNoProtocols,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n.pmProtocolAdd),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolCard(PmProtocol protocol, AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    protocol.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.pmFrequencyValue(protocol.frequencyMonths) +
                        (protocol.estimatedDurationHours != null
                            ? ' — ${l10n.pmDurationEstimated((protocol.estimatedDurationHours! * 60).round())}'
                            : ''),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.pmStepsProgress(0, protocol.checklist.length),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
              onPressed: () => _openForm(existing: protocol),
            ),
            if (_isAdmin)
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
                onPressed: () => _confirmDelete(protocol, l10n),
              ),
          ],
        ),
      ),
    );
  }
}
