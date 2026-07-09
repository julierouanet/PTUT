import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/equipment.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import 'equipment_picker_field.dart';

/// Ouvre le dialogue de liaison/correction d'équipement d'un incident, appelle
/// `PATCH /api/issues/:id/link-equipment` et affiche le snackbar de résultat.
/// Réutilisé par `IssueDetailScreen` et `TechnicianInterventionUpdateScreen`
/// pour ne pas dupliquer ce flux (sélecteur + motif + appel API + feedback).
///
/// [isCorrection] doit être `true` quand un équipement est déjà lié (l'action
/// remplace un lien existant) : un champ motif obligatoire (>= 10 caractères)
/// apparaît alors, aligné sur le pattern de `PATCH /api/issues/:id/detach`.
/// [onLinked] n'est appelé qu'en cas de succès, avec l'équipement choisi, pour
/// que l'appelant mette à jour son état local (pas de round-trip réseau
/// supplémentaire : l'équipement sélectionné est déjà connu du client).
Future<void> showEquipmentLinkDialog({
  required BuildContext context,
  required String issueId,
  required bool isCorrection,
  required void Function(Equipment equipment) onLinked,
}) async {
  final l10n = AppLocalizations.of(context)!;
  Equipment? selected;
  final reasonController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String? equipmentError;

  final chosen = await showDialog<Equipment>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(isCorrection
            ? l10n.changeEquipmentDialogTitle
            : l10n.linkEquipmentDialogTitle),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EquipmentPickerField(
                  errorText: equipmentError,
                  onSelected: (eq) => setDialogState(() {
                    selected = eq;
                    equipmentError = null;
                  }),
                ),
                if (isCorrection) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: l10n.changeEquipmentReasonLabel),
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? l10n.changeEquipmentReasonTooShort
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              if (selected == null) {
                setDialogState(() => equipmentError = l10n.changeEquipmentPickRequired);
                return;
              }
              Navigator.pop(ctx, selected);
            },
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    ),
  );
  if (chosen == null || !context.mounted) return;

  final reason = isCorrection ? reasonController.text.trim() : null;
  try {
    await DbApiService.instance.linkEquipment(issueId, chosen.id, reason: reason);
    onLinked(chosen);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(reason != null ? l10n.changeEquipmentSuccess : l10n.linkEquipmentSuccess),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  } catch (e) {
    if (!context.mounted) return;
    final msg = e is ApiException ? e.message : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
