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

// Définition d'une page : icône + permissions associées (le label est résolu à l'affichage via _pageLabel).
class _PageDef {
  final IconData icon;
  final List<Permission> permissions;
  const _PageDef(this.icon, this.permissions);
}

const Map<String, _PageDef> _pageDefs = {
  'dashboard':     _PageDef(Icons.dashboard_outlined,        [Permission.viewEquipment]),
  'equipment':     _PageDef(Icons.inventory_2_outlined,     [Permission.viewEquipment, Permission.manageEquipment]),
  'issueTracking': _PageDef(Icons.troubleshoot_outlined,    [Permission.trackIssues, Permission.approveRequests, Permission.assignTasks]),
  'issueForm':     _PageDef(Icons.report_problem_outlined,  [Permission.reportIssue]),
  'technician':    _PageDef(Icons.build_outlined,           [Permission.updateRepairs, Permission.registerParts]),
  'inventory':     _PageDef(Icons.inventory_outlined,       [Permission.viewInventory]),
  'reports':       _PageDef(Icons.analytics_outlined,       [Permission.generateReports]),
  'users':         _PageDef(Icons.people_outlined,          [Permission.manageUsers]),
  'settings':      _PageDef(Icons.settings_outlined,        [Permission.manageDepartments, Permission.manageCategories]),
  'logs':          _PageDef(Icons.history_outlined,         [Permission.manageUsers]),
};

String _pageLabel(String screenKey, AppLocalizations l10n) => switch (screenKey) {
  'dashboard'     => l10n.navDashboard,
  'equipment'     => l10n.navEquipment,
  'issueTracking' => l10n.navIssueTracking,
  'issueForm'     => l10n.navReportIssue,
  'technician'    => l10n.navTechnician,
  'inventory'     => l10n.navInventory,
  'reports'       => l10n.navReports,
  'users'         => l10n.navUsers,
  'settings'      => l10n.navSettings,
  'logs'          => l10n.navLogs,
  _               => screenKey,
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
      final order = DataService().sidebarOrder[role.apiName];
      _pagesEnabled[role.apiName] = {
        for (final s in allScreens)
          s: order == null ? true : order.contains(s),
      };
      final rolePerms = getPermissionsForRole(role).map((p) => p.name).toSet();
      _permissionsEnabled[role.apiName] = {
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
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.admin_panel_settings, size: 18),
                const SizedBox(width: 8),
                Text(l10n.settingsRolesTab),
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
      _sidebarOrder[_selectedRole.apiName] ?? defaultOrder,
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
                    child: Text(r.localizedName(l10n)),
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
                    _sidebarOrder = Map.from(_sidebarOrder)..[_selectedRole.apiName] = List.from(currentOrder);
                  });
                },
                itemBuilder: (context, index) {
                  final screenType = currentOrder[index];
                  final label = _pageLabel(screenType, l10n);
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
                    _sidebarOrder = Map.from(_sidebarOrder)..remove(_selectedRole.apiName);
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
                      _sidebarOrder[_selectedRole.apiName] ?? ['dashboard', 'equipment', 'issueTracking', 'issueForm', 'technician', 'inventory', 'reports', 'users', 'settings', 'logs'],
                    );
                    await DataService().saveSidebarConfig(_selectedRole.apiName, order);
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.settingsRolesTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(l10n.settingsRolesSubtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
            ElevatedButton.icon(
              onPressed: _showCreateRoleDialog,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.settingsNewRole),
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
          child: Row(children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              l10n.settingsAdminLockedInfo,
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
            )),
          ]),
        ),
        const SizedBox(height: 12),
        if (_rolesLoading)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (_roles.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(l10n.settingsNoRoles, style: const TextStyle(color: AppColors.textSecondary)),
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
    final l10n = AppLocalizations.of(context)!;
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
                  child: Text(l10n.settingsCustomBadge, style: const TextStyle(fontSize: 11, color: AppColors.warning)),
                ),
              ],
              const Spacer(),
              if (role.name == 'admin')
                Tooltip(
                  message: l10n.settingsAdminAlwaysAll,
                  child: TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.lock, size: 16),
                    label: Text(l10n.settingsLocked),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => _showEditPermissionsDialog(role),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(l10n.commonEdit),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              if (!role.isBuiltin)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.error,
                  tooltip: l10n.commonDelete,
                  onPressed: () => _confirmDeleteRole(role),
                ),
            ]),
            if (role.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(role.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
            const SizedBox(height: 10),
            Text(l10n.settingsRoleActive, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            role.permissions.isEmpty
                ? Text(l10n.settingsNoPermissions, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))
                : Wrap(
                    spacing: 6, runSpacing: 6,
                    children: role.permissions.map((p) {
                      final perm = Permission.values.where((e) => e.name == p).firstOrNull;
                      final label = perm?.localizedName(l10n) ?? p;
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
    final l10n = AppLocalizations.of(context)!;
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
                    Expanded(child: Text(l10n.settingsNewRoleTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ]),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      TextField(controller: nameCtrl, decoration: InputDecoration(labelText: l10n.settingsRoleIdLabel, helperText: l10n.settingsRoleIdHint, prefixIcon: const Icon(Icons.code))),
                      const SizedBox(height: 12),
                      TextField(controller: displayCtrl, decoration: InputDecoration(labelText: l10n.settingsRoleDisplayLabel, prefixIcon: const Icon(Icons.label_outline))),
                      const SizedBox(height: 12),
                      TextField(controller: descCtrl, decoration: InputDecoration(labelText: l10n.settingsRoleDescLabel, prefixIcon: const Icon(Icons.notes))),
                      const SizedBox(height: 16),
                      Text(l10n.settingsPermissionsLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...Permission.values.map((perm) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selectedPerms.contains(perm.name),
                        title: Text(perm.localizedName(l10n), style: const TextStyle(fontSize: 13)),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => setDialog(() { if (v == true) selectedPerms.add(perm.name); else selectedPerms.remove(perm.name); }),
                      )),
                      const SizedBox(height: 8),
                    ]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty || displayCtrl.text.trim().isEmpty) return;
                        try {
                          await AuthApiService.instance.createRole({'name': nameCtrl.text.trim(), 'display_name': displayCtrl.text.trim(), 'description': descCtrl.text.trim(), 'permissions': selectedPerms.toList()});
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadRoles();
                          await DataService().reloadRolesConfig();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsRoleCreated), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
                        } catch (_) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsRoleCreateError), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
                        }
                      },
                      child: Text(l10n.settingsCreateRole),
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
    final l10n = AppLocalizations.of(context)!;

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
                      Text(l10n.settingsEditPermissionsTitle(role.displayName), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (role.isBuiltin) Text(l10n.settingsBuiltinRole, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ])),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Row(children: [
                    TextButton.icon(onPressed: () => setDialog(() => currentPerms.addAll(Permission.values.map((p) => p.name))), icon: const Icon(Icons.select_all, size: 16), label: Text(l10n.settingsSelectAll, style: const TextStyle(fontSize: 12))),
                    TextButton.icon(onPressed: () => setDialog(() => currentPerms.clear()), icon: const Icon(Icons.deselect, size: 16), label: Text(l10n.settingsDeselectAll, style: const TextStyle(fontSize: 12))),
                  ]),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(
                      children: Permission.values.map((perm) => CheckboxListTile(
                        dense: true,
                        value: currentPerms.contains(perm.name),
                        title: Text(perm.localizedName(l10n), style: const TextStyle(fontSize: 13)),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => setDialog(() { if (v == true) currentPerms.add(perm.name); else currentPerms.remove(perm.name); }),
                      )).toList(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await DataService().saveRolePermissions(role.name, currentPerms.toList());
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadRoles();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsRolePermissionsUpdated(role.displayName)), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
                        } catch (_) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsRoleSaveError), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
                        }
                      },
                      child: Text(l10n.commonSave),
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsDeleteRole),
        content: Text(l10n.settingsRoleDeleteConfirm(role.displayName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.commonDelete)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthApiService.instance.deleteRole(role.name);
      await _loadRoles();
      await DataService().reloadRolesConfig();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsRoleDeletedToast(role.displayName)), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsRoleDeleteError), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
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
    final l10n = AppLocalizations.of(context)!;
    final pages = _pagesEnabled[_roleTabRole.apiName]!;
    final perms  = _permissionsEnabled[_roleTabRole.apiName]!;
    final isAdmin = _roleTabRole == UserRole.admin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsAccessByRole, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(l10n.settingsAccessDesc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),

        // Sélecteur de rôle
        Row(children: [
          const Icon(Icons.badge_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(l10n.settingsRoleLabel, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<UserRole>(
            value: _roleTabRole,
            decoration: const InputDecoration(isDense: true),
            items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.localizedName(l10n)))).toList(),
            onChanged: (r) { if (r != null) setState(() => _roleTabRole = r); },
          )),
        ]),

        if (isAdmin) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.lock, size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.settingsAdminAllAccess, style: const TextStyle(fontSize: 12, color: AppColors.error))),
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
                      onChanged: isAdmin ? null : (v) => setState(() { _pagesEnabled[_roleTabRole.apiName]![screenKey] = v ?? false; }),
                    ),
                    title: Row(children: [
                      Icon(def.icon, size: 18, color: pageEnabled ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Text(_pageLabel(screenKey, l10n), style: TextStyle(fontWeight: FontWeight.w600, color: pageEnabled ? AppColors.textPrimary : AppColors.textSecondary)),
                    ]),
                    children: pagePerms.isEmpty
                        ? [Padding(padding: const EdgeInsets.fromLTRB(56, 0, 16, 12), child: Text(l10n.settingsNoSpecificFunction, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)))]
                        : pagePerms.map((perm) {
                            final permEnabled = isAdmin ? true : (perms[perm.name] ?? false);
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(56, 0, 16, 4),
                              child: Row(children: [
                                Checkbox(
                                  value: permEnabled,
                                  activeColor: AppColors.primary,
                                  visualDensity: VisualDensity.compact,
                                  onChanged: (isAdmin || !pageEnabled) ? null : (v) => setState(() { _permissionsEnabled[_roleTabRole.apiName]![perm.name] = v ?? false; }),
                                ),
                                const SizedBox(width: 6),
                                Expanded(child: Text(perm.localizedName(l10n), style: TextStyle(fontSize: 13, color: pageEnabled ? AppColors.textPrimary : AppColors.textSecondary))),
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
                _pagesEnabled[_roleTabRole.apiName] = {for (final s in allScreens) s: true};
                _permissionsEnabled[_roleTabRole.apiName] = {for (final p in Permission.values) p.name: rolePerms.contains(p.name)};
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsResetDone), behavior: SnackBarBehavior.floating));
            },
            icon: const Icon(Icons.restore),
            label: Text(l10n.settingsReset),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            onPressed: (isAdmin || _roleSaving) ? null : () async {
              setState(() => _roleSaving = true);
              try {
                final enabledPages = _pageDefs.keys.where((k) => pages[k] == true).toList();
                await DataService().saveSidebarConfig(_roleTabRole.apiName, enabledPages);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsRoleConfigSaved), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
              } catch (_) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsRoleConfigSaveError), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
              } finally {
                if (mounted) setState(() => _roleSaving = false);
              }
            },
            icon: _roleSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
            label: Text(l10n.commonSave),
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
