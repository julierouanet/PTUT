import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/subcategory_detail_screen.dart';
import '../../services/db_api_service.dart';
import '../../theme/app_theme.dart';
import '../replacement_badge.dart';

class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  List<Map<String, dynamic>> _macroCategories = [];
  List<Map<String, dynamic>> _subCategories = [];
  bool _isLoading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final macro = await DbApiService.instance.getMacroCategories();
      final sub   = await DbApiService.instance.getSubCategories();
      if (mounted) setState(() {
        _macroCategories = macro;
        _subCategories   = sub;
        _isLoading       = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<Map<String, dynamic>> _subsForMacro(int macroId) {
    final items = _subCategories.where((s) => s['macro_category_id'] == macroId).toList();
    if (_search.isEmpty) return items;
    final q = _search.toLowerCase();
    return items.where((s) => (s['name'] as String).toLowerCase().contains(q)).toList();
  }

  Color _macroColor(String name) {
    switch (name.toLowerCase()) {
      case 'biomedical': return AppColors.error;
      case 'infrastructure': return AppColors.warning;
      case 'it': return AppColors.primary;
      default: return AppColors.textSecondary;
    }
  }

  String _macroLabel(AppLocalizations l10n, String name) {
    switch (name.toLowerCase()) {
      case 'biomedical': return l10n.settingsCatBiomedical;
      case 'infrastructure': return l10n.settingsCatInfrastructure;
      case 'it': return l10n.settingsCatIt;
      default: return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.commonSearch,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _macroCategories.isEmpty ? null : () => _showAddDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.settingsCatAddSub),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }

    return Card(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _macroCategories.length,
        itemBuilder: (context, i) {
          final macro = _macroCategories[i];
          final macroId = macro['id'] as int;
          final subs = _subsForMacro(macroId);
          final color = _macroColor(macro['name'] as String);

          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.category, color: color, size: 18),
              ),
              title: Row(
                children: [
                  Text(
                    _macroLabel(l10n, macro['name'] as String),
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_subCategories.where((s) => s['macro_category_id'] == macroId).length}',
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              children: [
                if (subs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(56, 4, 16, 12),
                    child: Text(
                      l10n.settingsEmptyList,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  )
                else
                  ...subs.map((sub) => _buildSubTile(
                      l10n, sub, color, macro['name'] as String)),
                const Divider(height: 1),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubTile(
      AppLocalizations l10n, Map<String, dynamic> sub, Color macroColor, String macroName) {
    final name = sub['name'] as String;
    final eqCount = (sub['equipment_count'] as int?) ?? 0;
    // Le plan de remplacement (RA3 S5) ne concerne que le biomédical.
    final isBiomedical = macroName.toLowerCase() == 'biomedical';
    final lifespan = sub['expected_lifespan_years'] as int?;

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(56, 0, 8, 0),
      leading: Container(
        width: 6, height: 6,
        decoration: BoxDecoration(color: macroColor, shape: BoxShape.circle),
      ),
      // Clic = page de détail de la sous-catégorie (toutes macro-catégories).
      // La section durée de vie / alertes reste réservée au biomédical via [isBiomedical].
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubcategoryDetailScreen(
            subcategoryId: sub['id'] as int,
            subcategoryName: name,
            expectedLifespanYears: lifespan,
            isBiomedical: isBiomedical,
          ),
        ),
      ).then((_) => _load()),
      title: Row(children: [
        Flexible(child: Text(name, style: const TextStyle(fontSize: 13))),
        // Triangle gris si durée de vie non définie (biomédical).
        if (isBiomedical && lifespan == null) ...[
          const SizedBox(width: 6),
          ReplacementBadge(
            status: 'donnee_manquante',
            tooltip: l10n.subcategoryLifespanUndefinedTooltip,
            size: 13,
          ),
        ],
      ]),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Durée de vie de référence (biomédical) — bouton éditable.
          if (isBiomedical)
            TextButton.icon(
              onPressed: () => _showLifespanDialog(l10n, sub),
              icon: const Icon(Icons.timelapse, size: 14),
              label: Text(
                lifespan == null ? '—' : '$lifespan ${l10n.subcategoryLifespanHint}',
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: lifespan == null
                    ? AppColors.replacementUnknown
                    : AppColors.primary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          if (eqCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
              child: Text(
                '$eqCount',
                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
            )
          else
            Tooltip(
              message: l10n.subcategoryEmptyTooltip,
              child: const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  void _showAddDialog() {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    int? selectedMacroId = _macroCategories.isNotEmpty ? _macroCategories.first['id'] as int : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.settingsCatAddSub, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.settingsCategoryName,
                    hintText: l10n.settingsCategoryNameHint,
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedMacroId,
                  decoration: InputDecoration(
                    labelText: l10n.settingsCatSelectMacro,
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: _macroCategories.map((m) => DropdownMenuItem<int>(
                    value: m['id'] as int,
                    child: Text(_macroLabel(l10n, m['name'] as String)),
                  )).toList(),
                  onChanged: (v) => setDialog(() => selectedMacroId = v),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.commonCancel),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty || selectedMacroId == null) return;
                        Navigator.pop(ctx);
                        try {
                          await DbApiService.instance.createSubCategory({
                            'name': nameCtrl.text.trim(),
                            'macro_category_id': selectedMacroId,
                          });
                          await _load();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(l10n.settingsCategoryAdded),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ));
                        } on ApiException catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(e.message),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                      child: Text(l10n.commonAdd),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dialogue de saisie de la durée de vie de référence (en années) — RA3 S5.
  /// Champ vide = durée non définie (null). Réservé admin côté serveur.
  void _showLifespanDialog(AppLocalizations l10n, Map<String, dynamic> sub) {
    final current = sub['expected_lifespan_years'] as int?;
    final ctrl = TextEditingController(text: current?.toString() ?? '');
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(l10n.subcategoryDetailLifespanSection),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sub['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.subcategoryLifespanLabel,
                  hintText: l10n.subcategoryLifespanHint,
                  prefixIcon: const Icon(Icons.timelapse),
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final raw = ctrl.text.trim();
                int? value;
                if (raw.isNotEmpty) {
                  final parsed = int.tryParse(raw);
                  if (parsed == null || parsed < 0) {
                    setDialog(() => errorText = l10n.subcategoryLifespanInvalid);
                    return;
                  }
                  value = parsed;
                }
                Navigator.pop(ctx);
                try {
                  await DbApiService.instance
                      .updateSubCategoryLifespan(sub['id'] as int, value);
                  await _load();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.subcategoryLifespanSaved),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ));
                } on ApiException catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.message),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }

}
