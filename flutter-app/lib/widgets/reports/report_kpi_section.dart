import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// Section des KPIs GMAO : MTTR approximé, conformité PM, top 3 départements.
///
/// Les trois KPIs sont disposés en ligne sur desktop (>= 800 px) et en colonne
/// sur mobile.  La card "Top départements" occupe 2× la place des deux autres
/// sur desktop.
class ReportKpiSection extends StatelessWidget {
  /// Délai moyen d'intervention en jours (null si données insuffisantes).
  final double? mttrDays;

  /// Nombre d'équipements avec PM planifiée dont la date n'est pas dépassée.
  final int pmCompliant;

  /// Nombre total d'équipements avec une PM planifiée.
  final int pmTotal;

  /// Top départements classés par nombre d'incidents (max 3).
  final List<MapEntry<String, int>> topDepartments;

  const ReportKpiSection({
    super.key,
    required this.mttrDays,
    required this.pmCompliant,
    required this.pmTotal,
    required this.topDepartments,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < 800;

    if (isMobile) {
      return Column(
        children: [
          _buildMttrCard(l10n),
          const SizedBox(height: 16),
          _buildPmCard(l10n),
          const SizedBox(height: 16),
          _buildTopDeptsCard(l10n),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildMttrCard(l10n)),
        const SizedBox(width: 16),
        Expanded(child: _buildPmCard(l10n)),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: _buildTopDeptsCard(l10n)),
      ],
    );
  }

  // ── MTTR ──────────────────────────────────────────────────────────────────

  Widget _buildMttrCard(AppLocalizations l10n) {
    final hasData = mttrDays != null;
    final Color color;
    if (!hasData) {
      color = AppColors.textSecondary;
    } else if (mttrDays! <= 1) {
      color = AppColors.success;
    } else if (mttrDays! <= 3) {
      color = AppColors.warning;
    } else {
      color = AppColors.error;
    }

    return _KpiCard(
      icon: Icons.timer_outlined,
      color: color,
      title: l10n.reportsMttr,
      value: hasData ? l10n.reportsMttrDays(mttrDays!.toStringAsFixed(1)) : l10n.reportsMttrNoData,
      subtitle: hasData ? l10n.reportsMttrHint : '',
    );
  }

  // ── Conformité PM ─────────────────────────────────────────────────────────

  Widget _buildPmCard(AppLocalizations l10n) {
    if (pmTotal == 0) {
      return _KpiCard(
        icon: Icons.verified_outlined,
        color: AppColors.textSecondary,
        title: l10n.reportsPmCompliance,
        value: l10n.reportsPmNoData,
        subtitle: '',
      );
    }

    final rate = (pmCompliant / pmTotal * 100).round();
    final Color color;
    if (rate >= 80) {
      color = AppColors.success;
    } else if (rate >= 60) {
      color = AppColors.warning;
    } else {
      color = AppColors.error;
    }

    return _KpiCard(
      icon: Icons.verified_outlined,
      color: color,
      title: l10n.reportsPmCompliance,
      value: '$rate%',
      subtitle: l10n.reportsPmTotal(pmTotal),
    );
  }

  // ── Top 3 départements impactés ───────────────────────────────────────────

  Widget _buildTopDeptsCard(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bar_chart, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.reportsTopDepts,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        l10n.reportsTopDeptsHint,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (topDepartments.isEmpty)
              Text(
                l10n.reportsTopDeptsEmpty,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              )
            else
              ...topDepartments.asMap().entries.map((entry) {
                final rank  = entry.key + 1;
                final dept  = entry.value;
                final Color rankColor;
                switch (rank) {
                  case 1: rankColor = AppColors.error;   break;
                  case 2: rankColor = AppColors.warning; break;
                  default: rankColor = AppColors.textSecondary;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: rankColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              color: rankColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          dept.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: rankColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${dept.value}',
                          style: TextStyle(
                            color: rankColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
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
}

// ── KPI Card générique ────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.all(20),
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
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
