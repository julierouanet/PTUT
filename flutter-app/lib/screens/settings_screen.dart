import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/config_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ConfigService _configService = ConfigService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _configService.addListener(_onConfigChange);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _configService.removeListener(_onConfigChange);
    super.dispose();
  }

  void _onConfigChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final hPad = isMobile ? 16.0 : 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ───────────────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.all(hPad),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settingsAdminSection, style: TextStyle(fontSize: isMobile ? 18 : 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text(l10n.settingsAdminSubtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),

        // ── Onglets départements / catégories ─────────────────────────────────
        Container(
          margin: EdgeInsets.symmetric(horizontal: hPad),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.all(4),
            tabs: [
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.business, size: 18),
                const SizedBox(width: 8),
                Text(l10n.settingsDepartmentsTab(_configService.departments.length)),
              ])),
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.category, size: 18),
                const SizedBox(width: 8),
                Text(l10n.settingsCategoriesTab(_configService.categories.length)),
              ])),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildDepartmentsTab(), _buildCategoriesTab()],
          ),
        ),
      ],
    );
  }

  // ── Onglets admin ──────────────────────────────────────────────────────────

  Widget _buildDepartmentsTab() {
    final l10n = AppLocalizations.of(context)!;
    final departments = _configService.departments;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showDepartmentDialog(null),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.settingsNewDepartment),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: departments.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final dept = departments[index];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                      child: Center(
                        child: Text(
                          dept.shortName.substring(0, dept.shortName.length > 2 ? 2 : dept.shortName.length),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    title: Text(dept.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${l10n.commonAbbreviation}: ${dept.shortName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dept.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                            child: Text(l10n.commonDefault, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          color: AppColors.primary,
                          onPressed: () => _showDepartmentDialog(dept),
                          tooltip: l10n.commonEdit,
                        ),
                        if (!dept.isDefault)
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            color: AppColors.error,
                            onPressed: () => _confirmDelete(l10n.settingsDeleteDepartment, dept.name, () {
                              _configService.deleteDepartment(dept.id);
                            }, isFeminine: false),
                            tooltip: l10n.commonDelete,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    final l10n = AppLocalizations.of(context)!;
    final categories = _configService.categories;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(null),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.settingsNewCategory),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.category, color: AppColors.success, size: 20),
                    ),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${l10n.commonAbbreviation}: ${cat.shortName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cat.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                            child: Text(l10n.commonDefault, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          color: AppColors.primary,
                          onPressed: () => _showCategoryDialog(cat),
                          tooltip: l10n.commonEdit,
                        ),
                        if (!cat.isDefault)
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            color: AppColors.error,
                            onPressed: () => _confirmDelete(l10n.settingsDeleteCategory, cat.name, () {
                              _configService.deleteCategory(cat.id);
                            }, isFeminine: true),
                            tooltip: l10n.commonDelete,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDepartmentDialog(DepartmentItem? dept) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = dept != null;
    final nameController      = TextEditingController(text: dept?.name ?? '');
    final shortNameController = TextEditingController(text: dept?.shortName ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  Text(isEdit ? l10n.settingsEditDepartment : l10n.settingsNewDepartment,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.settingsDepartmentName,
                  hintText: l10n.settingsDepartmentNameHint,
                  prefixIcon: const Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: shortNameController,
                decoration: InputDecoration(
                  labelText: l10n.settingsShortName,
                  hintText: l10n.settingsShortNameHint,
                  prefixIcon: const Icon(Icons.short_text),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isEmpty || shortNameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.commonFillAllFields), backgroundColor: AppColors.error),
                          );
                          return;
                        }
                        if (isEdit) {
                          _configService.updateDepartment(dept.id, nameController.text, shortNameController.text);
                        } else {
                          _configService.addDepartment(nameController.text, shortNameController.text);
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isEdit ? l10n.settingsDepartmentModified : l10n.settingsDepartmentAdded),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ));
                      },
                      child: Text(isEdit ? l10n.commonSave : l10n.commonAdd),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryDialog(CategoryItem? cat) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = cat != null;
    final nameController      = TextEditingController(text: cat?.name ?? '');
    final shortNameController = TextEditingController(text: cat?.shortName ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  Text(isEdit ? l10n.settingsEditCategory : l10n.settingsNewCategory,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.settingsCategoryName,
                  hintText: l10n.settingsCategoryNameHint,
                  prefixIcon: const Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: shortNameController,
                decoration: InputDecoration(
                  labelText: l10n.settingsShortName,
                  hintText: l10n.settingsCategoryShortHint,
                  prefixIcon: const Icon(Icons.short_text),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isEmpty || shortNameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.commonFillAllFields), backgroundColor: AppColors.error),
                          );
                          return;
                        }
                        if (isEdit) {
                          _configService.updateCategory(cat.id, nameController.text, shortNameController.text);
                        } else {
                          _configService.addCategory(nameController.text, shortNameController.text);
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isEdit ? l10n.settingsCategoryModified : l10n.settingsCategoryAdded),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ));
                      },
                      child: Text(isEdit ? l10n.commonSave : l10n.commonAdd),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String title, String name, VoidCallback onConfirm, {bool isFeminine = false}) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(l10n.settingsDeleteConfirm(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isFeminine ? l10n.settingsDeletedFeminine(title) : l10n.settingsDeleted(title)),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}
