import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/issue.dart';
import '../models/issue_photo.dart';
import '../models/equipment.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/db_api_service.dart';
import '../services/data_service.dart';
import '../services/notification_service.dart';
import 'urgency_badge.dart';
import 'status_badge.dart';

/// Motifs de rejet catégorisés — alignés sur REJECT_REASONS côté db-service.
const List<String> kRejectReasons = [
  'duplicate',
  'not_reproducible',
  'out_of_scope',
  'false_alarm',
  'other',
];

/// Libellé localisé d'un motif de rejet.
String _rejectReasonLabel(AppLocalizations l10n, String code) {
  switch (code) {
    case 'duplicate':
      return l10n.rejectReasonDuplicate;
    case 'not_reproducible':
      return l10n.rejectReasonNotReproducible;
    case 'out_of_scope':
      return l10n.rejectReasonOutOfScope;
    case 'false_alarm':
      return l10n.rejectReasonFalseAlarm;
    default:
      return l10n.rejectReasonOther;
  }
}

/// Affiche le sheet de validation rapide d'un incident.
/// < 800 px → ModalBottomSheet. >= 800 px → Dialog centré (max 560 px).
///
/// Le valideur peut : valider (→ Acknowledged), rejeter avec motif (→ Rejected),
/// ou réassigner le groupe. La liste appelante se rafraîchit au retour.
Future<void> showIssueValidationSheet(BuildContext context, Issue issue) {
  final isWide = MediaQuery.of(context).size.width >= AppBreakpoints.desktop;
  if (isWide) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: _ValidationSheetContent(issue: issue, parentContext: context),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => _ValidationSheetContent(
        issue: issue,
        parentContext: context,
        scrollController: scrollController,
      ),
    ),
  );
}

class _ValidationSheetContent extends StatefulWidget {
  final Issue issue;
  final BuildContext parentContext;
  final ScrollController? scrollController;

  const _ValidationSheetContent({
    required this.issue,
    required this.parentContext,
    this.scrollController,
  });

  @override
  State<_ValidationSheetContent> createState() => _ValidationSheetContentState();
}

class _ValidationSheetContentState extends State<_ValidationSheetContent> {
  List<IssuePhoto> _photos = [];
  bool _loadingPhotos = true;
  bool _busy = false; // une action API est en cours

  // Données dérivées du cache local, figées à l'ouverture (évite un filtre/tri
  // O(n) à chaque rebuild déclenché par setState).
  Equipment? _equipment;
  List<Issue> _previousIssues = [];

  Issue get _issue => widget.issue;

  @override
  void initState() {
    super.initState();
    _resolveLocalData();
    _loadPhotos();
  }

  // Résout l'équipement et l'historique d'incidents depuis le cache DataService.
  void _resolveLocalData() {
    if (_issue.equipmentId == null) return;
    _equipment = DataService()
        .equipment
        .where((e) => e.id == _issue.equipmentId)
        .firstOrNull;
    _previousIssues = DataService()
        .issues
        .where((i) => i.equipmentId == _issue.equipmentId && i.id != _issue.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Chargement des photos (non bloquant — erreur ignorée → liste vide).
  Future<void> _loadPhotos() async {
    try {
      final url =
          '${ApiConfig.dbBaseUrl}/api/issues/${Uri.encodeComponent(_issue.id)}/photos';
      final resp = await ApiClient.get(url);
      if (resp.statusCode == 200) {
        final raw = resp.body.isNotEmpty
            ? (jsonDecode(resp.body) as List)
            : <dynamic>[];
        if (mounted) {
          setState(() {
            _photos = raw
                .map((j) => IssuePhoto.fromJson(j as Map<String, dynamic>))
                .toList();
            _loadingPhotos = false;
          });
        }
        return;
      }
    } catch (_) {
      // ignoré — on affiche "aucune photo"
    }
    if (mounted) setState(() => _loadingPhotos = false);
  }

  // ── Helpers post-action ─────────────────────────────────────────────────────

  Future<void> _afterAction(String message, Color color) async {
    await DataService().reloadIssues();
    NotificationService().generateFromLoadedData();
    if (!mounted) return;
    Navigator.of(context).pop(); // ferme le sheet/dialog
    if (!widget.parentContext.mounted) return;
    ScaffoldMessenger.of(widget.parentContext).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showError(Object e) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${l10n.commonApiError}: $e'),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Action : Valider (→ Acknowledged, avec ajustement urgence/groupe) ────────

  void _onValidate() {
    final l10n = AppLocalizations.of(context)!;
    IssueUrgency selectedUrgency = _issue.urgency;
    String? selectedGroup = _issue.assignedGroup;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.issueValidationConfirmTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.issueValidationGroupLabel,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedGroup,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: const ['Biomédical', 'Infrastructure', 'IT']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedGroup = v),
                ),
                const SizedBox(height: 16),
                Text(l10n.issueValidationUrgencyLabel,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: IssueUrgency.values.map((u) {
                    final sel = selectedUrgency == u;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedUrgency = u),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: sel ? AppColors.primary : AppColors.border,
                            width: sel ? 2 : 1,
                          ),
                        ),
                        child: UrgencyBadge(urgency: u, isCompact: true),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _doValidate(selectedUrgency, selectedGroup);
              },
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(l10n.issueValidationValidate),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doValidate(IssueUrgency urgency, String? newGroup) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await DbApiService.instance.updateIssue(_issue.id, {
        'status': 'Acknowledged',
        'urgency': urgency.displayName,
        if (newGroup != null && newGroup != _issue.assignedGroup)
          'assigned_group': newGroup,
      });
      await _afterAction(
          l10n.issueValidationSuccess(_issue.displayName), AppColors.success);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Action : Ne pas valider (→ Rejected, motif catégorisé) ───────────────────

  void _onReject() {
    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    String? selectedReason;
    final commentController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isOther = selectedReason == 'other';
          return AlertDialog(
            title: Text(l10n.rejectConfirmTitle),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    isExpanded: true,
                    hint: Text(l10n.rejectReasonLabel),
                    decoration: InputDecoration(labelText: l10n.rejectReasonLabel),
                    items: kRejectReasons
                        .map((r) => DropdownMenuItem(
                            value: r, child: Text(_rejectReasonLabel(l10n, r))))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedReason = v),
                    validator: (v) => v == null ? l10n.rejectReasonLabel : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: commentController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: l10n.rejectCommentLabel,
                    ),
                    validator: (v) {
                      if (isOther && (v == null || v.trim().length < 5)) {
                        return l10n.rejectCommentRequired;
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final reason = selectedReason!;
                  final comment = commentController.text.trim();
                  Navigator.pop(ctx);
                  _doReject(reason, comment);
                },
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: Text(l10n.rejectConfirmButton),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _doReject(String reasonCode, String comment) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await DbApiService.instance
          .rejectIssue(_issue.id, reasonCode, comment.isEmpty ? null : comment);
      await _afterAction(l10n.rejectSuccess, AppColors.error);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Action : Réassigner le groupe (→ retour au pool, groupe changé) ──────────

  void _onReassign() {
    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    String? selectedGroup;
    final reasonController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.techReassignTitle),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.techReassignSubtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedGroup,
                  isExpanded: true,
                  hint: Text(l10n.techReassignGroupHint),
                  items: const ['IT', 'Infrastructure', 'Biomédical']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedGroup = v),
                  validator: (v) =>
                      v == null ? l10n.techReassignGroupRequired : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.techReassignReasonLabel,
                    hintText: l10n.techReassignReasonHint,
                  ),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? l10n.techReassignReasonMinLength
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final group = selectedGroup!;
                final reason = reasonController.text.trim();
                Navigator.pop(ctx);
                _doReassign(group, reason);
              },
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: Text(l10n.commonConfirm),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doReassign(String newGroup, String reason) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await DbApiService.instance.reassignIssue(_issue.id, newGroup, reason);
      await _afterAction(l10n.techReassignSuccess(newGroup), AppColors.warning);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // En-tête
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.issueValidationSheetTitle,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre incident + badges
                Row(children: [
                  Expanded(
                    child: Text(_issue.displayName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  UrgencyBadge(urgency: _issue.urgency, isCompact: true),
                  const SizedBox(width: 6),
                  IssueStatusBadge(status: _issue.status.displayName),
                ]),
                const SizedBox(height: 16),

                _buildReporterSection(l10n),
                const SizedBox(height: 16),
                _buildObjectSection(l10n),
                const SizedBox(height: 16),
                _buildProblemSection(l10n),
                const SizedBox(height: 16),
                _buildPhotosSection(l10n),
                if (_issue.equipmentId != null) ...[
                  const SizedBox(height: 16),
                  _buildHistorySection(l10n),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        _buildActions(l10n),
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary)),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _buildReporterSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.person_outline, l10n.issueValidationSheetReporter),
        _infoRow(Icons.account_circle_outlined,
            _issue.reporter.isNotEmpty ? _issue.reporter : '—'),
        if ((_issue.reporterEmail ?? '').isNotEmpty)
          _infoRow(Icons.email_outlined, _issue.reporterEmail!),
        if ((_issue.reporterPhone ?? '').isNotEmpty)
          _infoRow(Icons.phone_outlined, _issue.reporterPhone!),
        _infoRow(Icons.schedule, _issue.createdAt),
      ],
    );
  }

  Widget _buildObjectSection(AppLocalizations l10n) {
    final eq = _equipment;
    final children = <Widget>[
      _sectionTitle(Icons.inventory_2_outlined, l10n.issueValidationSheetObject),
    ];
    if (_issue.equipmentId != null) {
      if (eq != null) {
        children.add(_infoRow(Icons.label_outline, eq.name));
        children.add(_infoRow(Icons.category_outlined, eq.category));
        children.add(_infoRow(Icons.place_outlined, eq.location));
        if (eq.serialNumber.isNotEmpty) {
          children.add(_infoRow(Icons.qr_code, eq.serialNumber));
        }
      } else {
        // Équipement introuvable dans le cache local : afficher au moins le nom.
        children.add(_infoRow(
            Icons.label_outline, _issue.equipmentName ?? _issue.displayName));
      }
    } else {
      // Incident sans équipement : lieu / catégorie libre.
      children.add(_infoRow(Icons.place_outlined,
          _issue.locationId ?? _issue.department));
      if ((_issue.issueCategory ?? '').isNotEmpty) {
        children.add(_infoRow(Icons.category_outlined, _issue.issueCategory!));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildProblemSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
            Icons.report_problem_outlined, l10n.issueValidationSheetProblem),
        if (_issue.type.isNotEmpty)
          _infoRow(Icons.bookmark_border, _issue.type),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            _issue.description.isNotEmpty ? _issue.description : '—',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosSection(AppLocalizations l10n) {
    Widget body;
    if (_loadingPhotos) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (_photos.isEmpty) {
      body = Text(l10n.issueValidationSheetNoPhoto,
          style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary));
    } else {
      body = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _photos
            .map((p) => _SheetPhotoThumb(photo: p, issueId: _issue.id))
            .toList(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
            Icons.photo_library_outlined, l10n.issueValidationSheetPhotos),
        body,
      ],
    );
  }

  Widget _buildHistorySection(AppLocalizations l10n) {
    final previous = _previousIssues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.history, l10n.issueValidationSheetHistory),
        if (previous.isEmpty)
          Text(l10n.issueValidationSheetNoHistory,
              style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary))
        else
          ...previous.take(8).map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                        Text(i.createdAt.split('T').first,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IssueStatusBadge(status: i.status.displayName),
                ]),
              )),
      ],
    );
  }

  Widget _buildActions(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(),
            ),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _onValidate,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text(l10n.issueValidationValidate),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _onReject,
                icon: const Icon(Icons.cancel_outlined,
                    size: 16, color: AppColors.error),
                label: Text(l10n.rejectConfirmButton,
                    style: const TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _onReassign,
              icon: const Icon(Icons.swap_horiz,
                  size: 16, color: AppColors.warning),
              label: Text(l10n.techReassignButton,
                  style: const TextStyle(color: AppColors.warning)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.warning),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vignette photo (chargée via l'endpoint download, Content-Disposition inline) ──
class _SheetPhotoThumb extends StatefulWidget {
  final IssuePhoto photo;
  final String issueId;

  const _SheetPhotoThumb({required this.photo, required this.issueId});

  @override
  State<_SheetPhotoThumb> createState() => _SheetPhotoThumbState();
}

class _SheetPhotoThumbState extends State<_SheetPhotoThumb> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final url =
        '${ApiConfig.dbBaseUrl}/api/issues/${Uri.encodeComponent(widget.issueId)}'
        '/photos/${widget.photo.id}/download';
    try {
      final resp = await ApiClient.get(url);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() {
          _bytes = resp.bodyBytes;
          _loading = false;
        });
      } else {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  void _openFullScreen() {
    if (_bytes == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(children: [
          Container(
            color: Colors.black,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.9),
            child: InteractiveViewer(
              child: Image.memory(_bytes!, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
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
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openFullScreen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 80,
          height: 80,
          color: AppColors.background,
          child: _loading
              ? const Center(
                  child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : (_error || _bytes == null)
                  ? const Center(
                      child: Icon(Icons.broken_image,
                          color: AppColors.textMuted, size: 24))
                  : Image.memory(_bytes!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
