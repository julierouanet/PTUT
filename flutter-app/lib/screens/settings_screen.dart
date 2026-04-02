import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/auth_api_service.dart';
import '../services/config_service.dart';
import '../services/data_service.dart';
import '../models/user_role.dart';

class _RoleConfig {
  final String name;
  final String displayName;
  final String description;
  final bool isBuiltin;
  final List<String> permissions;
  const _RoleConfig({required this.name, required this.displayName, required this.description, required this.isBuiltin, required this.permissions});
  factory _RoleConfig.fromJson(Map<String, dynamic> j) => _RoleConfig(
    name: j['name'] as String,
    displayName: j['display_name'] as String,
    description: j['description'] as String? ?? '',
    isBuiltin: (j['is_builtin'] as int? ?? 0) == 1,
    permissions: (j['permissions'] as List?)?.cast<String>() ?? [],
  );
}

const List<MapEntry<String, String>> _kAllPermissions = [
  MapEntry('viewEquipment',     'Consulter les équipements'),
  MapEntry('reportIssue',       'Signaler un problème'),
  MapEntry('trackIssues',       'Suivre les demandes'),
  MapEntry('approveRequests',   'Approuver les demandes'),
  MapEntry('assignTasks',       'Assigner les tâches'),
  MapEntry('updateRepairs',     'Mettre à jour les réparations'),
  MapEntry('registerParts',     'Enregistrer les pièces'),
  MapEntry('manageEquipment',   'Gérer les équipements'),
  MapEntry('manageUsers',       'Gérer les utilisateurs'),
  MapEntry('manageDepartments', 'Gérer les départements'),
  MapEntry('manageCategories',  'Gérer les catégories'),
  MapEntry('generateReports',   'Générer des rapports'),
  MapEntry('viewInventory',     'Consulter l\'inventaire'),
];

// Définition d'une page : label, icône, permissions associées
class _PageDef {
  final String label;
  final IconData icon;
  final List<Permission> permissions;
  const _PageDef(this.label, this.icon, this.permissions);
}

const Map<String, _PageDef> _pageDefs = {
  'dashboard':     _PageDef('Tableau de bord',  Icons.dashboard_outlined,        [Permission.viewEquipment]),
  'equipment':     _PageDef('Équipements',        Icons.inventory_2_outlined,     [Permission.viewEquipment, Permission.manageEquipment]),
  'issueTracking': _PageDef('Suivi incidents',    Icons.troubleshoot_outlined,    [Permission.trackIssues, Permission.approveRequests, Permission.assignTasks]),
  'issueForm':     _PageDef('Signaler incident',  Icons.report_problem_outlined,  [Permission.reportIssue]),
  'technician':    _PageDef('Technicien',          Icons.build_outlined,           [Permission.updateRepairs, Permission.registerParts]),
  'inventory':     _PageDef('Inventaire',          Icons.inventory_outlined,       [Permission.viewInventory]),
  'reports':       _PageDef('Rapports',            Icons.analytics_outlined,       [Permission.generateReports]),
  'users':         _PageDef('Utilisateurs',        Icons.people_outlined,          [Permission.manageUsers]),
  'settings':      _PageDef('Paramètres',          Icons.settings_outlined,        [Permission.manageDepartments, Permission.manageCategories]),
  'logs':          _PageDef('Journaux',            Icons.history_outlined,         [Permission.manageUsers]),
};

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

  // État de l'onglet "Gestion des rôles" — accès aux pages
  UserRole _roleTabRole = UserRole.admin;
  late Map<String, Map<String, bool>> _pagesEnabled;
  late Map<String, Map<String, bool>> _permissionsEnabled;
  bool _roleSaving = false;

  // État de l'onglet "Gestion des rôles" — cards de rôles
  List<_RoleConfig> _roles = [];
  bool _rolesLoading = false;

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
    _tabController = TabController(length: 4, vsync: this);
    _configService.addListener(_onConfigChange);
    _loadRoles();
    // Charger la config actuelle depuis DataService (déjà chargée au login)
    _sidebarOrder = Map.from(DataService().sidebarOrder);

    // Initialiser les accès pages et fonctions depuis les valeurs par défaut
    const allScreens = ['dashboard', 'equipment', 'issueTracking', 'issueForm',
      'technician', 'inventory', 'reports', 'users', 'settings', 'logs'];
    _pagesEnabled = {};
    _permissionsEnabled = {};
    for (final role in UserRole.values) {
      final order = DataService().sidebarOrder[role.name];
      _pagesEnabled[role.name] = {
        for (final s in allScreens)
          s: order == null ? true : order.contains(s),
      };
      final rolePerms = getPermissionsForRole(role).map((p) => p.name).toSet();
      _permissionsEnabled[role.name] = {
        for (final p in Permission.values)
          p.name: rolePerms.contains(p.name),
      };
    }
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
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.menu, size: 18),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.settingsMenuOrder),
              ])),
              const Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.admin_panel_settings, size: 18),
                SizedBox(width: 8),
                Text('Gestion des rôles'),
              ])),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildDepartmentsTab(), _buildCategoriesTab(), _buildSidebarOrderTab(), _buildRoleManagementTab()],
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

  Future<void> _loadRoles() async {
    setState(() => _rolesLoading = true);
    try {
      final raw = await AuthApiService.instance.getRoles();
      setState(() {
        _roles = raw.map((j) => _RoleConfig.fromJson(j)).toList();
        _rolesLoading = false;
      });
    } catch (_) {
      setState(() => _rolesLoading = false);
    }
  }

  // ── Onglet : ordre du menu ─────────────────────────────────────────────────

  Widget _buildSidebarOrderTab() {
    final l10n = AppLocalizations.of(context)!;
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
              Text(l10n.settingsMenuOrderRole, style: const TextStyle(fontWeight: FontWeight.w500)),
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
          Text(
            l10n.settingsMenuOrderHint,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.settingsMenuOrderResetDone),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                icon: const Icon(Icons.restore),
                label: Text(l10n.settingsMenuOrderReset),
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
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l10n.settingsMenuOrderSaved),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l10n.commonSaveError),
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
                label: Text(l10n.settingsMenuOrderSave),
              ),
            ),
          ]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Onglet : gestion des rôles ────────────────────────────────────────────

  Widget _buildRoleManagementTab() {
    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRolesSection(),
            const SizedBox(height: 28),
            _buildPageAccessSection(),
          ],
        ),
      ),
    );
  }

  // ── Section 1 : cartes de rôles ───────────────────────────────────────────

  Widget _buildRolesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Rôles et permissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              SizedBox(height: 2),
              Text('Modifier les permissions ou créer un rôle personnalisé', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
            ElevatedButton.icon(
              onPressed: _showCreateRoleDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouveau rôle'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppColors.primary, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Les permissions de l\'Administrateur sont verrouillées — il a toujours accès à tout. Les rôles personnalisés peuvent être supprimés.',
              style: TextStyle(fontSize: 12, color: AppColors.primary),
            )),
          ]),
        ),
        const SizedBox(height: 12),
        if (_rolesLoading)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (_roles.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Aucun rôle chargé.', style: TextStyle(color: AppColors.textSecondary)),
          ))
        else
          ..._roles.map((role) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildRoleCard(role),
          )),
      ],
    );
  }

  Widget _buildRoleCard(_RoleConfig role) {
    final color = _roleColor(role.name);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(role.isBuiltin ? Icons.lock_outline : Icons.badge_outlined, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(role.displayName, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
              if (!role.isBuiltin) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Personnalisé', style: TextStyle(fontSize: 11, color: AppColors.warning)),
                ),
              ],
              const Spacer(),
              if (role.name == 'admin')
                Tooltip(
                  message: 'L\'administrateur a toujours toutes les permissions',
                  child: TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.lock, size: 16),
                    label: const Text('Verrouillé'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => _showEditPermissionsDialog(role),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modifier'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              if (!role.isBuiltin)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.error,
                  tooltip: 'Supprimer',
                  onPressed: () => _confirmDeleteRole(role),
                ),
            ]),
            if (role.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(role.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
            const SizedBox(height: 10),
            const Text('Permissions actives :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            role.permissions.isEmpty
                ? const Text('Aucune permission', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
                : Wrap(
                    spacing: 6, runSpacing: 6,
                    children: role.permissions.map((p) {
                      final label = _kAllPermissions.where((e) => e.key == p).firstOrNull?.value ?? p;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(10)),
                        child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  void _showCreateRoleDialog() {
    final nameCtrl    = TextEditingController();
    final displayCtrl = TextEditingController();
    final descCtrl    = TextEditingController();
    final selectedPerms = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                  decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                  child: Row(children: [
                    const Icon(Icons.badge_outlined, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Nouveau rôle personnalisé', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ]),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Identifiant (ex: nurse)', helperText: 'Lettres, chiffres, underscores', prefixIcon: Icon(Icons.code))),
                      const SizedBox(height: 12),
                      TextField(controller: displayCtrl, decoration: const InputDecoration(labelText: 'Nom affiché (ex: Infirmier)', prefixIcon: Icon(Icons.label_outline))),
                      const SizedBox(height: 12),
                      TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optionnel)', prefixIcon: Icon(Icons.notes))),
                      const SizedBox(height: 16),
                      const Text('Permissions', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ..._kAllPermissions.map((perm) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selectedPerms.contains(perm.key),
                        title: Text(perm.value, style: const TextStyle(fontSize: 13)),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => setDialog(() { if (v == true) selectedPerms.add(perm.key); else selectedPerms.remove(perm.key); }),
                      )),
                      const SizedBox(height: 8),
                    ]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler'))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty || displayCtrl.text.trim().isEmpty) return;
                        try {
                          await AuthApiService.instance.createRole({'name': nameCtrl.text.trim(), 'display_name': displayCtrl.text.trim(), 'description': descCtrl.text.trim(), 'permissions': selectedPerms.toList()});
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadRoles();
                          await DataService().reloadRolesConfig();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rôle créé'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
                        } catch (_) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la création'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
                        }
                      },
                      child: const Text('Créer'),
                    )),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPermissionsDialog(_RoleConfig role) {
    // L'admin est verrouillé — on n'ouvre pas le dialog
    if (role.name == 'admin') return;

    final currentPerms = Set<String>.from(role.permissions);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                  decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                  child: Row(children: [
                    const Icon(Icons.tune, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Permissions — ${role.displayName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (role.isBuiltin) const Text('Rôle intégré', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ])),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Row(children: [
                    TextButton.icon(onPressed: () => setDialog(() => currentPerms.addAll(_kAllPermissions.map((e) => e.key))), icon: const Icon(Icons.select_all, size: 16), label: const Text('Tout sélectionner', style: TextStyle(fontSize: 12))),
                    TextButton.icon(onPressed: () => setDialog(() => currentPerms.clear()), icon: const Icon(Icons.deselect, size: 16), label: const Text('Tout désélectionner', style: TextStyle(fontSize: 12))),
                  ]),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(
                      children: _kAllPermissions.map((perm) => CheckboxListTile(
                        dense: true,
                        value: currentPerms.contains(perm.key),
                        title: Text(perm.value, style: const TextStyle(fontSize: 13)),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => setDialog(() { if (v == true) currentPerms.add(perm.key); else currentPerms.remove(perm.key); }),
                      )).toList(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler'))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await DataService().saveRolePermissions(role.name, currentPerms.toList());
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadRoles();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permissions de ${role.displayName} mises à jour'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
                        } catch (_) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la sauvegarde'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
                        }
                      },
                      child: const Text('Enregistrer'),
                    )),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteRole(_RoleConfig role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le rôle'),
        content: Text('Supprimer "${role.displayName}" ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthApiService.instance.deleteRole(role.name);
      await _loadRoles();
      await DataService().reloadRolesConfig();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rôle "${role.displayName}" supprimé'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la suppression'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
    }
  }

  Color _roleColor(String name) {
    switch (name) {
      case 'admin':         return AppColors.error;
      case 'supervisor':    return AppColors.warning;
      case 'technician':    return AppColors.success;
      case 'hospitalStaff': return AppColors.primary;
      default:              return Colors.purple;
    }
  }

  // ── Section 2 : accès aux pages par rôle ─────────────────────────────────

  Widget _buildPageAccessSection() {
    final pages = _pagesEnabled[_roleTabRole.name]!;
    final perms  = _permissionsEnabled[_roleTabRole.name]!;
    final isAdmin = _roleTabRole == UserRole.admin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Accès aux pages par rôle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        const Text('Cochez les pages et fonctions accessibles pour le rôle sélectionné.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),

        // Sélecteur de rôle
        Row(children: [
          const Icon(Icons.badge_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          const Text('Rôle', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<UserRole>(
            value: _roleTabRole,
            decoration: const InputDecoration(isDense: true),
            items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.displayName))).toList(),
            onChanged: (r) { if (r != null) setState(() => _roleTabRole = r); },
          )),
        ]),

        if (isAdmin) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
            child: const Row(children: [
              Icon(Icons.lock, size: 16, color: AppColors.error),
              SizedBox(width: 8),
              Expanded(child: Text('L\'administrateur a accès à toutes les pages et fonctions sans restriction.', style: TextStyle(fontSize: 12, color: AppColors.error))),
            ]),
          ),
        ],

        const SizedBox(height: 12),
        Card(
          child: ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: _pageDefs.entries.map((entry) {
              final screenKey = entry.key;
              final def = entry.value;
              final pageEnabled = isAdmin ? true : (pages[screenKey] ?? false);
              final pagePerms = def.permissions;

              return Column(children: [
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Checkbox(
                      value: pageEnabled,
                      activeColor: AppColors.primary,
                      onChanged: isAdmin ? null : (v) => setState(() { _pagesEnabled[_roleTabRole.name]![screenKey] = v ?? false; }),
                    ),
                    title: Row(children: [
                      Icon(def.icon, size: 18, color: pageEnabled ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Text(def.label, style: TextStyle(fontWeight: FontWeight.w600, color: pageEnabled ? AppColors.textPrimary : AppColors.textSecondary)),
                    ]),
                    children: pagePerms.isEmpty
                        ? [const Padding(padding: EdgeInsets.fromLTRB(56, 0, 16, 12), child: Text('Aucune fonction spécifique', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)))]
                        : pagePerms.map((perm) {
                            final permEnabled = isAdmin ? true : (perms[perm.name] ?? false);
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(56, 0, 16, 4),
                              child: Row(children: [
                                Checkbox(
                                  value: permEnabled,
                                  activeColor: AppColors.primary,
                                  visualDensity: VisualDensity.compact,
                                  onChanged: (isAdmin || !pageEnabled) ? null : (v) => setState(() { _permissionsEnabled[_roleTabRole.name]![perm.name] = v ?? false; }),
                                ),
                                const SizedBox(width: 6),
                                Expanded(child: Text(perm.displayName, style: TextStyle(fontSize: 13, color: pageEnabled ? AppColors.textPrimary : AppColors.textSecondary))),
                              ]),
                            );
                          }).toList(),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: isAdmin ? null : () {
              const allScreens = ['dashboard', 'equipment', 'issueTracking', 'issueForm', 'technician', 'inventory', 'reports', 'users', 'settings', 'logs'];
              final rolePerms = getPermissionsForRole(_roleTabRole).map((p) => p.name).toSet();
              setState(() {
                _pagesEnabled[_roleTabRole.name] = {for (final s in allScreens) s: true};
                _permissionsEnabled[_roleTabRole.name] = {for (final p in Permission.values) p.name: rolePerms.contains(p.name)};
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réinitialisé aux valeurs par défaut'), behavior: SnackBarBehavior.floating));
            },
            icon: const Icon(Icons.restore),
            label: const Text('Réinitialiser'),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            onPressed: (isAdmin || _roleSaving) ? null : () async {
              setState(() => _roleSaving = true);
              try {
                final enabledPages = _pageDefs.keys.where((k) => pages[k] == true).toList();
                await DataService().saveSidebarConfig(_roleTabRole.name, enabledPages);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration sauvegardée'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
              } catch (_) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la sauvegarde'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
              } finally {
                if (mounted) setState(() => _roleSaving = false);
              }
            },
            icon: _roleSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
            label: const Text('Sauvegarder'),
          )),
        ]),
      ],
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
