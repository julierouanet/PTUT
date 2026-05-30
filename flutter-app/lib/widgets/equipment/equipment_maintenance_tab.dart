import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../models/issue.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../services/db_api_service.dart';
import '../../theme/app_theme.dart';
import 'equipment_detail_helpers.dart';

/// Onglet Maintenance — PM, historique, KPIs MTTR et bouton "Créer PM".
class EquipmentMaintenanceTab extends StatefulWidget {
  final Equipment equipment;
  final List<Issue> issues;

  /// Rappel pour recharger les données depuis l'écran parent après un PATCH.
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

  bool get _canSchedulePm {
    final auth = AuthService();
    return auth.canManageEquipment ||
        auth.hasPermission(Permission.updateRepairs);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasDates = (eq.lastPreventiveMaintenance?.isNotEmpty ?? false) ||
        (eq.nextPreventiveMaintenance?.isNotEmpty ?? false) ||
        (eq.nextRevisionDate?.isNotEmpty ?? false);
    final hasHistory = eq.maintenanceHistory.isNotEmpty;
    final hasFuture = eq.futureMaintenance.isNotEmpty;
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

          // ── Historique ─────────────────────────────────────────────
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, size: 18, color: AppColors.primary),
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
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiTile(
                    label: l10n.equipDetailTotalRepairs,
                    value: (resolvedCount + historyCount).toString(),
                    icon: Icons.build_circle_outlined,
                    color: AppColors.success,
                  ),
                ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(
              note,
              style: const TextStyle(
                fontSize: 10,
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
                color: preventiveColor(eq.preventiveMaintenanceAlertLevel),
              ),
          ],
        ),
      ),
    );
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
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
