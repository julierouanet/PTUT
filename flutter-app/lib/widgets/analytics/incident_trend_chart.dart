import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// Graphique linéaire — évolution des incidents signalés vs résolus sur 13 semaines glissantes.
class IncidentTrendChart extends StatefulWidget {
  /// 13 valeurs : index 0 = semaine la plus ancienne, 12 = semaine en cours.
  final List<int> createdPerWeek;
  final List<int> resolvedPerWeek;

  const IncidentTrendChart({
    super.key,
    required this.createdPerWeek,
    required this.resolvedPerWeek,
  });

  @override
  State<IncidentTrendChart> createState() => _IncidentTrendChartState();
}

class _IncidentTrendChartState extends State<IncidentTrendChart> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weekCount = widget.createdPerWeek.length.clamp(1, 13);

    // Plafond de l'axe Y avec marge minimale de 6
    final maxVal = [
      ...widget.createdPerWeek,
      ...widget.resolvedPerWeek,
    ].fold<int>(0, (m, v) => v > m ? v : m);
    final chartMaxY = (maxVal < 5 ? 6 : maxVal + 2).toDouble();
    final yInterval = (chartMaxY / 5).ceilToDouble().clamp(1.0, double.infinity);

    // Spots FlChart pour les deux courbes
    final createdSpots = List.generate(
      weekCount,
      (i) => FlSpot(i.toDouble(), widget.createdPerWeek[i].toDouble()),
    );
    final resolvedSpots = List.generate(
      weekCount,
      (i) => FlSpot(i.toDouble(), widget.resolvedPerWeek[i].toDouble()),
    );

    // Labels des semaines : date du lundi de chaque tranche de 7 jours
    final now = DateTime.now();
    final weekLabels = List.generate(weekCount, (i) {
      final monday = now.subtract(
        Duration(days: now.weekday - 1 + (weekCount - 1 - i) * 7),
      );
      return '${monday.day}/${monday.month}';
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.analyticsIncidentTrend,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            // Légende
            Row(
              children: [
                _LegendItem(color: AppColors.warning, label: l10n.analyticsCreatedSeries),
                const SizedBox(width: 20),
                _LegendItem(color: AppColors.success, label: l10n.analyticsResolvedSeries),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (weekCount - 1).toDouble(),
                  minY: 0,
                  maxY: chartMaxY,
                  clipData: const FlClipData.all(),
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
                        reservedSize: 28,
                        interval: 2,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= weekLabels.length || idx % 2 != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              weekLabels[idx],
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) =>
                          AppColors.textPrimary.withValues(alpha: 0.85),
                      getTooltipItems: (touchedSpots) =>
                          touchedSpots.map((spot) {
                        final label = spot.barIndex == 0
                            ? l10n.analyticsCreatedSeries
                            : l10n.analyticsResolvedSeries;
                        return LineTooltipItem(
                          '$label : ${spot.y.toInt()}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    // Courbe signalements
                    LineChartBarData(
                      spots: createdSpots,
                      isCurved: true,
                      color: AppColors.warning,
                      barWidth: 2.5,
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.warning.withValues(alpha: 0.07),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.warning,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        ),
                      ),
                    ),
                    // Courbe résolus
                    LineChartBarData(
                      spots: resolvedSpots,
                      isCurved: true,
                      color: AppColors.success,
                      barWidth: 2.5,
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.success.withValues(alpha: 0.07),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.success,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
