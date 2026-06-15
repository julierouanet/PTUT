import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/detail_breadcrumb.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import 'detail_screen_helpers.dart';

/// Dashboard d'un département (lecture seule).
///
/// Rangée de KPIs (total / opérationnels / maintenance / hors service / PM en
/// retard) puis liste des équipements (chaque tuile ouvre [EquipmentDetailScreen])
/// et liste des incidents ouverts. Responsive : KPIs empilés < 600px.
class DepartmentDetailScreen extends StatefulWidget {
  final int departmentId;
  final String departmentName;

  const DepartmentDetailScreen({
    super.key,
    required this.departmentId,
    required this.departmentName,
  });

  @override
  State<DepartmentDetailScreen> createState() => _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends State<DepartmentDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _kpis = const {};
  List<Map<String, dynamic>> _equipment = [];
  List<Map<String, dynamic>> _openIssues = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await DbApiService.instance.getDepartmentDetail(widget.departmentId);
      if (mounted) setState(() {
        _kpis = Map<String, dynamic>.from((detail['kpis'] as Map?) ?? const {});
        _equipment = List<Map<String, dynamic>>.from((detail['equipment'] as List?) ?? const []);
        _openIssues = List<Map<String, dynamic>>.from((detail['openIssues'] as List?) ?? const []);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  int _kpi(String key) => (_kpis[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.departmentDetailTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error))))
              : Column(
                  children: [
                    // Fil d'Ariane : [Département, page courante] → masqué (un seul segment connu).
                    DetailBreadcrumb(segments: [
                      BreadcrumbSegment(widget.departmentName),
                    ]),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(widget.departmentName,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 16),

                          _buildKpis(l10n),
                          const SizedBox(height: 16),

                          // ── Équipements ─────────────────────────────────────
                          detailSectionHeader(
                              Icons.inventory_2_outlined, l10n.subcategoryEquipmentSection),
                          const SizedBox(height: 8),
                          detailEquipmentTileList(context, _equipment,
                              emptyLabel: l10n.settingsEmptyList, subtitleKey: 'category'),
                          const SizedBox(height: 16),

                          // ── Incidents ouverts ───────────────────────────────
                          detailSectionHeader(
                              Icons.report_problem_outlined, l10n.departmentOpenIssuesSection),
                          const SizedBox(height: 8),
                          _buildIssuesList(l10n),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── KPIs responsives : 5 cartes en grille fluide (empilées sous 600px) ──────
  Widget _buildKpis(AppLocalizations l10n) {
    final cards = <Widget>[
      StatCard(title: l10n.dashboardTotal, value: '${_kpi('total')}',
          icon: Icons.devices_other, color: AppColors.primary),
      StatCard(title: l10n.dashboardOperational, value: '${_kpi('operational')}',
          icon: Icons.check_circle_outline, color: AppColors.success),
      StatCard(title: l10n.dashboardMaintenance, value: '${_kpi('maintenance')}',
          icon: Icons.build_outlined, color: AppColors.warning),
      StatCard(title: l10n.dashboardOutOfService, value: '${_kpi('outOfService')}',
          icon: Icons.cancel_outlined, color: AppColors.error),
      StatCard(title: l10n.dashboardPmOverdue, value: '${_kpi('pmOverdue')}',
          icon: Icons.event_busy_outlined, color: AppColors.error),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      // < 600 : 1 colonne ; < 900 : 2 colonnes ; sinon : 3 colonnes.
      final columns = width < 600 ? 1 : (width < 900 ? 2 : 3);
      const spacing = 12.0;
      final cardWidth = (width - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: cards
            .map((c) => SizedBox(width: cardWidth, child: c))
            .toList(),
      );
    });
  }

  Widget _buildIssuesList(AppLocalizations l10n) {
    if (_openIssues.isEmpty) return detailEmptyCard(l10n.dashboardNoIssues);
    return Card(
      child: Column(
        children: _openIssues.map((i) {
          final status = i['status'] as String? ?? '';
          final desc = i['description'] as String? ?? '—';
          final urgency = i['urgency'] as String? ?? '';
          return ListTile(
            dense: true,
            leading: const Icon(Icons.report_problem_outlined, size: 18, color: AppColors.warning),
            title: Text(desc,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14)),
            subtitle: urgency.isEmpty
                ? null
                : Text(urgency, style: const TextStyle(fontSize: 12)),
            trailing: status.isEmpty ? null : StatusBadge(status: status, isCompact: true),
          );
        }).toList(),
      ),
    );
  }
}
