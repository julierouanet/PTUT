import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// Histogramme — volume d'incidents traités par groupe technique.
///
/// Clés attendues dans [issuesByGroup] : 'Biomédical', 'IT', 'Infrastructure'.
/// Toute clé non reconnue est agrégée sous 'Autre'.
class ResolutionBarChart extends StatefulWidget {
  final Map<String, int> issuesByGroup;

  const ResolutionBarChart({super.key, required this.issuesByGroup});

  @override
  State<ResolutionBarChart> createState() => _ResolutionBarChartState();
}

class _ResolutionBarChartState extends State<ResolutionBarChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Couleur indigo pour le groupe IT (hors palette AppColors)
    const colorIT = Color(0xFF6366F1);

    final groups = [
      _GroupDef('Biomédical',     l10n.analyticsGroupBiomedical, AppColors.primary),
      _GroupDef('IT',             l10n.analyticsGroupIT,          colorIT),
      _GroupDef('Infrastructure', l10n.analyticsGroupInfra,       AppColors.warning),
      _GroupDef('Autre',          l10n.analyticsGroupOther,       AppColors.textSecondary),
    ];

    // Agrégation des clés inconnues dans 'Autre'
    final counts = <String, int>{
      'Biomédical': 0,
      'IT': 0,
      'Infrastructure': 0,
      'Autre': 0,
    };
    widget.issuesByGroup.forEach((key, val) {
      if (counts.containsKey(key)) {
        counts[key] = (counts[key] ?? 0) + val;
      } else {
        counts['Autre'] = (counts['Autre'] ?? 0) + val;
      }
    });

    final maxVal = counts.values.fold<int>(0, (m, v) => v > m ? v : m);
    final chartMaxY = (maxVal < 5 ? 6 : maxVal + 2).toDouble();
    final yInterval = (chartMaxY / 5).ceilToDouble().clamp(1.0, double.infinity);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.analyticsGroupBarTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: chartMaxY,
                  barTouchData: BarTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        _touchedIndex =
                            response?.spot?.touchedBarGroupIndex ?? -1;
                      });
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) =>
                          AppColors.textPrimary.withValues(alpha: 0.85),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final g = groups[groupIndex];
                        return BarTooltipItem(
                          '${g.label}\n${rod.toY.toInt()}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yInterval,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.border.withValues(alpha: 0.6),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border),
                      left: BorderSide(color: AppColors.border),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: yInterval,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= groups.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              groups[idx].label,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(groups.length, (i) {
                    final g = groups[i];
                    final count = (counts[g.key] ?? 0).toDouble();
                    final selected = _touchedIndex == i;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: count,
                          color: selected
                              ? g.color
                              : g.color.withValues(alpha: 0.72),
                          width: 36,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupDef {
  final String key;
  final String label;
  final Color color;
  const _GroupDef(this.key, this.label, this.color);
}
