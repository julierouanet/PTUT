import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../theme/app_theme.dart';

/// Bannière rouge vibrante affichée uniquement quand l'équipement est
/// critique (criticité A) ET hors service simultanément.
class EquipmentCriticalBanner extends StatelessWidget {
  final Equipment equipment;

  const EquipmentCriticalBanner({super.key, required this.equipment});

  bool get _shouldShow =>
      equipment.criticality == EquipmentCriticality.a &&
      equipment.status == EquipmentStatus.outOfService;

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.critical,
      child: Row(
        children: [
          const Icon(Icons.crisis_alert, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.equipDetailCriticalBanner,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
