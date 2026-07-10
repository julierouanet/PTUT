import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Élément individuel de la checklist PM.
class PmChecklistItem {
  final int step;
  final String label;
  bool isDone;
  /// Commentaire optionnel saisi par le technicien au moment de la validation.
  String comment;
  /// Statut de conformité (significatif uniquement si [isDone] == true).
  bool passed;

  PmChecklistItem({
    required this.step,
    required this.label,
    this.isDone = false,
    this.comment = '',
    this.passed = true,
  });

  factory PmChecklistItem.fromJson(dynamic j) {
    if (j is String) {
      // Format legacy : tableau de chaînes (données de seed)
      return PmChecklistItem(step: 0, label: j);
    }
    final map = j as Map<String, dynamic>;
    return PmChecklistItem(
      step: map['step'] as int? ?? 0,
      label: (map['label'] as String?) ?? (map['text'] as String?) ?? '',
      isDone: map['done'] as bool? ?? false,
      comment: map['comment'] as String? ?? '',
      passed: map['passed'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'step': step,
        'label': label,
        'done': isDone,
        'comment': comment,
        'passed': passed,
      };
}

/// Widget checklist interactive pour la validation de maintenance préventive.
///
/// Affiche les étapes d'un protocole PM avec des cases à cocher.
/// Accessible en modification uniquement si [Permission.updateRepairs].
///
/// Utilisé depuis [EquipmentMaintenanceTab]. L'état est accessible via [GlobalKey<PmChecklistWidgetState>].
class PmChecklistWidget extends StatefulWidget {
  /// Liste brute des items depuis pm_protocols.checklist (strings ou maps).
  final List<dynamic> checklist;

  /// Nom du protocole PM (affiché en titre).
  final String? protocolName;

  /// Fréquence PM en mois (affiché sous le titre).
  final int? frequencyMonths;

  /// Durée estimée en heures.
  final double? estimatedDurationHours;

  /// Autorise la navigation vers la gestion des protocoles PM de la sous-catégorie.
  final bool canManage;

  /// Appelé quand l'utilisateur souhaite créer/gérer les protocoles PM.
  final VoidCallback? onManageProtocols;

  /// `false` si l'équipement n'a pas de sous-catégorie assignée — dans ce cas
  /// le bloc "aucun protocole" reste non cliquable même si [canManage] est vrai.
  final bool hasSubcategory;

  const PmChecklistWidget({
    super.key,
    required this.checklist,
    this.protocolName,
    this.frequencyMonths,
    this.estimatedDurationHours,
    this.canManage = false,
    this.onManageProtocols,
    this.hasSubcategory = true,
  });

  @override
  State<PmChecklistWidget> createState() => PmChecklistWidgetState();
}

class PmChecklistWidgetState extends State<PmChecklistWidget> {
  late List<PmChecklistItem> _items;

  bool get _canEdit =>
      AuthService().hasPermission(Permission.updateRepairs);

  @override
  void initState() {
    super.initState();
    _items = widget.checklist
        .asMap()
        .entries
        .map((e) {
          final item = PmChecklistItem.fromJson(e.value);
          // Si step non fourni, utiliser l'index 1-based
          if (item.step == 0) {
            return PmChecklistItem(
              step: e.key + 1,
              label: item.label,
              isDone: item.isDone,
            );
          }
          return item;
        })
        .toList();
  }

  /// Retourne la liste courante (lecture seule) — appelé par le parent via GlobalKey.
  List<PmChecklistItem> get items => List.unmodifiable(_items);

  /// Nombre d'étapes validées.
  int get doneCount => _items.where((i) => i.isDone).length;

  /// Nombre total d'étapes.
  int get totalCount => _items.length;

  void _toggle(int index) {
    if (!_canEdit) return;
    setState(() => _items[index].isDone = !_items[index].isDone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Cas : checklist vide ou protocole absent
    if (_items.isEmpty) {
      final clickable = widget.canManage &&
          widget.onManageProtocols != null &&
          widget.hasSubcategory;
      final card = Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pmNoProtocolAvailable,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    if (clickable) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.pmProtocolAdd,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ] else if (!widget.hasSubcategory) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.pmProtocolNoSubcategory,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      return clickable
          ? InkWell(onTap: widget.onManageProtocols, child: card)
          : card;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ──────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.checklist,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.protocolName ?? l10n.pmChecklist,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.frequencyMonths != null)
                        Text(
                          l10n.pmFrequencyValue(widget.frequencyMonths!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                // Compteur progression
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: doneCount == totalCount
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: doneCount == totalCount
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    l10n.pmStepsProgress(doneCount, totalCount),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: doneCount == totalCount
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                ),
                if (widget.canManage && widget.onManageProtocols != null)
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        size: 18, color: AppColors.textSecondary),
                    tooltip: l10n.pmProtocolEdit,
                    onPressed: widget.onManageProtocols,
                  ),
              ],
            ),

            // Durée estimée
            if (widget.estimatedDurationHours != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.pmDurationEstimated(
                    (widget.estimatedDurationHours! * 60).round()),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
              ),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),

            // ── Liste des étapes ──────────────────────────────────────
            ..._items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              return CheckboxListTile(
                value: item.isDone,
                enabled: _canEdit,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.success,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.step}. ${item.label}',
                        style: TextStyle(
                          fontSize: 13,
                          color: item.isDone
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          decoration: item.isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                    if (item.isDone && _canEdit)
                      IconButton(
                        icon: Icon(
                          item.passed ? Icons.check_circle : Icons.cancel,
                          size: 20,
                          color: item.passed ? AppColors.success : AppColors.error,
                        ),
                        onPressed: () =>
                            setState(() => item.passed = !item.passed),
                      ),
                  ],
                ),
                subtitle: _canEdit
                    ? TextFormField(
                        initialValue: item.comment,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: l10n.pmTaskCommentLabel,
                          hintText: l10n.pmTaskCommentHint,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => item.comment = v,
                      )
                    : (item.comment.isNotEmpty
                        ? Text(
                            item.comment,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                          )
                        : null),
                onChanged: _canEdit ? (_) => _toggle(i) : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}
