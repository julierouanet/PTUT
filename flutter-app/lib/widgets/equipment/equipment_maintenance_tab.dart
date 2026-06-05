import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../models/issue.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../services/db_api_service.dart';
import '../../services/pdf_label_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pm_checklist_widget.dart';
import 'equipment_detail_helpers.dart';

/// Onglet Maintenance — PM, checklist, historique, KPIs MTTR et bouton "Créer PM".
class EquipmentMaintenanceTab extends StatefulWidget {
  final Equipment equipment;
  final List<Issue> issues;

  /// Rappel pour recharger les données depuis l'écran parent après mutation.
  final VoidCallback onRefresh;

  const EquipmentMaintenanceTab({
    super.key,
    required this.equipment,
    required this.issues,
    required this.onRefresh,
  });

  @override
  State<EquipmentMaintenanceTab> createState() =>
      _EquipmentMaintenanceTabState();
}

class _EquipmentMaintenanceTabState
    extends State<EquipmentMaintenanceTab> {
  Equipment get eq => widget.equipment;

  // ── État fréquence PM ────────────────────────────────────────────────────────
  int? _selectedFrequency;
  bool _savingFrequency = false;

  // ── État validation PM ───────────────────────────────────────────────────────
  bool _validating = false;
  final GlobalKey<PmChecklistWidgetState> _checklistKey =
      GlobalKey<PmChecklistWidgetState>();

  // ── État historique PM ───────────────────────────────────────────────────────
  bool _showAllPmHistory = false;

  bool get _canSchedulePm {
    final auth = AuthService();
    return auth.canManageEquipment ||
        auth.hasPermission(Permission.updateRepairs);
  }

  bool get _canValidatePm =>
      AuthService().hasPermission(Permission.updateRepairs);

  // Fréquence effective : plan existant > premier protocole > null
  int? get _effectiveFrequency {
    if (_selectedFrequency != null) return _selectedFrequency;
    if (eq.pmFrequencyMonths != null) return eq.pmFrequencyMonths;
    if (eq.pmProtocols.isNotEmpty) {
      final freq = eq.pmProtocols[0]['frequency_months'];
      return freq is int ? freq : null;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedFrequency = eq.pmFrequencyMonths;
  }

  @override
  void didUpdateWidget(EquipmentMaintenanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.equipment.pmFrequencyMonths !=
        widget.equipment.pmFrequencyMonths) {
      _selectedFrequency = widget.equipment.pmFrequencyMonths;
    }
  }

  // ── Checklist depuis pmProtocols ─────────────────────────────────────────────

  List<dynamic> get _checklistItems {
    if (eq.pmProtocols.isEmpty) return const [];
    final proto = eq.pmProtocols[0];
    final raw = proto['checklist'];
    if (raw is List) return raw;
    return const [];
  }

  Map<String, dynamic>? get _firstProtocol =>
      eq.pmProtocols.isNotEmpty ? eq.pmProtocols[0] : null;

  // ── Enregistrements PM préventifs ────────────────────────────────────────────

  List<MaintenanceRecord> get _pmHistory => eq.maintenanceHistory
      .where((r) =>
          r.maintenanceType == 'preventive' ||
          r.intervention.toLowerCase().contains('préventive') ||
          r.intervention.toLowerCase().contains('preventive'))
      .toList();

  // ── Taux de conformité PM ────────────────────────────────────────────────────

  int? _computeComplianceRate() {
    final records = _pmHistory;
    if (records.isEmpty) return null;

    final freqMonths = _effectiveFrequency ?? 12;

    // Trier chronologiquement
    final sorted = List<MaintenanceRecord>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));

    int dansDelais = 1; // La première PM est forcément "à jour"

    for (int i = 1; i < sorted.length; i++) {
      final prev = DateTime.tryParse(sorted[i - 1].date.substring(0, 10));
      final curr = DateTime.tryParse(sorted[i].date.substring(0, 10));
      if (prev == null || curr == null) continue;

      // Date attendue = précédente + fréquence mois + 15 jours de grâce
      final expectedDate =
          DateTime(prev.year, prev.month + freqMonths, prev.day);
      final graceDate = expectedDate.add(const Duration(days: 15));

      if (!curr.isAfter(graceDate)) dansDelais++;
    }

    return ((dansDelais / sorted.length) * 100).round();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasDates = (eq.lastPreventiveMaintenance?.isNotEmpty ?? false) ||
        (eq.nextPreventiveMaintenance?.isNotEmpty ?? false) ||
        (eq.nextRevisionDate?.isNotEmpty ?? false);
    final hasFuture = eq.futureMaintenance.isNotEmpty;
    final hasHistory = eq.maintenanceHistory.isNotEmpty;
    final hasPmHistory = _pmHistory.isNotEmpty;
    final hasChecklist = _checklistItems.isNotEmpty;
    final hasContent = hasDates || hasHistory || hasFuture;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Bannière alerte PM ──────────────────────────────────────
          _buildPreventiveAlertBanner(l10n),

          // ── Carte KPIs ─────────────────────────────────────────────
          _buildKpiCard(l10n),
          const SizedBox(height: 16),

          // ── Dates PM ───────────────────────────────────────────────
          if (hasDates) ...[
            _buildPmDatesCard(l10n),
            const SizedBox(height: 16),
          ],

          // ── Fréquence PM (Tâche 2) ────────────────────────────────
          if (_canSchedulePm) ...[
            _buildFrequencyCard(l10n),
            const SizedBox(height: 16),
          ],

          // ── Checklist PM (Tâche 1) ────────────────────────────────
          if (hasChecklist || _firstProtocol != null) ...[
            PmChecklistWidget(
              key: _checklistKey,
              checklist: _checklistItems,
              protocolName: _firstProtocol?['name'] as String?,
              frequencyMonths: _effectiveFrequency,
              estimatedDurationHours:
                  _firstProtocol?['estimated_duration_hours'] as double?,
            ),
            const SizedBox(height: 12),
          ] else ...[
            PmChecklistWidget(
              key: _checklistKey,
              checklist: const [],
            ),
            const SizedBox(height: 12),
          ],

          // ── Bouton "Valider la maintenance préventive" (Tâche 3) ──
          if (_canValidatePm) ...[
            _buildValidatePmButton(l10n),
            const SizedBox(height: 16),
          ],

          // ── Maintenances planifiées ────────────────────────────────
          if (hasFuture) ...[
            _buildMaintenanceListCard(
              l10n,
              title: l10n.equipmentFutureMaintenance,
              records: eq.futureMaintenance,
              icon: Icons.schedule,
              iconColor: AppColors.primary,
            ),
            const SizedBox(height: 16),
          ],

          // ── Historique PM préventives (Tâche 6) ───────────────────
          if (hasPmHistory) ...[
            _buildPmHistoryCard(l10n),
            const SizedBox(height: 16),
          ],

          // ── Historique complet ─────────────────────────────────────
          if (hasHistory) ...[
            _buildMaintenanceListCard(
              l10n,
              title: l10n.equipmentMaintenanceHistory,
              records: eq.maintenanceHistory,
              icon: Icons.build,
              iconColor: AppColors.warning,
            ),
            const SizedBox(height: 16),
          ],

          // ── Bouton "Créer PM" ──────────────────────────────────────
          if (_canSchedulePm)
            _buildSchedulePmButton(l10n),

          // ── État vide ──────────────────────────────────────────────
          if (!hasContent)
            _buildEmptyMaintenance(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Bannière alerte PM ───────────────────────────────────────────────────────

  Widget _buildPreventiveAlertBanner(AppLocalizations l10n) {
    final level = eq.preventiveMaintenanceAlertLevel;
    if (level != 'due' && level != 'soon') return const SizedBox.shrink();
    final isOverdue = level == 'due';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOverdue ? AppColors.errorLight : AppColors.warningLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isOverdue ? AppColors.error : AppColors.warning)
              .withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOverdue ? Icons.error_outline : Icons.schedule,
            size: 18,
            color: isOverdue ? AppColors.error : AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOverdue
                  ? l10n.preventiveAlertOverdue
                  : l10n.preventiveAlertSoon,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isOverdue ? AppColors.error : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Carte KPIs ───────────────────────────────────────────────────────────────

  Widget _buildKpiCard(AppLocalizations l10n) {
    final mttr = computeMttr(widget.issues);
    final resolvedCount = widget.issues
        .where((i) => kResolvedIssueStatuses.contains(i.status))
        .length;
    final historyCount = eq.maintenanceHistory.length;
    final complianceRate = _computeComplianceRate();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.equipDetailKpiSection,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildKpiTile(
                    label: l10n.equipDetailMttr,
                    value: mttr != null
                        ? l10n.equipDetailMttrValue(mttr)
                        : l10n.equipDetailMttrNoData,
                    icon: Icons.timer_outlined,
                    color: mttr == null
                        ? AppColors.textSecondary
                        : AppColors.primary,
                    note: mttr != null ? '★ estimation' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiTile(
                    label: l10n.equipDetailTotalRepairs,
                    value: (resolvedCount + historyCount).toString(),
                    icon: Icons.build_circle_outlined,
                    color: AppColors.success,
                  ),
                ),
                if (complianceRate != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiTile(
                      label: l10n.pmComplianceRate(complianceRate),
                      value: '$complianceRate%',
                      icon: Icons.verified_outlined,
                      color: complianceRate >= 80
                          ? AppColors.success
                          : complianceRate >= 60
                              ? AppColors.warning
                              : AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? note,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(
              note,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Dates PM ─────────────────────────────────────────────────────────────────

  Widget _buildPmDatesCard(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.preventiveSection,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (eq.nextRevisionDate != null &&
                eq.nextRevisionDate!.isNotEmpty)
              DetailInfoRow(
                l10n.equipmentNextRevision,
                formatDetailDate(eq.nextRevisionDate!),
                icon: Icons.event,
                color: revisionColor(eq.nextRevisionDate!),
              ),
            if (eq.lastPreventiveMaintenance != null &&
                eq.lastPreventiveMaintenance!.isNotEmpty)
              DetailInfoRow(
                l10n.lastPreventiveDate,
                formatDetailDate(eq.lastPreventiveMaintenance!),
              ),
            if (eq.nextPreventiveMaintenance != null &&
                eq.nextPreventiveMaintenance!.isNotEmpty)
              DetailInfoRow(
                l10n.nextPreventiveDate,
                formatDetailDate(eq.nextPreventiveMaintenance!),
                icon: Icons.event_available,
                color:
                    preventiveColor(eq.preventiveMaintenanceAlertLevel),
              ),
          ],
        ),
      ),
    );
  }

  // ── Fréquence PM (Tâche 2) ───────────────────────────────────────────────────

  static const List<int> _frequencyOptions = [1, 3, 6, 12, 24, 36];

  Widget _buildFrequencyCard(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.pmFrequencyLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _frequencyOptions.contains(_selectedFrequency)
                        ? _selectedFrequency
                        : null,
                    decoration: InputDecoration(
                      labelText: l10n.pmFrequencySelectLabel,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: _frequencyOptions
                        .map((m) => DropdownMenuItem<int>(
                              value: m,
                              child: Text(l10n.pmFrequencyValue(m)),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedFrequency = v),
                  ),
                ),
                const SizedBox(width: 10),
                _savingFrequency
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : ElevatedButton(
                        onPressed: _selectedFrequency != null
                            ? () => _saveFrequency(l10n)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                        child: Text(l10n.commonSave),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveFrequency(AppLocalizations l10n) async {
    final freq = _selectedFrequency;
    if (freq == null) return;
    setState(() => _savingFrequency = true);
    try {
      await DbApiService.instance.updatePmPlan(eq.id, freq);
      await DataService().reloadEquipment();
      if (mounted) {
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(l10n.pmFrequencySaved),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _savingFrequency = false);
    }
  }

  // ── Bouton validation PM (Tâche 3) ──────────────────────────────────────────

  Widget _buildValidatePmButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _validating ? null : () => _onValidatePm(l10n),
        icon: _validating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle_outline, size: 18),
        label: Text(l10n.pmValidateButton),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _onValidatePm(AppLocalizations l10n) async {
    final checklistState = _checklistKey.currentState;
    final items = checklistState?.items ?? const [];

    final unchecked = items.where((i) => !i.isDone).length;

    // Confirmation si au moins une étape non cochée
    if (unchecked > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.pmValidateConfirmTitle),
          content: Text(l10n.pmValidateConfirmBody(unchecked)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white),
              child: Text(l10n.commonConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    setState(() => _validating = true);

    try {
      final snapshot = items.map((i) => i.toJson()).toList();
      final result = await DbApiService.instance.validatePreventiveMaintenance(
        eq.id,
        checklistSnapshot: snapshot,
      );

      await DataService().reloadEquipment();
      if (!mounted) return;
      widget.onRefresh();

      final nextPm =
          result['next_preventive_maintenance'] as String? ?? '';

      // Dialog de confirmation avec prochaine date
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.check_circle,
                color: AppColors.success, size: 22),
            const SizedBox(width: 8),
            Text(l10n.pmValidateSuccess),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (nextPm.isNotEmpty)
                Text(
                  l10n.pmNextDate(formatDetailDate(nextPm)),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary),
                ),
            ],
          ),
          actions: [
            // Bouton impression étiquette (Tâche 4)
            TextButton.icon(
              icon: const Icon(Icons.print_outlined, size: 16),
              label: Text(l10n.pmPrintLabel),
              onPressed: () => _printLabel(
                nextPm: nextPm,
                ctx: ctx,
                l10n: l10n,
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              child: Text(l10n.commonClose),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  // ── Impression étiquette PDF (Tâche 4) ──────────────────────────────────────

  Future<void> _printLabel({
    required String nextPm,
    required BuildContext ctx,
    required AppLocalizations l10n,
  }) async {
    // Trouver le dernier enregistrement PM préventif pour le nom du technicien
    final lastPm = _pmHistory.isNotEmpty ? _pmHistory.first : null;
    final auth = AuthService();
    final techName = lastPm?.technician ?? auth.currentUser?.name ?? '';
    final performedAt =
        eq.lastPreventiveMaintenance ?? DateTime.now().toIso8601String();

    try {
      final bytes = await PdfLabelService.generateMaintenanceLabel(
        equipmentName: eq.name,
        serialNumber: eq.serialNumber.isNotEmpty ? eq.serialNumber : null,
        department: eq.department,
        technicianName: techName,
        performedAt: performedAt,
        nextPm: nextPm,
      );

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'etiquette_pm_${eq.id}.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// Bouton "Étiquette de maintenance" autonome (Tâche 4 — RBAC).
  Widget _buildLabelButton(AppLocalizations l10n) {
    if (_pmHistory.isEmpty) return const SizedBox.shrink();
    final lastPm = _pmHistory.first;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _printLabelFromHistory(lastPm, l10n),
        icon: const Icon(Icons.label_outline, size: 16),
        label: Text(l10n.pmEditLabel),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Future<void> _printLabelFromHistory(
      MaintenanceRecord record, AppLocalizations l10n) async {
    final nextPm = eq.nextPreventiveMaintenance ?? '';
    try {
      final bytes = await PdfLabelService.generateMaintenanceLabel(
        equipmentName: eq.name,
        serialNumber: eq.serialNumber.isNotEmpty ? eq.serialNumber : null,
        department: eq.department,
        technicianName: record.technician,
        performedAt: record.date,
        nextPm: nextPm,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'etiquette_pm_${eq.id}.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Listes de maintenance ────────────────────────────────────────────────────

  Widget _buildMaintenanceListCard(
    AppLocalizations l10n, {
    required String title,
    required List<MaintenanceRecord> records,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${records.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...records.map((m) => _buildMaintenanceRow(m, iconColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceRow(MaintenanceRecord m, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 36,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.intervention,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${formatDetailDate(m.date)} — ${m.technician}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Historique PM préventives (Tâche 6) ──────────────────────────────────────

  Widget _buildPmHistoryCard(AppLocalizations l10n) {
    final pmRecords = _pmHistory;
    final total = pmRecords.length;
    final displayed =
        _showAllPmHistory ? pmRecords : pmRecords.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre + compteur
            Row(
              children: [
                const Icon(Icons.history, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.pmHistoryTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Lignes compactes PM
            ...displayed.map((m) => _buildPmHistoryRow(m)),

            // Bouton "Voir tout"
            if (total > 10 && !_showAllPmHistory) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showAllPmHistory = true),
                icon: const Icon(Icons.expand_more, size: 16),
                label: Text(l10n.pmSeeAll),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary),
              ),
            ],

            // Bouton étiquette de la dernière PM
            if (_canValidatePm && _pmHistory.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildLabelButton(l10n),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPmHistoryRow(MaintenanceRecord m) {
    final steps = m.durationMinutes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              size: 14, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              formatDetailDate(m.date),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              m.technician,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          if (steps != null)
            Text(
              '${steps} min',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }

  // ── Bouton Créer PM ──────────────────────────────────────────────────────────

  Widget _buildSchedulePmButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _schedulePm(l10n),
        icon: const Icon(Icons.event_available, size: 16),
        label: Text(l10n.equipDetailCreatePm),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Future<void> _schedulePm(AppLocalizations l10n) async {
    final now = DateTime.now();
    final initial = eq.nextPreventiveMaintenance != null
        ? DateTime.tryParse(eq.nextPreventiveMaintenance!) ??
            now.add(const Duration(days: 30))
        : now.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate:
          initial.isBefore(now) ? now.add(const Duration(days: 1)) : initial,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;

    final iso = picked.toIso8601String().substring(0, 10);
    try {
      await DbApiService.instance
          .updateEquipment(eq.id, {'next_preventive_maintenance': iso});
      await DataService().reloadEquipment();
      if (mounted) {
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(l10n.equipmentSchedulePmSuccess),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── État vide ────────────────────────────────────────────────────────────────

  Widget _buildEmptyMaintenance() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.build_outlined, size: 40, color: AppColors.textMuted),
              SizedBox(height: 8),
              Text(
                '—',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
