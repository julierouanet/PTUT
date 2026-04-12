import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // ─── Export PDF — IDENTIQUE À L'ORIGINAL, seules les couleurs changent ───
  Future<void> _generatePDF(BuildContext context) async {
    final total = DataService().equipment.length;
    final disponible = DataService().equipment.where((e) => e.status == EquipmentStatus.disponible).length;
    final enUsage = DataService().equipment.where((e) => e.status == EquipmentStatus.enUsage).length;
    final enMaintenance = DataService().equipment.where((e) => e.status == EquipmentStatus.enMaintenance).length;
    final horsService = DataService().equipment.where((e) => e.status == EquipmentStatus.horsService).length;
    final totalIssues = DataService().issues.length;
    final openIssues = DataService().issues.where((i) => i.status.displayName == 'Ouvert').length;
    final inProgressIssues = DataService().issues.where((i) => i.status.displayName == 'En cours').length;
    final resolvedIssues = DataService().issues.where((i) => i.status.displayName == 'Resolu').length;
    final availabilityRate = total > 0 ? ((disponible + enUsage) / total * 100).round() : 0;

    final byDepartment = <String, int>{};
    for (final eq in DataService().equipment) {
      byDepartment[eq.department] = (byDepartment[eq.department] ?? 0) + 1;
    }

    final byType = <String, int>{};
    for (final issue in DataService().issues) {
      byType[issue.type] = (byType[issue.type] ?? 0) + 1;
    }
    final sortedTypes = byType.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sortedTypes.take(3).toList();

    // Charger le logo avec gestion d'erreur
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      print('Logo non trouvé: $e');
    }

    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    // ── PALETTE 60-30-10 PROFESSIONNELLE ──────────────────────────
    // 60% blanc — fond de page
    // 30% structure — bleu marine + gris pâle
    // 10% accents — couleurs fonctionnelles désaturées
    const navyBlue      = PdfColor.fromInt(0xFF1A2B4A); // en-têtes, bandes
    const structureGrey = PdfColor.fromInt(0xFFF2F4F7); // fond lignes alternées
    const borderGrey    = PdfColor.fromInt(0xFFD0D5DD); // bordures tableaux
    const textDark      = PdfColor.fromInt(0xFF1A1A2E); // titres
    const textMid       = PdfColor.fromInt(0xFF4A5568); // corps de texte
    const textLight     = PdfColor.fromInt(0xFF718096); // sous-titres, footer
    const accentBlue    = PdfColor.fromInt(0xFF2B6CB0); // chiffres clés
    const accentGreen   = PdfColor.fromInt(0xFF276749); // positif / disponible
    const accentOrange  = PdfColor.fromInt(0xFFC05621); // alertes / maintenance
    const accentRed     = PdfColor.fromInt(0xFF9B2335); // critique / hors service

    // ── PAGE DE COUVERTURE ────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context ctx) => pw.Stack(
          children: [
            pw.Container(color: PdfColors.white),

            // Bande marine en haut
            pw.Positioned(
              top: 0, left: 0, right: 0,
              child: pw.Container(height: 200, color: navyBlue),
            ),

            // Bande marine en bas
            pw.Positioned(
              bottom: 0, left: 0, right: 0,
              child: pw.Container(height: 80, color: navyBlue),
            ),

            // Contenu
            pw.Padding(
              padding: const pw.EdgeInsets.all(60),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SizedBox(height: 20),

                  // Logo
                  if (logoImage != null) pw.Image(logoImage, width: 100, height: 100),

                  pw.SizedBox(height: 16),

                  // Nom hôpital
                  pw.Text(
                    'Kabutare Hospital',
                    style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Republique du Rwanda',
                    style: const pw.TextStyle(fontSize: 14, color: PdfColors.white),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 80),

                  // Titre du rapport
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: navyBlue, width: 2),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'RAPPORT D\'ACTIVITES',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: navyBlue,
                            letterSpacing: 2,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Gestion des Equipements Medicaux',
                          style: pw.TextStyle(fontSize: 14, color: textMid),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 40),

                  // KPIs résumé
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: structureGrey,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _pdfCoverKpi('$total', 'Equipements', accentBlue),
                        _pdfCoverKpi('$availabilityRate%', 'Disponibilite', accentGreen),
                        _pdfCoverKpi('$totalIssues', 'Incidents', accentOrange),
                        _pdfCoverKpi('$resolvedIssues', 'Resolus', accentGreen),
                      ],
                    ),
                  ),

                  pw.Spacer(),

                  // Date en bas
                  pw.Text(
                    'Rapport genere le $dateStr',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // ── PAGES DE CONTENU ──────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 60),
        header: (pw.Context ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 16),
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const pw.BoxDecoration(
            color: navyBlue,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  if (logoImage != null) pw.Image(logoImage, width: 28, height: 28),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    'Kabutare Hospital — Gestion des Equipements',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  ),
                ],
              ),
              pw.Text(
                'Page ${ctx.pageNumber}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
              ),
            ],
          ),
        ),
        footer: (pw.Context ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: borderGrey)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Confidentiel — Usage interne uniquement', style: pw.TextStyle(fontSize: 8, color: textLight)),
              pw.Text(dateStr, style: pw.TextStyle(fontSize: 8, color: textLight)),
            ],
          ),
        ),
        build: (pw.Context ctx) => [

          // ── Section 1 ──
          _pdfSectionTitle('1. Resume executif', navyBlue),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: structureGrey,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: borderGrey),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfKpiBox('Total equipements', '$total', accentBlue),
                _pdfKpiBox('Taux de disponibilite', '$availabilityRate%', accentGreen),
                _pdfKpiBox('Incidents ouverts', '$openIssues', accentOrange),
                _pdfKpiBox('Incidents resolus', '$resolvedIssues', accentGreen),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // ── Section 2 ──
          _pdfSectionTitle('2. Repartition des statuts', navyBlue),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: borderGrey),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: navyBlue),
                children: [
                  _pdfTableHeader('Statut'),
                  _pdfTableHeader('Nombre'),
                  _pdfTableHeader('Pourcentage'),
                  _pdfTableHeader('Indicateur'),
                ],
              ),
              _pdfStatusRow('Disponible',     disponible,    total, accentGreen,  structureGrey),
              _pdfStatusRow('En usage',       enUsage,       total, accentBlue,   PdfColors.white),
              _pdfStatusRow('En maintenance', enMaintenance, total, accentOrange, structureGrey),
              _pdfStatusRow('Hors service',   horsService,   total, accentRed,    PdfColors.white),
            ],
          ),
          pw.SizedBox(height: 24),

          // ── Section 3 ──
          _pdfSectionTitle('3. Statistiques des incidents', navyBlue),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: borderGrey),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: navyBlue),
                children: [
                  _pdfTableHeader('Categorie'),
                  _pdfTableHeader('Nombre'),
                  _pdfTableHeader('Proportion'),
                ],
              ),
              _pdfIncidentRow('Total incidents', totalIssues,      totalIssues, textDark,    structureGrey),
              _pdfIncidentRow('Ouverts',         openIssues,       totalIssues, accentRed,   const PdfColor.fromInt(0xFFFFF0F0)),
              _pdfIncidentRow('En cours',        inProgressIssues, totalIssues, accentOrange,const PdfColor.fromInt(0xFFFFF8F0)),
              _pdfIncidentRow('Resolus',         resolvedIssues,   totalIssues, accentGreen, const PdfColor.fromInt(0xFFF0F7F0)),
            ],
          ),
          pw.SizedBox(height: 24),

          // ── Section 4 ──
          _pdfSectionTitle('4. Analyse des pannes recurrentes', navyBlue),
          pw.SizedBox(height: 8),
          pw.Text(
            'Identification des types de pannes les plus frequents pour cibler les actions preventives.',
            style: pw.TextStyle(fontSize: 10, color: textLight),
          ),
          pw.SizedBox(height: 12),
          if (top3.isEmpty)
            pw.Text('Aucune donnee disponible', style: pw.TextStyle(color: textLight))
          else
            pw.Table(
              border: pw.TableBorder.all(color: borderGrey),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: navyBlue),
                  children: [
                    _pdfTableHeader('Rang'),
                    _pdfTableHeader('Type de panne'),
                    _pdfTableHeader('Occurrences'),
                    _pdfTableHeader('Part (%)'),
                  ],
                ),
                ...top3.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final e = entry.value;
                  final pct = totalIssues > 0 ? (e.value / totalIssues * 100).round() : 0;
                  final rankColors = [accentRed, accentOrange, accentBlue];
                  final bgColors = [
                    const PdfColor.fromInt(0xFFFFF0F0),
                    const PdfColor.fromInt(0xFFFFF8F0),
                    structureGrey,
                  ];
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bgColors[entry.key]),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('#$rank', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: rankColors[entry.key]), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(e.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: textDark))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${e.value}', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: textMid))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('$pct%', textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: rankColors[entry.key]))),
                    ],
                  );
                }),
              ],
            ),
          pw.SizedBox(height: 24),

          // ── Section 5 ──
          _pdfSectionTitle('5. Equipements par departement', navyBlue),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: borderGrey),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: navyBlue),
                children: [
                  _pdfTableHeader('Departement'),
                  _pdfTableHeader('Equipements'),
                  _pdfTableHeader('Part (%)'),
                ],
              ),
              ...(byDepartment.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                .asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  final pct = total > 0 ? (e.value / total * 100).round() : 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: i.isEven ? structureGrey : PdfColors.white),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(e.key, style: pw.TextStyle(color: textDark))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${e.value}', textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: accentBlue))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('$pct%', textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(color: textMid))),
                    ],
                  );
                }),
            ],
          ),
          pw.SizedBox(height: 24),

          // ── Conclusion ──
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: structureGrey,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: navyBlue),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Conclusion',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                pw.SizedBox(height: 8),
                pw.Container(height: 2, color: accentBlue),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Ce rapport presente un taux de disponibilite de $availabilityRate% sur $total equipements enregistres. '
                  '${openIssues > 0 ? "$openIssues incident(s) ouvert(s) necessitent une attention immediate." : "Aucun incident ouvert a ce jour."} '
                  '${top3.isNotEmpty ? "Le type de panne le plus frequent est : ${top3.first.key} (${top3.first.value} occurrences)." : ""}',
                  style: pw.TextStyle(fontSize: 10, color: textMid),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // ── EXPORT — identique à l'original ──────────────────────────
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'rapport_kabutare_$dateStr.pdf',
    );
  }
}

// ── Helpers PDF ───────────────────────────────────────────────────────────────

pw.Widget _pdfCoverKpi(String value, String label, PdfColor color) {
  return pw.Column(
    children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: color)),
      pw.SizedBox(height: 4),
      pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
    ],
  );
}

pw.Widget _pdfSectionTitle(String title, PdfColor color) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: pw.BoxDecoration(
      border: pw.Border(left: pw.BorderSide(color: color, width: 4)),
      color: const PdfColor.fromInt(0xFFF2F4F7),
    ),
    child: pw.Text(
      title,
      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color),
    ),
  );
}

pw.Widget _pdfKpiBox(String label, String value, PdfColor color) {
  return pw.Column(
    children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: color)),
      pw.SizedBox(height: 4),
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
    ],
  );
}

pw.Widget _pdfTableHeader(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(text,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      textAlign: pw.TextAlign.center),
  );
}

pw.TableRow _pdfStatusRow(String label, int count, int total, PdfColor color, PdfColor bg) {
  final pct = total > 0 ? (count / total * 100).round() : 0;
  final barWidth = total > 0 ? count / total : 0.0;
  return pw.TableRow(
    decoration: pw.BoxDecoration(color: bg),
    children: [
      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(label)),
      pw.Padding(padding: const pw.EdgeInsets.all(8),
        child: pw.Text('$count', textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color))),
      pw.Padding(padding: const pw.EdgeInsets.all(8),
        child: pw.Text('$pct%', textAlign: pw.TextAlign.center)),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: pw.Stack(
          children: [
            pw.Container(height: 8, color: const PdfColor.fromInt(0xFFE0E0E0)),
            pw.Container(height: 8, width: 100 * barWidth, color: color),
          ],
        ),
      ),
    ],
  );
}

pw.TableRow _pdfIncidentRow(String label, int count, int total, PdfColor color, PdfColor bgColor) {
  final pct = total > 0 ? (count / total * 100).round() : 0;
  return pw.TableRow(
    decoration: pw.BoxDecoration(color: bgColor),
    children: [
      pw.Padding(padding: const pw.EdgeInsets.all(8),
        child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color))),
      pw.Padding(padding: const pw.EdgeInsets.all(8),
        child: pw.Text('$count', textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color))),
      pw.Padding(padding: const pw.EdgeInsets.all(8),
        child: pw.Text('$pct%', textAlign: pw.TextAlign.center)),
    ],
  );
}