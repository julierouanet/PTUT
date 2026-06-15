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
    double maintenanceCost = 0,
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
                  'Priorité à la durée réelle saisie dans les rapports d\'intervention '
                  'finalisés (duration_hours). À défaut : délai taken_at − created_at '
                  'sur les incidents clôturés (Completed / Verified / Closed).',
                  style: const pw.TextStyle(fontSize: 7, color: _textMuted),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Coût de maintenance (période) : ${maintenanceCost.toStringAsFixed(0)} RWF',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: maintenanceCost > 0 ? _primary : _textMuted,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Somme des coûts estimés (estimated_cost) des rapports d\'intervention '
                  'finalisés sur la période.',
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

  // ── Rapport « Plan de remplacement biomédical » (RA3 S5) ────────────────────

  /// Construit le PDF du plan de remplacement à partir de la réponse serveur
  /// ({ summary, items } de GET /api/equipment/replacement-plan).
  static Future<Uint8List> generateReplacementPlan({
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> items,
    required String generatedByName,
    required String generatedByRole,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();

    final biomedicalCount = (summary['biomedical_count'] as num?)?.toInt() ?? 0;
    final avgAge          = (summary['avg_age_years'] as num?)?.toDouble() ?? 0;
    final eolCount        = (summary['end_of_life_count'] as num?)?.toInt() ?? 0;
    final eolPct          = (summary['end_of_life_pct'] as num?)?.toDouble() ?? 0;
    final byHorizon       = (summary['by_horizon'] as Map?) ?? const {};
    final byCriticality   = (summary['by_criticality'] as Map?) ?? const {};

    int h(String k) => (byHorizon[k] as num?)?.toInt() ?? 0;
    int c(String k) => (byCriticality[k] as num?)?.toInt() ?? 0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        header: (context) => _buildReplacementHeader(now, generatedByName, generatedByRole),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // ── Section 1 : KPI de flotte ─────────────────────────────────
          _sectionTitle('1. SYNTHÈSE DE LA FLOTTE BIOMÉDICALE'),
          pw.Row(children: [
            pw.Expanded(child: _kpiBox('Équipements biomédicaux', '$biomedicalCount', _primary)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('Âge moyen (ans)', avgAge.toStringAsFixed(1), _primary)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('En fin de vie', '$eolCount', eolCount > 0 ? _error : _success)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('% en fin de vie', '${eolPct.toStringAsFixed(1)}%',
                eolPct >= 20 ? _error : _warning)),
          ]),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _subTitle('Par horizon budgétaire'),
                    _statLine('Cette année',          h('cette_annee'),      biomedicalCount, _error),
                    _statLine('1–2 ans',              h('1_2_ans'),          biomedicalCount, _warning),
                    _statLine('Plus tard',            h('plus_tard'),        biomedicalCount, _success),
                    _statLine('Donnée manquante',     h('donnee_manquante'), biomedicalCount, _textMuted),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _subTitle('Par criticité (Matrice ABC)'),
                    _statLine('A — Critique',  c('A'), biomedicalCount, _error),
                    _statLine('B — Important', c('B'), biomedicalCount, _warning),
                    _statLine('C — Courant',   c('C'), biomedicalCount, _success),
                  ],
                ),
              ),
            ],
          ),

          // ── Section 2 : Tableau détaillé ──────────────────────────────
          _sectionTitle('2. PLAN DE REMPLACEMENT DÉTAILLÉ'),
          if (items.isEmpty)
            _greenBanner('Aucun équipement biomédical à planifier.')
          else
            _replacementTable(items),
        ],
      ),
    );

    return doc.save();
  }

  // ── Rapport d'intervention par incident ─────────────────────────────────────

  /// Construit le PDF d'un rapport d'intervention pour un incident donné.
  /// Reçoit le rapport (champs structurés + pré-remplissage live de l'incident)
  /// déjà chargé par l'écran — aucun appel API ici (génération 100% client).
  static Future<Uint8List> generateInterventionReport({
    required Map<String, dynamic> report,
    required String issueId,
    required String generatedByName,
    required String generatedByRole,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();

    String s(dynamic v) => (v == null || v.toString().isEmpty) ? '—' : v.toString();
    double? n(dynamic v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

    final equipmentName = s(report['equipment_name']);
    final equipmentId   = report['equipment_id'] as String?;
    final issueStatus   = s(report['issue_status']);
    final isFinalized   = (report['report_status'] as String?) == 'finalized';

    final durationHours = n(report['duration_hours']);
    final estimatedCost = n(report['estimated_cost']);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        header: (context) => _buildInterventionHeader(now, generatedByName, generatedByRole, isFinalized),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // ── Section 1 : Identité incident + équipement ─────────────────
          _sectionTitle('1. INCIDENT & ÉQUIPEMENT'),
          _twoColTextTable([
            MapEntry('Référence incident', issueId),
            MapEntry('Équipement', equipmentName),
            if (equipmentId != null) MapEntry('Identifiant équipement', equipmentId),
            MapEntry('Statut incident', issueStatus),
          ]),

          // ── Section 2 : Diagnostic & actions (live incident) ────────────
          _sectionTitle('2. DIAGNOSTIC, ACTIONS & PIÈCES'),
          _labelledBlock('Diagnostic', s(report['diagnosis'])),
          _labelledBlock('Actions réalisées', s(report['actions'])),
          _labelledBlock('Pièces remplacées', s(report['parts_replaced'])),

          // ── Section 3 : Rapport structuré ──────────────────────────────
          _sectionTitle('3. RAPPORT D\'INTERVENTION'),
          _labelledBlock('Résumé', s(report['summary'])),
          _labelledBlock('Cause racine', s(report['root_cause'])),
          _labelledBlock('Recommandations', s(report['recommendations'])),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Expanded(child: _kpiBox('Durée (heures)',
                durationHours == null ? 'N/A' : durationHours.toStringAsFixed(1), _primary)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('Coût estimé (RWF)',
                estimatedCost == null ? 'N/A' : estimatedCost.toStringAsFixed(0), _warning)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('État final équipement',
                s(report['final_equipment_status']), _success)),
          ]),
          pw.SizedBox(height: 6),
          _twoColTextTable([
            MapEntry('Remise en service le', s(report['returned_to_service_at'])),
          ]),

          // ── Section 4 : Signatures ─────────────────────────────────────
          _sectionTitle('4. VALIDATION'),
          _twoColTextTable([
            MapEntry('Rédigé par', s(report['author_name'])),
            MapEntry('Validé par', s(report['validated_by_name'])),
            MapEntry('Date de validation', s(report['validated_at'])),
            MapEntry('Statut du rapport', isFinalized ? 'Finalisé' : 'Brouillon'),
          ]),
        ],
      ),
    );

    return doc.save();
  }

  // En-tête dédié du rapport d'intervention
  static pw.Widget _buildInterventionHeader(DateTime now, String byName, String byRole, bool isFinalized) {
    return pw.Column(children: [
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
                pw.Text('RAPPORT D\'INTERVENTION',
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Hôpital de District de Kabutare — Rwanda',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 8)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Généré le ${_fmtDate(now)} à ${_fmtTime(now)}',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text('Par : $byName  ($byRole)',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text(isFinalized ? 'Statut : FINALISÉ' : 'Statut : BROUILLON',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
    ]);
  }

  // Tableau libellé / valeur texte (2 colonnes)
  static pw.Widget _twoColTextTable(List<MapEntry<String, String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(4),
      },
      children: rows
          .map((e) => pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  child: pw.Text(e.key,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  child: pw.Text(e.value, style: const pw.TextStyle(fontSize: 8)),
                ),
              ]))
          .toList(),
    );
  }

  // Bloc « libellé + texte multi-ligne »
  static pw.Widget _labelledBlock(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _subTitle(label),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: _bgLight,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
          ),
        ],
      ),
    );
  }

  // En-tête dédié du plan de remplacement (sans période)
  static pw.Widget _buildReplacementHeader(DateTime now, String byName, String byRole) {
    return pw.Column(children: [
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
                pw.Text('PLAN DE REMPLACEMENT — ÉQUIPEMENTS BIOMÉDICAUX',
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Hôpital de District de Kabutare — Rwanda — Standard RA3 S5',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 8)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Généré le ${_fmtDate(now)} à ${_fmtTime(now)}',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text('Par : $byName  ($byRole)',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
    ]);
  }

  // Libellés français des statuts / horizons de remplacement
  static String _replacementStatusLabel(String s) => switch (s) {
        'a_remplacer'      => 'À remplacer',
        'bientot'          => 'Bientôt',
        'donnee_manquante' => 'Donnée manquante',
        _                  => 'OK',
      };

  static String _replacementHorizonLabel(String? hz) => switch (hz) {
        'cette_annee' => 'Cette année',
        '1_2_ans'     => '1–2 ans',
        'plus_tard'   => 'Plus tard',
        _             => '—',
      };

  // Tableau détaillé du plan de remplacement
  static pw.Widget _replacementTable(List<Map<String, dynamic>> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),   // Nom
        1: pw.FlexColumnWidth(2),   // Sous-cat
        2: pw.FlexColumnWidth(1),   // Criticité
        3: pw.FlexColumnWidth(1),   // Âge
        4: pw.FlexColumnWidth(1),   // Durée réf
        5: pw.FlexColumnWidth(1),   // Dépassement
        6: pw.FlexColumnWidth(2),   // Statut
        7: pw.FlexColumnWidth(2),   // Horizon
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _bgLight),
          children: [
            _th('Équipement'), _th('Sous-catégorie'), _th('Crit.'),
            _th('Âge'), _th('Réf.'), _th('Dépass.'), _th('Statut'), _th('Horizon'),
          ],
        ),
        ...items.map((m) {
          final status   = m['status_replacement'] as String? ?? 'ok';
          final age      = (m['age'] as num?)?.toInt();
          final lifespan = (m['lifespan'] as num?)?.toInt();
          final over     = (m['overshoot'] as num?)?.toInt();
          final color = status == 'a_remplacer'
              ? _error
              : status == 'bientot'
                  ? _warning
                  : status == 'donnee_manquante'
                      ? _textMuted
                      : _success;
          return pw.TableRow(children: [
            _td(m['name'] as String? ?? '—'),
            _td(m['subcategory'] as String? ?? '—'),
            _td(m['criticality'] as String? ?? '—'),
            _td(age?.toString() ?? '—'),
            _td(lifespan?.toString() ?? '—'),
            _td(over == null ? '—' : (over > 0 ? '+$over' : '$over')),
            _td(_replacementStatusLabel(status), bold: true, color: color),
            _td(_replacementHorizonLabel(m['horizon'] as String?)),
          ]);
        }),
      ],
    );
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
