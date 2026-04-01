import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/config_service.dart';
import '../services/data_service.dart';
import '../models/user_role.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ConfigService _configService = ConfigService();

  // État de l'onglet "Ordre du menu"
  UserRole _selectedRole = UserRole.admin;
  late Map<String, List<String>> _sidebarOrder;
  bool _sidebarSaving = false;

  /// Noms lisibles des types d'écrans
  static const Map<String, String> _screenLabels = {
    'dashboard':     'Tableau de bord',
    'equipment':     'Équipements',
    'issueTracking': 'Suivi incidents',
    'issueForm':     'Signaler incident',
    'technician':    'Technicien',
    'inventory':     'Inventaire',
    'reports':       'Rapports',
    'users':         'Utilisateurs',
    'settings':      'Paramètres',
    'logs':          'Journaux',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _configService.addListener(_onConfigChange);
    // Charger la config actuelle depuis DataService (déjà chargée au login)
    _sidebarOrder = Map.from(DataService().sidebarOrder);
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
              const Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.menu, size: 18),
                SizedBox(width: 8),
                Text('Ordre du menu'),
              ])),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildDepartmentsTab(), _buildCategoriesTab(), _buildSidebarOrderTab()],
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

  // ── Onglet : ordre du menu ─────────────────────────────────────────────────

  Widget _buildSidebarOrderTab() {
    // Ordre actuel pour le rôle sélectionné (ou ordre par défaut)
    final defaultOrder = ['dashboard', 'equipment', 'issueTracking', 'issueForm',
      'technician', 'inventory', 'reports', 'users', 'settings', 'logs'];
    final currentOrder = List<String>.from(
      _sidebarOrder[_selectedRole.name] ?? defaultOrder,
    );
    // Ajouter les items manquants à la fin
    for (final s in defaultOrder) {
      if (!currentOrder.contains(s)) currentOrder.add(s);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Sélecteur de rôle
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              const Text('Configurer pour le rôle :', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: const InputDecoration(isDense: true),
                  items: UserRole.values.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.displayName),
                  )).toList(),
                  onChanged: (r) { if (r != null) setState(() => _selectedRole = r); },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Faites glisser les éléments pour changer leur ordre dans la barre de navigation.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: currentOrder.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = currentOrder.removeAt(oldIndex);
                    currentOrder.insert(newIndex, item);
                    _sidebarOrder = Map.from(_sidebarOrder)..[_selectedRole.name] = List.from(currentOrder);
                  });
                },
                itemBuilder: (context, index) {
                  final screenType = currentOrder[index];
                  final label = _screenLabels[screenType] ?? screenType;
                  return ListTile(
                    key: ValueKey(screenType),
                    leading: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.drag_handle, color: AppColors.textSecondary),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _sidebarOrder = Map.from(_sidebarOrder)..remove(_selectedRole.name);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Ordre par défaut restauré (non encore sauvegardé)'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                icon: const Icon(Icons.restore),
                label: const Text('Réinitialiser'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _sidebarSaving ? null : () async {
                  setState(() => _sidebarSaving = true);
                  try {
                    final order = List<String>.from(
                      _sidebarOrder[_selectedRole.name] ?? ['dashboard', 'equipment', 'issueTracking', 'issueForm', 'technician', 'inventory', 'reports', 'users', 'settings', 'logs'],
                    );
                    await DataService().saveSidebarConfig(_selectedRole.name, order);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Ordre du menu sauvegardé'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Erreur : $e'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  } finally {
                    if (mounted) setState(() => _sidebarSaving = false);
                  }
                },
                icon: _sidebarSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: const Text('Sauvegarder'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
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
