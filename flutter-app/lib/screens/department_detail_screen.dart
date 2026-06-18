import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/detail_breadcrumb.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import 'detail_screen_helpers.dart';
import 'issue_detail_screen.dart';

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
  List<Map<String, dynamic>> _resolvedIssues = [];

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
        _resolvedIssues = List<Map<String, dynamic>>.from((detail['resolvedIssues'] as List?) ?? const []);
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

                          // ── Incidents en cours ──────────────────────────────
                          detailSectionHeader(
                              Icons.report_problem_outlined,
                              '${l10n.departmentOpenIssuesSection} (${_openIssues.length})'),
                          const SizedBox(height: 8),
                          _buildIssuesList(l10n, _openIssues, dateKey: 'created_at'),
                          const SizedBox(height: 16),

                          // ── Incidents résolus ───────────────────────────────
                          detailSectionHeader(
                              Icons.task_alt_outlined,
                              '${l10n.departmentResolvedIssuesSection} (${_resolvedIssues.length})'),
                          const SizedBox(height: 8),
                          _buildIssuesList(l10n, _resolvedIssues, dateKey: 'updated_at'),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── KPIs responsives : 6 cartes en grille fluide (empilées sous 600px) ──────
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
      StatCard(title: l10n.departmentOpenIssuesKpi, value: '${_kpi('openIssuesCount')}',
          icon: Icons.report_problem_outlined, color: AppColors.warning),
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

  /// Liste d'incidents en carte, paramétrée par la liste et la clé de date à
  /// afficher (`created_at` pour les incidents en cours, `updated_at` — date de
  /// clôture — pour les résolus). Chaque tuile ouvre [IssueDetailScreen].
  Widget _buildIssuesList(
    AppLocalizations l10n,
    List<Map<String, dynamic>> issues, {
    required String dateKey,
  }) {
    if (issues.isEmpty) return detailEmptyCard(l10n.dashboardNoIssues);
    return Card(
      child: Column(
        children: issues.map((i) {
          final id = i['id'] as String? ?? '';
          final status = i['status'] as String? ?? '';
          final desc = i['description'] as String? ?? '—';
          final urgency = i['urgency'] as String? ?? '';
          final equipmentName = i['equipment_name'] as String? ?? '';
          final locationName = i['location_name'] as String? ?? '';

          // Cible : équipement si renseigné, sinon lieu, sinon fallback générique.
          final target = equipmentName.isNotEmpty
              ? equipmentName
              : (locationName.isNotEmpty
                  ? locationName
                  : l10n.departmentIncidentTargetFallback);

          // Sous-titre : cible · urgence · date formatée (selon la section).
          final parts = <String>[target];
          if (urgency.isNotEmpty) parts.add(urgency);
          final dateLabel = detailFormatDate(i[dateKey] as String?);
          if (dateLabel != null) parts.add(dateLabel);

          return ListTile(
            dense: true,
            leading: _categoryBadge(l10n, i['issue_category'] as String?),
            title: Text(desc,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14)),
            subtitle: Text(parts.join(' · '),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            trailing: status.isEmpty ? null : StatusBadge(status: status, isCompact: true),
            onTap: id.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IssueDetailScreen(issueId: id),
                      ),
                    ),
          );
        }).toList(),
      ),
    );
  }

  /// Badge de catégorie d'incident (Biomedical / Infrastructure / IT) : icône +
  /// couleur distincte issues de [AppColors] — pas de couleur inline. Icône,
  /// couleur et libellé dérivent d'un seul switch sur la catégorie.
  Widget _categoryBadge(AppLocalizations l10n, String? category) {
    final (IconData icon, Color color, String label) = switch (category) {
      'Infrastructure' => (
          Icons.bolt_outlined, AppColors.warning, l10n.departmentIncidentCategoryInfrastructure),
      'IT' => (
          Icons.computer_outlined, AppColors.textSecondary, l10n.departmentIncidentCategoryIt),
      _ => (
          Icons.medical_services_outlined, AppColors.primary, l10n.departmentIncidentCategoryBiomedical),
    };
    return Tooltip(
      message: label,
      child: Icon(icon, size: 18, color: color),
    );
  }
}
