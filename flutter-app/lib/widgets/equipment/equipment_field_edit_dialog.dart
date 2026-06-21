import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../services/data_service.dart';
import '../../services/db_api_service.dart';
import '../../theme/app_theme.dart';
import 'equipment_detail_helpers.dart';

/// Type de champ éditable inline sur la fiche équipement.
enum EquipmentFieldType { text, number, date, status, criticality }

/// Ouvre un mini-dialog ciblé pour éditer **un seul** champ d'un équipement.
///
/// Sauvegarde via `DbApiService.updateEquipment(id, {apiKey: valeur})` →
/// `PUT /api/equipment/:id` (partiel via COALESCE côté backend). En cas
/// d'erreur backend (ex. année hors 1900-2100 → 400), le message est affiché
/// dans le dialog **sans le fermer**. Retourne `true` si la sauvegarde a réussi
/// (l'appelant déclenche alors son rechargement).
Future<bool> showEquipmentFieldEditDialog({
  required BuildContext context,
  required Equipment equipment,
  required String apiKey,
  required String title,
  required EquipmentFieldType type,
  String? initialValue,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _EquipmentFieldEditDialog(
      equipment: equipment,
      apiKey: apiKey,
      title: title,
      type: type,
      initialValue: initialValue,
    ),
  );
  return result ?? false;
}

class _EquipmentFieldEditDialog extends StatefulWidget {
  final Equipment equipment;
  final String apiKey;
  final String title;
  final EquipmentFieldType type;
  final String? initialValue;

  const _EquipmentFieldEditDialog({
    required this.equipment,
    required this.apiKey,
    required this.title,
    required this.type,
    this.initialValue,
  });

  @override
  State<_EquipmentFieldEditDialog> createState() =>
      _EquipmentFieldEditDialogState();
}

class _EquipmentFieldEditDialogState extends State<_EquipmentFieldEditDialog> {
  late final TextEditingController _textController;

  // Valeurs sélectionnées pour les types non textuels.
  EquipmentStatus? _status;
  EquipmentCriticality? _criticality;
  String? _dateIso; // ISO YYYY-MM-DD

  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialValue ?? '');
    if (widget.type == EquipmentFieldType.status) {
      _status = widget.equipment.status;
    } else if (widget.type == EquipmentFieldType.criticality) {
      _criticality = widget.equipment.criticality;
    } else if (widget.type == EquipmentFieldType.date) {
      final iso = widget.initialValue ?? '';
      _dateIso = iso.length >= 10 ? iso.substring(0, 10) : null;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ── Construction du payload selon le type de champ ──────────────────────────
  Object? _buildValue() {
    switch (widget.type) {
      case EquipmentFieldType.text:
        return _textController.text.trim();
      case EquipmentFieldType.number:
        return _textController.text.trim();
      case EquipmentFieldType.date:
        return _dateIso ?? '';
      case EquipmentFieldType.status:
        return _status?.displayName;
      case EquipmentFieldType.criticality:
        return _criticality?.displayName;
    }
  }

  Future<void> _save(AppLocalizations l10n) async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await DbApiService.instance
          .updateEquipment(widget.equipment.id, {widget.apiKey: _buildValue()});
      await DataService().reloadEquipment();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      // Erreur métier (ex. 400 année invalide) : afficher sans fermer le dialog.
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = l10n.commonApiError;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField(l10n),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: _saving ? null : () => _save(l10n),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(l10n.commonSave),
        ),
      ],
    );
  }

  // ── Champ d'édition selon le type ───────────────────────────────────────────
  Widget _buildField(AppLocalizations l10n) {
    switch (widget.type) {
      case EquipmentFieldType.text:
        return TextField(
          controller: _textController,
          autofocus: true,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _save(l10n),
        );

      case EquipmentFieldType.number:
        return TextField(
          controller: _textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _save(l10n),
        );

      case EquipmentFieldType.date:
        return Row(
          children: [
            Expanded(
              child: Text(
                _dateIso != null
                    ? formatDetailDate(_dateIso!)
                    : l10n.equipFieldEditNoDate,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.calendar_month, size: 16),
              label: Text(l10n.commonEdit),
              onPressed: () async {
                final now = DateTime.now();
                final initial = _dateIso != null
                    ? DateTime.tryParse(_dateIso!) ?? now
                    : now;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(now.year - 50),
                  lastDate: DateTime(now.year + 50),
                );
                if (picked != null) {
                  setState(() =>
                      _dateIso = picked.toIso8601String().substring(0, 10));
                }
              },
            ),
          ],
        );

      case EquipmentFieldType.status:
        return DropdownButtonFormField<EquipmentStatus>(
          value: _status,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: EquipmentStatus.values
              .map((s) => DropdownMenuItem<EquipmentStatus>(
                    value: s,
                    child: Text(s.localizedName(l10n)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _status = v),
        );

      case EquipmentFieldType.criticality:
        return DropdownButtonFormField<EquipmentCriticality>(
          value: _criticality,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: EquipmentCriticality.values
              .map((c) => DropdownMenuItem<EquipmentCriticality>(
                    value: c,
                    child: Text(c.localizedLabel(l10n)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _criticality = v),
        );
    }
  }
}
