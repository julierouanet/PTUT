import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/equipment.dart';
import '../models/inventory_item.dart';
import '../models/issue.dart';

/// Génère un rapport PDF GMAO pour l'Hôpital de District de Kabutare.
///
/// Toutes les données sont passées en paramètre depuis [ReportsScreen] —
/// aucun appel API supplémentaire (Option B : génération 100% côté client).
class PdfReportService {
  // Palette de couleurs du rapport
  static const _primary   = PdfColors.blue800;
  static const _success   = PdfColors.green800;
  static const _warning   = PdfColors.orange800;
  static const _error     = PdfColors.red800;
  static const _bgLight   = PdfColors.grey100;
  static const _border    = PdfColors.grey300;
  static const _textMuted = PdfColors.grey600;

  // ── API publique ───────────────────────────────────────────────────────────

  /// Construit et retourne les octets du PDF.
  static Future<Uint8List> generate({
    required DateTime startDate,
    required DateTime endDate,
    required String generatedByName,
    required String generatedByRole,
    required List<Equipment> allEquipment,
    required List<Issue> periodIssues,
    required double? mttrDays,
    required int pmCompliant,
    required int pmTotal,
    required List<MapEntry<String, int>> topDepartments,
    required List<InventoryItem> inventory,
  }) async {
    final doc  = pw.Document();
    final now  = DateTime.now();

    // ── Calculs dérivés ──────────────────────────────────────────────────────

    final totalEquip    = allEquipment.length;
    final operational   = allEquipment.where((e) => e.status == EquipmentStatus.operational).length;
    final maintenance   = allEquipment.where((e) => e.status == EquipmentStatus.maintenance).length;
    final outOfService  = allEquipment.where((e) => e.status == EquipmentStatus.outOfService).length;
    final toBeDisposal  = allEquipment.where((e) => e.status == EquipmentStatus.toBeDisposal).length;
    final availRate     = totalEquip == 0 ? 0 : (operational / totalEquip * 100).round();

    // Équipements par département (top 10)
    final byDept = <String, int>{};
    for (final eq in allEquipment) {
      byDept[eq.department] = (byDept[eq.department] ?? 0) + 1;
    }
    final topEquipDepts = (byDept.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))
        .take(10)
        .toList();

    // Équipements par catégorie (top 8)
    final byCat = <String, int>{};
    for (final eq in allEquipment) {
      byCat[eq.category] = (byCat[eq.category] ?? 0) + 1;
    }
    final topEquipCats = (byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))
        .take(8)
        .toList();

    // Incidents
    final totalIssues   = periodIssues.length;
    final openIssues    = periodIssues.where((i) => i.status == IssueStatus.reported).length;
    final resolvedIssues = periodIssues.where((i) =>
        i.status == IssueStatus.completed ||
        i.status == IssueStatus.verified  ||
        i.status == IssueStatus.closed).length;
    final inProgress    = (totalIssues - openIssues - resolvedIssues).clamp(0, totalIssues);
    final resolutionRate = totalIssues == 0 ? 0 : (resolvedIssues / totalIssues * 100).round();

    final critiqueCount = periodIssues.where((i) => i.urgency == IssueUrgency.critique).length;
    final urgentCount   = periodIssues.where((i) => i.urgency == IssueUrgency.urgent).length;
    final moyenCount    = periodIssues.where((i) => i.urgency == IssueUrgency.moyen).length;
    final faibleCount   = periodIssues.where((i) => i.urgency == IssueUrgency.faible).length;

    final bioCount   = periodIssues.where((i) => i.issueCategory == 'Biomedical').length;
    final infraCount = periodIssues.where((i) => i.issueCategory == 'Infrastructure').length;
    final itCount    = periodIssues.where((i) => i.issueCategory == 'IT').length;

    // PM
    final pmOverdue  = pmTotal - pmCompliant;
    final todayDate  = DateTime(now.year, now.month, now.day);
    final in30Days   = todayDate.add(const Duration(days: 30));
    final pmSoonCount = allEquipment.where((e) {
      if ((e.nextPreventiveMaintenance?.length ?? 0) < 10) return false;
      try {
        final next = DateTime.parse(e.nextPreventiveMaintenance!.substring(0, 10));
        return !next.isBefore(todayDate) && next.isBefore(in30Days);
      } catch (_) {
        return false;
      }
    }).length;

    // Inventaire
    final outOfStockItems = inventory.where((i) => i.status == StockStatus.outOfStock).toList();
    final lowStockItems   = inventory.where((i) => i.status == StockStatus.low).toList();

    // ── Document PDF ─────────────────────────────────────────────────────────

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        header: (context) => _buildHeader(now, startDate, endDate, generatedByName, generatedByRole),
        footer: (context) => _buildFooter(context),
        build: (context) => [

          // ── Section 1 : Synthèse générale ──────────────────────────────
          _sectionTitle('1. SYNTHÈSE GÉNÉRALE'),
          pw.Row(
            children: [
              pw.Expanded(child: _kpiBox('Total Équipements', '$totalEquip', _primary)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox('Taux de Disponibilité', '$availRate%', _success)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox('Incidents (période)', '$totalIssues', _warning)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox('Taux de Résolution', '$resolutionRate%',
                  resolutionRate >= 70 ? _success : _warning)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox(
                'MTTR (jours)',
                mttrDays == null ? 'N/A' : mttrDays.toStringAsFixed(1),
                mttrDays == null ? _textMuted : (mttrDays > 3 ? _warning : _success),
              )),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox(
                'Conformité PM',
                pmTotal == 0 ? 'N/A' : '${(pmCompliant / pmTotal * 100).round()}%',
                pmTotal > 0 && pmCompliant / pmTotal >= 0.8 ? _success : _warning,
              )),
            ],
          ),

          // ── Section 2 : Équipements ─────────────────────────────────────
          _sectionTitle('2. ÉQUIPEMENTS — ÉTAT COURANT (${_fmtDate(now)})'),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Répartition par statut
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _subTitle('Répartition par statut'),
                    _statLine('Opérationnel',   operational,  totalEquip, _success),
                    _statLine('En maintenance', maintenance,  totalEquip, _warning),
                    _statLine('Hors service',   outOfService, totalEquip, _error),
                    _statLine('À éliminer',     toBeDisposal, totalEquip, _textMuted),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              // Top 10 départements
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _subTitle('Équipements par département (top 10)'),
                    _twoColTable(topEquipDepts, unitSuffix: ''),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _subTitle('Répartition par catégorie (top 8)'),
          _twoColTable(topEquipCats, unitSuffix: ''),

          // ── Section 3 : Incidents de la période ─────────────────────────
          _sectionTitle(
            '3. INCIDENTS — PÉRIODE ${_fmtDate(startDate)} → ${_fmtDate(endDate)}',
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _subTitle('Par statut'),
                    _statLine('Ouverts (signalés)', openIssues,     totalIssues, _error),
                    _statLine('En cours',           inProgress,     totalIssues, _warning),
                    _statLine('Résolus',            resolvedIssues, totalIssues, _success),
                    pw.SizedBox(height: 8),
                    _subTitle('Par urgence'),
                    _statLine('Critique', critiqueCount, totalIssues, _error),
                    _statLine('Urgent',   urgentCount,   totalIssues, PdfColors.deepOrange),
                    _statLine('Moyen',    moyenCount,    totalIssues, _warning),
                    _statLine('Faible',   faibleCount,   totalIssues, _success),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _subTitle('Par catégorie technique'),
                    _statLine('Biomédical',    bioCount,   totalIssues, PdfColors.blue),
                    _statLine('Infrastructure', infraCount, totalIssues, PdfColors.teal),
                    _statLine('IT',             itCount,    totalIssues, PdfColors.purple),
                    pw.SizedBox(height: 8),
                    _subTitle('Départements les plus impactés'),
                    if (topDepartments.isEmpty)
                      pw.Text('Aucun incident sur la période',
                          style: pw.TextStyle(fontSize: 8, color: _textMuted))
                    else
                      _twoColTable(topDepartments, unitSuffix: ' inc.'),
                  ],
                ),
              ),
            ],
          ),

          // ── Section 4 : Maintenance Préventive ──────────────────────────
          _sectionTitle('4. MAINTENANCE PRÉVENTIVE (PM)'),
          pw.Row(
            children: [
              pw.Expanded(child: _kpiBox('Équipements avec PM', '$pmTotal', _primary)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox(
                'Conformité PM',
                pmTotal == 0 ? 'N/A' : '${(pmCompliant / pmTotal * 100).round()}%',
                pmTotal > 0 && pmCompliant / pmTotal >= 0.8 ? _success : _warning,
              )),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox('PM en retard',
                  '$pmOverdue', pmOverdue > 0 ? _error : _success)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox('PM imminentes (<30j)',
                  '$pmSoonCount', pmSoonCount > 0 ? _warning : _success)),
            ],
          ),

          // ── Section 5 : KPI GMAO — MTTR ─────────────────────────────────
          _sectionTitle('5. KPI GMAO — MTTR (Mean Time To Repair)'),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _bgLight,
              border: pw.Border.all(color: _border),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  mttrDays == null
                      ? 'MTTR : Données insuffisantes '
                        '(aucun incident clôturé avec date de prise en charge sur la période)'
                      : 'MTTR approximé sur la période : ${mttrDays.toStringAsFixed(1)} jour(s)',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: mttrDays == null
                        ? _textMuted
                        : (mttrDays > 3 ? _warning : _success),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Calculé sur les incidents clôturés (Completed / Verified / Closed) '
                  'ayant une date de prise en charge (taken_at) enregistrée. '
                  'Délai = taken_at − created_at. '
                  'Un MTTR strict nécessiterait un champ resolved_at côté backend.',
                  style: const pw.TextStyle(fontSize: 7, color: _textMuted),
                ),
              ],
            ),
          ),

          // ── Section 6 : Inventaire critique ─────────────────────────────
          _sectionTitle('6. INVENTAIRE CRITIQUE'),
          if (outOfStockItems.isEmpty && lowStockItems.isEmpty)
            _greenBanner('Aucun article en rupture ou en alerte de stock.')
          else ...[
            if (outOfStockItems.isNotEmpty) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
                child: pw.Text(
                  'Articles en rupture de stock (${outOfStockItems.length})',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _error),
                ),
              ),
              _inventoryTable(outOfStockItems, _error),
            ],
            if (lowStockItems.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  'Articles en stock faible (${lowStockItems.length})',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _warning),
                ),
              ),
              _inventoryTable(lowStockItems, _warning),
            ],
          ],
        ],
      ),
    );

    return doc.save();
  }

  // ── Helpers de structure PDF ───────────────────────────────────────────────

  static pw.Widget _buildHeader(
    DateTime now,
    DateTime start,
    DateTime end,
    String byName,
    String byRole,
  ) {
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const pw.BoxDecoration(
            color: _primary,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RAPPORT DE MAINTENANCE — GMAO',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Hôpital de District de Kabutare — Rwanda',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 8),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Généré le ${_fmtDate(now)} à ${_fmtTime(now)}',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7),
                  ),
                  pw.Text(
                    'Par : $byName  ($byRole)',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7),
                  ),
                  pw.Text(
                    'Période : ${_fmtDate(start)} → ${_fmtDate(end)}',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border)),
      ),
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Hôpital de Kabutare — Document confidentiel à usage interne',
            style: const pw.TextStyle(fontSize: 7, color: _textMuted),
          ),
          pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: _textMuted),
          ),
        ],
      ),
    );
  }

  // Titre de section coloré
  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const pw.BoxDecoration(
        color: _primary,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  // Sous-titre en gras
  static pw.Widget _subTitle(String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(label,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    );
  }

  // Boîte KPI avec valeur + libellé
  static pw.Widget _kpiBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 7, color: _textMuted)),
        ],
      ),
    );
  }

  // Ligne de statistique avec pastille colorée
  static pw.Widget _statLine(
      String label, int count, int total, PdfColor color) {
    final pct = total == 0 ? 0 : (count / total * 100).round();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Container(
            width: 8,
            height: 8,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          ),
          pw.Text(
            '$count  ($pct%)',
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: color),
          ),
        ],
      ),
    );
  }

  // Tableau à 2 colonnes (libellé / valeur)
  static pw.Widget _twoColTable(
      List<MapEntry<String, int>> entries,
      {required String unitSuffix}) {
    if (entries.isEmpty) {
      return pw.Text('Aucune donnée',
          style: const pw.TextStyle(fontSize: 8, color: _textMuted));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: _border),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1),
      },
      children: entries.map((e) {
        return pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: pw.Text(e.key,
                style: const pw.TextStyle(fontSize: 8)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: pw.Text('${e.value}$unitSuffix',
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right),
          ),
        ]);
      }).toList(),
    );
  }

  // Tableau des articles d'inventaire
  static pw.Widget _inventoryTable(
      List<InventoryItem> items, PdfColor accentColor) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _bgLight),
          children: [
            _th('Article'),
            _th('Stock actuel'),
            _th('Stock min'),
          ],
        ),
        ...items.map((item) => pw.TableRow(children: [
              _td(item.name),
              _td('${item.currentStock} ${item.unit}',
                  bold: true, color: accentColor),
              _td('${item.minStock} ${item.unit}'),
            ])),
      ],
    );
  }

  // Bannière verte (inventaire OK)
  static pw.Widget _greenBanner(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: _success),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 9, color: _success)),
    );
  }

  // Cellule d'en-tête de tableau
  static pw.Widget _th(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
    );
  }

  // Cellule de corps de tableau
  static pw.Widget _td(String text,
      {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  // ── Utilitaires de formatage ───────────────────────────────────────────────

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
