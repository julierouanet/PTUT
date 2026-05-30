import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../theme/app_theme.dart';

/// Dialogue QR Code — affiche l'identifiant de l'équipement sous forme
/// copiable dans le presse-papier.
///
/// Pour un vrai QR Code matriciel : ajouter `qr_flutter` dans pubspec.yaml
/// (https://pub.dev/packages/qr_flutter) et remplacer le placeholder visuel.
class EquipmentQrDialog extends StatelessWidget {
  final Equipment equipment;

  const EquipmentQrDialog({super.key, required this.equipment});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── En-tête ───────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.qr_code_2, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.equipDetailQrCodeTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.equipDetailQrCodeSubtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // ── Représentation visuelle + ID sélectionnable ───────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.border, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 80, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  SelectableText(
                    equipment.id,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Nom de l'équipement ───────────────────────────────────
            Text(
              equipment.name,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            // ── Bouton Copier ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: equipment.id));
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.equipDetailQrCodeCopied),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                },
                icon: const Icon(Icons.copy, size: 16),
                label: Text(l10n.equipDetailQrCodeCopy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
