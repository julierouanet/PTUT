import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/equipment.dart' show Equipment;
import '../models/issue.dart';
import '../models/issue_detail.dart';
import '../models/issue_photo.dart';
import '../models/user_role.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/equipment_picker_field.dart';
import '../widgets/status_badge.dart';
import '../widgets/urgency_badge.dart';
import '../widgets/issue/intervention_report_section.dart';
import 'equipment_detail_screen.dart';

/// Page complète de détail d'un incident — standard GMAO.
///
/// [issueId]       : identifiant de l'incident à charger.
/// [onNavigate]    : callback navigation vers l'écran technicien (index 4).
/// [isPanel]       : si true, pas de Scaffold — utilisé en mode Split View desktop.
/// [onClosePanel]  : callback pour fermer le panneau (mode panel uniquement).
class IssueDetailScreen extends StatefulWidget {
  final String issueId;
  final Function(int, {String? issueId})? onNavigate;
  final bool isPanel;
  final VoidCallback? onClosePanel;

  const IssueDetailScreen({
    super.key,
    required this.issueId,
    this.onNavigate,
    this.isPanel = false,
    this.onClosePanel,
  });

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  // ── Services ──────────────────────────────────────────────────────────────
  final AuthService _authService = AuthService();

  // ── État ──────────────────────────────────────────────────────────────────
  IssueDetail? _detail;
  List<IssuePhoto> _photos = [];
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  // ── RBAC ──────────────────────────────────────────────────────────────────

  bool get _isPrivileged {
    final roles = _authService.currentRoles;
    return roles.contains(UserRole.supervisor) || roles.contains(UserRole.admin);
  }

  bool get _isHospitalStaff =>
      _authService.currentRoles.contains(UserRole.hospitalStaff);

  bool get _isAdmin => _authService.currentRoles.contains(UserRole.admin);

  /// Le rapport est éditable si l'incident est pris en charge ET que
  /// l'utilisateur est privilégié OU le technicien assigné.
  bool _canEditReport(IssueDetail detail) {
    final issue = detail.issue;
    if (!issue.isHandled) return false;
    if (_isPrivileged) return true;
    final me = _authService.currentUser?.name;
    return me != null && me.isNotEmpty && me == issue.assignedTechnician;
  }

  // ── Cycle de vie ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(IssueDetailScreen old) {
    super.didUpdateWidget(old);
    if (old.issueId != widget.issueId) {
      setState(() { _loading = true; _error = null; _detail = null; });
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final detail = await DbApiService.instance.getIssueDetail(widget.issueId);
      if (!mounted) return;

      // Chargement des photos en parallèle (non bloquant — erreur ignorée)
      List<IssuePhoto> photos = [];
      try {
        final photosUrl =
            '${ApiConfig.dbBaseUrl}/api/issues/${Uri.encodeComponent(widget.issueId)}/photos';
        final photosResp = await ApiClient.get(photosUrl);
        if (photosResp.statusCode == 200) {
          final raw = jsonDecode(photosResp.body) as List;
          photos = raw.map((j) => IssuePhoto.fromJson(j as Map<String, dynamic>)).toList();
        }
      } catch (_) {}

      if (mounted) setState(() { _detail = detail; _photos = photos; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Formatage de dates ─────────────────────────────────────────────────────

  static String _fmtDateTime(String raw) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  static String _fmtDate(String raw) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  // ── Recherche date de prise en charge ─────────────────────────────────────

  String? _findAssignmentDate(List<IssueAuditEntry> log) {
    for (final entry in log) {
      final details   = entry.parsedDetails;
      final newStatus = details?['new_status'] as String?;
      if (newStatus == 'In Progress' || newStatus == 'Assigned') {
        return _fmtDate(entry.timestamp);
      }
      if (entry.action.contains('in_progress') || entry.action.contains('assigned')) {
        return _fmtDate(entry.timestamp);
      }
    }
    return null;
  }

  // ── Build principal ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return widget.isPanel ? _buildPanelContent(context, l10n) : _buildScaffold(l10n);
  }

  // ── Mode Scaffold (navigation standard) ───────────────────────────────────

  Widget _buildScaffold(AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _detail != null
              ? l10n.issuesIncidentId(_detail!.issue.id)
              : l10n.issueDetailTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
        actions: [
          if (_detail != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IssueStatusBadge(status: _detail!.issue.status.displayName),
                const SizedBox(width: 8),
                UrgencyBadge(urgency: _detail!.issue.urgency),
              ]),
            ),
        ],
      ),
      body: _buildBody(l10n),
      bottomNavigationBar: _detail != null ? _buildBottomBar(l10n) : null,
    );
  }

  // ── Mode Panel (split view desktop) ───────────────────────────────────────

  Widget _buildPanelContent(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En-tête du panneau
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            if (_detail != null) ...[
              Expanded(
                child: Text(
                  l10n.issuesIncidentId(_detail!.issue.id),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IssueStatusBadge(status: _detail!.issue.status.displayName),
              const SizedBox(width: 8),
              UrgencyBadge(urgency: _detail!.issue.urgency),
            ] else
              const Expanded(child: SizedBox()),
            const SizedBox(width: 8),
            if (widget.onClosePanel != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: l10n.issueDetailClosePanel,
                onPressed: widget.onClosePanel,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ]),
        ),
        // Corps
        Expanded(child: _buildBody(l10n)),
        // Barre d'action basse
        if (_detail != null) _buildBottomBar(l10n),
      ],
    );
  }

  // ── Corps commun ──────────────────────────────────────────────────────────

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l10n.issueDetailLoading,
              style: const TextStyle(color: AppColors.textSecondary)),
        ]),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(l10n.issueDetailLoadError,
              style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() { _loading = true; _error = null; });
              _load();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ]),
      );
    }

    final detail  = _detail!;
    final isMobile = MediaQuery.of(context).size.width < AppBreakpoints.tablet;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() { _loading = true; _error = null; });
        await _load();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHandledByBanner(l10n, detail),
            const SizedBox(height: 12),
            _buildHeaderCard(l10n, detail),
            const SizedBox(height: 12),
            if (_isPrivileged) ...[
              _buildSupervisorActions(l10n, detail),
              const SizedBox(height: 12),
            ],
            _buildContextCard(l10n, detail),
            const SizedBox(height: 12),
            _buildFailureCard(l10n, detail.issue),
            const SizedBox(height: 12),
            _buildInterventionCard(l10n, detail.issue),
            if (!_isHospitalStaff) ...[
              const SizedBox(height: 12),
              InterventionReportSection(
                key: ValueKey('report-${detail.issue.id}'),
                issueId: detail.issue.id,
                canEdit: _canEditReport(detail),
                isAdmin: _isAdmin,
              ),
            ],
            if (detail.maintenanceRecords.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildMaintenanceCard(l10n, detail.maintenanceRecords),
            ],
            const SizedBox(height: 12),
            _buildTimelineCard(l10n, detail.auditLog),
            const SizedBox(height: 12),
            _buildDocumentsCard(l10n),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── Bannière "Pris en charge" ──────────────────────────────────────────────

  Widget _buildHandledByBanner(AppLocalizations l10n, IssueDetail detail) {
    final issue = detail.issue;
    final isHandled = issue.isHandled;

    final Color bgColor;
    final Color borderColor;
    final Color iconColor;
    final IconData icon;

    if (!isHandled) {
      bgColor      = AppColors.warning.withValues(alpha: 0.08);
      borderColor  = AppColors.warning.withValues(alpha: 0.3);
      iconColor    = AppColors.warning;
      icon         = Icons.hourglass_top_rounded;
    } else if (_isHospitalStaff) {
      // Mise en valeur renforcée pour le personnel médical
      bgColor      = AppColors.success.withValues(alpha: 0.12);
      borderColor  = AppColors.success.withValues(alpha: 0.5);
      iconColor    = AppColors.success;
      icon         = Icons.shield_outlined;
    } else {
      bgColor      = AppColors.primaryLight;
      borderColor  = AppColors.primary.withValues(alpha: 0.3);
      iconColor    = AppColors.primary;
      icon         = Icons.engineering_outlined;
    }

    final String text;
    if (!isHandled) {
      text = l10n.issueDetailNotHandledYet;
    } else {
      final techName   = issue.assignedTechnician ?? '—';
      final assignDate =
          _findAssignmentDate(detail.auditLog) ?? _fmtDate(issue.createdAt);
      text = l10n.issueDetailHandledBy(techName, assignDate);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: _isHospitalStaff && isHandled ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: iconColor,
              fontWeight: _isHospitalStaff ? FontWeight.w600 : FontWeight.w500,
              fontSize: _isHospitalStaff ? 14 : 13,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Actions rapides superviseur / admin ───────────────────────────────────

  Widget _buildSupervisorActions(AppLocalizations l10n, IssueDetail detail) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        // Validation — uniquement pour un incident encore au statut "signalé"
        if (detail.issue.status == IssueStatus.reported)
          ElevatedButton.icon(
            onPressed: _submitting ? null : () => _showValidateDialog(l10n, detail),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: Text(l10n.issueValidationValidate),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _submitting ? null : () => _showReassignDialog(l10n, detail),
          icon: const Icon(Icons.swap_horiz, size: 16),
          label: Text(l10n.issueDetailReassignButton),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _submitting ? null : () => _showCommentDialog(l10n),
          icon: const Icon(Icons.comment_outlined, size: 16),
          label: Text(l10n.issueDetailAddCommentButton),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }

  // ── Dialogue réassignation ─────────────────────────────────────────────────

  void _showReassignDialog(AppLocalizations l10n, IssueDetail detail) {
    String? selectedGroup = detail.issue.assignedGroup;
    final reasonCtrl      = TextEditingController();
    final formKey         = GlobalKey<FormState>();
    const groups          = ['Biomédical', 'IT', 'Infrastructure'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.issueDetailReassignTitle),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.issueDetailReassignGroupLabel,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGroup,
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    items: groups
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedGroup = v),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.issueDetailReassignReasonLabel,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: l10n.issueDetailReassignReasonHint,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 5)
                            ? l10n.issueDetailReassignReasonMinLength
                            : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (selectedGroup == null) return;
                Navigator.pop(ctx);
                await _doReassign(
                    l10n, selectedGroup!, reasonCtrl.text.trim());
              },
              icon: const Icon(Icons.check, size: 16),
              label: Text(l10n.commonSave),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doReassign(
      AppLocalizations l10n, String group, String reason) async {
    setState(() => _submitting = true);
    try {
      await DbApiService.instance
          .reassignIssue(widget.issueId, group, reason);
      setState(() { _loading = true; _error = null; });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.issueDetailReassignSuccess),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.issueDetailReassignError(e.toString())),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Dialogue validation (tri d'un incident signalé) ────────────────────────

  Color _validationUrgencyColor(IssueUrgency u) {
    switch (u) {
      case IssueUrgency.faible:   return AppColors.textSecondary;
      case IssueUrgency.moyen:    return AppColors.warning;
      case IssueUrgency.urgent:   return AppColors.error;
      case IssueUrgency.critique: return AppColors.critical;
    }
  }

  void _showValidateDialog(AppLocalizations l10n, IssueDetail detail) {
    final issue = detail.issue;
    IssueUrgency selectedUrgency = issue.urgency;
    String? selectedGroup = issue.assignedGroup;
    const groups = ['Biomédical', 'IT', 'Infrastructure'];

    // Délai depuis le signalement (borné à 0 si le parsing échoue)
    int daysAgo;
    try {
      daysAgo = DateTime.now()
          .difference(DateTime.parse(issue.createdAt))
          .inDays;
      if (daysAgo < 0) daysAgo = 0;
    } catch (_) {
      daysAgo = 0;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.issueValidationConfirmTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicateur de délai depuis le signalement
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.schedule,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Text(l10n.issueValidationReportedAgo(daysAgo),
                        style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(l10n.issueValidationConfirmContent),
                const SizedBox(height: 8),
                Text(issue.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(issue.description,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),

                // Groupe technique
                Text(l10n.issueValidationGroupLabel,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedGroup,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: groups
                      .map((g) =>
                          DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedGroup = v),
                ),
                if (selectedGroup != null &&
                    selectedGroup != issue.assignedGroup)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(l10n.issueValidationRedirectLabel,
                          style: const TextStyle(
                              color: AppColors.warning, fontSize: 12)),
                    ]),
                  ),

                const SizedBox(height: 16),
                // Niveau d'urgence
                Text(l10n.issueValidationUrgencyLabel,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: IssueUrgency.values.map((u) {
                    final sel = selectedUrgency == u;
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedUrgency = u),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? _validationUrgencyColor(u)
                                  .withValues(alpha: 0.15)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: sel
                                ? _validationUrgencyColor(u)
                                : AppColors.border,
                            width: sel ? 2 : 1,
                          ),
                        ),
                        child: UrgencyBadge(urgency: u, isCompact: true),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text(l10n.issueValidationConfirmMessage,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _doValidate(l10n, issue, selectedUrgency, selectedGroup);
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

  Future<void> _doValidate(AppLocalizations l10n, Issue issue,
      IssueUrgency urgency, String? newGroup) async {
    setState(() => _submitting = true);
    try {
      await DbApiService.instance.updateIssue(issue.id, {
        'status': 'Acknowledged',
        'urgency': urgency.displayName,
        if (newGroup != null && newGroup != issue.assignedGroup)
          'assigned_group': newGroup,
      });
      setState(() { _loading = true; _error = null; });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.issueValidationSuccess(issue.displayName)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.issueValidationError(e.toString())),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Dialogue commentaire ───────────────────────────────────────────────────

  void _showCommentDialog(AppLocalizations l10n) {
    final commentCtrl = TextEditingController();
    final formKey     = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.issueDetailCommentTitle),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: commentCtrl,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.issueDetailCommentHint,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            validator: (v) =>
                (v == null || v.trim().length < 5)
                    ? l10n.issueDetailCommentMinLength
                    : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await _doAddComment(l10n, commentCtrl.text.trim());
            },
            icon: const Icon(Icons.send, size: 16),
            label: Text(l10n.issueDetailCommentSubmit),
          ),
        ],
      ),
    );
  }

  Future<void> _doAddComment(AppLocalizations l10n, String comment) async {
    setState(() => _submitting = true);
    try {
      await DbApiService.instance
          .updateIssue(widget.issueId, {'notes': comment});
      setState(() { _loading = true; _error = null; });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.issueDetailCommentSuccess),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.issueDetailCommentError(e.toString())),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Dialogue liaison tardive équipement ────────────────────────────────────

  void _showLinkEquipmentDialog(IssueDetail detail) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.linkEquipmentDialogTitle),
        content: EquipmentPickerField(
          onSelected: (eq) {
            Navigator.pop(ctx);
            _doLinkEquipment(l10n, detail.issue.id, eq);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  Future<void> _doLinkEquipment(
      AppLocalizations l10n, String issueId, Equipment equipment) async {
    setState(() => _submitting = true);
    try {
      await DbApiService.instance.linkEquipment(issueId, equipment.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.linkEquipmentSuccess),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Carte En-tête ──────────────────────────────────────────────────────────

  Widget _buildHeaderCard(AppLocalizations l10n, IssueDetail detail) {
    final issue = detail.issue;
    return _SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IssueStatusBadge(status: issue.status.displayName),
          const SizedBox(width: 8),
          UrgencyBadge(urgency: issue.urgency),
        ]),
        const SizedBox(height: 16),
        _ReporterRow(
          label: l10n.issueDetailReporter,
          name: issue.reporter,
          phone: issue.reporterPhone,
          email: issue.reporterEmail,
        ),
        _InfoRow(
          label: l10n.issueDetailReportDate,
          value: _fmtDateTime(issue.createdAt),
        ),
        if (detail.updatedAt != null && detail.updatedAt!.isNotEmpty)
          _InfoRow(
            label: l10n.issueDetailUpdatedAt,
            value: _fmtDateTime(detail.updatedAt!),
          ),
      ]),
    );
  }

  // ── Carte Contexte ─────────────────────────────────────────────────────────

  Widget _buildContextCard(AppLocalizations l10n, IssueDetail detail) {
    final issue     = detail.issue;
    final equipment = detail.equipment;
    final locText   = detail.locationText;

    return _SectionCard(
      title: l10n.issueDetailSectionContext,
      icon: Icons.info_outline,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Lien équipement
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 160,
              child: Text(l10n.issuesEquipment,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
            Expanded(
              child: issue.equipmentId != null
                  ? InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EquipmentDetailScreen(
                            equipmentId: issue.equipmentId!,
                          ),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                          child: Text(
                            issue.equipmentName ?? issue.equipmentId!,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.open_in_new,
                            size: 14, color: AppColors.primary),
                      ]),
                    )
                  : Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text(
                          issue.locationId ?? locText ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (_canEditReport(detail))
                          TextButton.icon(
                            onPressed: () => _showLinkEquipmentDialog(detail),
                            icon: const Icon(Icons.link, size: 16),
                            label: Text(l10n.linkEquipmentButton),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
            ),
          ]),
        ),
        if (issue.issueCategory != null)
          _InfoRow(
              label: l10n.issueDetailCategory, value: issue.issueCategory!),
        if (issue.assignedGroup != null)
          _InfoRow(label: l10n.issueDetailGroup, value: issue.assignedGroup!),
        _InfoRow(label: l10n.commonDepartment, value: issue.department),
        if (equipment != null && equipment['location'] != null)
          _InfoRow(
              label: l10n.issueDetailLocation,
              value: equipment['location'] as String),
      ]),
    );
  }

  // ── Carte Panne ────────────────────────────────────────────────────────────

  Widget _buildFailureCard(AppLocalizations l10n, Issue issue) {
    return _SectionCard(
      title: l10n.issueDetailSectionFailure,
      icon: Icons.warning_amber_rounded,
      iconColor: AppColors.error,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _InfoRow(label: l10n.issueDetailTypeLabel, value: issue.type),
        const SizedBox(height: 8),
        Text(l10n.issuesDescription,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(issue.description,
              style: const TextStyle(fontSize: 14, height: 1.5)),
        ),
      ]),
    );
  }

  // ── Carte Intervention ─────────────────────────────────────────────────────

  Widget _buildInterventionCard(AppLocalizations l10n, Issue issue) {
    final hasTech    = issue.assignedTechnician != null &&
        issue.assignedTechnician!.isNotEmpty;
    final hasDiag    = issue.diagnosis    != null && issue.diagnosis!.isNotEmpty;
    final hasActions = issue.actions      != null && issue.actions!.isNotEmpty;
    final hasParts   = issue.partsReplaced != null && issue.partsReplaced!.isNotEmpty;
    final hasAny     = hasTech || hasDiag || hasActions || hasParts;

    return _SectionCard(
      title: l10n.issueDetailSectionIntervention,
      icon: Icons.build_outlined,
      iconColor: AppColors.warning,
      child: hasAny
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (hasTech)
                _InfoRow(
                    label: l10n.issueDetailAssignedTech,
                    value: issue.assignedTechnician!),
              if (hasDiag) ...[
                _LargeInfoBlock(
                    label: l10n.issueDetailRootCause,
                    value: issue.diagnosis!),
                const SizedBox(height: 8),
              ],
              if (hasActions) ...[
                _LargeInfoBlock(
                    label: l10n.issueDetailCorrectiveActions,
                    value: issue.actions!),
                const SizedBox(height: 8),
              ],
              if (hasParts)
                _InfoRow(
                    label: l10n.issueDetailPartsUsed,
                    value: issue.partsReplaced!),
            ])
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                const Icon(Icons.hourglass_empty,
                    color: AppColors.textMuted, size: 18),
                const SizedBox(width: 8),
                Text(l10n.issueDetailNoIntervention,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic)),
              ]),
            ),
    );
  }

  // ── Carte Maintenance récente ──────────────────────────────────────────────

  Widget _buildMaintenanceCard(
      AppLocalizations l10n, List<MaintenanceRecord> records) {
    final past = records.where((r) => !r.isFuture).toList();
    if (past.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: l10n.issueDetailMaintenanceHistory,
      icon: Icons.history,
      iconColor: AppColors.primary,
      child: Column(
        children: past
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.intervention,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13)),
                                const SizedBox(height: 2),
                                Text('${r.date} — ${r.technician}',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ]),
                        ),
                      ]),
                ))
            .toList(),
      ),
    );
  }

  // ── Carte Timeline / Historique ────────────────────────────────────────────

  Widget _buildTimelineCard(AppLocalizations l10n, List<IssueAuditEntry> log) {
    return _SectionCard(
      title: l10n.issueDetailSectionHistory,
      icon: Icons.timeline,
      iconColor: AppColors.primary,
      child: log.isEmpty
          ? Row(children: [
              const Icon(Icons.history_toggle_off,
                  color: AppColors.textMuted, size: 18),
              const SizedBox(width: 8),
              Text(l10n.issueDetailNoHistory,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic)),
            ])
          : Column(
              children: List.generate(
                log.length,
                (i) => _TimelineEntry(
                  entry: log[i],
                  isLast: i == log.length - 1,
                  formatTimestamp: _fmtDateTime,
                ),
              ),
            ),
    );
  }

  // ── Carte Photos de l'incident ─────────────────────────────────────────────

  Widget _buildDocumentsCard(AppLocalizations l10n) {
    return _SectionCard(
      title: l10n.issuePhotosSection,
      icon: Icons.photo_library_outlined,
      iconColor: AppColors.primary,
      child: _photos.isEmpty
          ? Row(children: [
              const Icon(Icons.photo_outlined, color: AppColors.textMuted, size: 18),
              const SizedBox(width: 8),
              Text(l10n.issuePhotosNoPhotos,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                      fontSize: 13)),
            ])
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _photos.length == 1 ? 1 : 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _photos.length,
              itemBuilder: (_, i) => _PhotoThumbnail(
                photo: _photos[i],
                issueId: widget.issueId,
              ),
            ),
    );
  }

  // ── Barre de bas de page ───────────────────────────────────────────────────

  Widget _buildBottomBar(AppLocalizations l10n) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              if (widget.isPanel) {
                widget.onNavigate?.call(4, issueId: widget.issueId);
              } else {
                if (widget.onNavigate != null) {
                  Navigator.pop(context);
                  widget.onNavigate!(4, issueId: widget.issueId);
                } else {
                  Navigator.pop(context);
                }
              }
            },
            icon: const Icon(Icons.build, size: 18),
            label: Text(l10n.issueDetailUpdateButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets internes réutilisables ─────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final IconData? icon;
  final Color? iconColor;

  const _SectionCard({
    required this.child,
    this.title,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[
            Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
                const SizedBox(width: 8),
              ],
              Text(
                title!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ]),
            const Divider(height: 20),
          ],
          child,
        ]),
      ),
    );
  }
}

/// Ligne signaleur avec raccourcis appel et email.
class _ReporterRow extends StatelessWidget {
  final String label;
  final String name;
  final String? phone;
  final String? email;

  const _ReporterRow({
    required this.label,
    required this.name,
    this.phone,
    this.email,
  });

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone != null && phone!.isNotEmpty;
    final hasEmail = email != null && email!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: 160,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13)),
        ),
        if (hasPhone)
          Tooltip(
            message: phone!,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _launch('tel:$phone'),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.phone, size: 18, color: AppColors.primary),
              ),
            ),
          ),
        if (hasEmail)
          Tooltip(
            message: email!,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _launch('mailto:$email'),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.email_outlined, size: 18, color: AppColors.primary),
              ),
            ),
          ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 160,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13)),
        ),
      ]),
    );
  }
}

class _LargeInfoBlock extends StatelessWidget {
  final String label;
  final String value;

  const _LargeInfoBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(value,
            style: const TextStyle(fontSize: 13, height: 1.5)),
      ),
    ]);
  }
}

class _TimelineEntry extends StatelessWidget {
  final IssueAuditEntry entry;
  final bool isLast;
  final String Function(String) formatTimestamp;

  const _TimelineEntry({
    required this.entry,
    required this.isLast,
    required this.formatTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(entry.action);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 24,
          child: Column(children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 2,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.actionLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.userName} · ${entry.userRole}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  // Timestamp avec heure exacte
                  Text(
                    formatTimestamp(entry.timestamp),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                  if (entry.parsedDetails != null &&
                      (entry.parsedDetails!['new_status'] != null ||
                          entry.parsedDetails!['new_group'] != null)) ...[
                    const SizedBox(height: 4),
                    _buildDetailChips(entry.parsedDetails!),
                  ],
                ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildDetailChips(Map<String, dynamic> d) {
    final items = <Widget>[];
    final oldStatus = d['old_status'] as String?;
    final newStatus = d['new_status'] as String?;
    if (oldStatus != null && newStatus != null) {
      items.add(_chip('$oldStatus → $newStatus', AppColors.warning));
    }
    final oldGroup = d['old_group'] as String?;
    final newGroup = d['new_group'] as String?;
    if (oldGroup != null && newGroup != null) {
      items.add(_chip('$oldGroup → $newGroup', AppColors.primary));
    }
    return Wrap(spacing: 6, runSpacing: 4, children: items);
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500)),
    );
  }

  Color _actionColor(String action) {
    if (action == 'create_issue') return AppColors.error;
    if (action.contains('status_completed') ||
        action.contains('status_verified') ||
        action.contains('status_closed')) {
      return AppColors.success;
    }
    if (action.contains('status_in_progress') ||
        action.contains('status_assigned')) {
      return AppColors.warning;
    }
    if (action == 'reassign_issue') return AppColors.primary;
    return AppColors.textSecondary;
  }
}

// ── Vignette photo incident ────────────────────────────────────────────────────

class _PhotoThumbnail extends StatefulWidget {
  final IssuePhoto photo;
  final String issueId;

  const _PhotoThumbnail({required this.photo, required this.issueId});

  @override
  State<_PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<_PhotoThumbnail> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetchPhoto();
  }

  Future<void> _fetchPhoto() async {
    final url =
        '${ApiConfig.dbBaseUrl}/api/issues/${Uri.encodeComponent(widget.issueId)}'
        '/photos/${widget.photo.id}/download';
    try {
      final resp = await ApiClient.get(url);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() { _bytes = resp.bodyBytes; _loading = false; });
      } else {
        setState(() { _error = true; _loading = false; });
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              color: Colors.black,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.9,
              ),
              child: InteractiveViewer(
                child: Image.memory(_bytes!, fit: BoxFit.contain),
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
            Positioned(
              bottom: 12, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    widget.photo.originalName,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
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
          color: AppColors.background,
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _error || _bytes == null
                  ? const Center(
                      child: Icon(Icons.broken_image,
                          color: AppColors.textMuted, size: 32))
                  : Image.memory(_bytes!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
