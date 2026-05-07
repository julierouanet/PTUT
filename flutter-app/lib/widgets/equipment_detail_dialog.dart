import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/equipment.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';
import 'equipment_history_dialog.dart';

/// Dialogue de détail d'un équipement — affiche TOUS les champs de la table
/// `equipment` ainsi que les tags (table `equipment_tags`) et les
/// enregistrements de maintenance (passés et planifiés).
///
/// Sections :
///   - Identité (statut, nom, ID interne)
///   - Informations générales (département, catégorie, serial, location)
///   - Inventaire (fabricant, modèle, année, date d'installation)
///   - Tags d'inventaire
///   - Maintenance (prochaine révision, planifiée, historique)
///   - Informations système (created_at, updated_at)
class EquipmentDetailDialog extends StatelessWidget {
  final Equipment equipment;
  final VoidCallback? onEdit;
  final VoidCallback? onReport;

  const EquipmentDetailDialog({
    super.key,
    required this.equipment,
    this.onEdit,
    this.onReport,
  });

  static void show(
    BuildContext context,
    Equipment equipment, {
    VoidCallback? onEdit,
    VoidCallback? onReport,
  }) {
    showDialog(
      context: context,
      builder: (_) => EquipmentDetailDialog(
        equipment: equipment,
        onEdit: onEdit,
        onReport: onReport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final eq   = equipment;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── En-tête : nom + actions ─────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      eq.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onEdit!();
                          },
                          icon: const Icon(Icons.edit, color: AppColors.primary),
                          tooltip: l10n.commonEdit,
                        ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Statut ──────────────────────────────────────────────────
              Row(
                children: [
                  StatusBadge(status: eq.status.displayName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      eq.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Informations générales ──────────────────────────────────
              _buildSectionTitle(l10n.equipmentGeneralSection),
              _buildDetailRow(l10n.commonDepartment, eq.department),
              _buildDetailRow(l10n.commonCategory, eq.category),
              _buildDetailRow(l10n.equipmentSerialNumber, eq.serialNumber),
              if (eq.location.isNotEmpty)
                _buildDetailRow(l10n.equipmentLocation, eq.location),
              _buildDetailRow(l10n.equipmentInternalId, eq.id, mono: true),
              const SizedBox(height: 16),

              // ── Inventaire (champs XLSX 2025-2026) ──────────────────────
              if (_hasInventoryFields(eq)) ...[
                _buildSectionTitle(l10n.equipmentInventorySection),
                if (eq.manufacturer != null && eq.manufacturer!.isNotEmpty)
                  _buildDetailRow(l10n.equipmentManufacturer, eq.manufacturer!),
                if (eq.model != null && eq.model!.isNotEmpty)
                  _buildDetailRow(l10n.equipmentModel, eq.model!),
                if (eq.manufYear != null)
                  _buildDetailRow(l10n.equipmentManufYear, eq.manufYear!.toString()),
                if (eq.installDate != null && eq.installDate!.isNotEmpty)
                  _buildDetailRow(l10n.equipmentInstallDate, _formatDate(eq.installDate!)),
                const SizedBox(height: 16),
              ],

              // ── Tags d'inventaire ───────────────────────────────────────
              _buildSectionTitle(l10n.equipmentTags),
              if (eq.tags.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l10n.equipmentNoTags,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: eq.tags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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
                ),

              // ── Prochaine révision + maintenance planifiée ──────────────
              if (eq.nextRevisionDate != null && eq.nextRevisionDate!.isNotEmpty)
                _buildDetailRow(
                  l10n.equipmentNextRevision,
                  _formatDate(eq.nextRevisionDate!),
                  icon: Icons.event,
                  color: _revisionColor(eq.nextRevisionDate!),
                ),

              if (eq.futureMaintenance.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSectionTitle(l10n.equipmentFutureMaintenance),
                ...eq.futureMaintenance.map((m) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.schedule, color: AppColors.primary),
                      title: Text(m.intervention, style: const TextStyle(fontSize: 14)),
                      subtitle: Text('${_formatDate(m.date)} — ${m.technician}',
                          style: const TextStyle(fontSize: 12)),
                    )),
              ],

              // ── Historique de maintenance ───────────────────────────────
              if (eq.maintenanceHistory.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSectionTitle(l10n.equipmentMaintenanceHistory),
                ...eq.maintenanceHistory.map((m) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.build, color: AppColors.warning),
                      title: Text(m.intervention, style: const TextStyle(fontSize: 14)),
                      subtitle: Text('${_formatDate(m.date)} — ${m.technician}',
                          style: const TextStyle(fontSize: 12)),
                    )),
              ],

              // ── Informations système ────────────────────────────────────
              if (eq.createdAt != null || eq.updatedAt != null) ...[
                const SizedBox(height: 16),
                _buildSectionTitle(l10n.equipmentSystemInfoSection),
                if (eq.createdAt != null && eq.createdAt!.isNotEmpty)
                  _buildDetailRow(l10n.equipmentCreatedAt, _formatDateTime(eq.createdAt!)),
                if (eq.updatedAt != null && eq.updatedAt!.isNotEmpty)
                  _buildDetailRow(l10n.equipmentUpdatedAt, _formatDateTime(eq.updatedAt!)),
              ],

              const SizedBox(height: 24),

              // ── Boutons bas de page ─────────────────────────────────────
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => EquipmentHistoryDialog.show(context, eq),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('Historique'),
                  ),
                ),
                if (onReport != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onReport!();
                      },
                      icon: const Icon(Icons.report_problem_outlined, size: 16),
                      label: Text(l10n.equipmentReportProblem),
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _hasInventoryFields(Equipment eq) {
    return (eq.manufacturer != null && eq.manufacturer!.isNotEmpty) ||
        (eq.model != null && eq.model!.isNotEmpty) ||
        eq.manufYear != null ||
        (eq.installDate != null && eq.installDate!.isNotEmpty);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    IconData? icon,
    Color? color,
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: color ?? AppColors.textSecondary),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: color,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Formate une date ISO (`2025-12-31`) → `31/12/2025`
  String _formatDate(String iso) {
    if (iso.length < 10) return iso;
    final parts = iso.substring(0, 10).split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  /// Formate un timestamp (`2025-12-31 14:23:45`) → `31/12/2025 14:23`
  String _formatDateTime(String value) {
    final cleaned = value.replaceAll('T', ' ');
    if (cleaned.length < 10) return cleaned;
    final date = _formatDate(cleaned.substring(0, 10));
    if (cleaned.length >= 16) {
      return '$date ${cleaned.substring(11, 16)}';
    }
    return date;
  }

  /// Couleur selon la proximité de la date de révision
  Color _revisionColor(String iso) {
    try {
      final date = DateTime.parse(iso.substring(0, 10));
      final diff = date.difference(DateTime.now()).inDays;
      if (diff < 0) return AppColors.error;
      if (diff <= 30) return AppColors.warning;
      return AppColors.success;
    } catch (_) {
      return AppColors.textSecondary;
    }
  }
}
