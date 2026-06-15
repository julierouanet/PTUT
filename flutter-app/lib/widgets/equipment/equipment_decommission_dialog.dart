import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';

/// Résultat de la saisie de réforme renvoyé par [showDecommissionDialog].
class DecommissionResult {
  final String reason;
  final String method;
  final String? notes;
  final String? replacedById;

  const DecommissionResult({
    required this.reason,
    required this.method,
    this.notes,
    this.replacedById,
  });
}

/// Motifs de réforme — DOIT rester aligné sur la whitelist serveur
/// `DECOMMISSION_REASONS` (db-service/src/routes/equipment.js).
const List<String> kDecommissionReasons = [
  'irreparable', 'obsolete', 'replaced', 'lost', 'donated_out',
];

/// Méthodes d'élimination — alignées sur `DISPOSAL_METHODS` serveur.
const List<String> kDisposalMethods = [
  'destroyed', 'sold', 'donated', 'returned', 'cannibalized',
];

String decommissionReasonLabel(AppLocalizations l10n, String value) => switch (value) {
      'irreparable' => l10n.decommissionReasonValueIrreparable,
      'obsolete'    => l10n.decommissionReasonValueObsolete,
      'replaced'    => l10n.decommissionReasonValueReplaced,
      'lost'        => l10n.decommissionReasonValueLost,
      'donated_out' => l10n.decommissionReasonValueDonatedOut,
      _             => value,
    };

String disposalMethodLabel(AppLocalizations l10n, String value) => switch (value) {
      'destroyed'    => l10n.decommissionMethodValueDestroyed,
      'sold'         => l10n.decommissionMethodValueSold,
      'donated'      => l10n.decommissionMethodValueDonated,
      'returned'     => l10n.decommissionMethodValueReturned,
      'cannibalized' => l10n.decommissionMethodValueCannibalized,
      _              => value,
    };

/// Ouvre le formulaire de réforme : dialog centré (≥800px) ou bottom-sheet
/// (<800px), cf. convention `issue_category_selector`. Renvoie null si annulé.
Future<DecommissionResult?> showDecommissionDialog(
  BuildContext context,
  Equipment equipment,
) {
  final isWide = MediaQuery.of(context).size.width >= 800;
  final form = _DecommissionForm(equipment: equipment);

  if (isWide) {
    return showDialog<DecommissionResult>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: form,
        ),
      ),
    );
  }
  return showModalBottomSheet<DecommissionResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: form,
    ),
  );
}

class _DecommissionForm extends StatefulWidget {
  final Equipment equipment;
  const _DecommissionForm({required this.equipment});

  @override
  State<_DecommissionForm> createState() => _DecommissionFormState();
}

class _DecommissionFormState extends State<_DecommissionForm> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  String? _reason;
  String? _method;
  String? _replacedById;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _needsReplacement => _reason == 'replaced';

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // Garde-fou : motif « remplacé » impose un remplaçant (miroir du backend).
    if (_needsReplacement && (_replacedById == null || _replacedById!.isEmpty)) {
      return;
    }
    Navigator.pop(
      context,
      DecommissionResult(
        reason: _reason!,
        method: _method!,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        replacedById: _needsReplacement ? _replacedById : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Remplaçants candidats : équipements actifs (Disposed déjà exclus du cache),
    // hors l'équipement en cours de réforme.
    final candidates = DataService()
        .equipment
        .where((e) => e.id != widget.equipment.id)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.delete_sweep_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.decommissionDialogTitle,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(l10n.decommissionDialogBody,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),

              // ── Motif de réforme (obligatoire) ──────────────────────────
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: InputDecoration(
                  labelText: l10n.decommissionReasonLabel,
                  border: const OutlineInputBorder(),
                ),
                items: kDecommissionReasons
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(decommissionReasonLabel(l10n, r)),
                        ))
                    .toList(),
                validator: (v) => v == null ? l10n.decommissionReasonLabel : null,
                onChanged: (v) => setState(() => _reason = v),
              ),
              const SizedBox(height: 12),

              // ── Méthode d'élimination (obligatoire) ─────────────────────
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: InputDecoration(
                  labelText: l10n.decommissionMethodLabel,
                  border: const OutlineInputBorder(),
                ),
                items: kDisposalMethods
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(disposalMethodLabel(l10n, m)),
                        ))
                    .toList(),
                validator: (v) => v == null ? l10n.decommissionMethodLabel : null,
                onChanged: (v) => setState(() => _method = v),
              ),

              // ── Remplaçant (visible et requis si motif = remplacé) ──────
              if (_needsReplacement) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _replacedById,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.decommissionReplacementLabel,
                    hintText: l10n.decommissionReplacementHint,
                    border: const OutlineInputBorder(),
                  ),
                  items: candidates
                      .map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  validator: (v) => (v == null || v.isEmpty)
                      ? l10n.decommissionReplacementRequired
                      : null,
                  onChanged: (v) => setState(() => _replacedById = v),
                ),
              ],
              const SizedBox(height: 12),

              // ── Notes libres (optionnel) ────────────────────────────────
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: l10n.decommissionNotesLabel,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
                maxLength: 1000,
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(l10n.decommissionConfirmButton),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
