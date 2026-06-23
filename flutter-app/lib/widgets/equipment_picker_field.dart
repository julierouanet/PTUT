import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/equipment.dart';
import '../services/data_service.dart';

/// Champ de recherche/sélection d'équipement, extrait de [IssueFormScreen]
/// (sélecteur "Biomédical" original) pour être réutilisé tel quel dans
/// d'autres écrans (ex. liaison tardive d'un incident à un équipement).
///
/// Par défaut, recherche sur tout le catalogue ([DataService().equipment]),
/// sans filtre de catégorie. Passer [equipmentList] pour restreindre la
/// recherche (ex. usage historique filtré par catégorie biomédicale).
class EquipmentPickerField extends StatelessWidget {
  final ValueChanged<Equipment> onSelected;
  final List<Equipment>? equipmentList;
  final String? selectedEquipmentId;
  final VoidCallback? onClear;
  final String? hintText;
  final String? errorText;

  const EquipmentPickerField({
    super.key,
    required this.onSelected,
    this.equipmentList,
    this.selectedEquipmentId,
    this.onClear,
    this.hintText,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final list = equipmentList ?? DataService().equipment;

    return Autocomplete<Equipment>(
      displayStringForOption: (eq) => '${eq.name} - SN: ${eq.serialNumber}',
      optionsBuilder: (TextEditingValue value) {
        final query = value.text.toLowerCase().trim();
        if (query.isEmpty) {
          return const Iterable<Equipment>.empty();
        }
        return list.where((eq) =>
            eq.name.toLowerCase().contains(query) ||
            eq.serialNumber.toLowerCase().contains(query));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          onSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            hintText: hintText ?? l10n.issueFormSelectEquipment,
            prefixIcon:
                const Icon(Icons.search, color: AppColors.textSecondary),
            suffixIcon: selectedEquipmentId != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      textController.clear();
                      onClear?.call();
                    },
                  )
                : null,
            errorText: errorText,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final eq = options.elementAt(index);
                return ListTile(
                  dense: true,
                  leading:
                      const Icon(Icons.medical_services_outlined, size: 20),
                  title: Text(eq.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    'SN: ${eq.serialNumber} • ${eq.department}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: () => onSelected(eq),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
