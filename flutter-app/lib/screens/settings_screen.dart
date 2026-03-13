import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/config_service.dart';

/// Settings screen for managing departments and categories (Admin only)
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

  void _onConfigChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paramètres',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Gérer les départements et catégories d\'équipements',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.business, size: 18),
                      const SizedBox(width: 8),
                      Text('Départements (${_configService.departments.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.category, size: 18),
                      const SizedBox(width: 8),
                      Text('Catégories (${_configService.categories.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDepartmentsTab(),
                _buildCategoriesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentsTab() {
    final departments = _configService.departments;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Add button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showDepartmentDialog(null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau département'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // List
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
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          dept.shortName.substring(0, dept.shortName.length > 2 ? 2 : dept.shortName.length),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    title: Text(dept.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('Abréviation: ${dept.shortName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dept.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Par défaut', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          color: AppColors.primary,
                          onPressed: () => _showDepartmentDialog(dept),
                          tooltip: 'Modifier',
                        ),
                        if (!dept.isDefault)
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            color: AppColors.error,
                            onPressed: () => _confirmDelete('département', dept.name, () {
                              _configService.deleteDepartment(dept.id);
                            }),
                            tooltip: 'Supprimer',
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
    final categories = _configService.categories;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Add button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouvelle catégorie'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // List
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
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.category, color: AppColors.success, size: 20),
                    ),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('Abréviation: ${cat.shortName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cat.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Par défaut', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          color: AppColors.primary,
                          onPressed: () => _showCategoryDialog(cat),
                          tooltip: 'Modifier',
                        ),
                        if (!cat.isDefault)
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            color: AppColors.error,
                            onPressed: () => _confirmDelete('catégorie', cat.name, () {
                              _configService.deleteCategory(cat.id);
                            }),
                            tooltip: 'Supprimer',
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
    final isEdit = dept != null;
    final nameController = TextEditingController(text: dept?.name ?? '');
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
                  Text(
                    isEdit ? 'Modifier département' : 'Nouveau département',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du département',
                  hintText: 'Ex: Cardiologie',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: shortNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom abrégé',
                  hintText: 'Ex: Cardio',
                  prefixIcon: Icon(Icons.short_text),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isEmpty || shortNameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Veuillez remplir tous les champs'), backgroundColor: AppColors.error),
                          );
                          return;
                        }
                        if (isEdit) {
                          _configService.updateDepartment(dept.id, nameController.text, shortNameController.text);
                        } else {
                          _configService.addDepartment(nameController.text, shortNameController.text);
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEdit ? 'Département modifié' : 'Département ajouté'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
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
    final isEdit = cat != null;
    final nameController = TextEditingController(text: cat?.name ?? '');
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
                  Text(
                    isEdit ? 'Modifier catégorie' : 'Nouvelle catégorie',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la catégorie',
                  hintText: 'Ex: Équipement radiologique',
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: shortNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom abrégé',
                  hintText: 'Ex: Radio',
                  prefixIcon: Icon(Icons.short_text),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isEmpty || shortNameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Veuillez remplir tous les champs'), backgroundColor: AppColors.error),
                          );
                          return;
                        }
                        if (isEdit) {
                          _configService.updateCategory(cat.id, nameController.text, shortNameController.text);
                        } else {
                          _configService.addCategory(nameController.text, shortNameController.text);
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEdit ? 'Catégorie modifiée' : 'Catégorie ajoutée'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
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

  void _confirmDelete(String type, String name, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer $type'),
        content: Text('Êtes-vous sûr de vouloir supprimer "$name" ?\n\nCette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$type supprimé${type == 'catégorie' ? 'e' : ''}'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
