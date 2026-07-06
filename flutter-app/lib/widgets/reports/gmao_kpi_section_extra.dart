import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// Section des 5 indicateurs GMAO complémentaires : MTBF, backlog d'incidents,
/// taux d'obsolescence + âge moyen, répartition par criticité ABC (biomédical)
/// et downtime cumulé.
///
/// Grille responsive : 4 colonnes sur desktop (>= 800 px), 2 sur mobile.
class GmaoKpiSectionExtra extends StatelessWidget {
  /// Durée moyenne entre pannes (jours), parc entier. Null si aucune panne
  /// sur la période (division par zéro évitée en amont).
  final double? mtbfDays;

  /// Nombre total d'incidents non clôturés (tous statuts ouverts confondus).
  final int backlogTotal;

  /// Sous-ensemble de [backlogTotal] ouvert depuis plus de 30 jours.
  final int backlogOver30Days;

  /// Résumé du plan de remplacement biomédical (`GET /replacement-plan`).
  /// Null si la donnée n'a pas pu être chargée (réseau, permission).
  final Map<String, dynamic>? replacementSummary;

  /// Heures d'arrêt cumulées sur incidents clôturés de la période.
  final double downtimeHours;

  const GmaoKpiSectionExtra({
    super.key,
    required this.mtbfDays,
    required this.backlogTotal,
    required this.backlogOver30Days,
    required this.replacementSummary,
    required this.downtimeHours,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < AppBreakpoints.desktop;

    final cards = [
      _buildMtbfCard(l10n),
      _buildBacklogCard(l10n),
      _buildObsolescenceCard(l10n),
      _buildCriticalityCard(l10n),
      _buildDowntimeCard(l10n),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isMobile ? 1.1 : 1.3,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => cards[i],
    );
  }

  // ── MTBF ──────────────────────────────────────────────────────────────────

  Widget _buildMtbfCard(AppLocalizations l10n) {
    final hasData = mtbfDays != null;
    return _KpiCard(
      icon: Icons.schedule_outlined,
      color: hasData ? AppColors.primary : AppColors.textSecondary,
      title: l10n.reportsMtbf,
      value: hasData ? '${mtbfDays!.toStringAsFixed(1)} jours' : l10n.reportsMtbfNoData,
      subtitle: hasData ? l10n.reportsMtbfHint : '',
    );
  }

  // ── Backlog d'incidents ─────────────────────────────────────────────────────

  Widget _buildBacklogCard(AppLocalizations l10n) {
    return _KpiCard(
      icon: Icons.pending_actions_outlined,
      color: backlogTotal > 0 ? AppColors.warning : AppColors.success,
      title: l10n.reportsBacklog,
      value: '$backlogTotal',
      subtitle: backlogOver30Days > 0
          ? l10n.reportsBacklogOver30(backlogOver30Days)
          : '',
    );
  }

  /// Carte "Indisponible" affichée à la place d'une carte dépendant de
  /// [replacementSummary] tant que celui-ci n'a pas encore été chargé.
  Widget _noDataCard(AppLocalizations l10n, IconData icon, String title) {
    return _KpiCard(
      icon: icon,
      color: AppColors.textSecondary,
      title: title,
      value: l10n.reportsObsolescenceNoData,
      subtitle: '',
    );
  }

  // ── Taux d'obsolescence ─────────────────────────────────────────────────────

  Widget _buildObsolescenceCard(AppLocalizations l10n) {
    final summary = replacementSummary;
    if (summary == null) {
      return _noDataCard(l10n, Icons.hourglass_disabled_outlined, l10n.reportsObsolescenceRate);
    }

    final endOfLifePct = summary['end_of_life_pct'];
    final avgAge = summary['avg_age_years'];
    final biomedicalCount = summary['biomedical_count'];

    return _KpiCard(
      icon: Icons.hourglass_bottom_outlined,
      color: AppColors.warning,
      title: l10n.reportsObsolescenceRate,
      value: '$endOfLifePct%',
      subtitle: 'Âge moyen : $avgAge ans (biomédical, $biomedicalCount équipements)',
    );
  }

  // ── Répartition par criticité ABC ───────────────────────────────────────────

  Widget _buildCriticalityCard(AppLocalizations l10n) {
    final summary = replacementSummary;
    if (summary == null) {
      return _noDataCard(l10n, Icons.category_outlined, l10n.reportsCriticalityAbc);
    }

    final byCriticality = (summary['by_criticality'] as Map).cast<String, dynamic>();
    final a = byCriticality['A'] as int;
    final b = byCriticality['B'] as int;
    final c = byCriticality['C'] as int;

    return _KpiCard(
      icon: Icons.category_outlined,
      color: AppColors.primary,
      title: l10n.reportsCriticalityAbc,
      value: '${a + b + c}',
      subtitle: 'A : $a · B : $b · C : $c',
    );
  }

  // ── Downtime cumulé ─────────────────────────────────────────────────────────

  Widget _buildDowntimeCard(AppLocalizations l10n) {
    return _KpiCard(
      icon: Icons.power_off_outlined,
      color: downtimeHours > 0 ? AppColors.error : AppColors.success,
      title: l10n.reportsDowntimeTotal,
      value: '${downtimeHours.toStringAsFixed(0)} h',
      subtitle: l10n.reportsDowntimeHint,
    );
  }
}

// ── KPI Card générique (même style que report_kpi_section.dart) ──────────────

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;

  const _KpiCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
