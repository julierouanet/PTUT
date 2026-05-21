import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

// ── Enum période ─────────────────────────────────────────────────────────────

enum _Period { today, week, month }

// ── Écran Analytics ──────────────────────────────────────────────────────────

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _Period _period = _Period.today;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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
    final to = today.toIso8601String().substring(0, 10);
    return (from: from, to: to);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
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
          _data = jsonDecode(response.body) as Map<String, dynamic>;
          _loading = false;
        });
      } else {
        setState(() { _error = 'HTTP ${response.statusCode}'; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _setPeriod(_Period p) {
    if (_period == p) return;
    setState(() => _period = p);
    _load();
  }

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

  // ── Filtres période ──────────────────────────────────────────────────────

  Widget _buildPeriodFilter(AppLocalizations l10n) {
    return Row(
      children: [
        Text(l10n.analyticsPeriod, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(width: 12),
        _PeriodChip(label: l10n.analyticsToday,  value: _Period.today, current: _period, onTap: _setPeriod),
        const SizedBox(width: 8),
        _PeriodChip(label: l10n.analyticsWeek,   value: _Period.week,  current: _period, onTap: _setPeriod),
        const SizedBox(width: 8),
        _PeriodChip(label: l10n.analyticsMonth,  value: _Period.month, current: _period, onTap: _setPeriod),
      ],
    );
  }

  // ── Corps principal ──────────────────────────────────────────────────────

  Widget _buildBody(AppLocalizations l10n, bool isWide) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    final d = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStats(l10n, isWide, d),
            const SizedBox(height: 28),
            _buildEquipmentStatus(l10n, d),
            const SizedBox(height: 28),
            _buildTopActions(l10n, d),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── StatCards grille ─────────────────────────────────────────────────────

  Widget _buildStats(AppLocalizations l10n, bool isWide, Map<String, dynamic> d) {
    final cards = [
      _StatEntry(label: l10n.analyticsLogins,       value: '${d['logins'] ?? 0}',         icon: Icons.login,               color: AppColors.primary),
      _StatEntry(label: l10n.analyticsFailedLogins,  value: '${d['failed_logins'] ?? 0}',  icon: Icons.no_encryption_gmailerrorred_outlined, color: AppColors.error),
      _StatEntry(label: l10n.analyticsActiveUsers,   value: '${d['active_users'] ?? 0}',   icon: Icons.people_alt_outlined,  color: AppColors.success),
      _StatEntry(label: l10n.analyticsIssuesCreated, value: '${d['issues_created'] ?? 0}', icon: Icons.bug_report_outlined,  color: AppColors.warning),
      _StatEntry(label: l10n.analyticsIssuesResolved,value: '${d['issues_resolved'] ?? 0}',icon: Icons.check_circle_outline, color: AppColors.success),
      _StatEntry(label: l10n.analyticsEquipmentTotal,value: '${d['equipment_total'] ?? 0}',icon: Icons.medical_services_outlined, color: AppColors.primary),
    ];

    final crossCount = isWide ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isWide ? 1.6 : 1.3,
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

  // ── Répartition par statut équipement ────────────────────────────────────

  Widget _buildEquipmentStatus(AppLocalizations l10n, Map<String, dynamic> d) {
    final rawList = d['equipment_by_status'];
    if (rawList == null || rawList is! List || rawList.isEmpty) return const SizedBox.shrink();

    final items = rawList.cast<Map<String, dynamic>>();
    final total = items.fold<int>(0, (s, e) => s + ((e['count'] ?? 0) as int));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.analyticsEquipmentByStatus, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            if (total == 0)
              Text(l10n.analyticsNoData, style: const TextStyle(color: AppColors.textSecondary))
            else
              ...items.map((e) {
                final status = '${e['status'] ?? ''}';
                final count  = (e['count'] ?? 0) as int;
                final pct    = total > 0 ? count / total : 0.0;
                final color  = _statusColor(status);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(status, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          Text('$count (${(pct * 100).round()}%)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'operational': return AppColors.success;
      case 'maintenance': return AppColors.warning;
      case 'out_of_service': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  // ── Top actions ───────────────────────────────────────────────────────────

  Widget _buildTopActions(AppLocalizations l10n, Map<String, dynamic> d) {
    final rawList = d['top_actions'];
    if (rawList == null || rawList is! List || rawList.isEmpty) return const SizedBox.shrink();
    final items = rawList.cast<Map<String, dynamic>>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.analyticsTopActions, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Text(l10n.analyticsNoData, style: const TextStyle(color: AppColors.textSecondary))
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: items.map((e) {
                  final action = '${e['action'] ?? ''}';
                  final count  = (e['count'] ?? 0) as int;
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    label: Text(action, style: const TextStyle(fontSize: 13)),
                    backgroundColor: AppColors.primaryLight,
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliaires ───────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  final String label;
  final _Period value;
  final _Period current;
  final void Function(_Period) onTap;

  const _PeriodChip({required this.label, required this.value, required this.current, required this.onTap});

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
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      backgroundColor: Colors.white,
    );
  }
}

class _StatEntry {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatEntry({required this.label, required this.value, required this.icon, required this.color});
}
