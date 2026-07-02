import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../l10n/app_localizations.dart';
import '../../models/equipment_document.dart';
import '../../services/db_api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/open_blob_url.dart';

/// Section « Documents d'intervention » d'un incident.
///
/// Remplace l'ancien formulaire d'édition manuel (`InterventionReportSection`,
/// jamais réellement rempli en pratique) par la liste des PDF réels générés
/// à la clôture des boucles/du Bon de Travail, plus les pièces jointes
/// complémentaires (photos, certificats...) ajoutées par le technicien.
class InterventionDocumentsSection extends StatefulWidget {
  final String issueId;

  const InterventionDocumentsSection({super.key, required this.issueId});

  @override
  State<InterventionDocumentsSection> createState() => _InterventionDocumentsSectionState();
}

class _InterventionDocumentsSectionState extends State<InterventionDocumentsSection> {
  List<EquipmentDocument> _docs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final docs = await DbApiService.instance.getInterventionDocuments(widget.issueId);
      if (!mounted) return;
      setState(() { _docs = docs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openDocument(EquipmentDocument doc) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final bytes = await DbApiService.instance
          .downloadInterventionDocument(widget.issueId, doc.id);
      if (!mounted) return;
      if (doc.isPdf) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: doc.originalName);
      } else {
        _openBytes(bytes, doc.originalName, doc.mimeType);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.docDownloadError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _openBytes(Uint8List bytes, String name, String mime) {
    if (!mounted) return;
    if (kIsWeb) {
      openBytesInBrowser(bytes, mime, name);
      return;
    }
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
  }

  static String _formatDate(String raw) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
            const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${l10n.interventionDocumentsSectionTitle} (${_docs.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            if (_loading) const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ]),
          const SizedBox(height: 12),
          if (_error != null)
            Text(l10n.interventionDocumentsLoadError,
                style: const TextStyle(color: AppColors.error))
          else if (!_loading && _docs.isEmpty)
            Text(
              l10n.interventionDocumentsEmpty,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontStyle: FontStyle.italic, fontSize: 13),
            )
          else
            ..._docs.map((doc) => _DocumentTile(
              doc: doc,
              dateLabel: _formatDate(doc.uploadedAt),
              onOpen: () => _openDocument(doc),
            )),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final EquipmentDocument doc;
  final String dateLabel;
  final VoidCallback onOpen;

  const _DocumentTile({required this.doc, required this.dateLabel, required this.onOpen});

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
        '${doc.displaySize} · ${doc.uploaderDisplay} · $dateLabel',
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.open_in_new, size: 18),
        color: AppColors.primary,
        onPressed: onOpen,
      ),
    );
  }
}
