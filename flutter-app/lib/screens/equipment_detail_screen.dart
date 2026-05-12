import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/equipment.dart';
import '../models/issue.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/urgency_badge.dart';

/// Statuts considérés comme « actifs » (pas encore résolus)
const _activeStatuses = {
  IssueStatus.reported,
  IssueStatus.acknowledged,
  IssueStatus.assigned,
  IssueStatus.inProgress,
  IssueStatus.waitingMaterials,
};

/// Page de détail d'un équipement : informations complètes + maintenance + incidents.
///
/// Données chargées depuis db-service (GET /api/equipment/:id + GET /api/issues?equipment_id=…)
/// en parallèle à l'ouverture. Un [initialEquipment] peut être fourni pour afficher
/// les informations de base immédiatement pendant le chargement complet.
class EquipmentDetailScreen extends StatefulWidget {
  final String equipmentId;
  final Equipment? initialEquipment;
  final VoidCallback? onEdit;
  final VoidCallback? onReport;

  const EquipmentDetailScreen({
    super.key,
    required this.equipmentId,
    this.initialEquipment,
    this.onEdit,
    this.onReport,
  });

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen> {
  Equipment? _equipment;
  List<Issue> _issues = [];
  bool _loadingDetails = true;
  String? _error;

  List<Issue> get _activeIssues =>
      _issues.where((i) => _activeStatuses.contains(i.status)).toList();

  List<Issue> get _resolvedIssues =>
      _issues.where((i) => !_activeStatuses.contains(i.status)).toList();

  @override
  void initState() {
    super.initState();
    _equipment = widget.initialEquipment;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final results = await Future.wait([
        DbApiService.instance.getEquipmentById(widget.equipmentId),
        DbApiService.instance.getIssues(equipmentId: widget.equipmentId),
      ]);
      final eq = Equipment.fromApiJson(results[0] as Map<String, dynamic>);
      final rawIssues = (results[1] as List).cast<Map<String, dynamic>>();
      setState(() {
        _equipment = eq;
        _issues = rawIssues.map(Issue.fromApiJson).toList();
        _loadingDetails = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingDetails = false;
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final eq = _equipment;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          eq?.name ?? l10n.commonDetails,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.commonEdit,
              onPressed: () {
                Navigator.pop(context);
                widget.onEdit!();
              },
            ),
          if (widget.onReport != null)
            IconButton(
              icon: const Icon(Icons.report_problem_outlined),
              tooltip: l10n.equipmentReportProblem,
              onPressed: () {
                Navigator.pop(context);
                widget.onReport!();
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(l10n, eq),
    );
  }

  Widget _buildBody(AppLocalizations l10n, Equipment? eq) {
    // Chargement initial sans données disponibles
    if (_loadingDetails && eq == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (eq == null) {
      return Center(
        child: Text(
          _error ?? l10n.equipDetailLoadingError,
          style: const TextStyle(color: AppColors.error),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(l10n, eq),
          const SizedBox(height: 16),
          _buildMaintenanceCard(l10n, eq),
          const SizedBox(height: 16),
          _buildIssuesSection(l10n),
          if (_loadingDetails)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null && !_loadingDetails)
            _buildErrorBanner(l10n),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Section En-tête ──────────────────────────────────────────────────────────

  Widget _buildHeaderCard(AppLocalizations l10n, Equipment eq) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Statut + nom ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(status: eq.status.displayName),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    eq.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Informations générales ────────────────────────────────────
            _buildSectionTitle(l10n.equipmentGeneralSection),
            _buildInfoRow(l10n.commonDepartment, eq.department),
            _buildInfoRow(l10n.commonCategory, eq.category),
            if (eq.serialNumber.isNotEmpty)
              _buildInfoRow(l10n.equipmentSerialNumber, eq.serialNumber),
            if (eq.location.isNotEmpty)
              _buildInfoRow(l10n.equipmentLocation, eq.location),
            _buildInfoRow(l10n.equipmentInternalId, eq.id, mono: true),

            // ── Inventaire ────────────────────────────────────────────────
            if (_hasInventoryFields(eq)) ...[
              const SizedBox(height: 12),
              _buildSectionTitle(l10n.equipmentInventorySection),
              if (eq.manufacturer != null && eq.manufacturer!.isNotEmpty)
                _buildInfoRow(l10n.equipmentManufacturer, eq.manufacturer!),
              if (eq.model != null && eq.model!.isNotEmpty)
                _buildInfoRow(l10n.equipmentModel, eq.model!),
              if (eq.manufYear != null)
                _buildInfoRow(l10n.equipmentManufYear, eq.manufYear!.toString()),
              if (eq.installDate != null && eq.installDate!.isNotEmpty)
                _buildInfoRow(l10n.equipmentInstallDate, _formatDate(eq.installDate!)),
            ],

            // ── Tags ──────────────────────────────────────────────────────
            if (eq.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSectionTitle(l10n.equipmentTags),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: eq.tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            t,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Section Maintenance ──────────────────────────────────────────────────────

  Widget _buildMaintenanceCard(AppLocalizations l10n, Equipment eq) {
    final hasDates = (eq.lastPreventiveMaintenance?.isNotEmpty ?? false) ||
        (eq.nextPreventiveMaintenance?.isNotEmpty ?? false) ||
        (eq.nextRevisionDate?.isNotEmpty ?? false);
    final hasHistory = eq.maintenanceHistory.isNotEmpty;
    final hasFuture  = eq.futureMaintenance.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.preventiveSection,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Bandeau d'alerte maintenance préventive ───────────────────
            _buildPreventiveAlertBanner(l10n, eq),

            // ── Dates ─────────────────────────────────────────────────────
            if (hasDates) ...[
              if (eq.nextRevisionDate != null && eq.nextRevisionDate!.isNotEmpty)
                _buildInfoRow(
                  l10n.equipmentNextRevision,
                  _formatDate(eq.nextRevisionDate!),
                  icon: Icons.event,
                  color: _revisionColor(eq.nextRevisionDate!),
                ),
              if (eq.lastPreventiveMaintenance != null &&
                  eq.lastPreventiveMaintenance!.isNotEmpty)
                _buildInfoRow(
                  l10n.lastPreventiveDate,
                  _formatDate(eq.lastPreventiveMaintenance!),
                ),
              if (eq.nextPreventiveMaintenance != null &&
                  eq.nextPreventiveMaintenance!.isNotEmpty)
                _buildInfoRow(
                  l10n.nextPreventiveDate,
                  _formatDate(eq.nextPreventiveMaintenance!),
                  icon: Icons.event_available,
                  color: _preventiveColor(eq.preventiveMaintenanceAlertLevel),
                ),
            ],

            // ── Maintenances planifiées ───────────────────────────────────
            if (hasFuture) ...[
              const SizedBox(height: 8),
              _buildSectionTitle(l10n.equipmentFutureMaintenance),
              ...eq.futureMaintenance.map(
                (m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.schedule, color: AppColors.primary),
                  title: Text(m.intervention,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '${_formatDate(m.date)} — ${m.technician}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],

            // ── Historique de maintenance ─────────────────────────────────
            if (hasHistory) ...[
              const SizedBox(height: 8),
              _buildSectionTitle(l10n.equipmentMaintenanceHistory),
              ...eq.maintenanceHistory.map(
                (m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.build, color: AppColors.warning),
                  title: Text(m.intervention,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '${_formatDate(m.date)} — ${m.technician}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],

            // ── État vide ─────────────────────────────────────────────────
            if (!hasDates && !hasFuture && !hasHistory)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '—',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Section Incidents ────────────────────────────────────────────────────────

  Widget _buildIssuesSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Incidents en cours ────────────────────────────────────────────
        _buildIssueGroup(
          l10n,
          title: l10n.equipDetailCurrentIssues,
          issues: _activeIssues,
          emptyMessage: l10n.equipDetailNoCurrentIssues,
          icon: Icons.warning_amber_outlined,
          iconColor: AppColors.warning,
        ),
        const SizedBox(height: 12),
        // ── Historique des incidents ──────────────────────────────────────
        _buildIssueGroup(
          l10n,
          title: l10n.equipDetailPastIssues,
          issues: _resolvedIssues,
          emptyMessage: l10n.equipDetailNoPastIssues,
          icon: Icons.history,
          iconColor: AppColors.textSecondary,
        ),
        // ── Bouton signaler ───────────────────────────────────────────────
        if (widget.onReport != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onReport!();
              },
              icon: const Icon(Icons.report_problem_outlined, size: 16),
              label: Text(l10n.equipmentReportProblem),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIssueGroup(
    AppLocalizations l10n, {
    required String title,
    required List<Issue> issues,
    required String emptyMessage,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Titre + compteur ──────────────────────────────────────────
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (issues.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${issues.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Liste ou état vide ────────────────────────────────────────
            if (issues.isEmpty)
              Text(
                emptyMessage,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              )
            else
              ...issues.map((issue) => _buildIssueCard(l10n, issue)),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueCard(AppLocalizations l10n, Issue issue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Badges urgence + statut ───────────────────────────────────
          Row(
            children: [
              UrgencyBadge(urgency: issue.urgency, isCompact: true),
              const SizedBox(width: 8),
              IssueStatusBadge(status: issue.status.displayName),
              const Spacer(),
              Text(
                _formatDateShort(issue.createdAt),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Type + description ────────────────────────────────────────
          Text(
            issue.type,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            issue.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),

          // ── Technicien assigné ────────────────────────────────────────
          if (issue.assignedTechnician != null &&
              issue.assignedTechnician!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  issue.assignedTechnician!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Widgets utilitaires ──────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
    Color? color,
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 13, color: color ?? AppColors.textSecondary),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: color ?? AppColors.textPrimary,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreventiveAlertBanner(AppLocalizations l10n, Equipment eq) {
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
              isOverdue ? l10n.preventiveAlertOverdue : l10n.preventiveAlertSoon,
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

  Widget _buildErrorBanner(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_outlined, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.equipDetailLoadingError,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  bool _hasInventoryFields(Equipment eq) {
    return (eq.manufacturer != null && eq.manufacturer!.isNotEmpty) ||
        (eq.model != null && eq.model!.isNotEmpty) ||
        eq.manufYear != null ||
        (eq.installDate != null && eq.installDate!.isNotEmpty);
  }

  /// Formate une date ISO (`2025-12-31`) → `31/12/2025`
  String _formatDate(String iso) {
    if (iso.length < 10) return iso;
    final parts = iso.substring(0, 10).split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  /// Formate un horodatage en version courte `31/12/2025`
  String _formatDateShort(String value) {
    return _formatDate(value.replaceAll('T', ' '));
  }

  Color _revisionColor(String iso) {
    try {
      final date = DateTime.parse(iso.substring(0, 10));
      final diff = date.difference(DateTime.now()).inDays;
      if (diff < 0)  return AppColors.error;
      if (diff <= 30) return AppColors.warning;
      return AppColors.success;
    } catch (_) {
      return AppColors.textSecondary;
    }
  }

  Color _preventiveColor(String? level) {
    switch (level) {
      case 'due':  return AppColors.error;
      case 'soon': return AppColors.warning;
      case 'ok':   return AppColors.success;
      default:     return AppColors.textSecondary;
    }
  }
}
