import 'package:flutter/material.dart';
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
  String _roleFilter = 'Tous';
  String _searchTerm = '';

  List<User> get _filteredUsers {
    return DataService().users.where((user) {
      final matchesSearch = user.name.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchTerm.toLowerCase());
      final matchesRole = _roleFilter == 'Tous' || user.role.displayName == _roleFilter;
      return matchesSearch && matchesRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final users = DataService().users;
    final roleStats = {
      'Tous': users.length,
      for (var role in UserRole.values) role.displayName: users.where((u) => u.role == role).length,
    };

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestion des utilisateurs',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text("Gérer les comptes et les rôles des utilisateurs",
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showUserDialog(null),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Nouvel utilisateur'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Role summary cards
            Row(
              children: [
                _buildRoleCard('Total', users.length, Icons.people, AppColors.primary),
                const SizedBox(width: 12),
                _buildRoleCard('Admins', roleStats[UserRole.admin.displayName]!, Icons.admin_panel_settings, AppColors.error),
                const SizedBox(width: 12),
                _buildRoleCard('Superviseurs', roleStats[UserRole.supervisor.displayName]!, Icons.supervisor_account, AppColors.warning),
                const SizedBox(width: 12),
                _buildRoleCard('Techniciens', roleStats[UserRole.technician.displayName]!, Icons.build, AppColors.success),
                const SizedBox(width: 12),
                _buildRoleCard('Personnel', roleStats[UserRole.hospitalStaff.displayName]!, Icons.medical_services, AppColors.primary),
              ],
            ),
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
                        decoration: const InputDecoration(
                          hintText: 'Rechercher par nom ou email...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _roleFilter,
                        decoration: const InputDecoration(labelText: 'Filtrer par rôle', isDense: true),
                        items: roleStats.keys.map((role) => DropdownMenuItem(
                          value: role,
                          child: Text('$role (${roleStats[role]})'),
                        )).toList(),
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
                      columns: const [
                        DataColumn(label: Text('Utilisateur')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Département')),
                        DataColumn(label: Text('Rôle')),
                        DataColumn(label: Text('Statut')),
                        DataColumn(label: Text('Actions')),
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
                              Text(user.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          )),
                          DataCell(Text(user.email)),
                          DataCell(Text(user.department)),
                          DataCell(_buildRoleBadge(user.role)),
                          DataCell(_buildStatusBadge(user.isActive)),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                color: AppColors.primary,
                                onPressed: () => _showUserDialog(user),
                                tooltip: 'Modifier',
                              ),
                              IconButton(
                                icon: const Icon(Icons.key, size: 18),
                                color: AppColors.warning,
                                onPressed: () => _showPermissionsDialog(user),
                                tooltip: 'Permissions',
                              ),
                              IconButton(
                                icon: Icon(user.isActive ? Icons.block : Icons.check_circle, size: 18),
                                color: user.isActive ? AppColors.error : AppColors.success,
                                onPressed: () => _toggleUserStatus(user),
                                tooltip: user.isActive ? 'Désactiver' : 'Activer',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                color: AppColors.error,
                                onPressed: () => _confirmDeleteUser(user),
                                tooltip: 'Supprimer',
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

  Widget _buildRoleCard(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Card(
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
      ),
    );
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

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successLight : AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Actif' : 'Inactif',
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
    final isEdit   = user != null;
    final nameCtrl  = TextEditingController(text: user?.name ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final passCtrl  = TextEditingController();
    String selectedRole       = user?.role.name ?? UserRole.hospitalStaff.name;
    String selectedDepartment = user?.department ?? 'IT';

    final departments = ['IT', 'Radiologie', 'Réanimation', 'Stérilisation', 'Laboratoire', 'Urgences', 'Maintenance', 'Infrastructure'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEdit ? 'Modifier utilisateur' : 'Nouvel utilisateur',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(controller: nameCtrl,  decoration: const InputDecoration(labelText: 'Nom complet *', prefixIcon: Icon(Icons.person))),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email *', prefixIcon: Icon(Icons.email))),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: isEdit ? 'Nouveau mot de passe (laisser vide = inchangé)' : 'Mot de passe *',
                    prefixIcon: const Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDepartment,
                  decoration: const InputDecoration(labelText: 'Département', prefixIcon: Icon(Icons.business)),
                  items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setDialogState(() => selectedDepartment = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Rôle', prefixIcon: Icon(Icons.badge)),
                  items: UserRole.values.map((r) => DropdownMenuItem(value: r.name, child: Text(r.displayName))).toList(),
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler'))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                          if (!isEdit && passCtrl.text.isEmpty) return;
                          final data = {
                            'name':       nameCtrl.text,
                            'email':      emailCtrl.text,
                            'department': selectedDepartment,
                            'role':       selectedRole,
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
                                content: Text(isEdit ? 'Utilisateur modifié' : 'Utilisateur créé'),
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
                        child: Text(isEdit ? 'Enregistrer' : 'Créer'),
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
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Permissions — ${user.name}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              _buildRoleBadge(user.role),
              const SizedBox(height: 16),
              const Text('Permissions actives:', style: TextStyle(fontWeight: FontWeight.w500)),
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
                child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleUserStatus(User user) async {
    try {
      final newActive = await AuthApiService.instance.toggleUserStatus(user.id);
      await DataService().reloadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newActive ? 'Compte activé' : 'Compte désactivé'),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur'),
        content: Text('Supprimer le compte de "${user.name}" ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AuthApiService.instance.deleteUser(user.id);
                await DataService().reloadUsers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Utilisateur supprimé'),
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
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
