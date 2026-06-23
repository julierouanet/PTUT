import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/auth_service.dart';
import '../services/feature_service.dart';
import '../services/notification_service.dart';
import '../services/pdf_report_service.dart';
import '../models/issue.dart';
import '../models/issue_intervention_report.dart';
import '../models/issue_intervention_session.dart';
import '../models/inventory_item.dart';
import '../widgets/urgency_badge.dart';

/// Pièce sélectionnée depuis le catalogue d'inventaire.
class _SelectedPart {
  final String itemId;
  final String name;
  final String unit;
  int quantity = 1;

  _SelectedPart({
    required this.itemId,
    required this.name,
    required this.unit,
  });
}

/// Page dédiée à la mise à jour d'une intervention technicien : diagnostic,
/// actions, pièces, et toutes les actions terminales (clôture, escalade,
/// transfert, détachement).
class TechnicianInterventionUpdateScreen extends StatefulWidget {
  final Issue issue;

  const TechnicianInterventionUpdateScreen({super.key, required this.issue});

  @override
  State<TechnicianInterventionUpdateScreen> createState() =>
      _TechnicianInterventionUpdateScreenState();
}

class _TechnicianInterventionUpdateScreenState
    extends State<TechnicianInterventionUpdateScreen> {
  String _legacyPartsText = ''; // pièces sauvegardées en texte libre

  final _diagnosisController   = TextEditingController();
  final _actionsController     = TextEditingController(); // renommé action_taken dans les sessions
  final _outcomeController     = TextEditingController();
  final _nextActionsController = TextEditingController();
  final _partsSearchController = TextEditingController();

  bool _isSaving         = false;
  bool _isReassigning    = false;
  bool _isEscalating     = false;
  bool _isDetaching      = false;
  bool _isClosingSession = false;
  bool _planNextAction   = false;

  /// Vrai si une action API du formulaire d'intervention est en cours
  /// (désactive tous les boutons d'action pour éviter les appels concurrents).
  bool get _isBusy =>
      _isSaving || _isReassigning || _isEscalating || _isDetaching || _isClosingSession;

  // ── Suivi des modifications non sauvegardées ────────────────────────────────
  bool _isDirty = false;

  // ── Session active et dernière session fermée ────────────────────────────────
  IssueInterventionSession? _activeSession;
  IssueInterventionSession? _lastClosedSession;
  bool _sessionLoading = true;

  // ── Chronomètre d'intervention ───────────────────────────────────────────────
  Timer?    _timer;
  Duration  _elapsed             = Duration.zero;
  DateTime? _currentIssueTakenAt;

  // ── Sélection de pièces depuis l'inventaire ──────────────────────────────────
  final List<_SelectedPart> _selectedParts = [];

  String get _currentTechnicianName => AuthService().currentUser?.fullName ?? '';

  InventoryItem? _inventoryItemFor(String itemId) =>
      DataService().inventory.where((it) => it.id == itemId).firstOrNull;

  @override
  void initState() {
    super.initState();
    final issue = widget.issue;
    _legacyPartsText = issue.partsReplaced ?? '';
    // Pré-peuple les contrôleurs de façon synchrone depuis les champs de
    // l'incident (déjà disponibles) pour éviter un flash d'interface vide
    // pendant l'appel async de _loadActiveOrLastSession.
    _diagnosisController.text = issue.diagnosis ?? '';
    _actionsController.text   = issue.actions   ?? '';
    if (issue.status == IssueStatus.inProgress) {
      final takenAt = issue.takenAt != null ? DateTime.tryParse(issue.takenAt!) : null;
      _startTimer(takenAt ?? DateTime.now());
    }
    _diagnosisController.addListener(_markDirty);
    _actionsController.addListener(_markDirty);
    _outcomeController.addListener(_markDirty);
    _loadActiveOrLastSession();
  }

  Future<void> _loadActiveOrLastSession() async {
    try {
      final raw = await DbApiService.instance.getInterventionSessions(widget.issue.id);
      final sessions = raw
          .map((e) => IssueInterventionSession.fromApiJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;

      final active = sessions.where((s) => !s.isClosed).firstOrNull;
      final lastClosed = sessions.where((s) => s.isClosed).lastOrNull;

      setState(() {
        _activeSession     = active;
        _lastClosedSession = lastClosed;
        _sessionLoading    = false;

        if (active != null) {
          // Reprise d'une session active existante
          _diagnosisController.text = active.diagnosis ?? '';
          _actionsController.text   = active.actionTaken ?? '';
          _outcomeController.text   = active.outcome ?? '';
        } else if (lastClosed != null && !lastClosed.resolved) {
          // Réouverture après session non résolue : diagnostic en lecture seule
          _diagnosisController.text = lastClosed.diagnosis ?? '';
          // Champs action/outcome vides pour la nouvelle boucle
          _actionsController.text  = '';
          _outcomeController.text  = '';
        } else {
          // Premier passage ou après résolution : fallback issue fields
          _diagnosisController.text = widget.issue.diagnosis ?? '';
          _actionsController.text   = widget.issue.actions   ?? '';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _sessionLoading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _diagnosisController.removeListener(_markDirty);
    _actionsController.removeListener(_markDirty);
    _outcomeController.removeListener(_markDirty);
    _diagnosisController.dispose();
    _actionsController.dispose();
    _outcomeController.dispose();
    _nextActionsController.dispose();
    _partsSearchController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  // ── Helpers de session ────────────────────────────────────────────────────────

  /// Ferme silencieusement la session active. Ignoré si aucune session active.
  Future<void> _tryCloseActiveSession(String issueId, {String? nextActions}) async {
    try {
      await DbApiService.instance.closeActiveInterventionSession(issueId, {
        'resolved': false,
        'outcome': null,
        'next_actions': nextActions,
      });
    } catch (_) { /* ignoré si pas de session active */ }
  }

  /// Recharge les incidents et régénère les notifications après une mutation.
  Future<void> _refreshAfterMutation() async {
    await DataService().reloadIssues();
    NotificationService().generateFromLoadedData();
  }

  // ── Chronomètre ─────────────────────────────────────────────────────────────

  void _startTimer(DateTime takenAt) {
    _currentIssueTakenAt = takenAt;
    _elapsed = DateTime.now().difference(takenAt);
    _timer   = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(_currentIssueTakenAt!));
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer               = null;
    _currentIssueTakenAt = null;
    _elapsed             = Duration.zero;
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── Sérialisation des pièces ─────────────────────────────────────────────────

  String _serializeParts() {
    final structured = _selectedParts
        .map((p) => '${p.name} × ${p.quantity} (${p.unit})')
        .join(', ');
    if (_legacyPartsText.isNotEmpty && structured.isEmpty) return _legacyPartsText;
    if (_legacyPartsText.isNotEmpty) return '$structured ; $_legacyPartsText';
    return structured;
  }

  List<Map<String, dynamic>> _buildPartsConsumed() => _selectedParts
      .map((p) => {'item_id': p.itemId, 'quantity': p.quantity})
      .toList();

  // ── Garde-fou modifications non sauvegardées ────────────────────────────────

  Future<void> _handlePopAttempt() async {
    final l10n = AppLocalizations.of(context)!;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.techUnsavedChangesWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) {
      Navigator.pop(context);
    }
  }

  // ── Build principal ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final issue = widget.issue;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePopAttempt();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(issue.displayName)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildInterventionFormContent(l10n, issue),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Formulaire de mise à jour (Bon de Travail)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildInterventionFormContent(AppLocalizations l10n, Issue issue) {
    final role             = AuthService().primaryRole?.apiName;
    final inventoryEnabled = FeatureService().isModuleEnabled('inventory', role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Chronomètre si intervention active ───────────────────────────────
        if (_currentIssueTakenAt != null) ...[
          _buildStopwatchBadge(),
          const SizedBox(height: 16),
        ],

        // ── Récapitulatif incident ──────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(issue.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                UrgencyBadge(urgency: issue.urgency, isCompact: true),
              ]),
              const SizedBox(height: 4),
              Text(issue.description,
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                l10n.techReportedByDate(issue.reporter, issue.createdAt),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              // Date de prise en charge si disponible
              if (issue.takenAt != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.play_circle_outline,
                      size: 13, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    l10n.techTakenAtLabel(
                        issue.takenAt!.split('T').first),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.primary),
                  ),
                ]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ── Historique boucle précédente (réouverture) ──────────────────────
        if (!_sessionLoading && _lastClosedSession != null &&
            !_lastClosedSession!.resolved && _activeSession == null)
          _buildLoopHistoryBlock(l10n, _lastClosedSession!),

        // ── Diagnostic ──────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(l10n.techDiagnosis,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            // Bouton "Compléter le diagnostic" visible si diagnosis existant
            if (_diagnosisController.text.isNotEmpty)
              TextButton.icon(
                onPressed: _isBusy ? null : () => _showCompleteDiagnosisDialog(issue),
                icon: const Icon(Icons.add_comment_outlined, size: 15),
                label: Text(l10n.techCompleteDiagnosisButton,
                    style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Diagnostic en lecture seule si réouverture (non-resolved last session)
        if (!_sessionLoading && _lastClosedSession != null &&
            !_lastClosedSession!.resolved && _activeSession == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              _diagnosisController.text.isNotEmpty
                  ? _diagnosisController.text
                  : '—',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          )
        else
          TextFormField(
            controller: _diagnosisController,
            maxLines: 3,
            decoration: InputDecoration(hintText: l10n.techDiagnosisHint),
          ),
        const SizedBox(height: 22),

        // ── Action réalisée aujourd'hui ──────────────────────────────────────
        Text(l10n.techActionTakenLabel,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _actionsController,
          maxLines: 3,
          decoration: InputDecoration(hintText: l10n.techActionTakenHint),
        ),
        const SizedBox(height: 22),

        // ── Outcome ─────────────────────────────────────────────────────────
        Text(l10n.techOutcomeLabel,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _outcomeController,
          maxLines: 2,
          decoration: InputDecoration(hintText: l10n.techOutcomeHint),
        ),
        const SizedBox(height: 22),

        // ── Toggle + champ conditionnel "Actions à réaliser" ────────────────
        Row(
          children: [
            Expanded(
              child: Text(l10n.techNextActionsLabel,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Switch(
              value: _planNextAction,
              onChanged: _isBusy ? null : (v) => setState(() {
                _planNextAction = v;
                if (!v) _nextActionsController.clear();
              }),
              activeThumbColor: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(l10n.techPlanNextActionToggle,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        if (_planNextAction) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _nextActionsController,
            maxLines: 3,
            decoration: InputDecoration(hintText: l10n.techNextActionsHint),
          ),
        ],
        const SizedBox(height: 28),

        // ── Sélecteur de pièces ─────────────────────────────────────────────
        if (inventoryEnabled) ...[
          _buildPartsPicker(l10n),
          const SizedBox(height: 28),
        ],

        // ── Bouton fusionné Sauvegarder et fermer la session ─────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isBusy ? null : () => _doSaveAndClose(issue, inventoryEnabled),
            icon: _isClosingSession
                ? _buttonSpinner(Colors.white)
                : const Icon(Icons.save_outlined, size: 16),
            label: Text(l10n.techSaveAndCloseButton),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(height: 10),

        // ── Bouton Clôture formelle (Bon de Travail) ─────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isBusy
                ? null
                : () => _showWorkOrderDialog(issue, inventoryEnabled),
            icon: const Icon(Icons.verified_outlined, size: 16),
            label: Text(l10n.techMarkResolved),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(height: 10),

        // ── Bouton Escalader / Suspendre ─────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isBusy
                ? null
                : () => _showEscalateDialog(issue),
            icon: _isEscalating
                ? _buttonSpinner(AppColors.error)
                : const Icon(Icons.report_problem_outlined,
                    size: 16, color: AppColors.error),
            label: Text(l10n.techEscalateButton,
                style: const TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Bouton Transférer (reassign groupe) ──────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isBusy
                ? null
                : () => _showReassignDialog(issue),
            icon: _isReassigning
                ? _buttonSpinner(AppColors.warning)
                : const Icon(Icons.swap_horiz, size: 16, color: AppColors.warning),
            label: Text(l10n.techReassignButton,
                style: const TextStyle(color: AppColors.warning)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.warning),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Bouton Détacher (retour au pool) ─────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isBusy
                ? null
                : () => _showDetachDialog(issue),
            icon: _isDetaching
                ? _buttonSpinner(AppColors.textSecondary)
                : const Icon(Icons.link_off,
                    size: 16, color: AppColors.textSecondary),
            label: Text(l10n.detachButton,
                style: const TextStyle(color: AppColors.textSecondary)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Bloc historique de la boucle précédente (lecture seule)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildLoopHistoryBlock(AppLocalizations l10n, IssueInterventionSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.history, size: 15, color: AppColors.warning),
                const SizedBox(width: 6),
                Text(l10n.techLoopHistoryTitle(session.loopNumber),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.warning)),
              ]),
              if (session.diagnosis?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(l10n.techLoopDiagnosisLabel,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
                Text(session.diagnosis!, style: const TextStyle(fontSize: 12)),
              ],
              if (session.actionTaken?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(l10n.techLoopActionsLabel,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
                Text(session.actionTaken!, style: const TextStyle(fontSize: 12)),
              ],
              if (session.outcome?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(l10n.techLoopOutcomeLabel,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
                Text(session.outcome!, style: const TextStyle(fontSize: 12)),
              ],
              if (session.nextActions?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(l10n.techLoopNextActionsLabel,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
                Text(session.nextActions!, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Dialog : Compléter le diagnostic
  // ─────────────────────────────────────────────────────────────────────────────

  void _showCompleteDiagnosisDialog(Issue issue) {
    final l10n = AppLocalizations.of(context)!;
    final addendumCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.techCompleteDiagnosisTitle),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: addendumCtl,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.techCompleteDiagnosisHint),
            validator: (v) => (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final addendum = addendumCtl.text.trim();
              Navigator.pop(ctx);
              try {
                await DbApiService.instance.saveActiveInterventionSession(issue.id, {
                  'diagnosis_addendum': addendum,
                });
                if (mounted) setState(() {});
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.commonApiError),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers UI partagés
  // ─────────────────────────────────────────────────────────────────────────────

  /// Spinner compact utilisé comme icône de bouton pendant une action en cours.
  Widget _buttonSpinner(Color color) => SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );

  // ─────────────────────────────────────────────────────────────────────────────
  // Badge chronomètre
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildStopwatchBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 17, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            _formatElapsed(_elapsed),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.warning,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Dialog : Détachement d'un incident (retour au pool)
  // ─────────────────────────────────────────────────────────────────────────────

  void _showDetachDialog(Issue issue) {
    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.detachDialogTitle),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reasonController,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.detachReasonLabel),
            validator: (v) => (v == null || v.trim().length < 10)
                ? l10n.detachReasonMinLength
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
              final reason = reasonController.text.trim();
              Navigator.pop(ctx);
              await _doDetach(issue, reason);
            },
            icon: const Icon(Icons.link_off, size: 16),
            label: Text(l10n.commonConfirm),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textSecondary,
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _doDetach(Issue issue, String reason) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isDetaching = true);
    await _tryCloseActiveSession(issue.id, nextActions: reason);
    try {
      await DbApiService.instance.detachIssue(issue.id, reason);
      await _refreshAfterMutation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.link_off, color: Colors.white),
          const SizedBox(width: 12),
          Text(l10n.detachSuccess),
        ]),
        backgroundColor: AppColors.textSecondary,
        behavior: SnackBarBehavior.floating,
      ));
      _stopTimer();
      setState(() => _isDirty = false);
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.commonApiError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isDetaching = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Sélecteur de pièces depuis l'inventaire
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildPartsPicker(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.techPartsFromInventory,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _partsSearchController,
          decoration: InputDecoration(
            hintText: l10n.techPartsSearchHint,
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        // Suggestions si la requête fait ≥ 2 caractères
        if (_partsSearchController.text.trim().length >= 2)
          _buildPartsSuggestions(l10n),
        const SizedBox(height: 10),

        // Pièces sélectionnées
        if (_selectedParts.isEmpty && _legacyPartsText.isEmpty)
          Text(l10n.techPartsNoneSelected,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary))
        else ...[
          if (_selectedParts.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedParts
                  .map((p) => _buildSelectedPartChip(p, l10n))
                  .toList(),
            ),
          // Valeur texte libre sauvegardée antérieurement
          if (_legacyPartsText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_legacyPartsText,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ),
                ]),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPartsSuggestions(AppLocalizations l10n) {
    final query = _partsSearchController.text.trim().toLowerCase();
    final suggestions = DataService()
        .inventory
        .where((item) => item.name.toLowerCase().contains(query))
        .take(5)
        .toList();

    if (suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(l10n.techPartsNoResults,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Column(
        children: suggestions.asMap().entries.map((entry) {
          final item         = entry.value;
          final isOutOfStock = item.status == StockStatus.outOfStock;
          final alreadyAdded =
              _selectedParts.any((p) => p.itemId == item.id);
          final isLast = entry.key == suggestions.length - 1;

          return Column(children: [
            ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              title: Text(item.name,
                  style: TextStyle(
                      fontSize: 13,
                      color: isOutOfStock
                          ? AppColors.textMuted
                          : AppColors.textPrimary)),
              subtitle: Text(
                isOutOfStock
                    ? l10n.techPartsOutOfStock
                    : l10n.techPartsStockLabel(
                        item.currentStock, item.unit),
                style: TextStyle(
                    fontSize: 11,
                    color: isOutOfStock
                        ? AppColors.error
                        : AppColors.textSecondary),
              ),
              trailing: alreadyAdded
                  ? const Icon(Icons.check_circle,
                      size: 18, color: AppColors.success)
                  : IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          size: 20, color: AppColors.primary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: isOutOfStock
                          ? null
                          : () {
                              setState(() {
                                _selectedParts.add(_SelectedPart(
                                  itemId: item.id,
                                  name:   item.name,
                                  unit:   item.unit,
                                ));
                                _partsSearchController.clear();
                              });
                              _markDirty();
                            },
                    ),
            ),
            if (!isLast)
              const Divider(height: 1, indent: 12, endIndent: 12),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedPartChip(_SelectedPart part, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (part.quantity <= 1) return;
              setState(() => part.quantity--);
              _markDirty();
            },
            child:
                const Icon(Icons.remove, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 6),
          Text(
            '${part.name} × ${part.quantity} (${part.unit})',
            style: const TextStyle(fontSize: 12, color: AppColors.primary),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() => part.quantity++);
              _markDirty();
            },
            child: const Icon(Icons.add, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() => _selectedParts.remove(part));
              _markDirty();
            },
            child: const Icon(Icons.close,
                size: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Dialog : Bon de Travail — Clôture formelle
  // ─────────────────────────────────────────────────────────────────────────────

  void _showWorkOrderDialog(Issue issue, bool inventoryEnabled) {
    final l10n            = AppLocalizations.of(context)!;
    bool safetyChecked    = false;
    final closingNotesCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.verified_outlined,
                color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(l10n.techWorkOrderTitle,
                    style: const TextStyle(fontSize: 16))),
          ]),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Récapitulatif
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(issue.displayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(issue.department,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        if (inventoryEnabled && _selectedParts.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${l10n.techPartsFromInventory} : '
                            '${_selectedParts.map((p) => '${p.name} ×${p.quantity}').join(', ')}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.primary),
                          ),
                        ],
                      ]),
                ),
                const SizedBox(height: 16),

                // Checkbox de sécurité
                InkWell(
                  onTap: () => setDialogState(
                      () => safetyChecked = !safetyChecked),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: safetyChecked,
                        onChanged: (v) => setDialogState(
                            () => safetyChecked = v ?? false),
                        activeColor: AppColors.success,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            l10n.techWorkOrderSafetyCheck,
                            style: TextStyle(
                              fontSize: 13,
                              color: safetyChecked
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                              fontWeight: safetyChecked
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!safetyChecked)
                  Padding(
                    padding: const EdgeInsets.only(left: 46, top: 2),
                    child: Text(
                      l10n.techWorkOrderSafetyRequired,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.error),
                    ),
                  ),
                const SizedBox(height: 12),

                // Notes de clôture
                TextField(
                  controller: closingNotesCtl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.techWorkOrderClosingNotes,
                    hintText: l10n.techWorkOrderClosingNotesHint,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                closingNotesCtl.dispose();
                Navigator.pop(ctx);
              },
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: safetyChecked
                  ? () async {
                      final notes = closingNotesCtl.text.trim();
                      closingNotesCtl.dispose();
                      Navigator.pop(ctx);
                      // Si des pièces sont sélectionnées → confirmation déstockage
                      if (inventoryEnabled && _selectedParts.isNotEmpty) {
                        final confirmed =
                            await _showDestockConfirmDialog(issue);
                        if (!confirmed) return;
                      }
                      await _doWorkOrderClose(issue, notes, inventoryEnabled);
                    }
                  : null,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(l10n.techWorkOrderConfirm),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Dialog : Confirmation déstockage
  // ─────────────────────────────────────────────────────────────────────────────

  Future<bool> _showDestockConfirmDialog(Issue issue) async {
    final l10n = AppLocalizations.of(context)!;

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(children: [
              const Icon(Icons.inventory_2_outlined,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(l10n.techDestockConfirmTitle,
                  style: const TextStyle(fontSize: 16)),
            ]),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.techDestockConfirmSubtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),

                  // Liste des pièces avec stock actuel et estimé
                  ..._selectedParts.map((part) {
                    final inventoryItem = _inventoryItemFor(part.itemId);
                    final currentStock  = inventoryItem?.currentStock ?? 0;
                    final afterStock    = currentStock - part.quantity;
                    final isLow         = afterStock <= (inventoryItem?.minStock ?? 0);
                    final isNegative    = afterStock < 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isNegative
                            ? AppColors.errorLight
                            : isLow
                                ? AppColors.warningLight
                                : AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isNegative
                              ? AppColors.error
                              : isLow
                                  ? AppColors.warning
                                  : AppColors.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.techDestockItemLine(
                              part.name,
                              part.quantity,
                              part.unit,
                              currentStock,
                            ),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.techDestockStockAfter(
                                afterStock.clamp(0, 999999), part.unit),
                            style: TextStyle(
                              fontSize: 12,
                              color: isNegative
                                  ? AppColors.error
                                  : isLow
                                      ? AppColors.warning
                                      : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isLow && !isNegative) ...[
                            const SizedBox(height: 2),
                            Text(l10n.techDestockLowWarning,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.warning)),
                          ],
                          if (isNegative) ...[
                            const SizedBox(height: 2),
                            Text(
                              '⛔ Stock insuffisant pour cette quantité',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel),
              ),
              ElevatedButton.icon(
                // Désactivé si au moins une pièce est en stock insuffisant
                onPressed: _selectedParts.any((p) {
                  final inv = _inventoryItemFor(p.itemId);
                  return (inv?.currentStock ?? 0) < p.quantity;
                })
                    ? null
                    : () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check, size: 16),
                label: Text(l10n.techDestockConfirm),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Dialog : Escalade / Suspension
  // ─────────────────────────────────────────────────────────────────────────────

  void _showEscalateDialog(Issue issue) {
    final l10n          = AppLocalizations.of(context)!;
    final formKey       = GlobalKey<FormState>();
    String? escalStatus;
    final commentCtl    = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.report_problem_outlined,
                color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Text(l10n.techEscalateTitle,
                style: const TextStyle(fontSize: 16)),
          ]),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.techEscalateSubtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),

                  // Type d'escalade
                  Text(l10n.techEscalateStatusLabel,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: escalStatus,
                    hint: Text(l10n.techEscalateStatusLabel),
                    items: [
                      DropdownMenuItem(
                        value: 'Waiting Materials',
                        child: Row(children: [
                          const Icon(Icons.inventory_outlined,
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Text(l10n.techEscalateWaitingMaterials),
                        ]),
                      ),
                      DropdownMenuItem(
                        value: 'Redirected',
                        child: Row(children: [
                          const Icon(Icons.forward_outlined,
                              size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text(l10n.techEscalateRedirected),
                        ]),
                      ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => escalStatus = v),
                    validator: (v) =>
                        v == null ? l10n.techEscalateStatusRequired : null,
                  ),
                  const SizedBox(height: 16),

                  // Commentaire obligatoire
                  TextFormField(
                    controller: commentCtl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.techEscalateCommentLabel,
                      hintText: l10n.techEscalateCommentHint,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 10) {
                        return l10n.techEscalateCommentMinLength;
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                commentCtl.dispose();
                Navigator.pop(ctx);
              },
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final status  = escalStatus!;
                final comment = commentCtl.text.trim();
                commentCtl.dispose();
                Navigator.pop(ctx);
                await _doEscalate(issue, status, comment);
              },
              icon: const Icon(Icons.report_problem_outlined, size: 16),
              label: Text(l10n.commonConfirm),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Dialog : Transfert de groupe (réassignation)
  // ─────────────────────────────────────────────────────────────────────────────

  void _showReassignDialog(Issue issue) {
    final l10n        = AppLocalizations.of(context)!;
    final formKey     = GlobalKey<FormState>();
    String? selectedGroup;
    final reasonController = TextEditingController();

    showDialog(
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
                    hint: Text(l10n.techReassignGroupHint),
                    value: selectedGroup,
                    items: const ['IT', 'Infrastructure', 'Biomédical']
                        .map((g) =>
                            DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedGroup = v),
                    validator: (v) =>
                        v == null ? l10n.techReassignGroupRequired : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.techReassignReasonLabel,
                      hintText:  l10n.techReassignReasonHint,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 10) {
                        return l10n.techReassignReasonMinLength;
                      }
                      return null;
                    },
                  ),
                ]),
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
                await _doReassign(
                    issue, selectedGroup!, reasonController.text.trim());
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

  // ─────────────────────────────────────────────────────────────────────────────
  // Actions API
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _doReassign(
      Issue issue, String newGroup, String reason) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isReassigning = true);
    try {
      await DbApiService.instance.reassignIssue(issue.id, newGroup, reason);
      await _refreshAfterMutation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.swap_horiz, color: Colors.white),
          const SizedBox(width: 12),
          Text(l10n.techReassignSuccess(newGroup)),
        ]),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ));
      _stopTimer();
      setState(() => _isDirty = false);
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.commonApiError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isReassigning = false);
    }
  }

  Future<void> _doEscalate(
      Issue issue, String escalStatus, String comment) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isEscalating = true);
    await _tryCloseActiveSession(issue.id, nextActions: comment);
    try {
      await DbApiService.instance.escalateIssue(issue.id, escalStatus, comment);
      await _refreshAfterMutation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.report_problem_outlined, color: Colors.white),
          const SizedBox(width: 12),
          Text(l10n.techEscalateSuccess(escalStatus)),
        ]),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      _stopTimer();
      setState(() => _isDirty = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${l10n.commonApiError}: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isEscalating = false);
    }
  }

  Future<void> _doSaveAndClose(Issue issue, bool inventoryEnabled) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isClosingSession = true);
    try {
      final diagnosis   = _diagnosisController.text.trim();
      final actions     = _actionsController.text.trim();
      final outcome     = _outcomeController.text.trim();
      final nextActions = _planNextAction ? _nextActionsController.text.trim() : '';
      final serialized  = inventoryEnabled ? _serializeParts() : '';

      // 1. Met à jour l'incident
      await DbApiService.instance.updateIssue(issue.id, {
        'status':              'In Progress',
        'assigned_technician': _currentTechnicianName,
        if (diagnosis.isNotEmpty)  'diagnosis': diagnosis,
        if (actions.isNotEmpty)    'actions':   actions,
        if (serialized.isNotEmpty) 'parts_replaced': serialized,
      });

      // 2. Ferme la session active
      final sessionRaw = await DbApiService.instance.closeActiveInterventionSession(
        issue.id,
        {
          'resolved':     false,
          'outcome':      outcome.isNotEmpty     ? outcome     : null,
          'next_actions': nextActions.isNotEmpty ? nextActions : null,
        },
      );

      // 3. Génère le PDF de boucle
      final session = IssueInterventionSession.fromApiJson(sessionRaw);
      final user = AuthService().currentUser;
      final pdfBytes = await PdfReportService.generateInterventionSessionReport(
        session: session,
        issueId: issue.id,
        equipmentName: issue.equipmentName ?? issue.id,
        generatedByName: user?.name ?? '—',
        generatedByRole: user?.roles.firstOrNull?.displayName ?? '—',
      );

      // 4. Archive PDF si équipement connu
      if (issue.equipmentId != null && issue.equipmentId!.isNotEmpty) {
        try {
          await DbApiService.instance.archiveInterventionPdf(
            issue.equipmentId!,
            pdfBytes,
            'rapport_boucle_${issue.id}_${session.loopNumber}.pdf',
          );
        } catch (_) { /* archivage non bloquant */ }
      }

      await _refreshAfterMutation();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_outlined, color: Colors.white),
          const SizedBox(width: 12),
          Text(l10n.techSaveAndCloseSuccess),
        ]),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ));
      _stopTimer();
      setState(() => _isDirty = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${l10n.commonApiError}: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isClosingSession = false);
    }
  }

  Future<void> _doWorkOrderClose(
      Issue issue, String closingNotes, bool inventoryEnabled) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);

    // Fusionne les notes de clôture dans les actions si fournies
    String? finalActions;
    final existingActions = _actionsController.text.trim();
    if (closingNotes.isNotEmpty) {
      finalActions = existingActions.isNotEmpty
          ? '$existingActions\n[Clôture] $closingNotes'
          : '[Clôture] $closingNotes';
    } else if (existingActions.isNotEmpty) {
      finalActions = existingActions;
    }

    try {
      // Ferme la session active avec resolved=true avant de clore l'incident
      try {
        await DbApiService.instance.closeActiveInterventionSession(issue.id, {
          'resolved': true,
          'outcome': _outcomeController.text.trim().isNotEmpty
              ? _outcomeController.text.trim()
              : null,
        });
      } catch (_) { /* ignoré si pas de session active */ }

      await DbApiService.instance.updateIssue(issue.id, {
        'status':              'Completed',
        'assigned_technician': _currentTechnicianName,
        'diagnosis': _diagnosisController.text.trim().isNotEmpty
            ? _diagnosisController.text.trim()
            : null,
        'actions':        finalActions,
        'parts_replaced': inventoryEnabled && _serializeParts().isNotEmpty
            ? _serializeParts()
            : null,
        // Déstockage transactionnel côté backend
        if (inventoryEnabled && _selectedParts.isNotEmpty)
          'parts_consumed': _buildPartsConsumed(),
      });
      final reportOk = await _generateAndFinalizeReport(issue, finalActions);
      await _refreshAfterMutation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Text(l10n.techIssueResolved),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      if (!reportOk) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.techWorkOrderReportGenerationFailed),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ));
      }
      _stopTimer();
      setState(() => _isDirty = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${l10n.commonApiError}: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Génération automatique du rapport d'intervention à la clôture
  // ─────────────────────────────────────────────────────────────────────────────

  /// Construit, sauvegarde et finalise le rapport d'intervention à partir des
  /// données déjà saisies sur cet écran, puis archive son PDF sur l'équipement
  /// si applicable. N'échoue jamais : la clôture du Bon de Travail ne doit pas
  /// dépendre de cette étape annexe.
  Future<bool> _generateAndFinalizeReport(Issue issue, String? finalActions) async {
    try {
      final takenAt = _currentIssueTakenAt ??
          (issue.takenAt != null ? DateTime.tryParse(issue.takenAt!) : null);
      final durationHours = takenAt == null
          ? null
          : double.parse(
              (DateTime.now().difference(takenAt).inMinutes / 60.0).toStringAsFixed(1));
      final diagnosis = _diagnosisController.text.trim();

      // Construit un résumé compilé depuis toutes les boucles
      String? compiledSummary = finalActions;
      try {
        final rawSessions = await DbApiService.instance.getInterventionSessions(issue.id);
        final sessions = rawSessions
            .map((e) => IssueInterventionSession.fromApiJson(e as Map<String, dynamic>))
            .toList();
        if (sessions.isNotEmpty) {
          compiledSummary = sessions.map((s) {
            final date = s.closedAt?.split('T').first ?? s.startedAt.split('T').first;
            return 'Boucle ${s.loopNumber} ($date) : ${s.actionTaken ?? '—'} → ${s.outcome ?? '—'}';
          }).join('\n');
        }
      } catch (_) { /* fallback sur finalActions si l'appel échoue */ }

      await DbApiService.instance.saveInterventionReport(issue.id, {
        'summary': compiledSummary,
        'root_cause': diagnosis.isNotEmpty ? diagnosis : null,
        'duration_hours': durationHours,
        'returned_to_service_at': DateTime.now().toIso8601String().split('T').first,
        'final_equipment_status': 'Operational',
        'recommendations': null,
        'estimated_cost': null,
      });
      final raw = await DbApiService.instance.finalizeInterventionReport(issue.id);
      final report = IssueInterventionReport.fromApiJson(raw);

      final user = AuthService().currentUser;
      final pdfBytes = await PdfReportService.generateInterventionReport(
        report: report.toReportPdfJson(),
        issueId: issue.id,
        generatedByName: user?.name ?? '—',
        generatedByRole: user?.roles.isNotEmpty == true ? user!.roles.first.displayName : '—',
      );

      final equipmentId = report.equipmentId;
      if (equipmentId != null && equipmentId.isNotEmpty) {
        await DbApiService.instance.archiveInterventionPdf(
          equipmentId, pdfBytes, 'rapport_intervention_${issue.id}.pdf',
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
