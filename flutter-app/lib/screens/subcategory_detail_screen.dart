import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/replacement_badge.dart';

/// Page de détail d'une sous-catégorie biomédicale (RA3 S5).
///
/// Affiche la durée de vie de référence et la liste des « notifications » :
/// les équipements de cette sous-catégorie à remplacer / bientôt / sans donnée.
/// Ouverte via [MaterialPageRoute] depuis la gestion des sous-catégories.
class SubcategoryDetailScreen extends StatefulWidget {
  final int subcategoryId;
  final String subcategoryName;
  final int? expectedLifespanYears;

  const SubcategoryDetailScreen({
    super.key,
    required this.subcategoryId,
    required this.subcategoryName,
    this.expectedLifespanYears,
  });

  @override
  State<SubcategoryDetailScreen> createState() =>
      _SubcategoryDetailScreenState();
}

class _SubcategoryDetailScreenState extends State<SubcategoryDetailScreen> {
  bool _loading = true;
  String? _error;
  // Items du plan de remplacement appartenant à cette sous-catégorie
  // et porteurs d'une alerte (badge non nul).
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final plan  = await DbApiService.instance.getReplacementPlan();
      final items = (plan['items'] as List?) ?? const [];
      final alerts = <Map<String, dynamic>>[];
      for (final it in items) {
        final m = it as Map<String, dynamic>;
        if (m['subcategory'] == widget.subcategoryName) {
          final status = m['status_replacement'] as String? ?? 'ok';
          if (ReplacementBadge.colorFor(status) != null) alerts.add(m);
        }
      }
      if (mounted) setState(() { _alerts = alerts; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.subcategoryDetailTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── En-tête sous-catégorie ──────────────────────────────────────
          Text(widget.subcategoryName,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),

          // ── Durée de vie de référence ───────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.timelapse, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.subcategoryDetailLifespanSection,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (widget.expectedLifespanYears == null)
                  ReplacementBadge(
                    status: 'donnee_manquante',
                    tooltip: l10n.subcategoryLifespanUndefinedTooltip,
                  )
                else
                  Text('${widget.expectedLifespanYears} ${l10n.subcategoryLifespanHint}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // ── Section Notifications ───────────────────────────────────────
          Row(children: [
            const Icon(Icons.notifications_outlined,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(l10n.subcategoryDetailAlertsSection,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          _buildAlerts(l10n),
        ],
      ),
    );
  }

  Widget _buildAlerts(AppLocalizations l10n) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: const TextStyle(color: AppColors.error)),
        ),
      );
    }
    if (_alerts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.check_circle_outline,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Text(l10n.subcategoryDetailNoAlerts,
                style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      );
    }

    return Card(
      child: Column(
        children: _alerts.map((m) {
          final status   = m['status_replacement'] as String? ?? 'ok';
          final age      = (m['age'] as num?)?.toInt();
          final lifespan = (m['lifespan'] as num?)?.toInt();
          final crit     = m['criticality'] as String?;
          final tooltip  = ReplacementBadge.tooltipFor(l10n, status, age, lifespan, crit);
          return ListTile(
            dense: true,
            leading: ReplacementBadge(status: status, tooltip: tooltip),
            title: Text(m['name'] as String? ?? '—',
                style: const TextStyle(fontSize: 14)),
            subtitle: Text(tooltip.isEmpty
                ? l10n.replacementStatusUnknown
                : tooltip),
          );
        }).toList(),
      ),
    );
  }
}
