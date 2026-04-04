import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../models/equipment.dart';

/// Reports screen - view reports and analytics
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final total = DataService().equipment.length;
    final disponible = DataService().equipment.where((e) => e.status == EquipmentStatus.disponible).length;
    final enUsage = DataService().equipment.where((e) => e.status == EquipmentStatus.enUsage).length;
    final enMaintenance = DataService().equipment.where((e) => e.status == EquipmentStatus.enMaintenance).length;
    final horsService = DataService().equipment.where((e) => e.status == EquipmentStatus.horsService).length;

    // Équipements par département
    final byDepartment = <String, int>{};
    for (final eq in DataService().equipment) {
      byDepartment[eq.department] = (byDepartment[eq.department] ?? 0) + 1;
    }
    final sortedDepts = byDepartment.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Équipements par catégorie
    final byCategory = <String, int>{};
    for (final eq in DataService().equipment) {
      byCategory[eq.category] = (byCategory[eq.category] ?? 0) + 1;
    }

    // Statistiques incidents
    final totalIssues = DataService().issues.length;
    final openIssues = DataService().issues.where((i) => i.status.displayName == 'Ouvert').length;
    final resolvedIssues = DataService().issues.where((i) => i.status.displayName == 'Résolu').length;

    // Downtime analysis — top 3 types de pannes
    final byType = <String, int>{};
    for (final issue in DataService().issues) {
      byType[issue.type] = (byType[issue.type] ?? 0) + 1;
    }
    final sortedTypes = byType.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sortedTypes.take(3).toList();
    final totalForPareto = sortedTypes.fold(0, (sum, e) => sum + e.value);

    // Top équipements en panne
    final byEquipment = <String, int>{};
    for (final issue in DataService().issues) {
      byEquipment[issue.equipmentName] = (byEquipment[issue.equipmentName] ?? 0) + 1;
    }
    final sortedEquipment = byEquipment.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (isMobile) ...[
            Text(l10n.reportsTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(l10n.reportsSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _generatePDF(context),
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(l10n.reportsExport),
              ),
            ),
          ] else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.reportsTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(l10n.reportsSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _generatePDF(context),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(l10n.reportsExport),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                ),
              ],
            ),
          const SizedBox(height: 32),

          // Summary cards
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildSummaryCard(l10n.reportsTotalEquipment, '$total', Icons.inventory_2, AppColors.primary),
                  _buildSummaryCard(l10n.reportsAvailabilityRate, '${((disponible + enUsage) / total * 100).round()}%', Icons.check_circle, AppColors.success),
                  _buildSummaryCard(l10n.reportsTotalIssues, '$totalIssues', Icons.warning_amber, AppColors.warning),
                  _buildSummaryCard(l10n.reportsResolvedIssues, '$resolvedIssues', Icons.task_alt, AppColors.success),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Statuts + Départements
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildStatusReport(l10n, total, disponible, enUsage, enMaintenance, horsService)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildDepartmentReport(l10n, sortedDepts, byDepartment.length)),
                  ],
                );
              }
              return Column(children: [
                _buildStatusReport(l10n, total, disponible, enUsage, enMaintenance, horsService),
                const SizedBox(height: 24),
                _buildDepartmentReport(l10n, sortedDepts, byDepartment.length),
              ]);
            },
          ),
          const SizedBox(height: 24),

          // Catégories + Incidents
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildCategoryReport(l10n, byCategory)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildIssuesReport(l10n, totalIssues, openIssues, resolvedIssues)),
                  ],
                );
              }
              return Column(children: [
                _buildCategoryReport(l10n, byCategory),
                const SizedBox(height: 24),
                _buildIssuesReport(l10n, totalIssues, openIssues, resolvedIssues),
              ]);
            },
          ),
          const SizedBox(height: 24),

          // ── DOWNTIME ANALYSIS ──
          _buildDowntimeAnalysis(top3, sortedEquipment, totalForPareto, totalIssues),
        ],
      ),
    );
  }

  // ─── Downtime Analysis ───────────────────────────────────────
  Widget _buildDowntimeAnalysis(
    List<MapEntry<String, int>> top3,
    List<MapEntry<String, int>> sortedEquipment,
    int totalForPareto,
    int totalIssues,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analyse des pannes (Downtime)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text('Fréquence, causes et impact sur les équipements', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTop3Pannes(top3, totalForPareto)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildParetoRule(sortedEquipment, totalIssues)),
                ],
              );
            }
            return Column(children: [
              _buildTop3Pannes(top3, totalForPareto),
              const SizedBox(height: 24),
              _buildParetoRule(sortedEquipment, totalIssues),
            ]);
          },
        ),
      ],
    );
  }

  Widget _buildTop3Pannes(List<MapEntry<String, int>> top3, int total) {
    final colors = [AppColors.error, AppColors.warning, AppColors.primary];
    final medals = ['🥇', '🥈', '🥉'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top 3 des pannes récurrentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Types de problèmes les plus fréquents', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            if (top3.isEmpty)
              const Text('Aucune donnée disponible', style: TextStyle(color: AppColors.textSecondary))
            else
              ...top3.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final pct = total > 0 ? (e.value / total * 100).round() : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(medals[i], style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500))),
                          Text('${e.value} cas ($pct%)', style: TextStyle(color: colors[i], fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: total > 0 ? e.value / total : 0,
                        backgroundColor: colors[i].withValues(alpha: 0.1),
                        color: colors[i],
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

  Widget _buildParetoRule(List<MapEntry<String, int>> sortedEquipment, int totalIssues) {
    // Règle 80/20 — quels équipements génèrent 80% des incidents
    int cumul = 0;
    final paretoItems = <MapEntry<String, int>>[];
    for (final e in sortedEquipment) {
      cumul += e.value;
      paretoItems.add(e);
      if (totalIssues > 0 && cumul / totalIssues >= 0.8) break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Règle 80/20 — Équipements problématiques', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '${paretoItems.length} équipement(s) génèrent 80% des incidents',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            if (sortedEquipment.isEmpty)
              const Text('Aucune donnée disponible', style: TextStyle(color: AppColors.textSecondary))
            else
              ...paretoItems.map((e) {
                final pct = totalIssues > 0 ? (e.value / totalIssues * 100).round() : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                          Text('${e.value} ($pct%)', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: totalIssues > 0 ? e.value / totalIssues : 0,
                        backgroundColor: AppColors.errorLight,
                        color: AppColors.error,
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

  // ─── Widgets existants ────────────────────────────────────────
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusReport(AppLocalizations l10n, int total, int disponible, int enUsage, int enMaintenance, int horsService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reportsStatusBreakdown, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            _buildStatRow(l10n.reportsAvailable, disponible, total, AppColors.success),
            _buildStatRow(l10n.reportsInUse, enUsage, total, AppColors.primary),
            _buildStatRow(l10n.reportsInMaintenance, enMaintenance, total, AppColors.warning),
            _buildStatRow(l10n.reportsOutOfService, horsService, total, AppColors.error),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('($percentage%)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDepartmentReport(AppLocalizations l10n, List<MapEntry<String, int>> sortedDepts, int totalDepts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.reportsByDepartment, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                  child: Text('$totalDepts départements', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...sortedDepts.take(5).map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      value: sortedDepts.first.value > 0 ? e.value / sortedDepts.first.value : 0,
                      backgroundColor: AppColors.primaryLight,
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            )),
            if (sortedDepts.length > 5) ...[
              const SizedBox(height: 8),
              Text('+ ${sortedDepts.length - 5} autres départements', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryReport(AppLocalizations l10n, Map<String, int> byCategory) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reportsByCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            ...byCategory.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(12)),
                    child: Text('${e.value}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesReport(AppLocalizations l10n, int total, int open, int resolved) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reportsIssueStats, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            _buildStatRow(l10n.reportsOpenIssues, open, total, AppColors.error),
            _buildStatRow(l10n.reportsInProgressIssues, total - open - resolved, total, AppColors.warning),
            _buildStatRow(l10n.reportsResolvedIssuesLabel, resolved, total, AppColors.success),
          ],
        ),
      ),
    );
  }

  // ─── Export PDF ───────────────────────────────────────────────
  Future<void> _generatePDF(BuildContext context) async {
    final total = DataService().equipment.length;
    final disponible = DataService().equipment.where((e) => e.status == EquipmentStatus.disponible).length;
    final enUsage = DataService().equipment.where((e) => e.status == EquipmentStatus.enUsage).length;
    final enMaintenance = DataService().equipment.where((e) => e.status == EquipmentStatus.enMaintenance).length;
    final horsService = DataService().equipment.where((e) => e.status == EquipmentStatus.horsService).length;
    final totalIssues = DataService().issues.length;
    final openIssues = DataService().issues.where((i) => i.status.displayName == 'Ouvert').length;
    final resolvedIssues = DataService().issues.where((i) => i.status.displayName == 'Résolu').length;

    final byDepartment = <String, int>{};
    for (final eq in DataService().equipment) {
      byDepartment[eq.department] = (byDepartment[eq.department] ?? 0) + 1;
    }

    final byType = <String, int>{};
    for (final issue in DataService().issues) {
      byType[issue.type] = (byType[issue.type] ?? 0) + 1;
    }
    final sortedTypes = byType.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Rapport — Kabutare Hospital', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Gestion des équipements', style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey)),
                ],
              ),
              pw.Text('${now.day}/${now.month}/${now.year}', style: const pw.TextStyle(color: PdfColors.grey)),
            ],
          ),
          pw.Divider(),
          pw.SizedBox(height: 16),

          // Résumé
          pw.Text('Résumé général', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfStatBox('Total équipements', '$total'),
              _pdfStatBox('Disponibles', '$disponible'),
              _pdfStatBox('En maintenance', '$enMaintenance'),
              _pdfStatBox('Hors service', '$horsService'),
            ],
          ),
          pw.SizedBox(height: 24),

          // Statuts
          pw.Text('Répartition des statuts', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Statut', 'Nombre', 'Pourcentage'],
            data: [
              ['Disponible', '$disponible', '${total > 0 ? (disponible / total * 100).round() : 0}%'],
              ['En usage', '$enUsage', '${total > 0 ? (enUsage / total * 100).round() : 0}%'],
              ['En maintenance', '$enMaintenance', '${total > 0 ? (enMaintenance / total * 100).round() : 0}%'],
              ['Hors service', '$horsService', '${total > 0 ? (horsService / total * 100).round() : 0}%'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            cellPadding: const pw.EdgeInsets.all(8),
          ),
          pw.SizedBox(height: 24),

          // Incidents
          pw.Text('Statistiques incidents', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Type', 'Nombre'],
            data: [
              ['Total incidents', '$totalIssues'],
              ['Ouverts', '$openIssues'],
              ['En cours', '${totalIssues - openIssues - resolvedIssues}'],
              ['Résolus', '$resolvedIssues'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            cellPadding: const pw.EdgeInsets.all(8),
          ),
          pw.SizedBox(height: 24),

          // Top 3 pannes
          pw.Text('Top 3 des pannes récurrentes', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Rang', 'Type de panne', 'Nombre', 'Pourcentage'],
            data: sortedTypes.take(3).toList().asMap().entries.map((entry) {
              final rank = ['🥇', '🥈', '🥉'][entry.key];
              final e = entry.value;
              final pct = totalIssues > 0 ? (e.value / totalIssues * 100).round() : 0;
              return [rank, e.key, '${e.value}', '$pct%'];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            cellPadding: const pw.EdgeInsets.all(8),
          ),
          pw.SizedBox(height: 24),

          // Départements
          pw.Text('Équipements par département', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Département', "Nombre d'équipements"],
            data: (byDepartment.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              .map((e) => [e.key, '${e.value}']).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
            cellPadding: const pw.EdgeInsets.all(8),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'rapport_kabutare_${now.day}-${now.month}-${now.year}.pdf',
    );
  }

  pw.Widget _pdfStatBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
      ]),
    );
  }
}