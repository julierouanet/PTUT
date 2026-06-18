import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../models/issue_intervention_report.dart';
import '../../services/auth_service.dart';
import '../../services/db_api_service.dart';
import '../../services/pdf_report_service.dart';
import '../../theme/app_theme.dart';

/// Section « Rapport d'intervention » réutilisable.
///
/// Gère son propre cycle : chargement, édition, enregistrement (UPSERT),
/// finalisation (gel), réouverture (admin) et export PDF + archivage auto.
///
/// - [canEdit]  : l'utilisateur peut éditer le rapport en brouillon (technicien
///                assigné ou privilégié, incident pris en charge).
/// - [isAdmin]  : autorise la réouverture et l'édition d'un rapport finalisé.
/// - [readOnly] : vue consultation pure (personnel hospitalier).
class InterventionReportSection extends StatefulWidget {
  final String issueId;
  final bool canEdit;
  final bool isAdmin;
  final bool readOnly;

  const InterventionReportSection({
    super.key,
    required this.issueId,
    this.canEdit = false,
    this.isAdmin = false,
    this.readOnly = false,
  });

  @override
  State<InterventionReportSection> createState() => _InterventionReportSectionState();
}

class _InterventionReportSectionState extends State<InterventionReportSection> {
  IssueInterventionReport? _report;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  // Contrôleurs de formulaire
  final _summaryCtrl  = TextEditingController();
  final _rootCtrl     = TextEditingController();
  final _recoCtrl     = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _returnedCtrl = TextEditingController();
  final _costCtrl     = TextEditingController();
  String? _finalStatus;

  // Statuts d'incident autorisant la finalisation (alignés serveur)
  static const _finalizableStatuses = {'Completed', 'Verified', 'Closed'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _rootCtrl.dispose();
    _recoCtrl.dispose();
    _durationCtrl.dispose();
    _returnedCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await DbApiService.instance.getInterventionReport(widget.issueId);
      final report = IssueInterventionReport.fromApiJson(raw);
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
        _hydrateControllers(report);
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _hydrateControllers(IssueInterventionReport r) {
    _summaryCtrl.text  = r.summary ?? '';
    _rootCtrl.text     = r.rootCause ?? '';
    _recoCtrl.text     = r.recommendations ?? '';
    _durationCtrl.text = r.durationHours?.toString() ?? '';
    _returnedCtrl.text = r.returnedToServiceAt ?? '';
    _costCtrl.text     = r.estimatedCost?.toString() ?? '';
    _finalStatus       = r.finalEquipmentStatus;
  }

  // ── Permissions effectives ────────────────────────────────────────────────

  bool get _isFinalized => _report?.isFinalized ?? false;

  /// Le formulaire est éditable si : pas en lecture seule, et soit le rapport
  /// est en brouillon et l'utilisateur peut éditer, soit l'utilisateur est admin.
  bool get _isEditable {
    if (widget.readOnly) return false;
    if (_isFinalized) return widget.isAdmin;
    return widget.canEdit;
  }

  bool get _canFinalize {
    if (widget.readOnly || _isFinalized || !widget.canEdit) return false;
    return _finalizableStatuses.contains(_report?.issueStatus);
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Construit le payload PUT à partir des contrôleurs (champs vides → null).
  Map<String, dynamic> _buildPayload() {
    String? clean(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    double? num(TextEditingController c) =>
        double.tryParse(c.text.trim().replaceAll(',', '.'));
    return {
      'summary':                clean(_summaryCtrl),
      'root_cause':             clean(_rootCtrl),
      'recommendations':        clean(_recoCtrl),
      'duration_hours':         num(_durationCtrl),
      'returned_to_service_at': clean(_returnedCtrl),
      'estimated_cost':         num(_costCtrl),
      'final_equipment_status': _finalStatus,
    };
  }

  Future<void> _save(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final raw = await DbApiService.instance.saveInterventionReport(widget.issueId, _buildPayload());
      if (!mounted) return;
      setState(() => _report = IssueInterventionReport.fromApiJson(raw));
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.interventionReportSaved),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.interventionReportSaveError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      // Sauvegarde implicite avant gel pour ne rien perdre.
      await _saveSilently();
      final raw = await DbApiService.instance.finalizeInterventionReport(widget.issueId);
      final report = IssueInterventionReport.fromApiJson(raw);
      if (!mounted) return;
      setState(() => _report = report);

      messenger.showSnackBar(SnackBar(
        content: Text(l10n.interventionReportFinalized),
        behavior: SnackBarBehavior.floating,
      ));

      // Génère le PDF une seule fois : archivage auto sur l'équipement (si lié)
      // PUIS, dans tous les cas, ouverture du dialogue interactif de
      // téléchargement / impression pour le proposer à l'utilisateur.
      await _exportPdf(l10n, archive: true, report: report, alsoDownload: true);
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.interventionReportFinalizeError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Sauvegarde sans feedback (utilisée avant finalisation).
  Future<void> _saveSilently() async {
    await DbApiService.instance.saveInterventionReport(widget.issueId, _buildPayload());
  }

  Future<void> _reopen(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final raw = await DbApiService.instance.reopenInterventionReport(widget.issueId);
      if (!mounted) return;
      setState(() => _report = IssueInterventionReport.fromApiJson(raw));
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.interventionReportReopened),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.interventionReportReopenError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Génère le PDF (une seule fois) et le diffuse selon le contexte :
  /// - [archive] : si un équipement est lié, archive le PDF dans son historique.
  /// - [alsoDownload] : ouvre EN PLUS le dialogue interactif (téléchargement /
  ///   impression). Utilisé à la finalisation pour proposer le rapport figé.
  ///
  /// Appelé sans paramètre (bouton « Exporter PDF »), il archive si possible,
  /// sinon ouvre directement le dialogue interactif.
  Future<void> _exportPdf(
    AppLocalizations l10n, {
    bool archive = false,
    bool alsoDownload = false,
    IssueInterventionReport? report,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final r = report ?? _report;
    if (r == null) return;
    try {
      final user = AuthService().currentUser;
      final pdfBytes = await PdfReportService.generateInterventionReport(
        report: r.toReportPdfJson(),
        issueId: widget.issueId,
        generatedByName: user?.name ?? '—',
        generatedByRole: user?.roles.isNotEmpty == true ? user!.roles.first.displayName : '—',
      );

      final fileName = 'rapport_intervention_${widget.issueId}.pdf';
      final archived = archive && r.equipmentId != null && r.equipmentId!.isNotEmpty;

      if (archived) {
        // Archivage dans l'historique documentaire de l'équipement.
        await DbApiService.instance.archiveInterventionPdf(r.equipmentId!, pdfBytes, fileName);
        if (mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text(l10n.interventionReportArchived),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }

      // Dialogue interactif : si demandé explicitement, ou si rien n'a été
      // archivé (export simple sans équipement lié). Réutilise les mêmes octets.
      if (alsoDownload || !archived) {
        await Printing.layoutPdf(onLayout: (_) async => pdfBytes, name: fileName);
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(l10n.interventionReportExportError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return _card(l10n, const Center(
        child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
      ));
    }
    if (_error != null) {
      return _card(l10n, Text(l10n.interventionReportLoadError,
          style: const TextStyle(color: AppColors.error)));
    }

    // Vue lecture seule (staff) : rien à afficher si pas de rapport rédigé.
    if (widget.readOnly && (_report == null || (_report!.summary == null && !_isFinalized))) {
      return _card(l10n, Text(l10n.interventionReportEmptyReadonly,
          style: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic)));
    }

    return _card(l10n, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _prefillBlock(l10n),
        const SizedBox(height: 12),
        if (_isEditable) _editForm(l10n) else _readView(l10n),
        const SizedBox(height: 12),
        _actions(l10n),
      ],
    ));
  }

  Widget _card(AppLocalizations l10n, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.interventionReportSection,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            _statusBadge(l10n),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _statusBadge(AppLocalizations l10n) {
    final finalized = _isFinalized;
    final color = finalized ? AppColors.success : AppColors.warning;
    final label = finalized ? l10n.interventionReportFinalizedBadge : l10n.interventionReportDraftBadge;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  /// Bloc lecture seule des données issues de l'incident (pré-remplissage).
  Widget _prefillBlock(AppLocalizations l10n) {
    final r = _report!;
    Widget line(String label, String? value) {
      if (value == null || value.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RichText(text: TextSpan(
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          children: [
            TextSpan(text: '$label : ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        )),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.interventionReportPrefillTitle,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        line(l10n.issueDetailRootCause, r.diagnosis),
        line(l10n.issueDetailCorrectiveActions, r.actions),
        line(l10n.issueDetailPartsUsed, r.partsReplaced),
      ]),
    );
  }

  // ── Formulaire éditable ──────────────────────────────────────────────────
  Widget _editForm(AppLocalizations l10n) {
    if (_isFinalized && widget.isAdmin) {
      // Bandeau d'avertissement : on édite un rapport finalisé.
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(l10n.interventionReportLockedHint,
              style: const TextStyle(fontSize: 12, color: AppColors.warning)),
        ),
        ..._formFields(l10n),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: _formFields(l10n));
  }

  List<Widget> _formFields(AppLocalizations l10n) {
    return [
      _field(_summaryCtrl, l10n.interventionReportSummaryLabel, hint: l10n.interventionReportSummaryHint, maxLines: 3),
      _field(_rootCtrl, l10n.interventionReportRootCauseLabel, hint: l10n.interventionReportRootCauseHint, maxLines: 2),
      _field(_recoCtrl, l10n.interventionReportRecommendationsLabel, hint: l10n.interventionReportRecommendationsHint, maxLines: 2),
      Row(children: [
        Expanded(child: _field(_durationCtrl, l10n.interventionReportDurationLabel,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))])),
        const SizedBox(width: 10),
        Expanded(child: _field(_costCtrl, l10n.interventionReportCostLabel,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))])),
      ]),
      _field(_returnedCtrl, l10n.interventionReportReturnedAtLabel, hint: 'YYYY-MM-DD'),
      const SizedBox(height: 6),
      _statusDropdown(l10n),
    ];
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _statusDropdown(AppLocalizations l10n) {
    return DropdownButtonFormField<String>(
      initialValue: _finalStatus,
      decoration: InputDecoration(
        labelText: l10n.interventionReportFinalStatusLabel,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: EquipmentStatus.values
          .map((s) => DropdownMenuItem(value: s.displayName, child: Text(s.localizedName(l10n))))
          .toList(),
      onChanged: (v) => setState(() => _finalStatus = v),
    );
  }

  // ── Vue lecture seule ─────────────────────────────────────────────────────
  Widget _readView(AppLocalizations l10n) {
    final r = _report!;
    Widget block(String label, String? value) {
      if (value == null || value.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 14, height: 1.4)),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      block(l10n.interventionReportSummaryLabel, r.summary),
      block(l10n.interventionReportRootCauseLabel, r.rootCause),
      block(l10n.interventionReportRecommendationsLabel, r.recommendations),
      Row(children: [
        if (r.durationHours != null)
          Expanded(child: block(l10n.interventionReportDurationLabel, r.durationHours!.toStringAsFixed(1))),
        if (r.estimatedCost != null)
          Expanded(child: block(l10n.interventionReportCostLabel, r.estimatedCost!.toStringAsFixed(0))),
      ]),
      block(l10n.interventionReportFinalStatusLabel, r.finalEquipmentStatus),
      block(l10n.interventionReportReturnedAtLabel, r.returnedToServiceAt),
      block(l10n.interventionReportAuthorLabel, r.authorName),
      block(l10n.interventionReportValidatedByLabel, r.validatedByName),
    ]);
  }

  // ── Barre d'actions ───────────────────────────────────────────────────────
  Widget _actions(AppLocalizations l10n) {
    final hasReport = _report?.summary != null || _isFinalized;
    final buttons = <Widget>[];

    if (_isEditable) {
      buttons.add(FilledButton.icon(
        onPressed: _busy ? null : () => _save(l10n),
        icon: const Icon(Icons.save_outlined, size: 16),
        label: Text(l10n.interventionReportSaveButton),
      ));
    }
    if (_canFinalize) {
      buttons.add(FilledButton.icon(
        onPressed: _busy ? null : () => _finalize(l10n),
        icon: const Icon(Icons.lock_outline, size: 16),
        label: Text(l10n.interventionReportFinalizeButton),
        style: FilledButton.styleFrom(backgroundColor: AppColors.success),
      ));
    }
    if (_isFinalized && widget.isAdmin && !widget.readOnly) {
      buttons.add(OutlinedButton.icon(
        onPressed: _busy ? null : () => _reopen(l10n),
        icon: const Icon(Icons.lock_open_outlined, size: 16),
        label: Text(l10n.interventionReportReopenButton),
      ));
    }
    if (hasReport) {
      buttons.add(OutlinedButton.icon(
        onPressed: _busy ? null : () => _exportPdf(l10n),
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
        label: Text(l10n.interventionReportExportButton),
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 10, runSpacing: 8, children: buttons);
  }
}
