import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment_document.dart';
import '../../models/intervention_technician.dart';
import '../../services/db_api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/intervention_document_grouping.dart';
import '../../utils/open_blob_url.dart';
import '../doc_group_tile.dart';

enum _PeriodPreset { last7Days, thisMonth, lastMonth, custom }

/// Onglet « Documents » de la page technicien — liste, filtre (type, technicien,
/// période) et exporte (ZIP / impression PDF fusionnée) les documents de type
/// `intervention` et/ou `completion`, toutes équipements confondus. Visible
/// uniquement si `Permission.viewInterventionDocuments` est accordée (garde
/// appliquée par l'écran appelant).
class InterventionDocumentsTab extends StatefulWidget {
  const InterventionDocumentsTab({super.key});

  @override
  State<InterventionDocumentsTab> createState() => _InterventionDocumentsTabState();
}

class _InterventionDocumentsTabState extends State<InterventionDocumentsTab> {
  static final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');

  List<EquipmentDocument> _items = [];
  bool _loading = true;
  String? _error;

  List<InterventionTechnician> _technicians = [];
  String? _selectedTechnicianId;
  _PeriodPreset _preset = _PeriodPreset.last7Days;
  DateTimeRange? _customRange;

  bool _includeIntervention = true;
  bool _includeCompletion = true;

  bool _isExportingZip = false;
  bool _isExportingPdf = false;
  final Set<String> _exportingIssueIds = {};

  @override
  void initState() {
    super.initState();
    _loadTechnicians();
    _load();
  }

  // ── Calcul des bornes de période ────────────────────────────────────────────

  /// Bornes calendaires du préréglage courant, déjà formatées `yyyy-MM-dd`
  /// pour les query params `from`/`to` des endpoints `/api/documents/interventions/*`.
  (String from, String to) _currentDateFilters() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    late final DateTime from, to;
    switch (_preset) {
      case _PeriodPreset.last7Days:
        from = today.subtract(const Duration(days: 6));
        to = today;
      case _PeriodPreset.thisMonth:
        from = DateTime(now.year, now.month, 1);
        to = today;
      case _PeriodPreset.lastMonth:
        final firstOfThisMonth = DateTime(now.year, now.month, 1);
        to = firstOfThisMonth.subtract(const Duration(days: 1));
        from = DateTime(to.year, to.month, 1);
      case _PeriodPreset.custom:
        from = _customRange?.start ?? today;
        to = _customRange?.end ?? today;
    }
    return (_apiDateFormat.format(from), _apiDateFormat.format(to));
  }

  // ── Types de documents ───────────────────────────────────────────────────

  List<String> _selectedTypes() => [
        if (_includeIntervention) 'intervention',
        if (_includeCompletion) 'completion',
      ];

  /// Recharge technicien(s) puis liste, dans cet ordre : un changement de types
  /// peut invalider `_selectedTechnicianId` (garde-fou dans `_loadTechnicians`),
  /// donc `_load` ne doit partir qu'une fois cette invalidation tranchée —
  /// sinon un même clic déclencherait un `_load` en trop.
  Future<void> _onTypesChanged() async {
    await _loadTechnicians();
    if (!mounted) return;
    _load();
  }

  // ── Chargement ────────────────────────────────────────────────────────────

  Future<void> _loadTechnicians() async {
    try {
      final techs = await DbApiService.instance.getInterventionTechnicians(types: _selectedTypes());
      if (!mounted) return;
      final stillValid = _selectedTechnicianId == null || techs.any((t) => t.id == _selectedTechnicianId);
      setState(() {
        _technicians = techs;
        if (!stillValid) _selectedTechnicianId = null;
      });
    } catch (_) {
      // Filtre technicien optionnel : une erreur ici ne bloque pas la liste principale.
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final types = _selectedTypes();
    if (types.isEmpty) {
      setState(() {
        _items = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final (from, to) = _currentDateFilters();
      final items = await DbApiService.instance.getAllInterventionDocuments(
        uploadedBy: _selectedTechnicianId,
        from: from,
        to: to,
        types: types,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Filtres ───────────────────────────────────────────────────────────────

  void _onTechnicianChanged(String? technicianId) {
    setState(() => _selectedTechnicianId = technicianId);
    _load();
  }

  Future<void> _onPresetChanged(_PeriodPreset? preset) async {
    if (preset == null) return;
    if (preset == _PeriodPreset.custom) {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: now,
        initialDateRange: _customRange,
      );
      if (range == null) return; // annulé : préréglage inchangé
      setState(() { _preset = preset; _customRange = range; });
    } else {
      setState(() => _preset = preset);
    }
    _load();
  }

  // ── Exports ───────────────────────────────────────────────────────────────

  Future<void> _downloadZip() async {
    final l10n = AppLocalizations.of(context)!;
    await _runExport(
      setExporting: (v) => setState(() => _isExportingZip = v),
      fetch: (from, to) => DbApiService.instance.downloadInterventionDocumentsZip(
        uploadedBy: _selectedTechnicianId, from: from, to: to, types: _selectedTypes(),
      ),
      onSuccess: (bytes, from, to) =>
          _downloadOrNotifyWebOnly(bytes, 'application/zip', 'interventions_${from}_$to.zip'),
      emptyMessage: l10n.techDocumentsEmpty,
      errorMessage: l10n.techDocumentsZipError,
    );
  }

  Future<void> _printPdf() async {
    final l10n = AppLocalizations.of(context)!;
    await _runExport(
      setExporting: (v) => setState(() => _isExportingPdf = v),
      fetch: (from, to) => DbApiService.instance.printInterventionDocumentsPdf(
        uploadedBy: _selectedTechnicianId, from: from, to: to, types: _selectedTypes(),
      ),
      onSuccess: (bytes, from, to) => Printing.layoutPdf(onLayout: (_) async => bytes),
      emptyMessage: l10n.techDocumentsNoPdfToPrint,
      errorMessage: l10n.techDocumentsPrintError,
    );
  }

  /// Fusionne les PDF d'un seul groupe (incident) et déclenche le téléchargement.
  /// Utilise les mêmes filtres actifs (période, technicien, types) que la liste
  /// affichée : le PDF correspond à ce qui est visible à l'écran pour ce groupe,
  /// pas à l'intégralité des documents de l'incident en base.
  Future<void> _downloadIssuePdf(String issueId) async {
    final l10n = AppLocalizations.of(context)!;
    await _runExport(
      setExporting: (v) => setState(
          () => v ? _exportingIssueIds.add(issueId) : _exportingIssueIds.remove(issueId)),
      fetch: (from, to) => DbApiService.instance.printInterventionDocumentsPdf(
        issueId: issueId, uploadedBy: _selectedTechnicianId, from: from, to: to, types: _selectedTypes(),
      ),
      onSuccess: (bytes, from, to) =>
          _downloadOrNotifyWebOnly(bytes, 'application/pdf', 'intervention_${issueId}_${from}_$to.pdf'),
      emptyMessage: l10n.techDocumentsGroupNoPdf,
      errorMessage: l10n.techDocumentsPrintError,
    );
  }

  /// Sur web : déclenche le téléchargement du fichier via blob URL. Sur natif
  /// (pas de FS accessible depuis le navigateur) : informe l'utilisateur.
  Future<void> _downloadOrNotifyWebOnly(Uint8List bytes, String mimeType, String filename) async {
    if (kIsWeb) {
      openBytesInBrowser(bytes, mimeType, filename);
    } else {
      _showSnack(AppLocalizations.of(context)!.techDocumentsWebOnly, isError: false);
    }
  }

  /// Squelette commun aux deux exports (ZIP/PDF) : bascule le spinner,
  /// appelle l'API avec les filtres courants, et distingue le 404 « rien à
  /// exporter » d'une vraie erreur pour le message affiché.
  Future<void> _runExport({
    required void Function(bool) setExporting,
    required Future<Uint8List> Function(String from, String to) fetch,
    required Future<void> Function(Uint8List bytes, String from, String to) onSuccess,
    required String emptyMessage,
    required String errorMessage,
  }) async {
    setExporting(true);
    try {
      final (from, to) = _currentDateFilters();
      final bytes = await fetch(from, to);
      if (!mounted) return;
      await onSuccess(bytes, from, to);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.statusCode == 404 ? emptyMessage : errorMessage, isError: e.statusCode != 404);
    } catch (_) {
      if (!mounted) return;
      _showSnack(errorMessage, isError: true);
    } finally {
      if (mounted) setExporting(false);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFilters(l10n),
          ),
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  Widget _buildFilters(AppLocalizations l10n) {
    final typesSelected = _selectedTypes();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 0,
          children: [
            FilterChip(
              label: Text(l10n.techDocumentsTypeIntervention),
              selected: _includeIntervention,
              onSelected: (v) {
                setState(() => _includeIntervention = v);
                _onTypesChanged();
              },
            ),
            FilterChip(
              label: Text(l10n.techDocumentsTypeCompletion),
              selected: _includeCompletion,
              onSelected: (v) {
                setState(() => _includeCompletion = v);
                _onTypesChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String?>(
                value: _selectedTechnicianId,
                decoration: InputDecoration(
                  labelText: l10n.techDocumentsFilterTechnician,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.techDocumentsAllTechnicians),
                  ),
                  ..._technicians.map((t) => DropdownMenuItem<String?>(
                        value: t.id,
                        child: Text(t.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: _onTechnicianChanged,
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<_PeriodPreset>(
                value: _preset,
                decoration: InputDecoration(
                  labelText: l10n.techDocumentsFilterPeriod,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: _PeriodPreset.last7Days, child: Text(l10n.techDocumentsPresetLast7Days)),
                  DropdownMenuItem(value: _PeriodPreset.thisMonth, child: Text(l10n.techDocumentsPresetThisMonth)),
                  DropdownMenuItem(value: _PeriodPreset.lastMonth, child: Text(l10n.techDocumentsPresetLastMonth)),
                  DropdownMenuItem(value: _PeriodPreset.custom, child: Text(l10n.techDocumentsPresetCustom)),
                ],
                onChanged: _onPresetChanged,
              ),
            ),
            OutlinedButton.icon(
              onPressed: (_isExportingZip || typesSelected.isEmpty) ? null : _downloadZip,
              icon: _isExportingZip
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.archive_outlined, size: 18),
              label: Text(l10n.techDocumentsDownloadZip),
            ),
            OutlinedButton.icon(
              onPressed: (_isExportingPdf || typesSelected.isEmpty) ? null : _printPdf,
              icon: _isExportingPdf
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print_outlined, size: 18),
              label: Text(l10n.techDocumentsPrint),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_loading && _error == null)
          Text(
            l10n.techDocumentsCount(_items.length),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.techDocumentsRetry),
          ),
        ]),
      );
    }

    if (_items.isEmpty) {
      final message = _selectedTypes().isEmpty ? l10n.techDocumentsNoTypeSelected : l10n.techDocumentsEmpty;
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.folder_open, color: AppColors.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ]),
      );
    }

    final (:named, :orphans) = groupInterventionDocs(_items);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (var i = 0; i < named.length; i++)
          _buildGroupTile(l10n, issueId: named[i].key!, groupDocs: named[i].value, initiallyExpanded: i == 0),
        if (orphans != null)
          _buildGroupTile(l10n, issueId: null, groupDocs: orphans, initiallyExpanded: false),
      ],
    );
  }

  Widget _buildGroupTile(
    AppLocalizations l10n, {
    required String? issueId,
    required List<EquipmentDocument> groupDocs,
    required bool initiallyExpanded,
  }) {
    final isExporting = issueId != null && _exportingIssueIds.contains(issueId);
    return DocGroupTile(
      issueId: issueId,
      groupDocs: groupDocs,
      initiallyExpanded: initiallyExpanded,
      trailing: issueId == null
          ? null
          : IconButton(
              icon: isExporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              tooltip: l10n.techDocumentsDownloadIssuePdf,
              onPressed: isExporting ? null : () => _downloadIssuePdf(issueId),
            ),
      rowBuilder: (doc) => _DocumentRow(doc: doc),
    );
  }
}

// ── Ligne de document (lecture seule : équipement + technicien + date) ──────

class _DocumentRow extends StatelessWidget {
  final EquipmentDocument doc;

  const _DocumentRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final icon = doc.isPhoto
        ? Icons.photo_camera_outlined
        : doc.isPdf
            ? Icons.picture_as_pdf
            : doc.isImage
                ? Icons.image_outlined
                : Icons.insert_drive_file_outlined;
    final iconColor = doc.isPdf ? AppColors.error : AppColors.primary;

    final subtitleParts = <String>[
      doc.displaySize,
      doc.uploaderDisplay,
      formatDocDate(doc.uploadedAt),
      if (doc.equipmentName != null) doc.equipmentName!,
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              doc.originalName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          if (doc.annexNumber != null) ...[
            const SizedBox(width: 6),
            _AnnexBadge(label: l10n.docAnnexBadge(doc.annexNumber!)),
          ],
        ],
      ),
      subtitle: Text(
        subtitleParts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }
}

// ── Badge « Annexe {n} » ──────────────────────────────────────────────────────

class _AnnexBadge extends StatelessWidget {
  final String label;

  const _AnnexBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
      ),
    );
  }
}
