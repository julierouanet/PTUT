import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import 'equipment_detail_screen.dart';

/// Helpers partagés entre les fiches de détail (sous-catégorie, catégorie,
/// département, fabricant, modèle) pour éviter la duplication des briques UI
/// récurrentes (en-tête de section, carte « vide », liste d'équipements).

// Formateur de date partagé, construit une seule fois (la construction d'un
// DateFormat parse le motif — coûteux à répéter par ligne de liste).
final DateFormat _detailDateFmt = DateFormat('dd/MM/yyyy');

/// Formate une date ISO en `dd/MM/yyyy` (locale). Null si absente/invalide.
String? detailFormatDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return _detailDateFmt.format(DateTime.parse(raw).toLocal());
  } catch (_) {
    return null;
  }
}

/// En-tête de section : icône primaire + libellé.
Widget detailSectionHeader(IconData icon, String label) => Row(children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ]);

/// Carte affichée quand une liste est vide.
Widget detailEmptyCard(String message) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ),
    );

/// Liste d'équipements en carte : chaque tuile ouvre [EquipmentDetailScreen].
///
/// [subtitleKey] : clé optionnelle de la map à afficher en sous-titre (ex.
/// 'department' ou 'category'). Tuile non cliquable si l'id est absent.
Widget detailEquipmentTileList(
  BuildContext context,
  List<Map<String, dynamic>> equipment, {
  required String emptyLabel,
  String? subtitleKey,
}) {
  if (equipment.isEmpty) return detailEmptyCard(emptyLabel);
  return Card(
    child: Column(
      children: equipment.map((e) {
        final status = e['status'] as String? ?? '';
        final id = e['id'] as String? ?? '';
        final subtitle = subtitleKey == null ? null : e[subtitleKey] as String?;
        return ListTile(
          dense: true,
          leading: const Icon(Icons.inventory_2_outlined,
              size: 18, color: AppColors.textSecondary),
          title: Text(e['name'] as String? ?? '—', style: const TextStyle(fontSize: 14)),
          subtitle: (subtitle?.isNotEmpty == true)
              ? Text(subtitle!, style: const TextStyle(fontSize: 12))
              : null,
          trailing: status.isEmpty ? null : StatusBadge(status: status, isCompact: true),
          onTap: id.isEmpty
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EquipmentDetailScreen(equipmentId: id),
                    ),
                  ),
        );
      }).toList(),
    ),
  );
}
