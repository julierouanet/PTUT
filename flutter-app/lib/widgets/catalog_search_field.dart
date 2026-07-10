import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Entrée d'un référentiel simple {id, name} (fabricant ou modèle catalogue).
typedef CatalogEntry = Map<String, dynamic>;

/// Combo recherche + liste déroulante + création à la volée pour un
/// référentiel {id, name} (fabricant ou modèle catalogue). Remplace un
/// DropdownButtonFormField classique par un TextFormField filtrant : taper
/// filtre [items] par sous-chaîne (insensible à la casse) ; le focus seul
/// (champ vide) affiche la liste complète, comportement dropdown classique.
/// Si aucune correspondance exacte (insensible à la casse) n'existe pour la
/// saisie et que [onCreate] est fourni, une option "Ajouter « saisie » "
/// apparaît en bas de la liste.
class CatalogSearchField extends StatefulWidget {
  final String label;
  final List<CatalogEntry> items;
  final int? selectedId;
  final bool enabled;
  final String? disabledHint;
  final bool loading;
  final IconData icon;
  final ValueChanged<int?> onSelected;
  final Future<int> Function(String name)? onCreate;
  final String Function(String query) addOptionLabel;
  final String apiErrorLabel;

  const CatalogSearchField({
    super.key,
    required this.label,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    required this.addOptionLabel,
    required this.apiErrorLabel,
    this.enabled = true,
    this.disabledHint,
    this.loading = false,
    this.onCreate,
    this.icon = Icons.search,
  });

  @override
  State<CatalogSearchField> createState() => _CatalogSearchFieldState();
}

class _CatalogSearchFieldState extends State<CatalogSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _creating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _nameFor(widget.selectedId));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant CatalogSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      _controller.text = _nameFor(widget.selectedId);
    }
  }

  String _nameFor(int? id) {
    if (id == null) return '';
    final match = widget.items.where((i) => i['id'] == id);
    return match.isNotEmpty ? match.first['name'] as String : '';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<CatalogEntry> _filter(String query) {
    if (query.isEmpty) return widget.items;
    final q = query.toLowerCase();
    return widget.items
        .where((i) => (i['name'] as String).toLowerCase().contains(q))
        .toList();
  }

  bool _hasExactMatch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true; // pas d'option "Ajouter" pour une saisie vide
    return widget.items.any((i) => (i['name'] as String).toLowerCase() == q);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return TextFormField(
        enabled: false,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.disabledHint,
          prefixIcon: Icon(widget.icon),
          border: const OutlineInputBorder(),
        ),
      );
    }
    if (widget.loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RawAutocomplete<CatalogEntry>(
          textEditingController: _controller,
          focusNode: _focusNode,
          displayStringForOption: (option) => option['name'] as String,
          optionsBuilder: (value) => _filter(value.text),
          onSelected: (option) {
            setState(() => _errorMessage = null);
            widget.onSelected(option['id'] as int);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: widget.label,
                prefixIcon: Icon(widget.icon),
                suffixIcon: _creating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.arrow_drop_down),
                border: const OutlineInputBorder(),
              ),
            );
          },
          optionsViewBuilder: (context, onSelectedOption, options) {
            final query = _controller.text;
            final showAdd =
                widget.onCreate != null && !_creating && !_hasExactMatch(query);
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260, minWidth: 280),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final option in options)
                        ListTile(
                          dense: true,
                          title: Text(option['name'] as String),
                          onTap: () => onSelectedOption(option),
                        ),
                      if (showAdd)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.add_circle_outline,
                              color: AppColors.primary),
                          title: Text(
                            widget.addOptionLabel(query.trim()),
                            style: const TextStyle(color: AppColors.primary),
                          ),
                          onTap: () async {
                            setState(() {
                              _creating = true;
                              _errorMessage = null;
                            });
                            try {
                              final newId = await widget.onCreate!(query.trim());
                              onSelectedOption({'id': newId, 'name': query.trim()});
                            } catch (_) {
                              if (mounted) {
                                setState(() => _errorMessage = widget.apiErrorLabel);
                              }
                            } finally {
                              if (mounted) setState(() => _creating = false);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ),
      ],
    );
  }
}
