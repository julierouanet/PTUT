import 'package:flutter/material.dart';
import '../../models/equipment.dart';
import '../../models/issue.dart';
import '../../theme/app_theme.dart';

/// Statuts considérés comme actifs (incidents non encore résolus)
const Set<IssueStatus> kActiveIssueStatuses = {
  IssueStatus.reported,
  IssueStatus.acknowledged,
  IssueStatus.assigned,
  IssueStatus.inProgress,
  IssueStatus.waitingMaterials,
};

/// Statuts résolus — utilisés pour le calcul du MTTR
const Set<IssueStatus> kResolvedIssueStatuses = {
  IssueStatus.completed,
  IssueStatus.verified,
  IssueStatus.closed,
};

/// Formate une date ISO YYYY-MM-DD → DD/MM/YYYY
String formatDetailDate(String iso) {
  if (iso.length < 10) return iso;
  final parts = iso.substring(0, 10).split('-');
  if (parts.length != 3) return iso;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

/// Formate un horodatage (ISO avec T ou espace) → DD/MM/YYYY
String formatDetailDateShort(String value) {
  return formatDetailDate(value.replaceAll('T', ' '));
}

/// Couleur de la prochaine révision selon l'échéance
Color revisionColor(String iso) {
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

/// Couleur selon le niveau d'alerte de maintenance préventive
Color preventiveColor(String? level) {
  switch (level) {
    case 'due':
      return AppColors.error;
    case 'soon':
      return AppColors.warning;
    case 'ok':
      return AppColors.success;
    default:
      return AppColors.textSecondary;
  }
}

/// Vérifie si l'équipement a au moins un champ inventaire renseigné
bool hasInventoryFields(Equipment eq) {
  return (eq.manufacturer != null && eq.manufacturer!.isNotEmpty) ||
      (eq.model != null && eq.model!.isNotEmpty) ||
      eq.manufYear != null ||
      (eq.installDate != null && eq.installDate!.isNotEmpty);
}

/// Calcule le MTTR en jours depuis les incidents résolus (estimation grossière).
///
/// Approximation : durée entre [createdAt] et aujourd'hui pour les incidents
/// dont le statut est completed / verified / closed. Un suivi précis nécessiterait
/// un champ [resolved_at] côté API.
int? computeMttr(List<Issue> issues) {
  final resolved =
      issues.where((i) => kResolvedIssueStatuses.contains(i.status)).toList();
  if (resolved.isEmpty) return null;

  int totalDays = 0;
  int count = 0;
  for (final issue in resolved) {
    try {
      final created =
          DateTime.parse(issue.createdAt.replaceAll(' ', 'T'));
      final days = DateTime.now().difference(created).inDays;
      if (days >= 0) {
        totalDays += days;
        count++;
      }
    } catch (_) {}
  }
  if (count == 0) return null;
  return (totalDays / count).round();
}

// ── Widgets partagés ──────────────────────────────────────────────────────────

/// Ligne label / valeur standard du détail équipement
class DetailInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final bool mono;

  const DetailInfoRow(
    this.label,
    this.value, {
    super.key,
    this.icon,
    this.color,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
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
                  Icon(icon, size: 13,
                      color: color ?? AppColors.textSecondary),
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
}

/// Titre de section en majuscules espacées
class DetailSectionTitle extends StatelessWidget {
  final String title;

  const DetailSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
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
}
