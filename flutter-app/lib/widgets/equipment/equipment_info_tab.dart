import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../theme/app_theme.dart';
import '../status_badge.dart';
import 'equipment_detail_helpers.dart';
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

/// Onglet Informations — vue complète des métadonnées de l'équipement.
///
/// En vue complète ([linksEnabled] = true), les métadonnées (département,
/// catégorie, sous-catégorie, fabricant, modèle) deviennent des liens de
/// drill-down via [handlers]. En vue staff, [linksEnabled] reste false.
class EquipmentInfoTab extends StatelessWidget {
  final Equipment equipment;
  final bool linksEnabled;
  final EquipmentLinkHandlers handlers;

  const EquipmentInfoTab({
    super.key,
    required this.equipment,
    this.linksEnabled = false,
    this.handlers = const EquipmentLinkHandlers(),
  });

  /// Retourne le callback à brancher sur une ligne : null si les liens sont
  /// désactivés (vue staff) ou si la cible n'est pas navigable.
  VoidCallback? _link(VoidCallback? handler) => linksEnabled ? handler : null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final eq = equipment;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(context, l10n, eq),
          if (hasInventoryFields(eq)) ...[
            const SizedBox(height: 16),
            _buildInventoryCard(l10n, eq),
          ],
          if (eq.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTagsCard(l10n, eq),
          ],
          const SizedBox(height: 32),
        ],
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
            // ── Statut + nom + bouton QR ──────────────────────────────
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
              ],
            ),
            const SizedBox(height: 16),

            // ── Informations générales ────────────────────────────────
            DetailSectionTitle(l10n.equipmentGeneralSection),
            DetailInfoRow(l10n.commonDepartment, eq.department,
                onTap: _link(handlers.onDepartment)),
            DetailInfoRow(l10n.commonCategory, eq.category,
                onTap: _link(handlers.onCategory)),
            if (eq.macroCategory != null && eq.macroCategory!.isNotEmpty)
              DetailInfoRow(l10n.macroCategoryLabel, eq.macroCategory!),
            if (eq.subcategoryName != null && eq.subcategoryName!.isNotEmpty)
              DetailInfoRow(l10n.subcategoryLabel, eq.subcategoryName!,
                  onTap: _link(handlers.onSubcategory)),
            if (eq.serialNumber.isNotEmpty)
              DetailInfoRow(l10n.equipmentSerialNumber, eq.serialNumber),
            if (eq.location.isNotEmpty)
              DetailInfoRow(l10n.equipmentLocation, eq.location),
            DetailInfoRow(l10n.equipmentInternalId, eq.id, mono: true),

            // ── Criticité ─────────────────────────────────────────────
            if (eq.criticality != null) ...[
              const SizedBox(height: 4),
              _buildCriticalityRow(l10n, eq.criticality!),
            ],

            // ── Garantie ──────────────────────────────────────────────
            if (eq.warrantyEndDate != null && eq.warrantyEndDate!.isNotEmpty)
              _buildWarrantyRow(l10n, eq),
          ],
        ),
      ),
    );
  }

  // ── Carte inventaire ─────────────────────────────────────────────────────────

  Widget _buildInventoryCard(AppLocalizations l10n, Equipment eq) {
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
            if (eq.manufacturer != null && eq.manufacturer!.isNotEmpty)
              DetailInfoRow(l10n.equipmentManufacturer, eq.manufacturer!,
                  onTap: _link(handlers.onManufacturer)),
            if (eq.model != null && eq.model!.isNotEmpty)
              DetailInfoRow(l10n.equipmentModel, eq.model!,
                  onTap: _link(handlers.onModel)),
            if (eq.manufYear != null)
              DetailInfoRow(
                  l10n.equipmentManufYear, eq.manufYear!.toString()),
            if (eq.installDate != null && eq.installDate!.isNotEmpty)
              DetailInfoRow(
                l10n.equipmentInstallDate,
                formatDetailDate(eq.installDate!),
              ),
          ],
        ),
      ),
    );
  }

  // ── Carte tags ───────────────────────────────────────────────────────────────

  Widget _buildTagsCard(AppLocalizations l10n, Equipment eq) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.label_outline,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.equipmentTags,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _buildCriticalityRow(
      AppLocalizations l10n, EquipmentCriticality c) {
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
          Tooltip(
            message: tooltip,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: color.withValues(alpha: 0.4)),
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
        ],
      ),
    );
  }

  Widget _buildWarrantyRow(AppLocalizations l10n, Equipment eq) {
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
        ],
      ),
    );
  }
}
