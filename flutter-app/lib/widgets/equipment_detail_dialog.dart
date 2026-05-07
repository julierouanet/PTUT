import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/equipment.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';
import 'equipment_history_dialog.dart';

/// Dialogue de détail d'un équipement — widget réutilisable.
///
/// Appelable depuis n'importe quel écran :
/// ```dart
/// showDialog(context: context,
///   builder: (_) => EquipmentDetailDialog(equipment: eq));
/// ```
/// [onEdit]      → bouton ✏️ (optionnel, rôle admin/supervisor)
/// [onReport]    → bouton "Signaler un problème" (optionnel)
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

  /// Helper statique pour ouvrir facilement la dialog
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
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── En-tête ──────────────────────────────────────────────────
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
              const SizedBox(height: 16),

              // ── Statut ───────────────────────────────────────────────────
              StatusBadge(status: eq.status.displayName),
              const SizedBox(height: 24),

              // ── Informations générales ───────────────────────────────────
              _buildDetailRow(l10n.commonDepartment, eq.department),
              _buildDetailRow(l10n.commonCategory, eq.category),
              _buildDetailRow(l10n.equipmentSerialNumber, eq.serialNumber),
              if (eq.manufacturer != null && eq.manufacturer!.isNotEmpty)
                _buildDetailRow(l10n.equipmentManufacturer, eq.manufacturer!),
              if (eq.model != null && eq.model!.isNotEmpty)
                _buildDetailRow(l10n.equipmentModel, eq.model!),
              if (eq.manufYear != null)
                _buildDetailRow(l10n.equipmentManufYear, eq.manufYear!.toString()),
              if (eq.installDate != null && eq.installDate!.isNotEmpty)
                _buildDetailRow(l10n.equipmentInstallDate, _formatDate(eq.installDate!)),
              _buildDetailRow(l10n.equipmentSupplier, eq.supplier),
              _buildDetailRow(l10n.equipmentLocation, eq.location),
              if (eq.nextRevisionDate != null && eq.nextRevisionDate!.isNotEmpty)
                _buildDetailRow(
                  'Prochaine révision',
                  _formatDate(eq.nextRevisionDate!),
                  icon: Icons.event,
                  color: _revisionColor(eq.nextRevisionDate!),
                ),
              const SizedBox(height: 24),

              // ── Historique de maintenance ────────────────────────────────
              if (eq.maintenanceHistory.isNotEmpty) ...[
                Text(
                  l10n.equipmentMaintenanceHistory,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...eq.maintenanceHistory.map((m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.build, color: AppColors.warning),
                  title: Text(m.intervention),
                  subtitle: Text('${m.date} — ${m.technician}'),
                )),
                const SizedBox(height: 8),
              ],

              // ── Boutons bas de page ──────────────────────────────────────
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

  Widget _buildDetailRow(
    String label,
    String value, {
    IconData? icon,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: color ?? AppColors.textSecondary),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: AppColors.textSecondary),
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
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Formate une date ISO (2025-12-31) → "31/12/2025"
  String _formatDate(String iso) {
    if (iso.length < 10) return iso;
    final parts = iso.substring(0, 10).split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  /// Couleur selon la proximité de la date de révision
  Color _revisionColor(String iso) {
    try {
      final date = DateTime.parse(iso.substring(0, 10));
      final diff = date.difference(DateTime.now()).inDays;
      if (diff < 0) return AppColors.error;     // dépassée
      if (diff <= 30) return AppColors.warning;  // dans moins d'un mois
      return AppColors.success;                  // ok
    } catch (_) {
      return AppColors.textSecondary;
    }
  }
}
