import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/role_detail_config.dart';
import '../models/user_role.dart';
import '../services/auth_api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Liste de tous les écrans disponibles dans la sidebar (identiques à _allScreens du RolesTab).
const List<String> _kAllScreens = [
  'dashboard', 'equipment', 'issueTracking', 'issueForm',
  'technician', 'inventory', 'reports', 'users', 'settings', 'logs',
];

const Map<String, IconData> _kScreenIcons = {
  'dashboard':     Icons.dashboard_outlined,
  'equipment':     Icons.inventory_2_outlined,
  'issueTracking': Icons.troubleshoot_outlined,
  'issueForm':     Icons.report_problem_outlined,
  'technician':    Icons.build_outlined,
  'inventory':     Icons.inventory_outlined,
  'reports':       Icons.analytics_outlined,
  'users':         Icons.people_outlined,
  'settings':      Icons.settings_outlined,
  'logs':          Icons.history_outlined,
};

/// Affiche l'écran de détail d'un rôle avec 4 onglets :
/// Hiérarchie | Fonctionnalités | Menu | Utilisateurs
class RoleDetailScreen extends StatefulWidget {
  final String roleName;
  final String displayName;

  const RoleDetailScreen({
    super.key,
    required this.roleName,
    required this.displayName,
  });

  @override
  State<RoleDetailScreen> createState() => _RoleDetailScreenState();
}

class _RoleDetailScreenState extends State<RoleDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── État ─────────────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;

  // Données chargées
  String?       _parentRole;
  List<String>  _childRoles    = [];
  String?       _inheritedFrom;
  List<String>  _permissions   = [];
  List<String>  _sidebarOrder  = [];

  // Pagination onglet Utilisateurs
  final List<RoleUserSummary> _users = [];
  int  _usersPage   = 1;
  int  _usersTotal  = 0;
  bool _usersLoading = false;
  bool _usersHasMore = true;
  String? _usersError;

  // Sauvegarde en cours
  bool _savingPerms   = false;
  bool _savingSidebar = false;

  bool get _isAdmin => widget.roleName == 'admin';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Chargement ───────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        AuthApiService.instance.getRoleHierarchy(widget.roleName),
        AuthApiService.instance.getRolePermissions(widget.roleName),
        AuthApiService.instance.getRoleSidebarOrder(widget.roleName),
      ]);
      final hierarchy = results[0] as Map<String, dynamic>;
      final perms     = results[1] as List<String>;
      final sidebar   = results[2] as List<String>;

      if (mounted) {
        setState(() {
          _parentRole   = hierarchy['parent']        as String?;
          _childRoles   = List<String>.from(hierarchy['children'] as List? ?? []);
          _inheritedFrom = hierarchy['inheritedFrom'] as String?;
          _permissions  = perms;
          _sidebarOrder = sidebar.isNotEmpty ? sidebar : List.from(_kAllScreens);
          _loading      = false;
        });
      }
      _loadUsers(reset: true);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadUsers({bool reset = false}) async {
    if (_usersLoading) return;
    if (!reset && !_usersHasMore) return;
    setState(() { _usersLoading = true; _usersError = null; });
    try {
      final page = reset ? 1 : _usersPage;
      final data = await AuthApiService.instance.getRoleUsers(
        widget.roleName,
        page: page,
        limit: 20,
      );
      final list  = (data['users'] as List).map((j) => RoleUserSummary.fromJson(j as Map<String, dynamic>)).toList();
      final total = data['total'] as int? ?? 0;
      if (mounted) {
        setState(() {
          if (reset) _users.clear();
          _users.addAll(list);
          _usersPage   = page + 1;
          _usersTotal  = total;
          _usersHasMore = _users.length < total;
          _usersLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _usersError = e.toString(); _usersLoading = false; });
    }
  }

  // ── Sauvegarde des permissions ───────────────────────────────────────────────

  Future<void> _togglePermission(String perm, bool value) async {
    if (_isAdmin || _savingPerms) return;
    final prev = List<String>.from(_permissions);
    final next = value
        ? [..._permissions, perm]
        : _permissions.where((p) => p != perm).toList();
    setState(() { _permissions = next; _savingPerms = true; });
    try {
      await AuthApiService.instance.updateRolePermissions(widget.roleName, next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_successSnack(
          AppLocalizations.of(context)!.roleDetailSavedSuccess,
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _permissions = prev);
        ScaffoldMessenger.of(context).showSnackBar(_errorSnack(
          AppLocalizations.of(context)!.roleDetailSaveError,
        ));
      }
    } finally {
      if (mounted) setState(() => _savingPerms = false);
    }
  }

  // ── Sauvegarde de l'ordre sidebar ────────────────────────────────────────────

  Future<void> _saveSidebar() async {
    if (_savingSidebar) return;
    setState(() => _savingSidebar = true);
    try {
      await AuthApiService.instance.saveRoleSidebarOrder(widget.roleName, _sidebarOrder);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_successSnack(
          AppLocalizations.of(context)!.roleDetailSavedSuccess,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_errorSnack(
          AppLocalizations.of(context)!.roleDetailSaveError,
        ));
      }
    } finally {
      if (mounted) setState(() => _savingSidebar = false);
    }
  }

  void _toggleSidebarItem(String screen, bool currentlyVisible) {
    if (_isAdmin) return;
    setState(() {
      if (currentlyVisible) {
        _sidebarOrder = _sidebarOrder.where((s) => s != screen).toList();
      } else {
        _sidebarOrder = [..._sidebarOrder, screen];
      }
    });
    _saveSidebar();
  }

  // ── Snackbars ────────────────────────────────────────────────────────────────

  SnackBar _successSnack(String msg) => SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      );

  SnackBar _errorSnack(String msg) => SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      );

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = AuthService().currentUser;
    final isAdmin = currentUser?.roles.contains(UserRole.admin) ?? false;

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.displayName)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(l10n.accessDenied,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(l10n.accessDeniedMessage,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.displayName),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.roleDetailTabHierarchy),
            Tab(text: l10n.roleDetailTabFeatures),
            Tab(text: l10n.roleDetailTabMenu),
            Tab(text: l10n.roleDetailTabUsers),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorBanner(l10n)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHierarchyTab(l10n),
                    _buildFeaturesTab(l10n),
                    _buildMenuTab(l10n),
                    _buildUsersTab(l10n),
                  ],
                ),
    );
  }

  Widget _buildErrorBanner(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_error ?? '', textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.logsRetry),
            ),
          ],
        ),
      ),
    );
  }

  // ── Onglet 1 : Hiérarchie ─────────────────────────────────────────────────────

  Widget _buildHierarchyTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bannière héritage
          if (_inheritedFrom != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
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
                  l10n.roleDetailInheritedFrom(_inheritedFrom!),
                  style: const TextStyle(fontSize: 12, color: AppColors.primary),
                )),
              ]),
            ),

          // Rôle parent
          Text(l10n.roleDetailParentRole,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _parentRole != null
              ? _buildRoleChip(_parentRole!, navigable: true)
              : Text(l10n.roleDetailNoParent,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),

          const SizedBox(height: 24),

          // Rôles enfants
          Text(l10n.roleDetailChildRoles,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _childRoles.isEmpty
              ? Text(l10n.roleDetailNoChildren,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))
              : Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _childRoles.map((c) => _buildRoleChip(c, navigable: true)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String roleName, {bool navigable = false}) {
    final role = UserRole.fromApiName(roleName);
    final label = role?.displayName ?? roleName;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: navigable
          ? () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => RoleDetailScreen(roleName: roleName, displayName: label),
              ))
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, fontSize: 13)),
          if (navigable) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
          ],
        ]),
      ),
    );
  }

  // ── Onglet 2 : Fonctionnalités (permissions) ─────────────────────────────────

  Widget _buildFeaturesTab(AppLocalizations l10n) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            if (_isAdmin)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.lock, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.roleDetailAdminLocked,
                      style: const TextStyle(fontSize: 12, color: AppColors.error))),
                ]),
              ),
            ...Permission.values.map((perm) {
              final enabled = _isAdmin ? true : _permissions.contains(perm.name);
              return SwitchListTile(
                dense: true,
                value: enabled,
                activeColor: AppColors.primary,
                title: Text(perm.localizedName(l10n), style: const TextStyle(fontSize: 13)),
                subtitle: _inheritedFrom != null && enabled
                    ? Text(
                        l10n.roleDetailInheritedFrom(_inheritedFrom!),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      )
                    : null,
                onChanged: _isAdmin
                    ? null
                    : (v) => _togglePermission(perm.name, v),
              );
            }),
          ],
        ),
        if (_savingPerms)
          const Positioned(
            top: 8, right: 16,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Sauvegarde…', style: TextStyle(fontSize: 12)),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  // ── Onglet 3 : Menu (ordre sidebar) ─────────────────────────────────────────

  Widget _buildMenuTab(AppLocalizations l10n) {
    // Construire la liste complète : visibles en premier, cachés en dessous
    final visible = _sidebarOrder.where(_kAllScreens.contains).toList();
    final hidden  = _kAllScreens.where((s) => !visible.contains(s)).toList();

    return Column(
      children: [
        if (_isAdmin)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.lock, size: 14, color: AppColors.error),
              const SizedBox(width: 6),
              Expanded(child: Text(l10n.roleDetailAdminLocked,
                  style: const TextStyle(fontSize: 11, color: AppColors.error))),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(l10n.roleDetailMenuVisible,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const Spacer(),
              if (_savingSidebar)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            onReorder: _isAdmin
                ? (_, __) {}
                : (oldIdx, newIdx) {
                    setState(() {
                      if (newIdx > oldIdx) newIdx--;
                      final item = visible.removeAt(oldIdx);
                      visible.insert(newIdx, item);
                      _sidebarOrder = [...visible, ...hidden];
                    });
                    _saveSidebar();
                  },
            itemCount: visible.length + 1 + hidden.length,
            itemBuilder: (context, index) {
              if (index < visible.length) {
                final screen = visible[index];
                return _buildMenuTile(
                  key: ValueKey('v_$screen'),
                  screen: screen,
                  isVisible: true,
                  l10n: l10n,
                );
              }
              if (index == visible.length) {
                return Container(
                  key: const ValueKey('_divider'),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(l10n.roleDetailMenuHidden,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                );
              }
              final screen = hidden[index - visible.length - 1];
              return _buildMenuTile(
                key: ValueKey('h_$screen'),
                screen: screen,
                isVisible: false,
                l10n: l10n,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required Key key,
    required String screen,
    required bool isVisible,
    required AppLocalizations l10n,
  }) {
    final icon = _kScreenIcons[screen] ?? Icons.circle_outlined;
    final label = _pageLabel(screen, l10n);
    return ListTile(
      key: key,
      leading: Icon(icon, size: 20, color: isVisible ? AppColors.primary : AppColors.textSecondary),
      title: Text(label, style: TextStyle(
        color: isVisible ? AppColors.textPrimary : AppColors.textSecondary,
        fontSize: 14,
      )),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off,
                size: 18,
                color: isVisible ? AppColors.success : AppColors.textSecondary),
            tooltip: isVisible ? 'Masquer' : 'Afficher',
            onPressed: _isAdmin ? null : () => _toggleSidebarItem(screen, isVisible),
          ),
          if (isVisible) const Icon(Icons.drag_handle, color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }

  // ── Onglet 4 : Utilisateurs ─────────────────────────────────────────────────

  Widget _buildUsersTab(AppLocalizations l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Text(
              l10n.roleDetailUsersCount(_usersTotal),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
        if (_usersError != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_usersError!, style: const TextStyle(fontSize: 12, color: AppColors.error))),
                TextButton(
                  onPressed: () => _loadUsers(reset: true),
                  child: Text(l10n.logsRetry, style: const TextStyle(fontSize: 12)),
                ),
              ]),
            ),
          ),
        Expanded(
          child: _users.isEmpty && !_usersLoading
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_outline, size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    Text(l10n.roleDetailNoUsers,
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: _users.length + (_usersLoading ? 1 : 0) + (_usersHasMore && !_usersLoading ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                  itemBuilder: (context, index) {
                    if (index < _users.length) {
                      final user = _users[index];
                      final initials = _initials(user.name);
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryLight,
                          child: Text(initials,
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        title: Text(user.name.isNotEmpty ? user.name : user.username,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text(user.email,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      );
                    }
                    if (_usersLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    // Bouton "Charger plus"
                    return TextButton(
                      onPressed: _loadUsers,
                      child: Text(l10n.settingsLoadMore),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _pageLabel(String key, AppLocalizations l10n) => switch (key) {
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
        _               => key,
      };
}
