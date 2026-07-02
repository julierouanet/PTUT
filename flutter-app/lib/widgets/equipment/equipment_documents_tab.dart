import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/open_blob_url.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../models/equipment_document.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/intervention_document_grouping.dart';
import '../../utils/mime_from_extension.dart';
import '../doc_group_tile.dart';

/// Onglet Documents d'un équipement.
///
/// Affiché uniquement pour les rôles non-hospitalStaff
/// (la garde RBAC est déjà appliquée par EquipmentDetailScreen qui redirige
/// le personnel médical vers EquipmentStaffView).
///
/// Deux sections :
///  • Techniques & Certifications (document_type: technical, certification)
///  • Documents d'intervention    (document_type: intervention)
class EquipmentDocumentsTab extends StatefulWidget {
  final Equipment equipment;

  const EquipmentDocumentsTab({super.key, required this.equipment});

  @override
  State<EquipmentDocumentsTab> createState() => _EquipmentDocumentsTabState();
}

class _EquipmentDocumentsTabState extends State<EquipmentDocumentsTab> {
  List<EquipmentDocument> _docs = [];
  bool _loading = true;
  String? _error;

  bool get _canManage => AuthService().canManageEquipment;

  String get _baseUrl =>
      '${ApiConfig.dbBaseUrl}/api/equipment/${Uri.encodeComponent(widget.equipment.id)}';

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  // ── Chargement ────────────────────────────────────────────────────────────────

  Future<void> _loadDocuments() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await ApiClient.get('$_baseUrl/documents');
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final raw = jsonDecode(resp.body) as List;
        setState(() {
          _docs = raw.map((j) => EquipmentDocument.fromJson(j as Map<String, dynamic>)).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Erreur ${resp.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Upload ────────────────────────────────────────────────────────────────────

  Future<void> _uploadDocument(BuildContext ctx, String docType) async {
    final l10n = AppLocalizations.of(ctx)!;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final mimeType = mimeFromExtension(file.extension ?? '');

    try {
      await ApiClient.postMultipart(
        '$_baseUrl/documents',
        Uint8List.fromList(bytes),
        file.name,
        mimeType,
        {'type': docType},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(l10n.docUploadSuccess),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      await _loadDocuments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(l10n.docUploadError(e.toString())),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Téléchargement ────────────────────────────────────────────────────────────

  Future<void> _openDocument(BuildContext ctx, EquipmentDocument doc) async {
    final l10n = AppLocalizations.of(ctx)!;
    final url = '$_baseUrl/documents/${doc.id}/download';
    try {
      final resp = await ApiClient.get(url);
      if (!mounted) return;
      if (resp.statusCode != 200) throw Exception('Erreur ${resp.statusCode}');

      // Sur web : ouverture via blob URL
      _openBytes(resp.bodyBytes, doc.originalName, doc.mimeType);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(l10n.docDownloadError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _openBytes(Uint8List bytes, String name, String mime) {
    if (!mounted) return;

    if (kIsWeb) {
      // Sur web : blob URL via import conditionnel (dart:html inaccessible sur VM/natif)
      openBytesInBrowser(bytes, mime, name);
      return;
    }

    // Sur natif : préview image en plein écran uniquement
    if (mime.startsWith('image/')) {
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
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                ),
                child: InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // PDF natif : informer que l'ouverture nécessite un plugin externe
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$name — ouverture PDF non supportée sur cette plateforme natif'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Suppression ───────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(BuildContext ctx, EquipmentDocument doc) async {
    final l10n = AppLocalizations.of(ctx)!;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.docDeleteConfirmTitle),
        content: Text(l10n.docDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final resp = await ApiClient.delete('$_baseUrl/documents/${doc.id}');
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(l10n.docDeleteSuccess),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
        await _loadDocuments();
      } else {
        throw Exception('Erreur ${resp.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('${l10n.commonError} : $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Sélecteur de type pour l'upload ──────────────────────────────────────────

  Future<void> _showUploadDialog(BuildContext ctx) async {
    final l10n = AppLocalizations.of(ctx)!;
    String? selectedType;
    final types = <String, String>{
      'technical':     l10n.docTypeTechnical,
      'intervention':  l10n.docTypeIntervention,
      'certification': l10n.docTypeCertification,
    };

    await showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(l10n.docTypeLabel),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: types.entries.map((e) => RadioListTile<String>(
              title: Text(e.value),
              value: e.key,
              groupValue: selectedType,
              onChanged: (v) => setDialogState(() => selectedType = v),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: selectedType == null ? null : () {
                Navigator.pop(dialogCtx);
                _uploadDocument(ctx, selectedType!);
              },
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
            onPressed: _loadDocuments,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ]),
      );
    }

    final techDocs = _docs
        .where((d) => d.documentType == 'technical' || d.documentType == 'certification')
        .toList();
    final interDocs = _docs.where((d) => d.documentType == 'intervention').toList();

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section technique + certifications ──────────────────────────
            _DocumentSection(
              title: l10n.docTechnicalSection,
              icon: Icons.description_outlined,
              docs: techDocs,
              canManage: _canManage,
              emptyLabel: l10n.docNoDocuments,
              onOpen: (doc) => _openDocument(context, doc),
              onDelete: (doc) => _confirmDelete(context, doc),
              onAdd: _canManage ? () => _showUploadDialog(context) : null,
            ),
            const SizedBox(height: 16),

            // ── Section documents d'intervention (regroupés par incident) ──
            _InterventionDocumentsSection(
              docs: interDocs,
              canManage: _canManage,
              emptyLabel: l10n.docNoDocuments,
              onOpen: (doc) => _openDocument(context, doc),
              onDelete: (doc) => _confirmDelete(context, doc),
              onAdd: _canManage ? () => _showUploadDialog(context) : null,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

}

// ── En-tête de section mutualisé ─────────────────────────────────────────────

class _DocumentSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final bool canManage;
  final VoidCallback? onAdd;

  const _DocumentSectionHeader({
    required this.title,
    required this.icon,
    required this.count,
    required this.canManage,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          '$title ($count)',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      if (canManage && onAdd != null)
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.upload_file, size: 16),
          label: const Text('Ajouter', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        ),
    ]);
  }
}

// ── Section de documents (technique / certifications) ────────────────────────

class _DocumentSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<EquipmentDocument> docs;
  final bool canManage;
  final String emptyLabel;
  final void Function(EquipmentDocument) onOpen;
  final void Function(EquipmentDocument) onDelete;
  final VoidCallback? onAdd;

  const _DocumentSection({
    required this.title,
    required this.icon,
    required this.docs,
    required this.canManage,
    required this.emptyLabel,
    required this.onOpen,
    required this.onDelete,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DocumentSectionHeader(
              title: title,
              icon: icon,
              count: docs.length,
              canManage: canManage,
              onAdd: onAdd,
            ),
            const Divider(height: 20),
            if (docs.isEmpty)
              _emptyRow(emptyLabel)
            else
              ...docs.map((doc) => _DocumentTile(
                doc: doc,
                canManage: canManage,
                onOpen: () => onOpen(doc),
                onDelete: () => onDelete(doc),
              )),
          ],
        ),
      ),
    );
  }
}

// ── Section documents d'intervention (regroupée par incident) ────────────────

class _InterventionDocumentsSection extends StatelessWidget {
  final List<EquipmentDocument> docs;
  final bool canManage;
  final String emptyLabel;
  final void Function(EquipmentDocument) onOpen;
  final void Function(EquipmentDocument) onDelete;
  final VoidCallback? onAdd;

  const _InterventionDocumentsSection({
    required this.docs,
    required this.canManage,
    required this.emptyLabel,
    required this.onOpen,
    required this.onDelete,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (:named, :orphans) = groupInterventionDocs(docs);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DocumentSectionHeader(
              title: l10n.docInterventionSection,
              icon: Icons.build_outlined,
              count: docs.length,
              canManage: canManage,
              onAdd: onAdd,
            ),
            const Divider(height: 20),

            if (docs.isEmpty)
              _emptyRow(emptyLabel)
            else ...[
              for (var i = 0; i < named.length; i++)
                _groupTile(
                  issueId: named[i].key!,
                  groupDocs: named[i].value,
                  initiallyExpanded: i == 0,
                ),
              if (orphans != null)
                _groupTile(
                  issueId: null,
                  groupDocs: orphans,
                  initiallyExpanded: false,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _groupTile({
    required String? issueId,
    required List<EquipmentDocument> groupDocs,
    required bool initiallyExpanded,
  }) {
    return DocGroupTile(
      issueId: issueId,
      groupDocs: groupDocs,
      initiallyExpanded: initiallyExpanded,
      children: groupDocs.map((doc) => _DocumentTile(
        doc: doc,
        canManage: canManage,
        onOpen: () => onOpen(doc),
        onDelete: () => onDelete(doc),
      )).toList(),
    );
  }
}

// ── État vide partagé ─────────────────────────────────────────────────────────

Widget _emptyRow(String label) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(children: [
    const Icon(Icons.folder_open, color: AppColors.textMuted, size: 18),
    const SizedBox(width: 8),
    Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontStyle: FontStyle.italic,
        fontSize: 13,
      ),
    ),
  ]),
);

// ── Tuile d'un document ───────────────────────────────────────────────────────

class _DocumentTile extends StatelessWidget {
  final EquipmentDocument doc;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _DocumentTile({
    required this.doc,
    required this.canManage,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final icon = doc.isPdf
        ? Icons.picture_as_pdf
        : doc.isImage
            ? Icons.image_outlined
            : Icons.insert_drive_file_outlined;

    final iconColor = doc.isPdf ? AppColors.error : AppColors.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
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
        '${doc.displaySize} · ${doc.uploaderName} · ${formatDocDate(doc.uploadedAt)}',
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 18),
            tooltip: 'Ouvrir',
            color: AppColors.primary,
            onPressed: onOpen,
          ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Supprimer',
              color: AppColors.error,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
