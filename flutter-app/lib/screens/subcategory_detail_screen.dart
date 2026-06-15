import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/replacement_badge.dart';
import '../widgets/status_badge.dart';
import 'brand_detail_screen.dart';

/// Page de détail d'une sous-catégorie.
///
/// Pour **toutes** les sous-catégories : liste des équipements + liste des
/// fabricants présents (catalogue). Pour les sous-catégories **biomédicales**
/// uniquement (RA3 S5) : durée de vie de référence + alertes de remplacement.
/// Ouverte via [MaterialPageRoute] depuis la gestion des sous-catégories.
class SubcategoryDetailScreen extends StatefulWidget {
  final int subcategoryId;
  final String subcategoryName;
  final int? expectedLifespanYears;

  /// Active les sections durée de vie / alertes de remplacement (biomédical).
  final bool isBiomedical;

  const SubcategoryDetailScreen({
    super.key,
    required this.subcategoryId,
    required this.subcategoryName,
    this.expectedLifespanYears,
    this.isBiomedical = true,
  });

  @override
  State<SubcategoryDetailScreen> createState() =>
      _SubcategoryDetailScreenState();
}

class _SubcategoryDetailScreenState extends State<SubcategoryDetailScreen> {
  bool _loading = true;
  String? _error;

  // Équipements et fabricants de la sous-catégorie (catalogue).
  List<Map<String, dynamic>> _equipment = [];
  List<Map<String, dynamic>> _brands = [];

  // Items du plan de remplacement appartenant à cette sous-catégorie
  // et porteurs d'une alerte (badge non nul) — biomédical uniquement.
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Détail sous-catégorie : équipements + fabricants.
      final detail = await DbApiService.instance.getSubCategoryDetail(widget.subcategoryId);
      _equipment = List<Map<String, dynamic>>.from((detail['equipment'] as List?) ?? const []);
      _brands = List<Map<String, dynamic>>.from((detail['brands'] as List?) ?? const []);

      // Alertes de remplacement (biomédical uniquement).
      if (widget.isBiomedical) {
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
        _alerts = alerts;
      }

      if (mounted) setState(() => _loading = false);
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── En-tête sous-catégorie ──────────────────────────────
                    Text(widget.subcategoryName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 16),

                    // ── Durée de vie de référence (biomédical) ──────────────
                    if (widget.isBiomedical) ...[
                      _buildLifespanCard(l10n),
                      const SizedBox(height: 16),
                      _buildAlertsSection(l10n),
                      const SizedBox(height: 16),
                    ],

                    // ── Équipements (toutes macro-catégories) ───────────────
                    _buildSectionHeader(
                        Icons.inventory_2_outlined, l10n.subcategoryEquipmentSection),
                    const SizedBox(height: 8),
                    _buildEquipmentList(l10n),
                    const SizedBox(height: 16),

                    // ── Fabricants (catalogue) ──────────────────────────────
                    _buildSectionHeader(Icons.factory_outlined, l10n.subcategoryBrandsSection),
                    const SizedBox(height: 8),
                    _buildBrandsList(l10n),
                  ],
                ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: AppColors.error)),
        ),
      );

  Widget _buildSectionHeader(IconData icon, String label) => Row(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ]);

  Widget _buildLifespanCard(AppLocalizations l10n) => Card(
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),
      );

  Widget _buildAlertsSection(AppLocalizations l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              Icons.notifications_outlined, l10n.subcategoryDetailAlertsSection),
          const SizedBox(height: 8),
          if (_alerts.isEmpty)
            Card(
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
            )
          else
            Card(
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
            ),
        ],
      );

  Widget _buildEquipmentList(AppLocalizations l10n) {
    if (_equipment.isEmpty) {
      return _emptyCard(l10n.settingsEmptyList);
    }
    return Card(
      child: Column(
        children: _equipment.map((e) {
          final status = e['status'] as String? ?? '';
          return ListTile(
            dense: true,
            leading: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.textSecondary),
            title: Text(e['name'] as String? ?? '—', style: const TextStyle(fontSize: 14)),
            trailing: status.isEmpty ? null : StatusBadge(status: status, isCompact: true),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBrandsList(AppLocalizations l10n) {
    if (_brands.isEmpty) {
      return _emptyCard(l10n.subcategoryNoBrands);
    }
    return Card(
      child: Column(
        children: _brands.map((b) {
          final modelCount = (b['model_count'] as int?) ?? 0;
          final eqCount = (b['equipment_count'] as int?) ?? 0;
          return ListTile(
            dense: true,
            leading: const Icon(Icons.factory_outlined, size: 18, color: AppColors.primary),
            title: Text(b['name'] as String? ?? '—', style: const TextStyle(fontSize: 14)),
            subtitle: Text(l10n.catalogBrandCounts(modelCount, eqCount),
                style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BrandDetailScreen(
                  brandId: b['id'] as int,
                  brandName: b['name'] as String? ?? '—',
                  subcategoryId: widget.subcategoryId,
                  subcategoryName: widget.subcategoryName,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyCard(String message) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
      );
}
