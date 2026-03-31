import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/auth_api_service.dart';
import '../models/user.dart';
import '../models/user_role.dart';

/// User management screen - Admin only
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _roleFilter = 'all'; // internal key
  String _searchTerm = '';

  List<User> get _filteredUsers {
    return DataService().users.where((user) {
      final matchesSearch = user.name.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchTerm.toLowerCase());
      final matchesRole = _roleFilter == 'all' || user.role.displayName == _roleFilter;
      return matchesSearch && matchesRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final users = DataService().users;
    final roleStats = {
      'all': users.length,
      for (var role in UserRole.values) role.displayName: users.where((u) => u.role == role).length,
    };

    final isMobile = MediaQuery.of(context).size.width < 600;

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
                  SizedBox(width: w, child: _buildRoleCardWidget(l10n.usersTechnicians, roleStats[UserRole.technician.displayName]!, Icons.build, AppColors.success)),
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
                _buildRoleCard(l10n.usersTechnicians, roleStats[UserRole.technician.displayName]!, Icons.build, AppColors.success),
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
                          ...UserRole.values.map((role) => DropdownMenuItem(
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

            // Users table
            SizedBox(
              width: double.infinity,
              child: Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 340),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppColors.background),
                      columns: [
                        DataColumn(label: Text(l10n.usersUser)),
                        DataColumn(label: Text(l10n.commonEmail)),
                        DataColumn(label: Text(l10n.commonDepartment)),
                        DataColumn(label: Text(l10n.commonRole)),
                        DataColumn(label: Text(l10n.commonStatus)),
                        DataColumn(label: Text(l10n.commonActions)),
                      ],
                      rows: _filteredUsers.map((user) => DataRow(
                        cells: [
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.2),
                                child: Text(
                                  user.name.substring(0, 1).toUpperCase(),
                                  style: TextStyle(color: _getRoleColor(user.role), fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          )),
                          DataCell(Text(user.email)),
                          DataCell(Text(user.department)),
                          DataCell(_buildRoleBadge(user.role)),
                          DataCell(_buildStatusBadge(user.isActive, l10n)),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                color: AppColors.primary,
                                onPressed: () => _showUserDialog(user),
                                tooltip: l10n.commonEdit,
                              ),
                              IconButton(
                                icon: const Icon(Icons.key, size: 18),
                                color: AppColors.warning,
                                onPressed: () => _showPermissionsDialog(user),
                                tooltip: l10n.usersPermissions,
                              ),
                              IconButton(
                                icon: Icon(user.isActive ? Icons.block : Icons.check_circle, size: 18),
                                color: user.isActive ? AppColors.error : AppColors.success,
                                onPressed: () => _toggleUserStatus(user),
                                tooltip: user.isActive ? l10n.usersDisable : l10n.usersEnable,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                color: AppColors.error,
                                onPressed: () => _confirmDeleteUser(user),
                                tooltip: l10n.commonDelete,
                              ),
                            ],
                          )),
                        ],
                      )).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:         return AppColors.error;
      case UserRole.supervisor:    return AppColors.warning;
      case UserRole.technician:    return AppColors.success;
      case UserRole.hospitalStaff: return AppColors.primary;
    }
  }

  void _showUserDialog(User? user) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit        = user != null;
    final firstNameCtrl = TextEditingController(text: user?.firstName ?? '');
    final lastNameCtrl  = TextEditingController(text: user?.lastName ?? '');
    final emailCtrl     = TextEditingController(text: user?.email ?? '');
    final phoneCtrl     = TextEditingController(text: user?.phone ?? '');
    final passCtrl  = TextEditingController();
    String selectedRole       = user?.role.name ?? UserRole.hospitalStaff.name;
    String selectedDepartment = user?.department ?? 'IT';

    final departments = ['IT', 'Radiologie', 'Réanimation', 'Stérilisation', 'Laboratoire', 'Urgences', 'Maintenance', 'Infrastructure'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
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
                    Text(isEdit ? l10n.usersEditTitle : l10n.usersNewTitle,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),
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
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(labelText: l10n.commonRole, prefixIcon: const Icon(Icons.badge)),
                  items: UserRole.values.map((r) => DropdownMenuItem(value: r.name, child: Text(r.displayName))).toList(),
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
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
                          final fullName = '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}'.trim();
                          final data = {
                            'first_name':  firstNameCtrl.text.trim(),
                            'last_name':   lastNameCtrl.text.trim(),
                            'name':        fullName,
                            'email':       emailCtrl.text,
                            'department':  selectedDepartment,
                            'role':        selectedRole,
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
                                content: Text('Erreur: $e'),
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
              _buildRoleBadge(user.role),
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
              const SizedBox(height: 24),
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
          content: Text('Erreur: $e'),
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
                    content: Text('Erreur: $e'),
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
