import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../models/issue.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/pdf_label_service.dart';
import '../../theme/app_theme.dart';
import '../replacement_badge.dart';
import '../status_badge.dart';
import 'equipment_critical_banner.dart';
import 'equipment_detail_helpers.dart';
import 'equipment_field_edit_dialog.dart';
import 'equipment_qr_dialog.dart';

/// Callbacks de drill-down depuis les métadonnées de la fiche équipement.
///
/// Chaque callback est `null` si la cible n'est pas navigable (id absent) :
/// la ligne correspondante reste alors un texte simple non cliquable.
class EquipmentLinkHandlers {
  final VoidCallback? onDepartment;
  final VoidCallback? onCategory;
  final VoidCallback? onSubcategory;
  final VoidCallback? onManufacturer;
  final VoidCallback? onModel;

  const EquipmentLinkHandlers({
    this.onDepartment,
    this.onCategory,
    this.onSubcategory,
    this.onManufacturer,
    this.onModel,
  });
}

/// Onglet Informations — tableau de bord central de l'équipement.
///
/// Outre les métadonnées (avec drill-down en vue complète via [handlers]), cet
/// onglet consolide désormais : la bannière critique, le résumé d'état, le bloc
/// de notifications cliquable, l'édition par champ (crayons) et les étiquettes
/// (QR + maintenance). Les notifications n'apparaissent **que** sur cet onglet.
///
/// En vue staff, [linksEnabled] reste false (aucune édition, aucun lien).
class EquipmentInfoTab extends StatelessWidget {
  final Equipment equipment;
  final bool linksEnabled;
  final EquipmentLinkHandlers handlers;

  /// Incidents de l'équipement — pour le résumé d'état et la notif « incident ».
  final List<Issue> issues;

  /// Rappel pour recharger la fiche après une édition par champ.
  final VoidCallback? onRefresh;

  /// Item du plan de remplacement de cet équipement (null si absent/non chargé).
  final Map<String, dynamic>? replacementItem;

  /// Indique que le plan de remplacement a fini de charger (succès ou échec).
  final bool replacementLoaded;

  /// L'utilisateur courant est admin (seul habilité à saisir la durée de vie).
  final bool isAdmin;

  const EquipmentInfoTab({
    super.key,
    required this.equipment,
    this.linksEnabled = false,
    this.handlers = const EquipmentLinkHandlers(),
    this.issues = const [],
    this.onRefresh,
    this.replacementItem,
    this.replacementLoaded = false,
    this.isAdmin = false,
  });

  /// Retourne le callback à brancher sur une ligne : null si les liens sont
  /// désactivés (vue staff) ou si la cible n'est pas navigable.
  VoidCallback? _link(VoidCallback? handler) => linksEnabled ? handler : null;

  // RBAC édition par champ : gestionnaire d'équipement OU droit de réparation.
  bool get _canEdit {
    if (!linksEnabled) return false;
    final auth = AuthService();
    return auth.canManageEquipment ||
        auth.hasPermission(Permission.updateRepairs);
  }

  // RBAC étiquette PM : droit de validation des réparations.
  bool get _canEditPmLabel =>
      linksEnabled && AuthService().hasPermission(Permission.updateRepairs);

  // RBAC notif « remplacement conseillé » : admin/superviseur.
  bool get _canSeeReplacement =>
      linksEnabled && AuthService().canGenerateReports;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final eq = equipment;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Bannière critique (criticité A + hors service) ───────────
          if (linksEnabled)
            EquipmentCriticalBanner(
              equipment: eq,
              onTap: () => DefaultTabController.of(context).animateTo(2),
            ),

          // ── Résumé d'état ────────────────────────────────────────────
          if (linksEnabled) ...[
            _buildStateSummaryCard(l10n, eq),
            const SizedBox(height: 16),
            // ── Notifications consolidées ─────────────────────────────
            _buildNotificationsCard(context, l10n, eq),
            const SizedBox(height: 16),
          ],

          _buildHeaderCard(context, l10n, eq),
          if (hasInventoryFields(eq) || _canEdit) ...[
            const SizedBox(height: 16),
            _buildInventoryCard(context, l10n, eq),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Lancement de l'édition par champ ─────────────────────────────────────────

  Future<void> _editField(
    BuildContext context,
    AppLocalizations l10n,
    Equipment eq, {
    required String apiKey,
    required String label,
    required EquipmentFieldType type,
    String? initial,
  }) async {
    final ok = await showEquipmentFieldEditDialog(
      context: context,
      equipment: eq,
      apiKey: apiKey,
      title: l10n.equipFieldEditTitle(label),
      type: type,
      initialValue: initial,
    );
    // On reste sur l'onglet ; on recharge la fiche pour refléter l'état serveur.
    if (ok) onRefresh?.call();
  }

  // ── Résumé d'état ────────────────────────────────────────────────────────────

  Widget _buildStateSummaryCard(AppLocalizations l10n, Equipment eq) {
    final activeCount =
        issues.where((i) => kActiveIssueStatuses.contains(i.status)).length;
    final totalCount = issues.length;

    final (maintLabel, maintColor) = switch (eq.preventiveMaintenanceAlertLevel) {
      'due'  => (l10n.equipDetailMaintOverdue, AppColors.error),
      'soon' => (l10n.equipDetailMaintSoon, AppColors.warning),
      'ok'   => (l10n.equipDetailMaintUpToDate, AppColors.success),
      _      => (l10n.equipDetailMaintNone, AppColors.textSecondary),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.equipDetailStateSection,
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
                Expanded(
                  child: _buildSummaryTile(
                    icon: Icons.report_problem_outlined,
                    label: l10n.equipDetailIncidentsLabel,
                    value: l10n.equipDetailIncidentsSummary(
                        activeCount, totalCount),
                    color: activeCount > 0
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryTile(
                    icon: Icons.health_and_safety_outlined,
                    label: l10n.equipDetailMaintenanceLabel,
                    value: maintLabel,
                    color: maintColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
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
              fontSize: 15,
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
        ],
      ),
    );
  }

  // ── Notifications consolidées ────────────────────────────────────────────────

  Widget _buildNotificationsCard(
      BuildContext context, AppLocalizations l10n, Equipment eq) {
    final signals = <Widget>[];
    final replStatus = replacementItem?['status_replacement'] as String?;

    // 1. Durée de vie de référence manquante → fiche sous-catégorie (admin) /
    //    message d'orientation (non-admin). Masquée si pas de sous-catégorie.
    if (replacementLoaded &&
        replStatus == 'donnee_manquante' &&
        eq.subcategoryId != null) {
      signals.add(_signalRow(
        icon: Icons.hourglass_empty,
        color: AppColors.replacementUnknown,
        text: l10n.equipDetailNotifLifespanMissing,
        onTap: () {
          if (isAdmin) {
            handlers.onSubcategory?.call();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.equipDetailContactAdmin),
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
      ));
    }

    // 2. Incident ouvert → onglet Incidents.
    final hasActiveIncident =
        issues.any((i) => kActiveIssueStatuses.contains(i.status));
    if (hasActiveIncident) {
      signals.add(_signalRow(
        icon: Icons.error_outline,
        color: AppColors.error,
        text: l10n.equipDetailNotifIncidentOpen,
        onTap: () => DefaultTabController.of(context).animateTo(2),
      ));
    }

    // 3. PM en retard / bientôt → onglet Maintenance.
    final pmLevel = eq.preventiveMaintenanceAlertLevel;
    if (pmLevel == 'due') {
      signals.add(_signalRow(
        icon: Icons.error_outline,
        color: AppColors.error,
        text: l10n.equipDetailNotifPmDue,
        onTap: () => DefaultTabController.of(context).animateTo(1),
      ));
    } else if (pmLevel == 'soon') {
      signals.add(_signalRow(
        icon: Icons.schedule,
        color: AppColors.warning,
        text: l10n.equipDetailNotifPmSoon,
        onTap: () => DefaultTabController.of(context).animateTo(1),
      ));
    }

    // 4. Remplacement conseillé → informatif (tooltip détaillé), pas de nav.
    //    Admin/superviseur uniquement.
    if (_canSeeReplacement &&
        replacementLoaded &&
        (replStatus == 'a_remplacer' || replStatus == 'bientot')) {
      final age      = (replacementItem?['age'] as num?)?.toInt();
      final lifespan = (replacementItem?['lifespan'] as num?)?.toInt();
      final crit     = replacementItem?['criticality'] as String?;
      final tooltip  =
          ReplacementBadge.tooltipFor(l10n, replStatus!, age, lifespan, crit);
      final label = replStatus == 'a_remplacer'
          ? l10n.replacementStatusDue
          : l10n.replacementStatusSoon;
      signals.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          ReplacementBadge(status: replStatus, tooltip: tooltip),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tooltip.isEmpty ? label : '$label — $tooltip',
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
        ]),
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.notifications_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                l10n.equipmentDetailAlertsTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (signals.isEmpty)
              Row(children: [
                const Icon(Icons.check_circle_outline,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text(l10n.equipmentDetailNoAlerts,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ])
            else
              ...signals,
          ],
        ),
      ),
    );
  }

  /// Ligne de notification cliquable : icône + texte + chevron.
  Widget _signalRow({
    required IconData icon,
    required Color color,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
          const Icon(Icons.chevron_right,
              size: 18, color: AppColors.textMuted),
        ]),
      ),
    );
  }

  // ── Carte principale ─────────────────────────────────────────────────────────

  Widget _buildHeaderCard(
      BuildContext context, AppLocalizations l10n, Equipment eq) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Statut + nom + actions (QR, étiquette PM) ─────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(status: eq.status.displayName),
                if (_canEdit)
                  EditPencil(
                    onTap: () => _editField(context, l10n, eq,
                        apiKey: 'status',
                        label: l10n.commonStatus,
                        type: EquipmentFieldType.status),
                  ),
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
                if (_canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.textSecondary,
                    tooltip: l10n.commonEdit,
                    onPressed: () => _editField(context, l10n, eq,
                        apiKey: 'name',
                        label: l10n.equipmentName,
                        type: EquipmentFieldType.text,
                        initial: eq.name),
                  ),
                Tooltip(
                  message: l10n.equipDetailQrCode,
                  child: IconButton(
                    icon: const Icon(Icons.qr_code_2),
                    color: AppColors.textSecondary,
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => EquipmentQrDialog(equipment: eq),
                    ),
                  ),
                ),
                if (_canEditPmLabel)
                  Tooltip(
                    message: l10n.pmEditLabel,
                    child: IconButton(
                      icon: const Icon(Icons.label_outline),
                      color: AppColors.textSecondary,
                      onPressed: () => _printPmLabel(context, l10n, eq),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Informations générales ────────────────────────────────
            DetailSectionTitle(l10n.equipmentGeneralSection),
            DetailInfoRow(l10n.commonDepartment, eq.department,
                onTap: _link(handlers.onDepartment),
                onEdit: _canEdit
                    ? () => _editField(context, l10n, eq,
                        apiKey: 'department',
                        label: l10n.commonDepartment,
                        type: EquipmentFieldType.text,
                        initial: eq.department)
                    : null),
            DetailInfoRow(l10n.commonCategory, eq.category,
                onTap: _link(handlers.onCategory)),
            if (eq.macroCategory != null && eq.macroCategory!.isNotEmpty)
              DetailInfoRow(l10n.macroCategoryLabel, eq.macroCategory!),
            if (eq.subcategoryName != null && eq.subcategoryName!.isNotEmpty)
              DetailInfoRow(l10n.subcategoryLabel, eq.subcategoryName!,
                  onTap: _link(handlers.onSubcategory)),
            // Modèle remonté ici (drill-down conservé) + édition libre.
            if ((eq.model != null && eq.model!.isNotEmpty) || _canEdit)
              DetailInfoRow(
                  l10n.equipmentModel,
                  (eq.model != null && eq.model!.isNotEmpty) ? eq.model! : '—',
                  onTap: _link(handlers.onModel),
                  onEdit: _canEdit
                      ? () => _editField(context, l10n, eq,
                          apiKey: 'model',
                          label: l10n.equipmentModel,
                          type: EquipmentFieldType.text,
                          initial: eq.model)
                      : null),
            if (eq.serialNumber.isNotEmpty || _canEdit)
              DetailInfoRow(
                  l10n.equipmentSerialNumber,
                  eq.serialNumber.isNotEmpty ? eq.serialNumber : '—',
                  onEdit: _canEdit
                      ? () => _editField(context, l10n, eq,
                          apiKey: 'serial_number',
                          label: l10n.equipmentSerialNumber,
                          type: EquipmentFieldType.text,
                          initial: eq.serialNumber)
                      : null),
            if (eq.location.isNotEmpty || _canEdit)
              DetailInfoRow(
                  l10n.equipmentLocation,
                  eq.location.isNotEmpty ? eq.location : '—',
                  onEdit: _canEdit
                      ? () => _editField(context, l10n, eq,
                          apiKey: 'location',
                          label: l10n.equipmentLocation,
                          type: EquipmentFieldType.text,
                          initial: eq.location)
                      : null),
            DetailInfoRow(l10n.equipmentInternalId, eq.id, mono: true),

            // ── Criticité ─────────────────────────────────────────────
            if (eq.criticality != null) ...[
              const SizedBox(height: 4),
              _buildCriticalityRow(context, l10n, eq),
            ] else if (_canEdit) ...[
              const SizedBox(height: 4),
              DetailInfoRow(l10n.criticalityLabel, '—',
                  onEdit: () => _editField(context, l10n, eq,
                      apiKey: 'criticality',
                      label: l10n.criticalityLabel,
                      type: EquipmentFieldType.criticality)),
            ],

            // ── Garantie ──────────────────────────────────────────────
            if (eq.warrantyEndDate != null && eq.warrantyEndDate!.isNotEmpty)
              _buildWarrantyRow(context, l10n, eq)
            else if (_canEdit)
              DetailInfoRow(l10n.warrantyEndDate, '—',
                  onEdit: () => _editField(context, l10n, eq,
                      apiKey: 'warranty_end_date',
                      label: l10n.warrantyEndDate,
                      type: EquipmentFieldType.date)),

            // ── Description métier (sous-catégorie, lecture seule) ─────
            if ((eq.subcategoryDescription ?? '').isNotEmpty)
              DetailInfoRow(
                  l10n.equipDetailDescriptionLabel, eq.subcategoryDescription!),

            // ── Étiquettes (déplacées dans Informations générales) ────
            if (eq.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTagsBlock(l10n, eq),
            ],
          ],
        ),
      ),
    );
  }

  // ── Carte inventaire ─────────────────────────────────────────────────────────

  Widget _buildInventoryCard(
      BuildContext context, AppLocalizations l10n, Equipment eq) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.equipmentInventorySection,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if ((eq.manufacturer != null && eq.manufacturer!.isNotEmpty) ||
                _canEdit)
              DetailInfoRow(
                  l10n.equipmentManufacturer,
                  (eq.manufacturer != null && eq.manufacturer!.isNotEmpty)
                      ? eq.manufacturer!
                      : '—',
                  onTap: _link(handlers.onManufacturer),
                  onEdit: _canEdit
                      ? () => _editField(context, l10n, eq,
                          apiKey: 'manufacturer',
                          label: l10n.equipmentManufacturer,
                          type: EquipmentFieldType.text,
                          initial: eq.manufacturer)
                      : null),
            if (eq.manufYear != null || _canEdit)
              DetailInfoRow(
                  l10n.equipmentManufYear,
                  eq.manufYear != null ? eq.manufYear!.toString() : '—',
                  onEdit: _canEdit
                      ? () => _editField(context, l10n, eq,
                          apiKey: 'manuf_year',
                          label: l10n.equipmentManufYear,
                          type: EquipmentFieldType.number,
                          initial: eq.manufYear?.toString())
                      : null),
            if ((eq.installDate != null && eq.installDate!.isNotEmpty) ||
                _canEdit)
              DetailInfoRow(
                  l10n.equipmentInstallDate,
                  (eq.installDate != null && eq.installDate!.isNotEmpty)
                      ? formatDetailDate(eq.installDate!)
                      : '—',
                  onEdit: _canEdit
                      ? () => _editField(context, l10n, eq,
                          apiKey: 'install_date',
                          label: l10n.equipmentInstallDate,
                          type: EquipmentFieldType.date,
                          initial: eq.installDate)
                      : null),
          ],
        ),
      ),
    );
  }

  // ── Bloc tags (intégré aux Informations générales) ───────────────────────────

  Widget _buildTagsBlock(AppLocalizations l10n, Equipment eq) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.label_outline,
                size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              l10n.equipmentTags,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: eq.tags
              .map((t) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
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
    );
  }

  // ── Étiquette PM (état courant) ──────────────────────────────────────────────

  Future<void> _printPmLabel(
      BuildContext context, AppLocalizations l10n, Equipment eq) async {
    final auth = AuthService();
    // Technicien : dernière PM connue, sinon utilisateur courant.
    final lastPmTech = eq.maintenanceHistory.isNotEmpty
        ? eq.maintenanceHistory.first.technician
        : null;
    final techName =
        (lastPmTech != null && lastPmTech.isNotEmpty)
            ? lastPmTech
            : (auth.currentUser?.name ?? '');
    final performedAt =
        eq.lastPreventiveMaintenance ?? DateTime.now().toIso8601String();
    final nextPm = eq.nextPreventiveMaintenance ?? '';

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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _buildCriticalityRow(
      BuildContext context, AppLocalizations l10n, Equipment eq) {
    final c = eq.criticality!;
    final (label, color, tooltip) = switch (c) {
      EquipmentCriticality.a => (
          l10n.criticalityA,
          AppColors.error,
          l10n.criticalityTooltipA,
        ),
      EquipmentCriticality.b => (
          l10n.criticalityB,
          AppColors.warning,
          l10n.criticalityTooltipB,
        ),
      EquipmentCriticality.c => (
          l10n.criticalityC,
          AppColors.success,
          l10n.criticalityTooltipC,
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              l10n.criticalityLabel,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Tooltip(
              message: tooltip,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
          if (_canEdit)
            EditPencil(
              onTap: () => _editField(context, l10n, eq,
                  apiKey: 'criticality',
                  label: l10n.criticalityLabel,
                  type: EquipmentFieldType.criticality),
            ),
        ],
      ),
    );
  }

  Widget _buildWarrantyRow(
      BuildContext context, AppLocalizations l10n, Equipment eq) {
    final level = eq.warrantyAlertLevel;
    final (statusLabel, color) = switch (level) {
      'expired'       => (l10n.warrantyExpired, AppColors.error),
      'expiring_soon' => (l10n.warrantyExpiringSoon, AppColors.warning),
      _               => (l10n.warrantyValid, AppColors.success),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              l10n.warrantyEndDate,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  formatDetailDate(eq.warrantyEndDate!),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color),
                  ),
                ),
              ],
            ),
          ),
          if (_canEdit)
            EditPencil(
              onTap: () => _editField(context, l10n, eq,
                  apiKey: 'warranty_end_date',
                  label: l10n.warrantyEndDate,
                  type: EquipmentFieldType.date,
                  initial: eq.warrantyEndDate),
            ),
        ],
      ),
    );
  }
}
