import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/db_api_service.dart';
import '../../theme/app_theme.dart';

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
              label: const Text('Réessayer'),
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
                  ...subs.map((sub) => _buildSubTile(l10n, sub, color)),
                const Divider(height: 1),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubTile(AppLocalizations l10n, Map<String, dynamic> sub, Color macroColor) {
    final name = sub['name'] as String;
    final eqCount = (sub['equipment_count'] as int?) ?? 0;

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(56, 0, 8, 0),
      leading: Container(
        width: 6, height: 6,
        decoration: BoxDecoration(color: macroColor, shape: BoxShape.circle),
      ),
      title: Text(name, style: const TextStyle(fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (eqCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
              child: Text(
                '$eqCount',
                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit, size: 16),
            color: AppColors.primary,
            onPressed: () => _showEditDialog(sub),
            tooltip: l10n.commonEdit,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 16),
            color: eqCount > 0 ? AppColors.textMuted : AppColors.error,
            onPressed: eqCount > 0 ? null : () => _confirmDeleteSub(l10n, sub),
            tooltip: eqCount > 0 ? l10n.settingsDeptDeleteDisabledTooltip : l10n.commonDelete,
            visualDensity: VisualDensity.compact,
          ),
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

  void _showEditDialog(Map<String, dynamic> sub) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: sub['name'] as String);
    int selectedMacroId = sub['macro_category_id'] as int;

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
                    Text(l10n.settingsEditCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.settingsCategoryName,
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
                  onChanged: (v) { if (v != null) setDialog(() => selectedMacroId = v); },
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
                        if (nameCtrl.text.trim().isEmpty) return;
                        Navigator.pop(ctx);
                        try {
                          await DbApiService.instance.updateSubCategory(sub['id'] as int, {
                            'name': nameCtrl.text.trim(),
                            'macro_category_id': selectedMacroId,
                          });
                          await _load();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(l10n.settingsCategoryModified),
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

  Future<void> _confirmDeleteSub(AppLocalizations l10n, Map<String, dynamic> sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsDeleteCategory),
        content: Text(l10n.settingsDeleteConfirm(sub['name'] as String)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DbApiService.instance.deleteSubCategory(sub['id'] as int);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.settingsDeletedFeminine(l10n.settingsDeleteCategory)),
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
  }
}
