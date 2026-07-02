import 'dart:convert';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/auth_api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import 'user_detail_screen.dart';

/// Modèle léger pour une demande de changement de département.
class _DeptRequest {
  final String id;
  final String userId;
  final String userName;
  final String currentDepartment;
  final String requestedDepartment;
  final String status;
  final String createdAt;

  const _DeptRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.currentDepartment,
    required this.requestedDepartment,
    required this.status,
    required this.createdAt,
  });

  factory _DeptRequest.fromJson(Map<String, dynamic> j) => _DeptRequest(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    userName: j['user_name'] as String,
    currentDepartment: j['current_department'] as String,
    requestedDepartment: j['requested_department'] as String,
    status: j['status'] as String,
    createdAt: j['created_at'] as String? ?? '',
  );
}

/// Modèle léger pour une demande de rôle.
class _RoleRequest {
  final String id;
  final String userId;
  final String userName;
  final List<String> currentRoles;
  final String requestedRole;
  final String status;
  final DateTime createdAt;

  const _RoleRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.currentRoles,
    required this.requestedRole,
    required this.status,
    required this.createdAt,
  });

  factory _RoleRequest.fromJson(Map<String, dynamic> j) {
    List<String> roles = [];
    try {
      roles = (jsonDecode(j['current_roles'] as String? ?? '[]') as List).cast<String>();
    } catch (_) {}
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(j['created_at'] as String? ?? '');
    } catch (_) {
      createdAt = DateTime.now();
    }
    return _RoleRequest(
      id:            j['id']             as String,
      userId:        j['user_id']        as String,
      userName:      j['user_name']      as String,
      currentRoles:  roles,
      requestedRole: j['requested_role'] as String,
      status:        j['status']         as String,
      createdAt:     createdAt,
    );
  }
}

/// Actions disponibles dans le menu contextuel d'une ligne utilisateur (mode compact).
enum _UserAction { edit, permissions, toggle, delete }

/// User management screen - Admin only
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _roleFilter = 'all';
  String _searchTerm = '';

  List<_DeptRequest> _deptRequests = [];
  bool _deptRequestsLoading = false;
  bool _deptRequestsExpanded = false;
  final _deptTileController = ExpansionTileController();

  List<_RoleRequest> _roleRequests = [];
  bool _roleRequestsLoading = false;
  bool _roleRequestsExpanded = false;
  final _roleTileController = ExpansionTileController();

  @override
  void initState() {
    super.initState();
    _loadDeptRequests();
    _loadRoleRequests();
  }

  // ── Chargement données ────────────────────────────────────────────────────

  Future<void> _loadDeptRequests() async {
    setState(() => _deptRequestsLoading = true);
    try {
      await DataService().reloadDeptRequests();
      final requests = DataService().deptRequests
          .map((j) => _DeptRequest.fromJson(j))
          .toList();
      setState(() {
        _deptRequests = requests;
        _deptRequestsLoading = false;
      });
      NotificationService().generateFromLoadedData();
      if (requests.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try { _deptTileController.expand(); } catch (_) {}
          }
        });
      }
    } catch (e) {
      setState(() => _deptRequestsLoading = false);
      debugPrint('UserManagement: erreur chargement demandes dept — $e');
    }
  }

  Future<void> _loadRoleRequests() async {
    setState(() => _roleRequestsLoading = true);
    List<_RoleRequest> requests = [];
    try {
      await DataService().reloadRoleRequests();
      requests = DataService().roleRequests.map(_RoleRequest.fromJson).toList();
    } catch (e) {
      debugPrint('UserManagement: erreur chargement demandes rôle — $e');
    } finally {
      if (mounted) setState(() { _roleRequests = requests; _roleRequestsLoading = false; });
    }
    NotificationService().generateFromLoadedData();
    if (requests.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { try { _roleTileController.expand(); } catch (_) {} }
      });
    }
  }

  List<User> get _filteredUsers {
    return DataService().users.where((user) {
      final matchesSearch = user.name.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchTerm.toLowerCase());
      final matchesRole = _roleFilter == 'all' || user.roles.any((r) => r.displayName == _roleFilter);
      return matchesSearch && matchesRole;
    }).toList();
  }

  // ── Build principal ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _buildUsersTab(context, l10n);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ONGLET 1 : UTILISATEURS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildUsersTab(BuildContext context, AppLocalizations l10n) {
    final users = DataService().users;
    // Statistiques par rôle (un utilisateur multi-rôles est compté dans chaque catégorie).
    // On utilise kAssignableRoles pour exclure le `technician` générique déprécié.
    final roleStats = {
      'all': users.length,
      for (var role in kAssignableRoles)
        role.displayName: users.where((u) => u.hasRole(role)).length,
    };
    // Synthèse "Techniciens" : utilisateurs ayant au moins un des 3 rôles tech spécialisés.
    final techniciansCount = users.where((u) =>
      u.hasRole(UserRole.technicianBiomedical) ||
      u.hasRole(UserRole.technicianIt) ||
      u.hasRole(UserRole.technicianInfra)
    ).length;

    final isMobile = MediaQuery.of(context).size.width < AppBreakpoints.tablet;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            if (isMobile) ...[
              Text(l10n.usersTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(l10n.usersSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showUserDialog(null),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: Text(l10n.usersNew),
                ),
              ),
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.usersTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(l10n.usersSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showUserDialog(null),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(l10n.usersNew),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // Role summary cards
            if (isMobile)
              LayoutBuilder(builder: (context, constraints) {
                final w = (constraints.maxWidth - 12) / 2;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(width: w, child: _buildRoleCardWidget(l10n.usersTotal, users.length, Icons.people, AppColors.primary)),
                  SizedBox(width: w, child: _buildRoleCardWidget(l10n.usersAdmins, roleStats[UserRole.admin.displayName]!, Icons.admin_panel_settings, AppColors.error)),
                  SizedBox(width: w, child: _buildRoleCardWidget(l10n.usersSupervisors, roleStats[UserRole.supervisor.displayName]!, Icons.supervisor_account, AppColors.warning)),
                  SizedBox(width: w, child: _buildRoleCardWidget(l10n.usersTechnicians, techniciansCount, Icons.build, AppColors.success)),
                  SizedBox(width: w, child: _buildRoleCardWidget(l10n.usersStaff, roleStats[UserRole.hospitalStaff.displayName]!, Icons.medical_services, AppColors.primary)),
                ]);
              })
            else
              Row(children: [
                _buildRoleCard(l10n.usersTotal, users.length, Icons.people, AppColors.primary),
                const SizedBox(width: 12),
                _buildRoleCard(l10n.usersAdmins, roleStats[UserRole.admin.displayName]!, Icons.admin_panel_settings, AppColors.error),
                const SizedBox(width: 12),
                _buildRoleCard(l10n.usersSupervisors, roleStats[UserRole.supervisor.displayName]!, Icons.supervisor_account, AppColors.warning),
                const SizedBox(width: 12),
                _buildRoleCard(l10n.usersTechnicians, techniciansCount, Icons.build, AppColors.success),
                const SizedBox(width: 12),
                _buildRoleCard(l10n.usersStaff, roleStats[UserRole.hospitalStaff.displayName]!, Icons.medical_services, AppColors.primary),
              ]),
            const SizedBox(height: 20),

            // Filters
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        onChanged: (value) => setState(() => _searchTerm = value),
                        decoration: InputDecoration(
                          hintText: l10n.usersSearchHint,
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _roleFilter,
                        decoration: InputDecoration(labelText: l10n.usersFilterByRole, isDense: true),
                        items: [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('${l10n.commonAll} (${roleStats['all']})'),
                          ),
                          ...kAssignableRoles.map((role) => DropdownMenuItem(
                            value: role.displayName,
                            child: Text('${role.displayName} (${roleStats[role.displayName]})'),
                          )),
                        ],
                        onChanged: (value) => setState(() => _roleFilter = value!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section demandes de changement de département
            _buildDeptRequestsSection(),
            const SizedBox(height: 20),

            // Section demandes de rôle
            _buildRoleRequestsSection(),
            const SizedBox(height: 20),

            // Users table
            _buildUsersTable(l10n),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ONGLET 1 — SECTION DEMANDES DE DÉPARTEMENT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDeptRequestsSection() {
    final count = _deptRequests.length;
    return Card(
      child: ExpansionTile(
        controller: _deptTileController,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.swap_horiz, color: AppColors.warning),
            if (count > 0)
              Positioned(
                right: -6, top: -4,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  child: Center(
                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        ),
        title: const Text('Demandes de changement de département', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          _deptRequestsLoading ? 'Chargement…' : '$count demande${count > 1 ? 's' : ''} en attente',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        initiallyExpanded: _deptRequestsExpanded,
        onExpansionChanged: (v) => setState(() => _deptRequestsExpanded = v),
        children: [
          if (_deptRequestsLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_deptRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text('Aucune demande en attente.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...  _deptRequests.map((req) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.warningLight,
                child: Text(
                  req.userName.isNotEmpty ? req.userName[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(req.userName, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Row(children: [
                Text(req.currentDepartment, style: const TextStyle(fontSize: 12)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward, size: 12, color: AppColors.textMuted)),
                Text(req.requestedDepartment, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ]),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                    tooltip: 'Approuver',
                    onPressed: () => _resolveDeptRequest(req, 'approved'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                    tooltip: 'Rejeter',
                    onPressed: () => _resolveDeptRequest(req, 'rejected'),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ONGLET 1 — SECTION DEMANDES DE RÔLE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRoleRequestsSection() {
    final count = _roleRequests.length;
    return Card(
      child: ExpansionTile(
        controller: _roleTileController,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.badge_outlined, color: AppColors.warning),
            if (count > 0)
              Positioned(
                right: -6, top: -4,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  child: Center(
                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        ),
        title: const Text('Demandes de rôle en attente', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          _roleRequestsLoading ? 'Chargement…' : '$count demande${count > 1 ? 's' : ''} en attente',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        initiallyExpanded: _roleRequestsExpanded,
        onExpansionChanged: (v) => setState(() => _roleRequestsExpanded = v),
        children: [
          if (_roleRequestsLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_roleRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text('Aucune demande en attente.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ..._roleRequests.map((req) {
              final now  = DateTime.now();
              final diff = now.difference(req.createdAt);
              final ageText = diff.inDays == 0
                  ? 'depuis ${diff.inHours}h'
                  : 'depuis ${diff.inDays}j';
              final ageColor = diff > const Duration(hours: 48)
                  ? AppColors.error
                  : AppColors.textMuted;
              return ListTile(
                onTap: () => _openUserDetailFromRoleRequest(req),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.warningLight,
                  child: Text(
                    req.userName.isNotEmpty ? req.userName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(req.userName, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Row(children: [
                  Text(req.currentRoles.join(', '), style: const TextStyle(fontSize: 12)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward, size: 12, color: AppColors.textMuted)),
                  Text(req.requestedRole, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(width: 8),
                  Text(ageText, style: TextStyle(fontSize: 11, color: ageColor)),
                ]),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                      tooltip: 'Approuver',
                      onPressed: () => _resolveRoleRequest(req, 'approved'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                      tooltip: 'Rejeter',
                      onPressed: () => _resolveRoleRequest(req, 'rejected'),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _resolveRoleRequest(_RoleRequest req, String status) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(
            status == 'approved' ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: status == 'approved' ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Text(status == 'approved' ? 'Approuver la demande' : 'Rejeter la demande'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(text: TextSpan(
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              children: [
                TextSpan(text: req.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: ' : '),
                TextSpan(text: req.currentRoles.join(', ')),
                const TextSpan(text: ' → '),
                TextSpan(text: req.requestedRole, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            )),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optionnel)',
                hintText: 'Raison de la décision…',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'approved' ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(status == 'approved' ? 'Approuver' : 'Rejeter'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthApiService.instance.resolveRoleRequest(req.id, status: status, adminNote: noteCtrl.text.trim());
      await DataService().reloadUsers();
      await _loadRoleRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'approved'
              ? 'Demande approuvée — rôle attribué'
              : 'Demande rejetée'),
          backgroundColor: status == 'approved' ? AppColors.success : AppColors.error,
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
        await _loadRoleRequests();
      }
    }
  }

  Future<void> _resolveDeptRequest(_DeptRequest req, String status) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(
            status == 'approved' ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: status == 'approved' ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Text(status == 'approved' ? 'Approuver la demande' : 'Rejeter la demande'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(text: TextSpan(
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              children: [
                TextSpan(text: req.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: ' : '),
                TextSpan(text: req.currentDepartment),
                const TextSpan(text: ' → '),
                TextSpan(text: req.requestedDepartment, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            )),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optionnel)',
                hintText: 'Raison de la décision…',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'approved' ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(status == 'approved' ? 'Approuver' : 'Rejeter'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthApiService.instance.resolveDepartmentRequest(
        req.id, status: status, adminNote: noteCtrl.text.trim(),
      );
      await DataService().reloadUsers();
      await _loadDeptRequests();
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'approved'
              ? 'Demande approuvée — département mis à jour'
              : 'Demande rejetée'),
          backgroundColor: status == 'approved' ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TABLE UTILISATEURS RESPONSIVE
  // ══════════════════════════════════════════════════════════════════════════

  static const _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
  );

  /// Conteneur principal de la liste. Utilise LayoutBuilder pour choisir
  /// entre le mode large (≥ 640 px) et le mode compact (sidebar ouverte,
  /// petit écran).
  Widget _buildUsersTable(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        clipBehavior: Clip.hardEdge,
        child: _filteredUsers.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Aucun utilisateur', style: TextStyle(color: AppColors.textSecondary))),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 640;
                  return Column(
                    children: [
                      _buildUsersListHeader(l10n, wide: wide),
                      ..._filteredUsers.map((u) => _buildUserRow(u, l10n, wide: wide)),
                    ],
                  );
                },
              ),
      ),
    );
  }

  /// Ligne d'en-tête imitant les colonnes du DataTable.
  Widget _buildUsersListHeader(AppLocalizations l10n, {required bool wide}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: wide
          ? Row(children: [
              const SizedBox(width: 44), // avatar
              Expanded(flex: 5, child: Text(l10n.usersUser,       style: _headerStyle)),
              Expanded(flex: 4, child: Text(l10n.commonEmail,     style: _headerStyle)),
              Expanded(flex: 3, child: Text(l10n.commonDepartment, style: _headerStyle)),
              const SizedBox(width: 118, child: Text('Rôle',      style: _headerStyle)),
              const SizedBox(width: 80,  child: Text('Statut',    style: _headerStyle)),
              const SizedBox(width: 132, child: Text('Actions',   style: _headerStyle)),
            ])
          : Row(children: [
              const SizedBox(width: 44),
              Expanded(child: Text(l10n.usersUser, style: _headerStyle)),
              SizedBox(width: 76, child: Text('Statut', style: _headerStyle, textAlign: TextAlign.center)),
              const SizedBox(width: 40),
            ]),
    );
  }

  /// Ligne utilisateur — layout large ou compact selon [wide].
  Widget _buildUserRow(User user, AppLocalizations l10n, {required bool wide}) {
    final primaryRole = _primaryRoleOf(user);
    final roleColor   = _getRoleColor(primaryRole);
    final isSelf      = user.id == AuthService().currentUser?.id;
    final severity    = _userSeverity(user);

    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: roleColor.withValues(alpha: 0.15),
      child: Text(
        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
        style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToUserDetail(user),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: wide
              // ── Mode large : toutes les colonnes en Row ────────────────────
              ? Row(children: [
                  avatar,
                  const SizedBox(width: 12),
                  // Nom + icône d'alerte éventuelle
                  Expanded(
                    flex: 5,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (severity != null) ...[
                          Icon(
                            Icons.warning_rounded,
                            size: 16,
                            color: severity == 'high' ? AppColors.error : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            user.fullName,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Email
                  Expanded(
                    flex: 4,
                    child: Text(
                      user.email,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Département
                  Expanded(
                    flex: 3,
                    child: Text(
                      user.department,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Rôle principal + badge "+N" si multi-rôles
                  SizedBox(width: 110, child: _buildPrimaryRoleBadge(user)),
                  const SizedBox(width: 8),
                  // Statut
                  SizedBox(width: 72, child: _buildStatusBadge(user.isActive, l10n)),
                  const SizedBox(width: 8),
                  // Boutons d'action (toujours visibles, largeur fixe)
                  SizedBox(
                    width: 132,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          color: AppColors.primary,
                          onPressed: () => _showUserDialog(user),
                          tooltip: l10n.commonEdit,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        ),
                        IconButton(
                          icon: const Icon(Icons.key, size: 18),
                          color: AppColors.warning,
                          onPressed: () => _showPermissionsDialog(user),
                          tooltip: l10n.usersPermissions,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        ),
                        IconButton(
                          icon: Icon(user.isActive ? Icons.block : Icons.check_circle_outline, size: 18),
                          color: user.isActive ? AppColors.error : AppColors.success,
                          onPressed: () => _toggleUserStatus(user),
                          tooltip: user.isActive ? l10n.usersDisable : l10n.usersEnable,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        ),
                        Tooltip(
                          message: isSelf ? 'Impossible de supprimer son propre compte' : l10n.commonDelete,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: isSelf ? AppColors.textMuted : AppColors.error,
                            onPressed: isSelf ? null : () => _confirmDeleteUser(user),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          ),
                        ),
                      ],
                    ),
                  ),
                ])
              // ── Mode compact : nom + email empilés, popup menu ─────────────
              : Row(children: [
                  avatar,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (severity != null) ...[
                              Icon(
                                Icons.warning_rounded,
                                size: 14,
                                color: severity == 'high' ? AppColors.error : AppColors.warning,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                user.fullName,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          user.email,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(user.isActive, l10n),
                  // Menu déroulant compact pour les actions
                  PopupMenuButton<_UserAction>(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    tooltip: 'Actions',
                    onSelected: (action) {
                      switch (action) {
                        case _UserAction.edit:        _showUserDialog(user);
                        case _UserAction.permissions: _showPermissionsDialog(user);
                        case _UserAction.toggle:      _toggleUserStatus(user);
                        case _UserAction.delete:      if (!isSelf) _confirmDeleteUser(user);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: _UserAction.edit,
                        child: _actionItem(Icons.edit, l10n.commonEdit, AppColors.primary),
                      ),
                      PopupMenuItem(
                        value: _UserAction.permissions,
                        child: _actionItem(Icons.key, l10n.usersPermissions, AppColors.warning),
                      ),
                      PopupMenuItem(
                        value: _UserAction.toggle,
                        child: _actionItem(
                          user.isActive ? Icons.block : Icons.check_circle_outline,
                          user.isActive ? l10n.usersDisable : l10n.usersEnable,
                          user.isActive ? AppColors.error : AppColors.success,
                        ),
                      ),
                      if (!isSelf)
                        PopupMenuItem(
                          value: _UserAction.delete,
                          child: _actionItem(Icons.delete_outline, l10n.commonDelete, AppColors.error),
                        ),
                    ],
                  ),
                ]),
        ),
      ),
    );
  }

  /// Badge du rôle principal + compteur "+N" si l'utilisateur a plusieurs rôles.
  Widget _buildPrimaryRoleBadge(User user) {
    final primary    = _primaryRoleOf(user);
    final color      = _getRoleColor(primary);
    final extraCount = (user.roles.where(kAssignableRoles.contains).length - 1).clamp(0, 99);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              primary.displayName,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
        if (extraCount > 0) ...[
          const SizedBox(width: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(8)),
            child: Text('+$extraCount', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  /// Item de PopupMenu avec icône colorée.
  Widget _actionItem(IconData icon, String label, Color color) => Row(children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 10),
    Text(label, style: TextStyle(color: color)),
  ]);

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGETS COMMUNS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRoleCardWidget(String label, int count, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(String label, int count, IconData icon, Color color) {
    return Expanded(child: _buildRoleCardWidget(label, count, icon, color));
  }

  Widget _buildRoleBadge(UserRole role) {
    final color = _getRoleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(role.displayName, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  /// Affichage compact d'une liste de rôles (Wrap de badges côte à côte).
  Widget _buildRolesBadges(List<UserRole> roles) {
    if (roles.isEmpty) {
      return Text('—', style: TextStyle(color: AppColors.textMuted));
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: roles.map(_buildRoleBadge).toList(),
    );
  }

  /// Rôle "principal" d'un utilisateur (priorité fixe), utilisé pour l'avatar.
  UserRole _primaryRoleOf(User u) {
    const priority = [
      UserRole.admin,
      UserRole.supervisor,
      UserRole.technicianBiomedical,
      UserRole.technicianIt,
      UserRole.technicianInfra,
      UserRole.technician,
      UserRole.hospitalStaff,
    ];
    for (final r in priority) {
      if (u.hasRole(r)) return r;
    }
    return u.roles.isNotEmpty ? u.roles.first : UserRole.hospitalStaff;
  }

  Widget _buildStatusBadge(bool isActive, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successLight : AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? l10n.usersActive : l10n.usersInactive,
        style: TextStyle(color: isActive ? AppColors.success : AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  /// Sévérité effective d'un utilisateur : combine les données du modèle et les demandes de département chargées.
  String? _userSeverity(User user) {
    if (!user.isEmailVerified) return 'high';
    if (_deptRequests.any((r) => r.userId == user.id)) return 'medium';
    if (user.phone == null || user.phone!.isEmpty) return 'medium';
    return null;
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:                return AppColors.error;
      case UserRole.supervisor:           return AppColors.warning;
      case UserRole.technician:           return AppColors.success;
      case UserRole.technicianBiomedical: return AppColors.success;
      case UserRole.technicianIt:         return AppColors.primary;
      case UserRole.technicianInfra:      return AppColors.warning;
      case UserRole.hospitalStaff:        return AppColors.primary;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _navigateToUserDetail(User user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserDetailScreen(user: user)),
    );
    // Rafraîchit la liste au retour en cas de modification, suppression ou résolution de demande.
    // Les deux rechargements sont indépendants (endpoints distincts) : lancés en parallèle.
    if (mounted) {
      await Future.wait([DataService().reloadUsers(), _loadRoleRequests()]);
      setState(() {});
    }
  }

  /// Ouvre le détail de l'utilisateur ciblé par une demande de rôle en attente.
  Future<void> _openUserDetailFromRoleRequest(_RoleRequest req) async {
    final user = DataService().users.where((u) => u.id == req.userId).firstOrNull;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Utilisateur introuvable (peut-être supprimé)'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    await _navigateToUserDetail(user);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DIALOGS UTILISATEURS
  // ══════════════════════════════════════════════════════════════════════════

  void _showUserDialog(User? user) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit        = user != null;
    final firstNameCtrl = TextEditingController(text: user?.firstName ?? '');
    final lastNameCtrl  = TextEditingController(text: user?.lastName ?? '');
    final emailCtrl     = TextEditingController(text: user?.email ?? '');
    final phoneCtrl     = TextEditingController(text: user?.phone ?? '');
    final passCtrl  = TextEditingController();
    // Multi-sélection : on stocke les rôles sous forme d'un Set d'enum.
    // Pré-cocher les rôles existants (en filtrant le `technician` générique déprécié).
    final Set<UserRole> selectedRoles = (user?.roles ?? const [UserRole.hospitalStaff])
        .where(kAssignableRoles.contains)
        .toSet();
    if (selectedRoles.isEmpty) selectedRoles.add(UserRole.hospitalStaff);
    String selectedDepartment = user?.department ?? 'IT';

    final departments = ['IT', 'Radiologie', 'Réanimation', 'Stérilisation', 'Laboratoire', 'Urgences', 'Maintenance', 'Infrastructure'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── En-tête (fixe) ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEdit ? l10n.usersEditTitle : l10n.usersNewTitle,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Corps scrollable ────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: firstNameCtrl,
                                decoration: const InputDecoration(labelText: 'Prénom', prefixIcon: Icon(Icons.person)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: lastNameCtrl,
                                decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.person)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: l10n.usersEmailLabel, prefixIcon: const Icon(Icons.email))),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: isEdit ? l10n.usersNewPassword : l10n.usersPasswordLabel,
                            prefixIcon: const Icon(Icons.lock),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(controller: phoneCtrl, decoration: InputDecoration(labelText: l10n.usersPhone, prefixIcon: const Icon(Icons.phone))),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedDepartment,
                          decoration: InputDecoration(labelText: l10n.commonDepartment, prefixIcon: const Icon(Icons.business)),
                          items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                          onChanged: (v) => setDialogState(() => selectedDepartment = v!),
                        ),
                        const SizedBox(height: 12),
                        // Multi-sélection des rôles via FilterChip (Wrap)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 6),
                            child: Text(l10n.commonRole, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: kAssignableRoles.map((r) {
                            final selected = selectedRoles.contains(r);
                            final color = _getRoleColor(r);
                            return FilterChip(
                              label: Text(r.displayName),
                              selected: selected,
                              selectedColor: color.withValues(alpha: 0.15),
                              checkmarkColor: color,
                              side: BorderSide(color: selected ? color : AppColors.border),
                              labelStyle: TextStyle(
                                color: selected ? color : AppColors.textPrimary,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                              onSelected: (value) => setDialogState(() {
                                if (value) {
                                  selectedRoles.add(r);
                                } else if (selectedRoles.length > 1) {
                                  selectedRoles.remove(r);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Pied (fixe) ─────────────────────────────────────────
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (firstNameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                          if (!isEdit && passCtrl.text.isEmpty) return;
                          if (selectedRoles.isEmpty) return;
                          final fullName = '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}'.trim();
                          final data = {
                            'first_name':  firstNameCtrl.text.trim(),
                            'last_name':   lastNameCtrl.text.trim(),
                            'name':        fullName,
                            'email':       emailCtrl.text,
                            'department':  selectedDepartment,
                            'roles':       selectedRoles.map((r) => r.apiName).toList(),
                            if (phoneCtrl.text.isNotEmpty) 'phone': phoneCtrl.text,
                            if (passCtrl.text.isNotEmpty)  'password': passCtrl.text,
                          };
                          try {
                            if (isEdit) {
                              await AuthApiService.instance.updateUser(user.id, data);
                            } else {
                              await AuthApiService.instance.createUser(data);
                            }
                            await DataService().reloadUsers();
                            if (mounted) setState(() {});
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(isEdit ? l10n.usersModified : l10n.usersCreated),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          } catch (e) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(AppLocalizations.of(context)!.commonApiError),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          }
                        },
                        child: Text(isEdit ? l10n.commonSave : l10n.commonCreate),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPermissionsDialog(User user) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.usersPermissionsTitle(user.name),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              _buildRolesBadges(user.roles),
              const SizedBox(height: 16),
              Text(l10n.usersActivePermissions, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.permissions.map((p) => Chip(
                  label: Text(p.displayName, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.successLight,
                  side: BorderSide.none,
                )).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pour modifier les permissions, rendez-vous dans l\'onglet Rôles.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleUserStatus(User user) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final newActive = await AuthApiService.instance.toggleUserStatus(user.id);
      await DataService().reloadUsers();
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newActive ? l10n.usersAccountActivated : l10n.usersAccountDeactivated),
          backgroundColor: newActive ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _confirmDeleteUser(User user) {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.usersDeleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.usersDeleteConfirm(user.name)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Raison de la suppression (optionnel)',
                hintText: 'Ex : Départ de l\'établissement, doublon…',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(ctx);
              try {
                await AuthApiService.instance.deleteUser(user.id, reason: reason.isEmpty ? null : reason);
                await DataService().reloadUsers();
                if (mounted) setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.usersDeleted),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(AppLocalizations.of(context)!.commonApiError),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}
