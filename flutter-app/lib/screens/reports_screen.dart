import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/pdf_report_service.dart';
import '../models/equipment.dart';
import '../models/issue.dart';
import '../utils/csv_export.dart';
import '../widgets/reports/report_kpi_section.dart';

enum _ReportPeriod { last7, last30, last90, yearToDate, custom }

// Type d'archive : mensuelle ou annuelle
enum _ArchiveType { monthly, annual }

/// Écran de rapports et d'analyses GMAO.
///
/// Fonctionnalités :
/// - Sélecteur de période global (7 j, 30 j, 90 j, année en cours, personnalisée)
/// - KPIs GMAO : MTTR approximé, conformité PM, top 3 départements impactés
/// - Répartition des équipements (statut, département, catégorie)
/// - Statistiques des incidents filtrées sur la période sélectionnée
/// - Export CSV réel (web) ou message informatif (mobile/desktop)
/// - Section "Archives" : téléchargement des rapports mensuels (24 mois) ou annuels
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportPeriod _period = _ReportPeriod.last30;
  DateTimeRange? _customRange;
  bool _isExporting    = false;
  bool _isExportingPdf = false;

  // ── État de la section Archives ────────────────────────────────────────────
  _ArchiveType _archiveType        = _ArchiveType.monthly;
  // Index dans la liste des 24 derniers mois (0 = mois courant, 1 = mois précédent, …)
  int          _archiveMonthOffset = 0;
  // Année sélectionnée pour les rapports annuels
  late int     _archiveYear        = DateTime.now().year;
  bool         _isDownloadingArchive = false;

  // ── Calcul de la plage temporelle active ───────────────────────────────────

  DateTimeRange _effectiveRange() {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _ReportPeriod.last7:
        return DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today);
      case _ReportPeriod.last30:
        return DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today);
      case _ReportPeriod.last90:
        return DateTimeRange(start: today.subtract(const Duration(days: 89)), end: today);
      case _ReportPeriod.yearToDate:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: today);
      case _ReportPeriod.custom:
        return _customRange ??
            DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today);
    }
  }

  // ── Filtrage des incidents ─────────────────────────────────────────────────

  List<Issue> _issuesInPeriod(DateTimeRange range) {
    final startDay = DateTime(range.start.year, range.start.month, range.start.day);
    final endDay   = DateTime(range.end.year,   range.end.month,   range.end.day);

    return DataService().issues.where((i) {
      if (i.createdAt.length < 10) return false;
      try {
        final d = DateTime.parse(i.createdAt.substring(0, 10));
        return !d.isBefore(startDay) && !d.isAfter(endDay);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  // ── KPIs GMAO ─────────────────────────────────────────────────────────────

  /// MTTR approximé : délai moyen entre `created_at` et `taken_at` pour les
  /// incidents clôturés (completed / verified / closed) ayant un `taken_at`.
  ///
  /// Un MTTR strict nécessiterait un champ `resolved_at` côté backend.
  /// La valeur retournée est en JOURS (null = données insuffisantes).
  double? _computeMttr(List<Issue> issues) {
    final resolved = issues.where((i) {
      final done = i.status == IssueStatus.completed ||
                   i.status == IssueStatus.verified  ||
                   i.status == IssueStatus.closed;
      return done && (i.takenAt?.isNotEmpty ?? false);
    }).toList();

    if (resolved.isEmpty) return null;

    double totalHours = 0;
    int    count      = 0;

    for (final issue in resolved) {
      try {
        final created = DateTime.parse(issue.createdAt.substring(0, 10));
        final taken   = DateTime.parse(issue.takenAt!.substring(0, 10));
        final hours   = taken.difference(created).inHours;
        if (hours >= 0) {
          totalHours += hours;
          count++;
        }
      } catch (_) {}
    }

    return count == 0 ? null : totalHours / count / 24.0;
  }

  /// Conformité PM : ratio d'équipements avec PM planifiée dont la date
  /// `next_preventive_maintenance` n'est pas encore dépassée.
  ///
  /// Retourne (compliant, total).  Si total == 0, aucun plan PM n'est configuré.
  (int, int) _computePmCompliance() {
    final allEquip = DataService().equipment;
    final withPm = allEquip
        .where((e) => (e.nextPreventiveMaintenance?.length ?? 0) >= 10)
        .toList();
    if (withPm.isEmpty) return (0, 0);

    final todayDay = DateTime.now();
    final today0   = DateTime(todayDay.year, todayDay.month, todayDay.day);

    final compliant = withPm.where((e) {
      try {
        final next = DateTime.parse(e.nextPreventiveMaintenance!.substring(0, 10));
        return !next.isBefore(today0);
      } catch (_) {
        return true;
      }
    }).length;

    return (compliant, withPm.length);
  }

  /// Top 3 départements par nombre d'incidents sur la période.
  List<MapEntry<String, int>> _topDepartments(List<Issue> issues) {
    final counts = <String, int>{};
    for (final i in issues) {
      if (i.department.isNotEmpty) {
        counts[i.department] = (counts[i.department] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }

  // ── Export CSV ─────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _exportCsv(BuildContext context, AppLocalizations l10n) async {
    setState(() => _isExporting = true);

    try {
      final range  = _effectiveRange();
      final issues = _issuesInPeriod(range);
      final mttr   = _computeMttr(issues);
      final (pmCompliant, pmTotal) = _computePmCompliance();

      final startStr = _fmtDate(range.start);
      final endStr   = _fmtDate(range.end);
      final nowStr   = _fmtDate(DateTime.now());

      final mttrStr = mttr == null
          ? l10n.reportsMttrNoData
          : l10n.reportsMttrDays(mttr.toStringAsFixed(1));
      final pmStr = pmTotal == 0
          ? l10n.reportsPmNoData
          : '${(pmCompliant / pmTotal * 100).round()}%';

      final resolvedCount = issues.where((i) =>
          i.status == IssueStatus.completed ||
          i.status == IssueStatus.verified  ||
          i.status == IssueStatus.closed).length;

      final resolutionStr = issues.isEmpty
          ? '0%'
          : '${(resolvedCount / issues.length * 100).round()}%';

      String q(String s) => '"${s.replaceAll('"', '""')}"';

      final sb = StringBuffer()
        ..writeln('Rapport GMAO - Hopital de Kabutare')
        ..writeln('Exporte le;$nowStr')
        ..writeln('Periode;$startStr - $endStr')
        ..writeln('')
        ..writeln('INDICATEURS GMAO')
        ..writeln('Indicateur;Valeur')
        ..writeln('${l10n.reportsMttr};$mttrStr')
        ..writeln('${l10n.reportsPmCompliance};$pmStr')
        ..writeln('${l10n.reportsResolutionRate};$resolutionStr')
        ..writeln('')
        ..writeln('INCIDENTS DE LA PERIODE (${issues.length})')
        ..writeln('ID;Equipement;Departement;Type;Urgence;Statut;Signale le;Pris en charge le');

      for (final i in issues) {
        final takenDate = (i.takenAt != null && i.takenAt!.length >= 10)
            ? i.takenAt!.substring(0, 10)
            : (i.takenAt ?? '-');
        sb.writeln([
          q(i.id),
          q(i.equipmentName ?? '-'),
          q(i.department),
          q(i.type),
          q(i.urgency.displayName),
          q(i.status.displayName),
          q(i.createdAt.length >= 10 ? i.createdAt.substring(0, 10) : i.createdAt),
          q(takenDate),
        ].join(';'));
      }

      final filename =
          'rapport_gmao_${startStr.replaceAll('/', '-')}_${endStr.replaceAll('/', '-')}.csv';
      final success = downloadCsv(sb.toString(), filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? l10n.reportsExportCsvSuccess : l10n.reportsExportCsvWebOnly),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Export PDF ─────────────────────────────────────────────────────────────

  Future<void> _exportPdf(BuildContext context, AppLocalizations l10n) async {
    setState(() => _isExportingPdf = true);

    // Capture avant tout await pour éviter use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);

    try {
      final range        = _effectiveRange();
      final issues       = _issuesInPeriod(range);
      final mttr         = _computeMttr(issues);
      final (compliant, total) = _computePmCompliance();
      final topDepts     = _topDepartments(issues);
      final user         = AuthService().currentUser;

      final pdfBytes = await PdfReportService.generate(
        startDate:       range.start,
        endDate:         range.end,
        generatedByName: user?.name ?? '—',
        generatedByRole: user?.roles.isNotEmpty == true
            ? user!.roles.first.name
            : '—',
        allEquipment:    DataService().equipment,
        periodIssues:    issues,
        mttrDays:        mttr,
        pmCompliant:     compliant,
        pmTotal:         total,
        topDepartments:  topDepts,
        inventory:       DataService().inventory,
      );

      final startStr = _fmtDate(range.start).replaceAll('/', '-');
      final endStr   = _fmtDate(range.end).replaceAll('/', '-');

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'rapport_kabutare_${startStr}_$endStr.pdf',
      );

      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(l10n.reportsPdfSuccess),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(l10n.reportsPdfError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  // ── Sélecteur de période ──────────────────────────────────────────────────

  Future<void> _pickCustomRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
      locale: Localizations.localeOf(context),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (range != null && mounted) {
      setState(() {
        _period      = _ReportPeriod.custom;
        _customRange = range;
      });
    }
  }

  Widget _buildPeriodChip(String label, _ReportPeriod period) {
    final isSelected = _period == period;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontSize: 13,
      ),
      onSelected: (_) => setState(() => _period = period),
    );
  }

  // ── Utilitaires Archives ───────────────────────────────────────────────────

  /// Retourne le premier jour du mois offset (0 = mois courant, 1 = mois précédent, …)
  DateTime _archiveMonthStart(int offset) {
    final now = DateTime.now();
    return DateTime(now.year, now.month - offset, 1);
  }

  /// Retourne le dernier jour du mois sélectionné.
  DateTime _archiveMonthEnd(DateTime start) {
    return DateTime(start.year, start.month + 1, 1)
        .subtract(const Duration(days: 1));
  }

  /// Traduit un numéro de mois (1–12) en chaîne localisée.
  String _monthName(AppLocalizations l10n, int month) => switch (month) {
    1  => l10n.monthJanuary,
    2  => l10n.monthFebruary,
    3  => l10n.monthMarch,
    4  => l10n.monthApril,
    5  => l10n.monthMay,
    6  => l10n.monthJune,
    7  => l10n.monthJuly,
    8  => l10n.monthAugust,
    9  => l10n.monthSeptember,
    10 => l10n.monthOctober,
    11 => l10n.monthNovember,
    _  => l10n.monthDecember,
  };

  /// Génère et ouvre le PDF pour la période d'archive sélectionnée.
  Future<void> _downloadArchivePdf(BuildContext context, AppLocalizations l10n) async {
    setState(() => _isDownloadingArchive = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Calcul de la plage de dates selon le type d'archive
      final DateTimeRange range;
      if (_archiveType == _ArchiveType.monthly) {
        final start = _archiveMonthStart(_archiveMonthOffset);
        final end   = _archiveMonthEnd(start);
        range = DateTimeRange(start: start, end: end);
      } else {
        range = DateTimeRange(
          start: DateTime(_archiveYear, 1, 1),
          end:   DateTime(_archiveYear, 12, 31),
        );
      }

      final issues                = _issuesInPeriod(range);
      final mttr                  = _computeMttr(issues);
      final (pmCompliant, pmTotal) = _computePmCompliance();
      final topDepts              = _topDepartments(issues);
      final user                  = AuthService().currentUser;

      final pdfBytes = await PdfReportService.generate(
        startDate:       range.start,
        endDate:         range.end,
        generatedByName: user?.name ?? '—',
        generatedByRole: user?.roles.isNotEmpty == true
            ? user!.roles.first.name
            : '—',
        allEquipment:    DataService().equipment,
        periodIssues:    issues,
        mttrDays:        mttr,
        pmCompliant:     pmCompliant,
        pmTotal:         pmTotal,
        topDepartments:  topDepts,
        inventory:       DataService().inventory,
      );

      // Libellé du fichier selon le type d'archive
      final String periodLabel;
      if (_archiveType == _ArchiveType.monthly) {
        final start = range.start;
        periodLabel = '${_monthName(l10n, start.month).toLowerCase()}_${start.year}';
      } else {
        periodLabel = '${_archiveYear}';
      }

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'rapport_kabutare_$periodLabel.pdf',
      );

      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(l10n.reportsPdfSuccess),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(l10n.reportsPdfError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isDownloadingArchive = false);
    }
  }

  /// Construit la section "Archives & Rapports Historiques".
  Widget _buildArchivesSection(BuildContext context, AppLocalizations l10n) {
    final now       = DateTime.now();
    final yearList  = [now.year, now.year - 1];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de section
            Row(
              children: [
                const Icon(Icons.archive_outlined, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  l10n.reportsArchivesSectionTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.reportsArchivesHint,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // ── Sélecteur de type (Mensuel / Annuel) ──────────────────────
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.reportsArchivesTypeMonthly),
                  selected: _archiveType == _ArchiveType.monthly,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _archiveType == _ArchiveType.monthly
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  onSelected: (_) => setState(() {
                    _archiveType        = _ArchiveType.monthly;
                    _archiveMonthOffset = 0;
                  }),
                ),
                ChoiceChip(
                  label: Text(l10n.reportsArchivesTypeAnnual),
                  selected: _archiveType == _ArchiveType.annual,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _archiveType == _ArchiveType.annual
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  onSelected: (_) => setState(() {
                    _archiveType = _ArchiveType.annual;
                    _archiveYear = now.year;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Sélecteur de période dynamique ────────────────────────────
            if (_archiveType == _ArchiveType.monthly)
              DropdownButtonFormField<int>(
                value: _archiveMonthOffset,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                items: List.generate(24, (i) {
                  final d = _archiveMonthStart(i);
                  return DropdownMenuItem(
                    value: i,
                    child: Text('${_monthName(l10n, d.month)} ${d.year}'),
                  );
                }),
                onChanged: (v) {
                  if (v != null) setState(() => _archiveMonthOffset = v);
                },
              )
            else
              DropdownButtonFormField<int>(
                value: _archiveYear,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                items: yearList
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _archiveYear = v);
                },
              ),
            const SizedBox(height: 16),

            // ── Bouton de téléchargement ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDownloadingArchive
                    ? null
                    : () => _downloadArchivePdf(context, l10n),
                icon: _isDownloadingArchive
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  _isDownloadingArchive
                      ? l10n.reportsArchivesDownloading
                      : l10n.reportsArchivesDownload,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomChip(BuildContext context, AppLocalizations l10n) {
    final isSelected = _period == _ReportPeriod.custom;
    final label = isSelected && _customRange != null
        ? '${_fmtDate(_customRange!.start)} → ${_fmtDate(_customRange!.end)}'
        : l10n.reportsPeriodCustom;

    return ActionChip(
      avatar: Icon(
        Icons.calendar_today_outlined,
        size: 14,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      label: Text(label),
      backgroundColor: isSelected ? AppColors.primary : null,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontSize: 13,
      ),
      onPressed: () => _pickCustomRange(context),
    );
  }

  // ── Build principal ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: DataService(),
      builder: (context, _) {
        final range        = _effectiveRange();
        final periodIssues = _issuesInPeriod(range);

        // État actuel des équipements (non filtré par période)
        final allEquip     = DataService().equipment;
        final total        = allEquip.length;
        final operational  = allEquip.where((e) => e.status == EquipmentStatus.operational).length;
        final maintenance  = allEquip.where((e) => e.status == EquipmentStatus.maintenance).length;
        final outOfService = allEquip.where((e) => e.status == EquipmentStatus.outOfService).length;

        final byDepartment = <String, int>{};
        final byCategory   = <String, int>{};
        for (final eq in allEquip) {
          byDepartment[eq.department] = (byDepartment[eq.department] ?? 0) + 1;
          byCategory[eq.category]     = (byCategory[eq.category]     ?? 0) + 1;
        }

        // Incidents filtrés sur la période
        final totalPeriod   = periodIssues.length;
        final openIssues    = periodIssues
            .where((i) => i.status == IssueStatus.reported)
            .length;
        final resolvedCount = periodIssues.where((i) =>
            i.status == IssueStatus.completed ||
            i.status == IssueStatus.verified  ||
            i.status == IssueStatus.closed)
            .length;

        // KPIs GMAO
        final mttrDays                  = _computeMttr(periodIssues);
        final (pmCompliant, pmTotal)    = _computePmCompliance();
        final topDepts                  = _topDepartments(periodIssues);

        final isMobile = MediaQuery.of(context).size.width < 600;
        final pad      = isMobile ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête ────────────────────────────────────────────────────
              _buildHeader(l10n, isMobile),
              const SizedBox(height: 16),

              // ── Section Archives — en tête de page pour accès rapide ───────
              if (AuthService().canGenerateReports) ...[
                _buildArchivesSection(context, l10n),
                const SizedBox(height: 24),
              ],

              // ── Sélecteur de période + export CSV ─────────────────────────
              _buildPeriodBar(context, l10n),
              const SizedBox(height: 24),

              // ── Cartes de résumé (4 KPIs haut niveau) ────────────────────
              _buildSummaryGrid(l10n, total, operational, totalPeriod, resolvedCount),
              const SizedBox(height: 24),

              // ── KPIs GMAO : MTTR, PM, top depts ──────────────────────────
              _buildSectionHeader(l10n.reportsKpiSectionTitle, Icons.analytics_outlined),
              const SizedBox(height: 12),
              ReportKpiSection(
                mttrDays:       mttrDays,
                pmCompliant:    pmCompliant,
                pmTotal:        pmTotal,
                topDepartments: topDepts,
              ),
              const SizedBox(height: 24),

              // ── Répartition équipements (état courant) ────────────────────
              LayoutBuilder(builder: (_, constraints) {
                final wide       = constraints.maxWidth > 800;
                final statusCard = _buildStatusReport(l10n, total, operational, maintenance, outOfService);
                final deptCard   = _buildDepartmentReport(l10n, byDepartment);
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: statusCard),
                          const SizedBox(width: 24),
                          Expanded(child: deptCard),
                        ],
                      )
                    : Column(children: [
                        statusCard,
                        const SizedBox(height: 24),
                        deptCard,
                      ]);
              }),
              const SizedBox(height: 24),

              // ── Catégories + statistiques incidents (période) ─────────────
              LayoutBuilder(builder: (_, constraints) {
                final wide      = constraints.maxWidth > 800;
                final catCard   = _buildCategoryReport(l10n, byCategory);
                final issueCard = _buildIssuesReport(l10n, totalPeriod, openIssues, resolvedCount);
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: catCard),
                          const SizedBox(width: 24),
                          Expanded(child: issueCard),
                        ],
                      )
                    : Column(children: [
                        catCard,
                        const SizedBox(height: 24),
                        issueCard,
                      ]);
              }),
            ],
          ),
        );
      },
    );
  }

  // ── Widgets helpers ────────────────────────────────────────────────────────

  Widget _buildHeader(AppLocalizations l10n, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.reportsTitle,
          style: TextStyle(
            fontSize: isMobile ? 20 : 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(l10n.reportsSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildPeriodBar(BuildContext context, AppLocalizations l10n) {
    final csvButton = TextButton.icon(
      onPressed: _isExporting ? null : () => _exportCsv(context, l10n),
      icon: _isExporting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_outlined, size: 18),
      label: Text(l10n.reportsExportCsv),
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    );

    final pdfButton = AuthService().canGenerateReports
        ? Tooltip(
            message: l10n.reportsPdfExportTooltip,
            child: TextButton.icon(
              onPressed: _isExportingPdf ? null : () => _exportPdf(context, l10n),
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(_isExportingPdf
                  ? l10n.reportsExportPDFProgress
                  : l10n.reportsExportPDF),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
            ),
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sur mobile : empiler le label et les boutons pour éviter l'overflow
            LayoutBuilder(builder: (_, constraints) {
              final isMobileBar = constraints.maxWidth < 600;
              if (isMobileBar) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.reportsPeriodLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      csvButton,
                      if (pdfButton != null) ...[const SizedBox(width: 4), pdfButton],
                    ]),
                  ],
                );
              }
              return Row(children: [
                const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  l10n.reportsPeriodLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                csvButton,
                if (pdfButton != null) ...[const SizedBox(width: 4), pdfButton],
              ]);
            }),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildPeriodChip(l10n.reportsPeriodLast7,      _ReportPeriod.last7),
                _buildPeriodChip(l10n.reportsPeriodLast30,     _ReportPeriod.last30),
                _buildPeriodChip(l10n.reportsPeriodLast90,     _ReportPeriod.last90),
                _buildPeriodChip(l10n.reportsPeriodYearToDate, _ReportPeriod.yearToDate),
                _buildCustomChip(context, l10n),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid(
    AppLocalizations l10n,
    int total,
    int operational,
    int periodIssues,
    int resolved,
  ) {
    final availRate = total == 0 ? 0 : (operational / total * 100).round();
    return LayoutBuilder(builder: (_, constraints) {
      final crossCount = constraints.maxWidth > 800 ? 4 : 2;
      return GridView.count(
        crossAxisCount: crossCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
        children: [
          _buildSummaryCard(
            l10n.reportsTotalEquipment, '$total', Icons.inventory_2, AppColors.primary),
          _buildSummaryCard(
            l10n.reportsAvailabilityRate, '$availRate%', Icons.check_circle, AppColors.success),
          _buildSummaryCard(
            l10n.reportsIssuesInPeriod, '$periodIssues', Icons.warning_amber, AppColors.warning),
          _buildSummaryCard(
            l10n.reportsResolvedIssues, '$resolved', Icons.task_alt, AppColors.success),
        ],
      );
    });
  }

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
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusReport(
    AppLocalizations l10n,
    int total,
    int operational,
    int maintenance,
    int outOfService,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reportsStatusBreakdown,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _buildStatRow(l10n.reportsOperational,   operational,  total, AppColors.success),
            _buildStatRow(l10n.reportsInMaintenance, maintenance,  total, AppColors.warning),
            _buildStatRow(l10n.reportsOutOfService,  outOfService, total, AppColors.error),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int count, int total, Color color) {
    final percentage = total == 0 ? 0 : (count / total * 100).round();
    final progress   = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label)),
              Text('$count', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(
                '($percentage%)',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentReport(AppLocalizations l10n, Map<String, int> byDepartment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reportsByDepartment,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            if (byDepartment.isEmpty)
              Text('—', style: const TextStyle(color: AppColors.textSecondary))
            else
              ...byDepartment.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(e.key, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${e.value}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
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
            Text(
              l10n.reportsByCategory,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            if (byCategory.isEmpty)
              Text('—', style: const TextStyle(color: AppColors.textSecondary))
            else
              ...byCategory.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(e.key, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${e.value}',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesReport(
    AppLocalizations l10n,
    int total,
    int open,
    int resolved,
  ) {
    final inProgress = (total - open - resolved).clamp(0, total);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reportsIssueStats,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.reportsIssuesInPeriod,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildStatRow(l10n.reportsOpenIssues,          open,       total, AppColors.error),
            _buildStatRow(l10n.reportsInProgressIssues,    inProgress, total, AppColors.warning),
            _buildStatRow(l10n.reportsResolvedIssuesLabel, resolved,   total, AppColors.success),
          ],
        ),
      ),
    );
  }
}
