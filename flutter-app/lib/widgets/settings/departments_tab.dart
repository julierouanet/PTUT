import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/db_api_service.dart';
import '../../theme/app_theme.dart';

class DepartmentsTab extends StatefulWidget {
  const DepartmentsTab({super.key});

  @override
  State<DepartmentsTab> createState() => _DepartmentsTabState();
}

class _DepartmentsTabState extends State<DepartmentsTab> {
  List<Map<String, dynamic>> _departments = [];
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
      final data = await DbApiService.instance.getDepartments();
      if (mounted) setState(() { _departments = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _departments;
    final q = _search.toLowerCase();
    return _departments.where((d) =>
      (d['name'] as String).toLowerCase().contains(q) ||
      ((d['description'] as String?) ?? '').toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // ── Barre d'action ─────────────────────────────────────────────
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
                onPressed: () => _showDialog(null),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.settingsNewDepartment),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Corps ──────────────────────────────────────────────────────
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
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
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(l10n.settingsEmptyList, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) => _buildTile(l10n, items[i]),
      ),
    );
  }

  Widget _buildTile(AppLocalizations l10n, Map<String, dynamic> dept) {
    final name = dept['name'] as String;
    final description = dept['description'] as String?;
    final equipCount = (dept['equipment_count'] as int?) ?? 0;
    final issueCount = (dept['open_issues_count'] as int?) ?? 0;

    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
        child: Center(
          child: Text(
            name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: description != null && description.isNotEmpty
          ? Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (equipCount > 0)
            _statBadge(l10n.settingsDeptStatsAssets(equipCount), AppColors.primaryLight, AppColors.primary),
          if (issueCount > 0) ...[
            const SizedBox(width: 4),
            _statBadge(l10n.settingsDeptStatsOt(issueCount), AppColors.warningLight, AppColors.warning),
          ],
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            color: AppColors.primary,
            onPressed: () => _showDialog(dept),
            tooltip: l10n.commonEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18),
            color: AppColors.error,
            onPressed: equipCount > 0
                ? null
                : () => _confirmDelete(l10n, dept),
            tooltip: equipCount > 0
                ? l10n.settingsDeptDeleteDisabledTooltip
                : l10n.commonDelete,
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
  );

  void _showDialog(Map<String, dynamic>? dept) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = dept != null;
    final nameCtrl = TextEditingController(text: dept?['name'] as String? ?? '');
    final descCtrl = TextEditingController(text: dept?['description'] as String? ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? l10n.settingsEditDepartment : l10n.settingsNewDepartment,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.settingsDepartmentName,
                  hintText: l10n.settingsDepartmentNameHint,
                  prefixIcon: const Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: l10n.settingsDeptDescription,
                  hintText: l10n.settingsDeptDescriptionHint,
                  prefixIcon: const Icon(Icons.notes),
                ),
                maxLines: 2,
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
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(l10n.commonFillAllFields),
                          backgroundColor: AppColors.error,
                        ));
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        final body = {
                          'name': nameCtrl.text.trim(),
                          if (descCtrl.text.trim().isNotEmpty) 'description': descCtrl.text.trim(),
                        };
                        if (isEdit) {
                          await DbApiService.instance.updateDepartment(dept['id'] as int, body);
                        } else {
                          await DbApiService.instance.createDepartment(body);
                        }
                        await _load();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isEdit ? l10n.settingsDepartmentModified : l10n.settingsDepartmentAdded),
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
                    child: Text(isEdit ? l10n.commonSave : l10n.commonAdd),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(AppLocalizations l10n, Map<String, dynamic> dept) async {
    final name = dept['name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsDeleteDepartment),
        content: Text(l10n.settingsDeptConfirmDelete(name)),
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
      await DbApiService.instance.deleteDepartment(dept['id'] as int);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.settingsDeleted(l10n.settingsDeleteDepartment)),
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
