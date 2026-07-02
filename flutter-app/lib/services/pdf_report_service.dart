import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/equipment.dart';
import '../models/equipment_document.dart';
import '../models/equipment_final_report.dart';
import '../models/inventory_item.dart';
import '../models/issue.dart';
import '../models/issue_intervention_report.dart';
import '../models/issue_intervention_session.dart';
import '../models/issue_photo.dart';

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

  /// Retourne une chaîne affichable pour une valeur potentiellement nulle/vide.
  /// Utilisé dans toutes les méthodes de génération PDF pour éviter les champs vides.
  static String _s(dynamic v) => (v == null || v.toString().isEmpty) ? '—' : v.toString();

  /// Charge le logo de l'hôpital pour le letterhead (octets bruts, une fois par document).
  static Future<Uint8List> _loadLogo() async =>
      (await rootBundle.load('assets/images/logo_hopital.png')).buffer.asUint8List();

  /// Numéro de référence horodaté pour les rapports périodiques (préfixe + yyyyMMdd-HHmmss).
  static String _timestampedReportNo(String prefix, DateTime now) =>
      '$prefix-${DateFormat('yyyyMMdd-HHmmss').format(now)}';

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
    double? documentedClosureRatePct,
  }) async {
    final doc  = pw.Document();
    final now  = DateTime.now();
    final logo = pw.MemoryImage(await _loadLogo());
    final reportNo = _timestampedReportNo('RPT-MNT', now);

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
        header: (context) => _buildHeader(
            now, startDate, endDate, generatedByName, generatedByRole, logo, reportNo),
        footer: (context) => _buildFooter(context),
        build: (context) => [

          // ── Section 1 : Synthèse générale ──────────────────────────────
          _sectionTitle('1. GENERAL SUMMARY'),
          pw.Row(
            children: [
              pw.Expanded(child: _kpiBox('Total Equipment', '$totalEquip', _primary)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox('Availability Rate', '$availRate%', _success)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox('Incidents (period)', '$totalIssues', _warning)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox('Resolution Rate', '$resolutionRate%',
                  resolutionRate >= 70 ? _success : _warning)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox(
                'MTTR (days)',
                mttrDays == null ? 'N/A' : mttrDays.toStringAsFixed(1),
                mttrDays == null ? _textMuted : (mttrDays > 3 ? _warning : _success),
              )),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox(
                'PM Compliance',
                pmTotal == 0 ? 'N/A' : '${(pmCompliant / pmTotal * 100).round()}%',
                pmTotal > 0 && pmCompliant / pmTotal >= 0.8 ? _success : _warning,
              )),
            ],
          ),

          // ── Section 2 : Équipements ─────────────────────────────────────
          _sectionTitle('2. EQUIPMENT — CURRENT STATUS (${_fmtDate(now)})'),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Répartition par statut
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _subTitle('Breakdown by status'),
                    _statLine('Operational',       operational,  totalEquip, _success),
                    _statLine('Under Maintenance',  maintenance,  totalEquip, _warning),
                    _statLine('Out of Service',     outOfService, totalEquip, _error),
                    _statLine('To Be Disposed',     toBeDisposal, totalEquip, _textMuted),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              // Top 10 départements
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _subTitle('Equipment by department (top 10)'),
                    _twoColTable(topEquipDepts, unitSuffix: ''),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _subTitle('Breakdown by category (top 8)'),
          _twoColTable(topEquipCats, unitSuffix: ''),

          // ── Section 3 : Incidents de la période ─────────────────────────
          _sectionTitle(
            '3. INCIDENTS — PERIOD ${_fmtDate(startDate)} → ${_fmtDate(endDate)}',
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _subTitle('By status'),
                    _statLine('Open (reported)', openIssues,     totalIssues, _error),
                    _statLine('In Progress',     inProgress,     totalIssues, _warning),
                    _statLine('Resolved',        resolvedIssues, totalIssues, _success),
                    pw.SizedBox(height: 8),
                    _subTitle('By urgency'),
                    _statLine('Critical', critiqueCount, totalIssues, _error),
                    _statLine('Urgent',   urgentCount,   totalIssues, PdfColors.deepOrange),
                    _statLine('Medium',   moyenCount,    totalIssues, _warning),
                    _statLine('Low',      faibleCount,   totalIssues, _success),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _subTitle('By technical category'),
                    _statLine('Biomedical',     bioCount,   totalIssues, PdfColors.blue),
                    _statLine('Infrastructure', infraCount, totalIssues, PdfColors.teal),
                    _statLine('IT',             itCount,    totalIssues, PdfColors.purple),
                    pw.SizedBox(height: 8),
                    _subTitle('Most impacted departments'),
                    if (topDepartments.isEmpty)
                      pw.Text('No incidents during this period',
                          style: pw.TextStyle(fontSize: 8, color: _textMuted))
                    else
                      _twoColTable(topDepartments, unitSuffix: ' inc.'),
                  ],
                ),
              ),
            ],
          ),

          // ── Section 4 : Maintenance Préventive ──────────────────────────
          _sectionTitle('4. PREVENTIVE MAINTENANCE (PM)'),
          pw.Row(
            children: [
              pw.Expanded(child: _kpiBox('Equipment with PM', '$pmTotal', _primary)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox(
                'PM Compliance',
                pmTotal == 0 ? 'N/A' : '${(pmCompliant / pmTotal * 100).round()}%',
                pmTotal > 0 && pmCompliant / pmTotal >= 0.8 ? _success : _warning,
              )),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox('Overdue PM',
                  '$pmOverdue', pmOverdue > 0 ? _error : _success)),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiBox('Upcoming PM (<30d)',
                  '$pmSoonCount', pmSoonCount > 0 ? _warning : _success)),
            ],
          ),

          // ── Section 5 : KPI GMAO — MTTR ─────────────────────────────────
          _sectionTitle('5. CMMS KPI — MTTR (Mean Time To Repair)'),
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
                      ? 'MTTR: Insufficient data '
                        '(no incident closed with a take-charge date during this period)'
                      : 'Approximate MTTR for the period: ${mttrDays.toStringAsFixed(1)} day(s)',
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
                  'Priority given to the actual duration entered in finalized intervention '
                  'reports (duration_hours). Otherwise: delay between taken_at and created_at '
                  'for closed incidents (Completed / Verified / Closed).',
                  style: const pw.TextStyle(fontSize: 7, color: _textMuted),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Maintenance cost (period): ${maintenanceCost.toStringAsFixed(0)} RWF',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: maintenanceCost > 0 ? _primary : _textMuted,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Sum of estimated costs (estimated_cost) from finalized intervention '
                  'reports during the period.',
                  style: const pw.TextStyle(fontSize: 7, color: _textMuted),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  documentedClosureRatePct == null
                      ? 'Documented closure rate: Insufficient data '
                        '(no incident closed during this period)'
                      : 'Documented closure rate: '
                        '${documentedClosureRatePct.toStringAsFixed(0)}%',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: documentedClosureRatePct == null
                        ? _textMuted
                        : (documentedClosureRatePct >= 80 ? _success : _warning),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Share of incidents closed (Completed / Verified / Closed) during the '
                  'period with at least one archived intervention PDF document.',
                  style: const pw.TextStyle(fontSize: 7, color: _textMuted),
                ),
              ],
            ),
          ),

          // ── Section 6 : Inventaire critique ─────────────────────────────
          _sectionTitle('6. CRITICAL INVENTORY'),
          if (outOfStockItems.isEmpty && lowStockItems.isEmpty)
            _greenBanner('No items out of stock or low on stock.')
          else ...[
            if (outOfStockItems.isNotEmpty) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
                child: pw.Text(
                  'Out of stock items (${outOfStockItems.length})',
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
                  'Low stock items (${lowStockItems.length})',
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
    final logo = pw.MemoryImage(await _loadLogo());
    final reportNo = _timestampedReportNo('RPT-RPL', now);

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
        header: (context) => _buildReplacementHeader(
            now, generatedByName, generatedByRole, logo, reportNo),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // ── Section 1 : KPI de flotte ─────────────────────────────────
          _sectionTitle('1. BIOMEDICAL FLEET SUMMARY'),
          pw.Row(children: [
            pw.Expanded(child: _kpiBox('Biomedical Equipment', '$biomedicalCount', _primary)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('Average Age (years)', avgAge.toStringAsFixed(1), _primary)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('End of Life', '$eolCount', eolCount > 0 ? _error : _success)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('% End of Life', '${eolPct.toStringAsFixed(1)}%',
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
                    _subTitle('By budget horizon'),
                    _statLine('This year',       h('cette_annee'),      biomedicalCount, _error),
                    _statLine('1–2 years',       h('1_2_ans'),          biomedicalCount, _warning),
                    _statLine('Later',           h('plus_tard'),        biomedicalCount, _success),
                    _statLine('Missing data',    h('donnee_manquante'), biomedicalCount, _textMuted),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _subTitle('By criticality (ABC Matrix)'),
                    _statLine('A — Critical',  c('A'), biomedicalCount, _error),
                    _statLine('B — Important', c('B'), biomedicalCount, _warning),
                    _statLine('C — Standard',  c('C'), biomedicalCount, _success),
                  ],
                ),
              ),
            ],
          ),

          // ── Section 2 : Tableau détaillé ──────────────────────────────
          _sectionTitle('2. DETAILED REPLACEMENT PLAN'),
          if (items.isEmpty)
            _greenBanner('No biomedical equipment to plan for.')
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
    List<EquipmentDocument> attachmentDocs = const [],
    List<IssuePhoto> attachmentPhotos = const [],
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final logo = pw.MemoryImage(await _loadLogo());
    final reportNo = 'INC-$issueId';

    double? n(dynamic v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

    final equipmentName = _s(report['equipment_name']);
    final equipmentId   = report['equipment_id'] as String?;
    final issueStatus   = _s(report['issue_status']);
    final isFinalized   = (report['report_status'] as String?) == 'finalized';

    final durationHours = n(report['duration_hours']);
    final estimatedCost = n(report['estimated_cost']);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        header: (context) => _buildInterventionHeader(
            now, generatedByName, generatedByRole, isFinalized, logo, reportNo),
        footer: (context) => _buildFooter(context, reference: 'Incident $issueId'),
        build: (context) => [
          // ── Section 1 : Identité incident + équipement ─────────────────
          _sectionTitle('1. INCIDENT & EQUIPMENT'),
          _twoColTextTable([
            MapEntry('Incident Reference', issueId),
            MapEntry('Equipment', equipmentName),
            if (equipmentId != null) MapEntry('Equipment ID', equipmentId),
            MapEntry('Incident Status', issueStatus),
          ]),

          // ── Section 2 : Diagnostic & actions (live incident) ────────────
          _sectionTitle('2. DIAGNOSIS & ACTIONS'),
          _labelledBlock('Diagnosis', _s(report['diagnosis'])),
          _labelledBlock('Actions taken', _s(report['actions'])),

          // ── Section 3 : Rapport structuré ──────────────────────────────
          _sectionTitle('3. INTERVENTION REPORT'),
          _labelledBlock('Summary', _s(report['summary'])),
          _labelledBlock('Root cause', _s(report['root_cause'])),
          _labelledBlock('Recommendations', _s(report['recommendations'])),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Expanded(child: _kpiBox('Duration (hours)',
                durationHours == null ? 'N/A' : durationHours.toStringAsFixed(1), _primary)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('Estimated cost (RWF)',
                estimatedCost == null ? 'N/A' : estimatedCost.toStringAsFixed(0), _warning)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('Final equipment status',
                _s(report['final_equipment_status']), _success)),
          ]),
          pw.SizedBox(height: 6),
          _twoColTextTable([
            MapEntry('Returned to service on', _s(report['returned_to_service_at'])),
          ]),

          // ── Section 4 : Signatures ─────────────────────────────────────
          _sectionTitle('4. VALIDATION'),
          _twoColTextTable([
            MapEntry('Drafted by', _s(report['author_name'])),
            MapEntry('Validated by', _s(report['validated_by_name'])),
            MapEntry('Validation date', _s(report['validated_at'])),
            MapEntry('Report status', isFinalized ? 'Finalized' : 'Draft'),
          ]),

          // ── Section 5 : Annexes (documents + photos) ────────────────────
          _sectionTitle('5. ATTACHMENTS'),
          attachmentDocs.isEmpty && attachmentPhotos.isEmpty
              ? pw.Text('No attachment recorded for this incident.',
                  style: const pw.TextStyle(fontSize: 8, color: _textMuted))
              : _attachmentsTable(attachmentDocs, attachmentPhotos),
        ],
      ),
    );

    return doc.save();
  }

  // Tableau des annexes (documents complémentaires + photos) d'un incident
  static pw.Widget _attachmentsTable(
      List<EquipmentDocument> docs, List<IssuePhoto> photos) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),   // Nom
        1: pw.FlexColumnWidth(1),   // Type
        2: pw.FlexColumnWidth(2),   // Date
        3: pw.FlexColumnWidth(2),   // Uploadeur
        4: pw.FlexColumnWidth(1),   // Taille
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _bgLight),
          children: [
            _th('Name'), _th('Type'), _th('Uploaded on'), _th('Uploaded by'), _th('Size (KB)'),
          ],
        ),
        ...docs.map((d) => pw.TableRow(children: [
              _td(d.originalName),
              _td('Document'),
              _td(_s(d.uploadedAt).split(' ').first),
              _td(_s(d.uploaderName)),
              _td(d.fileSizeKb.toString()),
            ])),
        ...photos.map((p) => pw.TableRow(children: [
              _td(p.originalName),
              _td('Photo'),
              _td(_s(p.uploadedAt).split(' ').first),
              _td('—'),
              _td(p.fileSizeKb.toString()),
            ])),
      ],
    );
  }

  // ── PDF par boucle d'intervention ───────────────────────────────────────────

  static Future<Uint8List> generateInterventionSessionReport({
    required IssueInterventionSession session,
    required String issueId,
    required String equipmentName,
    required String generatedByName,
    required String generatedByRole,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final logo = pw.MemoryImage(await _loadLogo());
    final reportNo = 'INC-$issueId-L${session.loopNumber}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        header: (context) => _buildSessionHeader(
            now, generatedByName, generatedByRole, issueId, session.loopNumber, logo, reportNo),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // ── Section 1 : Identité incident / équipement / boucle ───────────
          _sectionTitle('1. INCIDENT & EQUIPMENT'),
          _twoColTextTable([
            MapEntry('Incident Reference', issueId),
            MapEntry('Equipment', equipmentName),
            MapEntry('Loop No.', session.loopNumber.toString()),
            MapEntry('Technician', _s(session.technicianName)),
            MapEntry('Started', session.startedAt.split('T').first),
            if (session.closedAt != null)
              MapEntry('Closed', session.closedAt!.split('T').first),
            if (session.durationHours != null)
              MapEntry('Duration (h)', session.durationHours!.toStringAsFixed(1)),
          ]),

          // ── Section 2 : Diagnostic ────────────────────────────────────────
          _sectionTitle('2. DIAGNOSIS'),
          _labelledBlock('Diagnosis', _s(session.diagnosis)),
          if (session.diagnosisAddendum?.isNotEmpty == true)
            _labelledBlock('Diagnosis addendum', _s(session.diagnosisAddendum)),

          // ── Section 3 : Action & Outcome ──────────────────────────────────
          _sectionTitle('3. ACTION TAKEN & OUTCOME'),
          _labelledBlock('Action taken', _s(session.actionTaken)),
          _labelledBlock('Outcome', _s(session.outcome)),

          // ── Section 4 : Statut résolution ─────────────────────────────────
          _sectionTitle('4. STATUS'),
          if (session.resolved)
            _labelledBlock('Resolution', '✔ Incident resolved during this loop')
          else ...[
            _labelledBlock('Resolution', '⚠ Incident not resolved — follow-up required'),
            _labelledBlock('Next actions', _s(session.nextActions)),
          ],

          // ── Section 5 : Signature ─────────────────────────────────────────
          _sectionTitle('5. SIGNATURE'),
          _twoColTextTable([
            MapEntry('Generated by', generatedByName),
            MapEntry('Role', generatedByRole),
            MapEntry('Generation date', '${_fmtDate(now)} at ${_fmtTime(now)}'),
          ]),
        ],
      ),
    );

    return doc.save();
  }

  // ── Rapport final équipement (résumé interventions + KPI) ───────────────────

  /// Construit le PDF du rapport final équipement : résumé KPI (MTTR, taux de
  /// réouverture, downtime cumulé) + tableau de l'historique des interventions
  /// résolues. Reçoit le modèle déjà parsé par DbApiService.getEquipmentFinalReport —
  /// aucun appel API ici (génération 100% client, pattern generateInterventionReport).
  static Future<Uint8List> generateEquipmentFinalReport({
    required EquipmentFinalReport report,
    required String generatedByName,
    required String generatedByRole,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final logo = pw.MemoryImage(await _loadLogo());
    final equipmentId = report.equipmentId;
    final summary      = report.summary;
    final reportNo = 'EQ-$equipmentId';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        header: (context) => _buildEquipmentFinalReportHeader(
            now, generatedByName, generatedByRole, report.equipmentName, logo, reportNo),
        footer: (context) => _buildFooter(context, reference: 'Equipment $equipmentId'),
        build: (context) => [
          // ── Section 1 : KPI ───────────────────────────────────────────
          _sectionTitle('1. SUMMARY'),
          pw.Row(children: [
            pw.Expanded(child: _kpiBox('Total interventions',
                summary.totalInterventions.toString(), _primary)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('Average MTTR (hours)',
                summary.mttrHoursAvg == null ? '—' : summary.mttrHoursAvg!.toStringAsFixed(1), _warning)),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.Expanded(child: _kpiBox('Reopened rate',
                summary.reopenedRatePct == null ? '—' : '${summary.reopenedRatePct!.toStringAsFixed(1)}%', _error)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('Total downtime (hours)',
                summary.downtimeHoursTotal.toStringAsFixed(1), _success)),
          ]),

          // ── Section 2 : Historique des interventions ─────────────────
          _sectionTitle('2. INTERVENTION HISTORY'),
          report.interventions.isEmpty
              ? pw.Text('No resolved intervention recorded for this equipment.',
                  style: const pw.TextStyle(fontSize: 8, color: _textMuted))
              : _interventionHistoryTable(report.interventions),
        ],
      ),
    );

    return doc.save();
  }

  // ── Rapport final par incident (KPI + résumé problème/résolution) ───────────

  /// Construit le PDF du rapport final d'un incident : résumé KPI (boucles,
  /// durée, coût, statut final équipement) + résumé problème/résolution.
  /// Distinct du rapport final équipement agrégé — généré systématiquement au
  /// Mark Resolved, y compris pour les incidents sans équipement lié.
  static Future<Uint8List> generateIssueFinalReport({
    required IssueInterventionReport report,
    required String issueId,
    required String equipmentOrLocationName,
    required String urgency,
    required int sessionsCount,
    required String generatedByName,
    required String generatedByRole,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final logo = pw.MemoryImage(await _loadLogo());
    final reportNo = 'FIN-$issueId';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        header: (context) => _buildIssueFinalReportHeader(
            now, generatedByName, generatedByRole, equipmentOrLocationName, urgency, logo, reportNo),
        footer: (context) => _buildFooter(context, reference: 'Incident $issueId'),
        build: (context) => [
          // ── Section 1 : KPI ───────────────────────────────────────────
          _sectionTitle('1. SUMMARY'),
          pw.Row(children: [
            pw.Expanded(child: _kpiBox('Total intervention loops', '$sessionsCount', _primary)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('Resolution duration (hours)',
                report.durationHours == null ? 'N/A' : report.durationHours!.toStringAsFixed(1), _warning)),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.Expanded(child: _kpiBox('Estimated cost (RWF)',
                report.estimatedCost == null ? 'N/A' : report.estimatedCost!.toStringAsFixed(0), _error)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _kpiBox('Final equipment status',
                _s(report.finalEquipmentStatus), _success)),
          ]),

          // ── Section 2 : Résumé problème/résolution ─────────────────────
          _sectionTitle('2. PROBLEM & RESOLUTION SUMMARY'),
          _labelledBlock('Summary', _s(report.summary)),
          _labelledBlock('Root cause', _s(report.rootCause)),
          _labelledBlock('Recommendations', _s(report.recommendations)),
        ],
      ),
    );

    return doc.save();
  }

  // En-tête dédié du rapport final par incident
  static pw.Widget _buildIssueFinalReportHeader(DateTime now, String byName, String byRole,
      String equipmentOrLocationName, String urgency, pw.MemoryImage logo, String reportNo) {
    return pw.Column(children: [
      _buildLetterhead(logo),
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
                pw.Text('FINAL INTERVENTION REPORT',
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Kabutare District Hospital — Rwanda',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 8)),
                pw.Text('Equipment/Location: $equipmentOrLocationName',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 8)),
                pw.Text('Urgency: $urgency',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 8)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Generated on ${_fmtDate(now)} at ${_fmtTime(now)}',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text('By: $byName  ($byRole)',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text('Report No: $reportNo',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
    ]);
  }

  // En-tête dédié du rapport final équipement
  static pw.Widget _buildEquipmentFinalReportHeader(DateTime now, String byName,
      String byRole, String equipmentName, pw.MemoryImage logo, String reportNo) {
    return pw.Column(children: [
      _buildLetterhead(logo),
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
                pw.Text('EQUIPMENT FINAL REPORT',
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Kabutare District Hospital — Rwanda',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 8)),
                pw.Text('Equipment: $equipmentName',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 8)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Generated on ${_fmtDate(now)} at ${_fmtTime(now)}',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text('By: $byName  ($byRole)',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text('Report No: $reportNo',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
    ]);
  }

  // Tableau de l'historique des interventions résolues
  static pw.Widget _interventionHistoryTable(List<EquipmentFinalReportIntervention> interventions) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),   // Date résolution
        1: pw.FlexColumnWidth(2),   // Technicien
        2: pw.FlexColumnWidth(1),   // Durée (h)
        3: pw.FlexColumnWidth(2),   // Cause racine
        4: pw.FlexColumnWidth(3),   // Résumé
        5: pw.FlexColumnWidth(1),   // Réouverte
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _bgLight),
          children: [
            _th('Resolved'), _th('Technician'), _th('Duration (h)'),
            _th('Root cause'), _th('Summary'), _th('Reopened'),
          ],
        ),
        ...interventions.map((i) {
          return pw.TableRow(children: [
            _td(_s(i.resolvedAt).split(' ').first),
            _td(_s(i.technicianName)),
            _td(i.durationHours == null ? '—' : i.durationHours!.toStringAsFixed(1)),
            _td(_s(i.rootCause)),
            _td(_s(i.summary)),
            _td(i.reopened ? 'Yes' : 'No', color: i.reopened ? _warning : null),
          ]);
        }),
      ],
    );
  }

  // Letterhead (logo + adresse officielle) répété en haut de chaque page
  static pw.Widget _buildLetterhead(pw.MemoryImage logo) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(logo, width: 42, height: 42, fit: pw.BoxFit.contain),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Southern Province', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Huye District', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Kabutare District Hospital',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text('P.O. Box: 621 Butare', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Email: kabutarespital@gmail.com', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSessionHeader(DateTime now, String byName, String byRole,
      String issueId, int loopNumber, pw.MemoryImage logo, String reportNo) {
    return pw.Column(children: [
      _buildLetterhead(logo),
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
                pw.Text('INTERVENTION LOOP REPORT — No. $loopNumber',
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Kabutare District Hospital — Rwanda',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 8)),
                pw.Text('Incident No: $issueId',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 8)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Generated on ${_fmtDate(now)} at ${_fmtTime(now)}',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text('By: $byName  ($byRole)',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text('Report No: $reportNo',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
    ]);
  }

  // En-tête dédié du rapport d'intervention
  static pw.Widget _buildInterventionHeader(DateTime now, String byName, String byRole,
      bool isFinalized, pw.MemoryImage logo, String reportNo) {
    return pw.Column(children: [
      _buildLetterhead(logo),
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
                pw.Text('INTERVENTION REPORT',
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Kabutare District Hospital — Rwanda',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 8)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Generated on ${_fmtDate(now)} at ${_fmtTime(now)}',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text('By: $byName  ($byRole)',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text('Report No: $reportNo',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text(isFinalized ? 'Status: FINALIZED' : 'Status: DRAFT',
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
  static pw.Widget _buildReplacementHeader(
      DateTime now, String byName, String byRole, pw.MemoryImage logo, String reportNo) {
    return pw.Column(children: [
      _buildLetterhead(logo),
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
                pw.Text('REPLACEMENT PLAN — BIOMEDICAL EQUIPMENT',
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Kabutare District Hospital — Rwanda — RA3 S5 Standard',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 8)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Generated on ${_fmtDate(now)} at ${_fmtTime(now)}',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text('By: $byName  ($byRole)',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
                pw.Text('Report No: $reportNo',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7)),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
    ]);
  }

  // Libellés des statuts / horizons de remplacement
  static String _replacementStatusLabel(String s) => switch (s) {
        'a_remplacer'      => 'To replace',
        'bientot'          => 'Soon',
        'donnee_manquante' => 'Missing data',
        _                  => 'OK',
      };

  static String _replacementHorizonLabel(String? hz) => switch (hz) {
        'cette_annee' => 'This year',
        '1_2_ans'     => '1–2 years',
        'plus_tard'   => 'Later',
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
            _th('Equipment'), _th('Subcategory'), _th('Crit.'),
            _th('Age'), _th('Ref.'), _th('Overshoot'), _th('Status'), _th('Horizon'),
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
    pw.MemoryImage logo,
    String reportNo,
  ) {
    return pw.Column(
      children: [
        _buildLetterhead(logo),
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
                    'MAINTENANCE REPORT — CMMS',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Kabutare District Hospital — Rwanda',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 8),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Generated on ${_fmtDate(now)} at ${_fmtTime(now)}',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7),
                  ),
                  pw.Text(
                    'By: $byName  ($byRole)',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7),
                  ),
                  pw.Text(
                    'Period: ${_fmtDate(start)} → ${_fmtDate(end)}',
                    style: const pw.TextStyle(color: PdfColor(0.85, 0.85, 0.85), fontSize: 7),
                  ),
                  pw.Text(
                    'Report No: $reportNo',
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

  static pw.Widget _buildFooter(pw.Context context, {String? reference}) {
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
            'Kabutare Hospital — Confidential document, internal use only',
            style: const pw.TextStyle(fontSize: 7, color: _textMuted),
          ),
          pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}'
            '${reference != null ? ' — $reference' : ''}',
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
      return pw.Text('No data',
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
            _th('Item'),
            _th('Current Stock'),
            _th('Min Stock'),
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
