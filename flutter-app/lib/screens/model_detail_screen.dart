import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user_role.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/open_blob_url.dart';
import '../widgets/detail_breadcrumb.dart';
import '../widgets/status_badge.dart';
import 'detail_screen_helpers.dart';
import 'subcategory_detail_screen.dart';

/// Fiche technique d'un modèle (couple fabricant + modèle).
///
/// Trois sections :
///  • Équipements   — les équipements rattachés au modèle.
///  • Documents     — fiches techniques / interventions / certifications.
///  • Protocoles PM — protocoles de maintenance liés au modèle.
///
/// Édition (upload/suppression doc, lien/délien protocole) réservée à la
/// permission [Permission.manageCategories].
class ModelDetailScreen extends StatefulWidget {
  final int modelId;
  final String modelName;
  final String brandName;
  final int subcategoryId;
  final String subcategoryName;

  const ModelDetailScreen({
    super.key,
    required this.modelId,
    required this.modelName,
    required this.brandName,
    required this.subcategoryId,
    required this.subcategoryName,
  });

  @override
  State<ModelDetailScreen> createState() => _ModelDetailScreenState();
}

class _ModelDetailScreenState extends State<ModelDetailScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _equipment = [];
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _protocols = [];

  bool get _canManage => AuthService().hasPermission(Permission.manageCategories);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await DbApiService.instance.getModelDetail(widget.modelId);
      if (mounted) setState(() {
        _equipment = List<Map<String, dynamic>>.from((detail['equipment'] as List?) ?? const []);
        _documents = List<Map<String, dynamic>>.from((detail['documents'] as List?) ?? const []);
        _protocols = List<Map<String, dynamic>>.from((detail['protocols'] as List?) ?? const []);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.modelDetailTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error))))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Fil d'Ariane : Sous-catégorie (cliquable) › Modèle courant.
                    // Le fabricant est omis (pas d'id fabricant dans ce contexte).
                    DetailBreadcrumb(
                      padding: const EdgeInsets.only(bottom: 8),
                      segments: [
                        BreadcrumbSegment(widget.subcategoryName, onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubcategoryDetailScreen(
                              subcategoryId: widget.subcategoryId,
                              subcategoryName: widget.subcategoryName,
                            ),
                          ),
                        )),
                        BreadcrumbSegment(widget.modelName),
                      ],
                    ),
                    // ── En-tête ─────────────────────────────────────────────
                    Text(widget.modelName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('${widget.brandName} · ${widget.subcategoryName}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),

                    // ── Équipements ─────────────────────────────────────────
                    _sectionHeader(Icons.inventory_2_outlined, l10n.modelEquipmentSection),
                    const SizedBox(height: 8),
                    _buildEquipment(l10n),
                    const SizedBox(height: 16),

                    // ── Documents ───────────────────────────────────────────
                    Row(children: [
                      Expanded(child: _sectionHeader(Icons.description_outlined, l10n.modelDocumentsSection)),
                      if (_canManage)
                        TextButton.icon(
                          onPressed: () => _showUploadDialog(l10n),
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: Text(l10n.commonAdd, style: const TextStyle(fontSize: 12)),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    _buildDocuments(l10n),
                    const SizedBox(height: 16),

                    // ── Protocoles PM ───────────────────────────────────────
                    Row(children: [
                      Expanded(child: _sectionHeader(Icons.checklist, l10n.modelProtocolsSection)),
                      if (_canManage)
                        TextButton.icon(
                          onPressed: () => _showLinkProtocolDialog(l10n),
                          icon: const Icon(Icons.add_link, size: 16),
                          label: Text(l10n.catalogLinkProtocol, style: const TextStyle(fontSize: 12)),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    _buildProtocols(l10n),
                  ],
                ),
    );
  }

  Widget _sectionHeader(IconData icon, String label) =>
      detailSectionHeader(icon, label);

  Widget _emptyCard(String message) => detailEmptyCard(message);

  Widget _buildEquipment(AppLocalizations l10n) {
    if (_equipment.isEmpty) return _emptyCard(l10n.settingsEmptyList);
    return Card(
      child: Column(
        children: _equipment.map((e) {
          final status = e['status'] as String? ?? '';
          return ListTile(
            dense: true,
            leading: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.textSecondary),
            title: Text(e['name'] as String? ?? '—', style: const TextStyle(fontSize: 14)),
            trailing: status.isEmpty ? null : StatusBadge(status: status, isCompact: true),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDocuments(AppLocalizations l10n) {
    if (_documents.isEmpty) return _emptyCard(l10n.docNoDocuments);
    return Card(
      child: Column(
        children: _documents.map((d) {
          final mime = d['mime_type'] as String? ?? '';
          final isPdf = mime.contains('pdf');
          return ListTile(
            dense: true,
            leading: Icon(isPdf ? Icons.picture_as_pdf : Icons.image_outlined,
                size: 20, color: isPdf ? AppColors.error : AppColors.primary),
            title: Text(d['original_name'] as String? ?? '—',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
            subtitle: Text(_docTypeLabel(l10n, d['document_type'] as String? ?? ''),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  color: AppColors.primary,
                  tooltip: l10n.commonOpen,
                  onPressed: () => _openDocument(l10n, d),
                ),
                if (_canManage)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppColors.error,
                    tooltip: l10n.commonDelete,
                    onPressed: () => _confirmDeleteDocument(l10n, d),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProtocols(AppLocalizations l10n) {
    if (_protocols.isEmpty) return _emptyCard(l10n.modelNoProtocols);
    return Card(
      child: Column(
        children: _protocols.map((p) {
          final freq = (p['frequency_months'] as num?)?.toInt();
          return ListTile(
            dense: true,
            leading: const Icon(Icons.checklist, size: 18, color: AppColors.textSecondary),
            title: Text(p['name'] as String? ?? '—', style: const TextStyle(fontSize: 14)),
            subtitle: freq == null
                ? null
                : Text(l10n.catalogProtocolFrequency(freq),
                    style: const TextStyle(fontSize: 12)),
            trailing: _canManage
                ? IconButton(
                    icon: const Icon(Icons.link_off, size: 18),
                    color: AppColors.error,
                    tooltip: l10n.catalogUnlinkProtocol,
                    onPressed: () => _unlinkProtocol(l10n, p['id'] as int),
                  )
                : null,
          );
        }).toList(),
      ),
    );
  }

  String _docTypeLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'technical':     return l10n.docTypeTechnical;
      case 'intervention':  return l10n.docTypeIntervention;
      case 'certification': return l10n.docTypeCertification;
      default:              return type;
    }
  }

  // ── Upload document ─────────────────────────────────────────────────────────
  Future<void> _showUploadDialog(AppLocalizations l10n) async {
    String? selectedType;
    final types = <String, String>{
      'technical':     l10n.docTypeTechnical,
      'intervention':  l10n.docTypeIntervention,
      'certification': l10n.docTypeCertification,
    };
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(l10n.docTypeLabel),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: types.entries.map((e) => RadioListTile<String>(
              title: Text(e.value),
              value: e.key,
              groupValue: selectedType,
              onChanged: (v) => setDialog(() => selectedType = v),
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            ElevatedButton(
              onPressed: selectedType == null ? null : () {
                Navigator.pop(ctx);
                _pickAndUpload(l10n, selectedType!);
              },
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(AppLocalizations l10n, String docType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    try {
      await DbApiService.instance.uploadModelDocument(
        widget.modelId,
        Uint8List.fromList(bytes),
        file.name,
        _mimeFromExtension(file.extension ?? ''),
        type: docType,
      );
      await _load();
      _snack(l10n.docUploadSuccess);
    } catch (e) {
      _snack(l10n.docUploadError(e.toString()), error: true);
    }
  }

  Future<void> _openDocument(AppLocalizations l10n, Map<String, dynamic> doc) async {
    final url = ApiConfig.modelDocumentDownloadUrl(widget.modelId, doc['id'] as int);
    try {
      final resp = await ApiClient.get(url);
      if (!mounted) return;
      if (resp.statusCode != 200) throw Exception('Erreur ${resp.statusCode}');
      final mime = doc['mime_type'] as String? ?? 'application/octet-stream';
      final name = doc['original_name'] as String? ?? 'document';
      if (kIsWeb) {
        openBytesInBrowser(resp.bodyBytes, mime, name);
      } else if (mime.startsWith('image/')) {
        _previewImage(resp.bodyBytes);
      } else {
        _snack('$name — ${l10n.docOpenNativeUnsupported}');
      }
    } catch (e) {
      _snack(l10n.docDownloadError, error: true);
    }
  }

  void _previewImage(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              color: Colors.black,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
              child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDocument(AppLocalizations l10n, Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.docDeleteConfirmTitle),
        content: Text(l10n.docDeleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DbApiService.instance.deleteModelDocument(widget.modelId, doc['id'] as int);
      await _load();
      _snack(l10n.docDeleteSuccess);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }

  // ── Lien / délien protocole PM ──────────────────────────────────────────────
  Future<void> _showLinkProtocolDialog(AppLocalizations l10n) async {
    // Protocoles disponibles : ceux de la sous-catégorie non encore liés.
    List<Map<String, dynamic>> available = [];
    try {
      final detail = await DbApiService.instance.getSubCategoryDetail(widget.subcategoryId);
      final all = List<Map<String, dynamic>>.from((detail['protocols'] as List?) ?? const []);
      final linkedIds = _protocols.map((p) => p['id'] as int).toSet();
      available = all.where((p) => !linkedIds.contains(p['id'] as int)).toList();
    } catch (e) {
      _snack(e.toString(), error: true);
      return;
    }
    if (!mounted) return;

    if (available.isEmpty) {
      _snack(l10n.catalogNoProtocolToLink);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.catalogLinkProtocol),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: available.map((p) => ListTile(
              dense: true,
              title: Text(p['name'] as String? ?? '—', style: const TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.add_link, size: 18, color: AppColors.primary),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await DbApiService.instance.linkModelProtocol(widget.modelId, p['id'] as int);
                  await _load();
                  _snack(l10n.catalogProtocolLinked);
                } on ApiException catch (e) {
                  _snack(e.message, error: true);
                }
              },
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
        ],
      ),
    );
  }

  Future<void> _unlinkProtocol(AppLocalizations l10n, int protocolId) async {
    try {
      await DbApiService.instance.unlinkModelProtocol(widget.modelId, protocolId);
      await _load();
      _snack(l10n.catalogProtocolUnlinked);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }

  static String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
      default:
        return 'application/pdf';
    }
  }
}
