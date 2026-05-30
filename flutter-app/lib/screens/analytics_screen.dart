import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/analytics/incident_trend_chart.dart';
import '../widgets/analytics/resolution_bar_chart.dart';

// ── Enum période ─────────────────────────────────────────────────────────────

enum _Period { today, week, month }

// ── Écran Analytiques GMAO ───────────────────────────────────────────────────

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _Period _period = _Period.week;

  // Données agrégées (période sélectionnée, depuis /api/analytics)
  Map<String, dynamic>? _analyticsData;
  String? _analyticsError;

  // Erreur spécifique aux graphiques (chargement /api/issues)
  String? _issuesError;

  // Séries pour le LineChart (13 semaines glissantes)
  List<int> _createdPerWeek = List.filled(13, 0);
  List<int> _resolvedPerWeek = List.filled(13, 0);

  // Volume par groupe pour le BarChart (période courante)
  Map<String, int> _issuesByGroup = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Plage de dates selon la période ─────────────────────────────────────────

  ({String from, String to}) _dateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final String from;
    switch (_period) {
      case _Period.today:
        from = today.toIso8601String().substring(0, 10);
      case _Period.week:
        from = today.subtract(const Duration(days: 6)).toIso8601String().substring(0, 10);
      case _Period.month:
        from = today.subtract(const Duration(days: 29)).toIso8601String().substring(0, 10);
    }
    return (from: from, to: today.toIso8601String().substring(0, 10));
  }

  // ── Chargement parallèle ────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _analyticsError = null;
      _issuesError = null;
    });
    await Future.wait([
      _loadAnalyticsData(),
      _loadIssuesForCharts(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAnalyticsData() async {
    try {
      final range = _dateRange();
      final uri = Uri.parse(ApiConfig.analyticsUrl).replace(queryParameters: {
        'from': range.from,
        'to': range.to,
      });
      final response = await ApiClient.get(uri.toString());
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _analyticsData = jsonDecode(response.body) as Map<String, dynamic>;
        });
      } else {
        setState(() => _analyticsError = 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _analyticsError = e.toString());
    }
  }

  Future<void> _loadIssuesForCharts() async {
    try {
      final issues = await DbApiService.instance.getIssues();
      if (!mounted) return;
      final result = _computeChartData(issues);
      setState(() {
        _createdPerWeek = result.created;
        _resolvedPerWeek = result.resolved;
        _issuesByGroup = result.byGroup;
      });
    } catch (e) {
      if (mounted) setState(() => _issuesError = e.toString());
    }
  }

  // ── Calcul des séries graphiques ─────────────────────────────────────────────

  ({List<int> created, List<int> resolved, Map<String, int> byGroup})
      _computeChartData(List<Map<String, dynamic>> issues) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Fenêtre glissante : 13 semaines = 91 jours
    final startOf13Weeks = today.subtract(const Duration(days: 90));

    final range = _dateRange();
    final periodFrom = DateTime.parse(range.from);
    final periodTo = today.add(const Duration(days: 1));

    final created = List<int>.filled(13, 0);
    final resolved = List<int>.filled(13, 0);
    final byGroup = <String, int>{};

    const terminalStatuses = {'Completed', 'Verified', 'Closed'};

    for (final issue in issues) {
      DateTime? createdAt;
      final createdStr = issue['created_at'] as String?;
      if (createdStr != null) {
        try {
          createdAt = DateTime.parse(createdStr);
        } catch (_) {}
      }

      // Série 13 semaines — incidents créés
      if (createdAt != null) {
        final diff = createdAt.difference(startOf13Weeks).inDays;
        if (diff >= 0 && diff < 91) {
          created[(diff ~/ 7).clamp(0, 12)]++;
        }
      }

      // Série 13 semaines — incidents résolus (updated_at quand statut terminal)
      final status = issue['status'] as String? ?? '';
      if (terminalStatuses.contains(status)) {
        final updatedStr = issue['updated_at'] as String?;
        if (updatedStr != null) {
          try {
            final updatedAt = DateTime.parse(updatedStr);
            final diff = updatedAt.difference(startOf13Weeks).inDays;
            if (diff >= 0 && diff < 91) {
              resolved[(diff ~/ 7).clamp(0, 12)]++;
            }
          } catch (_) {}
        }
      }

      // BarChart — incidents par groupe, filtrés sur la période courante
      if (createdAt != null &&
          !createdAt.isBefore(periodFrom) &&
          createdAt.isBefore(periodTo)) {
        final group = (issue['group'] as String?)?.isNotEmpty == true
            ? issue['group'] as String
            : 'Autre';
        byGroup[group] = (byGroup[group] ?? 0) + 1;
      }
    }

    return (created: created, resolved: resolved, byGroup: byGroup);
  }

  // ── Changement de période ────────────────────────────────────────────────────

  void _setPeriod(_Period p) {
    if (_period == p) return;
    setState(() => _period = p);
    _load();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodFilter(l10n),
            const SizedBox(height: 24),
            Expanded(child: _buildBody(l10n, isWide)),
          ],
        ),
      ),
    );
  }

  // ── Filtre de période ─────────────────────────────────────────────────────

  Widget _buildPeriodFilter(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            l10n.analyticsPeriod,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          _PeriodChip(
            label: l10n.analyticsToday,
            value: _Period.today,
            current: _period,
            onTap: _setPeriod,
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: l10n.analyticsWeek,
            value: _Period.week,
            current: _period,
            onTap: _setPeriod,
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: l10n.analyticsMonth,
            value: _Period.month,
            current: _period,
            onTap: _setPeriod,
          ),
        ],
      ),
    );
  }

  // ── Corps principal ────────────────────────────────────────────────────────

  Widget _buildBody(AppLocalizations l10n, bool isWide) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_analyticsError != null && _analyticsData == null) {
      return _buildFullError(_analyticsError!, l10n);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section 1 : KPIs incidents ──────────────────────────────
            _SectionHeader(title: l10n.analyticsIssueKpiSection),
            const SizedBox(height: 16),
            _buildIssueKpiGrid(l10n, isWide),
            const SizedBox(height: 28),

            // ── Section 2 : État des équipements ────────────────────────
            _SectionHeader(title: l10n.analyticsEquipmentSection),
            const SizedBox(height: 16),
            _buildEquipmentGrid(l10n, isWide),
            const SizedBox(height: 12),
            _buildEquipmentStatusBars(l10n),
            const SizedBox(height: 28),

            // ── Section 3 : Graphiques de tendance ──────────────────────
            _SectionHeader(
              title: l10n.analyticsChartsSection,
              subtitle: l10n.analyticsChartsPeriodNote,
            ),
            const SizedBox(height: 16),
            if (_issuesError != null)
              _buildChartErrorBanner(l10n)
            else ...[
              IncidentTrendChart(
                createdPerWeek: _createdPerWeek,
                resolvedPerWeek: _resolvedPerWeek,
              ),
              const SizedBox(height: 16),
              ResolutionBarChart(issuesByGroup: _issuesByGroup),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── KPIs incidents (4 StatCards) ──────────────────────────────────────────

  Widget _buildIssueKpiGrid(AppLocalizations l10n, bool isWide) {
    final d = _analyticsData ?? {};
    final total = (d['issues_total'] ?? 0) as int;
    final resolvedCount = (d['issues_resolved'] ?? 0) as int;
    final open = (d['issues_open'] ?? 0) as int;
    final resolutionRate =
        total > 0 ? '${(resolvedCount / total * 100).round()}%' : '—';

    return _StatsGrid(
      isWide: isWide,
      cards: [
        _StatEntry(
          label: l10n.analyticsIssuesCreated,
          value: '$total',
          icon: Icons.bug_report_outlined,
          color: AppColors.warning,
        ),
        _StatEntry(
          label: l10n.analyticsIssuesResolved,
          value: '$resolvedCount',
          icon: Icons.check_circle_outline,
          color: AppColors.success,
        ),
        _StatEntry(
          label: l10n.analyticsOpenIssuesLabel,
          value: '$open',
          icon: Icons.pending_outlined,
          color: AppColors.primary,
        ),
        _StatEntry(
          label: l10n.analyticsResolutionRateLabel,
          value: resolutionRate,
          icon: Icons.trending_up_outlined,
          color: AppColors.success,
        ),
      ],
    );
  }

  // ── Métriques équipements (4 StatCards) ───────────────────────────────────

  Widget _buildEquipmentGrid(AppLocalizations l10n, bool isWide) {
    final d = _analyticsData ?? {};
    // L'API retourne un objet JSON { "operational": 95, "maintenance": 10, ... }
    final rawStatus = d['equipment_by_status'];
    final Map<String, dynamic> eqStatus =
        rawStatus is Map<String, dynamic> ? rawStatus : {};

    final operational = ((eqStatus['operational'] as num?)?.toInt()) ?? 0;
    final maintenance = ((eqStatus['maintenance'] as num?)?.toInt()) ?? 0;
    final outOfService = ((eqStatus['out_of_service'] as num?)?.toInt()) ?? 0;
    final total = (d['equipment_total'] ?? 0) as int;

    return _StatsGrid(
      isWide: isWide,
      cards: [
        _StatEntry(
          label: l10n.analyticsEquipmentTotal,
          value: '$total',
          icon: Icons.medical_services_outlined,
          color: AppColors.primary,
        ),
        _StatEntry(
          label: l10n.dashboardOperational,
          value: '$operational',
          icon: Icons.check_circle_outline,
          color: AppColors.success,
        ),
        _StatEntry(
          label: l10n.dashboardInMaintenance,
          value: '$maintenance',
          icon: Icons.build_outlined,
          color: AppColors.warning,
        ),
        _StatEntry(
          label: l10n.dashboardOutOfService,
          value: '$outOfService',
          icon: Icons.cancel_outlined,
          color: AppColors.error,
        ),
      ],
    );
  }

  // ── Barres de progression par statut équipement ──────────────────────────

  Widget _buildEquipmentStatusBars(AppLocalizations l10n) {
    final d = _analyticsData ?? {};
    final rawStatus = d['equipment_by_status'];
    if (rawStatus is! Map<String, dynamic> || rawStatus.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = rawStatus.values
        .fold<int>(0, (s, v) => s + ((v as num?)?.toInt() ?? 0));
    if (total == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.analyticsEquipmentByStatus,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...rawStatus.entries.map((e) {
              final count = ((e.value as num?)?.toInt()) ?? 0;
              final pct = count / total;
              final color = _statusColor(e.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          e.key,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$count  (${(pct * 100).round()}%)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 8,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Erreur plein écran (API analytics inaccessible) ──────────────────────

  Widget _buildFullError(String error, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(error, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.analyticsRetry),
          ),
        ],
      ),
    );
  }

  // ── Bannière d'erreur graphiques (issues inaccessibles) ──────────────────

  Widget _buildChartErrorBanner(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_outlined,
              color: AppColors.warning,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.analyticsNoChartData,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: _load,
              child: Text(l10n.analyticsRetry),
            ),
          ],
        ),
      ),
    );
  }

  // ── Couleur de statut équipement ─────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'operational':
        return AppColors.success;
      case 'maintenance':
        return AppColors.warning;
      case 'out_of_service':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}

// ── Widgets auxiliaires ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<_StatEntry> cards;
  final bool isWide;

  const _StatsGrid({required this.cards, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isWide ? 1.5 : 1.3,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => StatCard(
        title: cards[i].label,
        value: cards[i].value,
        icon: cards[i].icon,
        color: cards[i].color,
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final _Period value;
  final _Period current;
  final void Function(_Period) onTap;

  const _PeriodChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(value),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
      ),
      backgroundColor: Colors.white,
    );
  }
}

class _StatEntry {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatEntry({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
