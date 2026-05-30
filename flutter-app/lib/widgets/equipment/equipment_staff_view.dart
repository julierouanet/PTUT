import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../models/issue.dart';
import '../../screens/issue_detail_screen.dart';
import '../../theme/app_theme.dart';
import '../urgency_badge.dart';
import '../issue_category_selector.dart';
import 'equipment_detail_helpers.dart';

/// Vue simplifiée pour le rôle [UserRole.hospitalStaff].
///
/// Masque toutes les informations techniques GMAO. Affiche :
///   1. Bannière critique (si applicable)
///   2. Statut en grand + localisation
///   3. Bouton massif "Signaler une panne" (ouvre le sélecteur de catégorie)
///   4. Incidents actifs (max 3)
///   5. Informations de contact du service technique
class EquipmentStaffView extends StatelessWidget {
  final Equipment equipment;
  final List<Issue> issues;
  final bool loading;

  const EquipmentStaffView({
    super.key,
    required this.equipment,
    required this.issues,
    this.loading = false,
  });

  List<Issue> get _active =>
      issues.where((i) => kActiveIssueStatuses.contains(i.status)).toList();

  bool get _isCriticalOos =>
      equipment.criticality == EquipmentCriticality.a &&
      equipment.status == EquipmentStatus.outOfService;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Alerte critique (si criticité A + hors service) ─────────
          if (_isCriticalOos) ...[
            _buildCriticalAlert(l10n),
            const SizedBox(height: 12),
          ],

          // ── Statut en grand ─────────────────────────────────────────
          _buildStatusCard(l10n),
          const SizedBox(height: 16),

          // ── Bouton Signaler (prominent) ─────────────────────────────
          _buildReportButton(context, l10n),
          const SizedBox(height: 16),

          // ── Incidents actifs ────────────────────────────────────────
          _buildActiveIssues(context, l10n),
          const SizedBox(height: 16),

          // ── Contact équipe technique ────────────────────────────────
          _buildContactCard(l10n),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Bannière critique ────────────────────────────────────────────────────────

  Widget _buildCriticalAlert(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.critical,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.crisis_alert, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.equipDetailCriticalBanner,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Carte statut ─────────────────────────────────────────────────────────────

  Widget _buildStatusCard(AppLocalizations l10n) {
    final statusColor = getStatusColor(equipment.status.displayName);
    final statusBg = getStatusBackgroundColor(equipment.status.displayName);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              equipment.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Badge statut agrandi
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                equipment.status.displayName,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (equipment.location.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    equipment.location,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ],
            if (equipment.department.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    equipment.department,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Bouton signaler ──────────────────────────────────────────────────────────

  Widget _buildReportButton(BuildContext context, AppLocalizations l10n) {
    return ElevatedButton.icon(
      onPressed: () => showIssueCategorySelector(context),
      icon: const Icon(Icons.report_problem, size: 20),
      label: Text(
        l10n.equipDetailStaffReportButton,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Incidents actifs ─────────────────────────────────────────────────────────

  Widget _buildActiveIssues(BuildContext context, AppLocalizations l10n) {
    final active = _active;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  size: 18,
                  color: active.isEmpty
                      ? AppColors.success
                      : AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.equipDetailStaffActiveIssues,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (active.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${active.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (active.isEmpty)
              Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(
                    l10n.equipDetailStaffNoActiveIssues,
                    style: const TextStyle(
                        color: AppColors.success, fontSize: 13),
                  ),
                ],
              )
            else
              ...active.take(3).map((issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              IssueDetailScreen(issueId: issue.id),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.warning
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            UrgencyBadge(
                                urgency: issue.urgency,
                                isCompact: true),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                issue.type,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                size: 16,
                                color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  // ── Contact équipe technique ─────────────────────────────────────────────────

  Widget _buildContactCard(AppLocalizations l10n) {
    final (contactLabel, contactIcon) =
        _resolveContact(l10n, equipment.macroCategory?.toLowerCase() ?? '');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.support_agent,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.equipDetailStaffContactSection,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(contactIcon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  contactLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (String, IconData) _resolveContact(AppLocalizations l10n, String macro) {
    if (macro.contains('biomedical') || macro.contains('biomédical')) {
      return (l10n.equipDetailStaffContactBiomedical,
          Icons.medical_services_outlined);
    }
    if (macro.contains('it') || macro.contains('informatique')) {
      return (l10n.equipDetailStaffContactIt, Icons.computer_outlined);
    }
    if (macro.contains('infrastructure')) {
      return (l10n.equipDetailStaffContactInfra, Icons.engineering_outlined);
    }
    return (l10n.equipDetailStaffContactGeneric, Icons.build_outlined);
  }
}
