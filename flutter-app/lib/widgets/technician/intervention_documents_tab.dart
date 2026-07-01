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
import '../../utils/open_blob_url.dart';
import '../pagination_footer.dart';

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
  static const int _pageSize = 20;
  static final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');

  List<EquipmentDocument> _items = [];
  int _total = 0, _page = 1, _totalPages = 1;
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
    _load(page: 1);
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

  Future<void> _load({int page = 1}) async {
    if (!mounted) return;
    final types = _selectedTypes();
    if (types.isEmpty) {
      setState(() {
        _items = [];
        _total = 0;
        _page = 1;
        _totalPages = 1;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final (from, to) = _currentDateFilters();
      final result = await DbApiService.instance.getInterventionDocumentsPaged(
        page: page,
        limit: _pageSize,
        uploadedBy: _selectedTechnicianId,
        from: from,
        to: to,
        types: types,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _page = result.page;
        _totalPages = result.totalPages;
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
    _load(page: 1);
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
    _load(page: 1);
  }

  // ── Exports ───────────────────────────────────────────────────────────────

  Future<void> _downloadZip() async {
    final l10n = AppLocalizations.of(context)!;
    await _runExport(
      setExporting: (v) => setState(() => _isExportingZip = v),
      fetch: (from, to) => DbApiService.instance.downloadInterventionDocumentsZip(
        uploadedBy: _selectedTechnicianId, from: from, to: to, types: _selectedTypes(),
      ),
      onSuccess: (bytes, from, to) async {
        if (kIsWeb) {
          openBytesInBrowser(bytes, 'application/zip', 'interventions_${from}_$to.zip');
        } else {
          _showSnack(l10n.techDocumentsWebOnly, isError: false);
        }
      },
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
      onRefresh: () => _load(page: _page),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFilters(l10n),
          ),
          Expanded(child: _buildBody(l10n)),
          if (!_loading && _error == null && _totalPages > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: PaginationFooter(
                currentPage: _page,
                totalPages: _totalPages,
                isLoading: _loading,
                onPageChange: (p) => _load(page: p),
              ),
            ),
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
            l10n.techDocumentsCount(_total),
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
            onPressed: () => _load(page: _page),
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

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => _DocumentRow(doc: _items[i]),
    );
  }
}

// ── Ligne de document (lecture seule : équipement + technicien + date) ──────

class _DocumentRow extends StatelessWidget {
  final EquipmentDocument doc;

  const _DocumentRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    final icon = doc.isPdf
        ? Icons.picture_as_pdf
        : doc.isImage
            ? Icons.image_outlined
            : Icons.insert_drive_file_outlined;
    final iconColor = doc.isPdf ? AppColors.error : AppColors.primary;

    final subtitleParts = <String>[
      doc.displaySize,
      doc.uploaderName,
      _formatDate(doc.uploadedAt),
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
      title: Text(
        doc.originalName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitleParts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }
}
