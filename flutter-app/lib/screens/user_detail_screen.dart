import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../services/data_service.dart';
import '../services/auth_api_service.dart';
import '../services/auth_service.dart';
import 'logs_screen.dart';

/// Demande de changement de département en attente pour un utilisateur.
class _DeptRequest {
  final String id;
  final String userId;
  final String currentDepartment;
  final String requestedDepartment;

  const _DeptRequest({
    required this.id,
    required this.userId,
    required this.currentDepartment,
    required this.requestedDepartment,
  });

  factory _DeptRequest.fromJson(Map<String, dynamic> j) => _DeptRequest(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    currentDepartment: j['current_department'] as String,
    requestedDepartment: j['requested_department'] as String,
  );
}

/// Page de détail administratif d'un utilisateur.
///
/// Affiche le profil complet, les alertes (téléphone manquant, demande de
/// département), les informations du compte et les actions d'administration.
class UserDetailScreen extends StatefulWidget {
  final User user;

  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late User _user;

  bool _togglingStatus = false;
  bool _deletingUser = false;
  bool _resolvingRequest = false;

  _DeptRequest? _pendingDeptRequest;
  bool _loadingDeptRequest = true;

  // ── Cycle de vie ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadPendingDeptRequest();
  }

  // ── Chargement ────────────────────────────────────────────────────────────

  Future<void> _loadPendingDeptRequest() async {
    setState(() => _loadingDeptRequest = true);
    try {
      await DataService().reloadDeptRequests();
      final match = DataService().deptRequests
          .map(_DeptRequest.fromJson)
          .where((r) => r.userId == _user.id)
          .firstOrNull;
      if (mounted) setState(() { _pendingDeptRequest = match; _loadingDeptRequest = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDeptRequest = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _toggleStatus() async {
    setState(() => _togglingStatus = true);
    try {
      final newActive = await AuthApiService.instance.toggleUserStatus(_user.id);
      await DataService().reloadUsers();
      if (mounted) {
        setState(() { _user = _user.copyWith(isActive: newActive); _togglingStatus = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newActive
              ? AppLocalizations.of(context)!.usersAccountActivated
              : AppLocalizations.of(context)!.usersAccountDeactivated),
          backgroundColor: newActive ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) { setState(() => _togglingStatus = false); _showErrorSnackBar(); }
    }
  }

  Future<void> _resolveDeptRequest(String status) async {
    if (_pendingDeptRequest == null) return;
    setState(() => _resolvingRequest = true);
    try {
      await AuthApiService.instance.resolveDepartmentRequest(
        _pendingDeptRequest!.id,
        status: status,
      );
      await DataService().reloadUsers();
      final updated = DataService().users.where((u) => u.id == _user.id).firstOrNull;
      if (mounted) {
        setState(() {
          _resolvingRequest = false;
          if (updated != null) _user = updated;
        });
      }
      await _loadPendingDeptRequest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'approved' ? 'Demande approuvée — département mis à jour' : 'Demande rejetée'),
          backgroundColor: status == 'approved' ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) { setState(() => _resolvingRequest = false); _showErrorSnackBar(); }
    }
  }

  Future<void> _confirmAndDeleteUser() async {
    final l10n = AppLocalizations.of(context)!;
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.usersDeleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.usersDeleteConfirm(_user.name)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Raison de la suppression (optionnel)',
                hintText: 'Ex : Départ de l\'établissement, doublon…',
              ),
              maxLines: 2,
            ),
          ],
        ),
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
    if (confirmed != true || !mounted) return;

    setState(() => _deletingUser = true);
    try {
      final reason = reasonCtrl.text.trim();
      await AuthApiService.instance.deleteUser(_user.id, reason: reason.isEmpty ? null : reason);
      await DataService().reloadUsers();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.usersDeleted),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) { setState(() => _deletingUser = false); _showErrorSnackBar(); }
    }
  }

  /// Dialogue de modification du profil (département, rôles, téléphone).
  void _showEditDialog() {
    final l10n = AppLocalizations.of(context)!;
    final firstNameCtrl = TextEditingController(text: _user.firstName);
    final lastNameCtrl  = TextEditingController(text: _user.lastName);
    final phoneCtrl     = TextEditingController(text: _user.phone ?? '');
    final Set<UserRole> selectedRoles = _user.roles
        .where(kAssignableRoles.contains).toSet();
    if (selectedRoles.isEmpty) selectedRoles.add(UserRole.hospitalStaff);
    String selectedDept = _user.department.isNotEmpty ? _user.department : 'IT';

    const departments = ['IT', 'Radiologie', 'Réanimation', 'Stérilisation', 'Laboratoire', 'Urgences', 'Maintenance', 'Infrastructure'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── En-tête ──────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.usersEditTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Corps scrollable ──────────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: TextField(controller: firstNameCtrl, decoration: const InputDecoration(labelText: 'Prénom', prefixIcon: Icon(Icons.person)))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: lastNameCtrl, decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.person)))),
                        ]),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneCtrl,
                          decoration: InputDecoration(labelText: l10n.usersPhone, prefixIcon: const Icon(Icons.phone)),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedDept,
                          decoration: InputDecoration(labelText: l10n.commonDepartment, prefixIcon: const Icon(Icons.business)),
                          items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                          onChanged: (v) => setDialogState(() => selectedDept = v!),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(l10n.commonRole, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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

                // ── Pied ─────────────────────────────────────────────────────
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (firstNameCtrl.text.trim().isEmpty) return;
                        if (selectedRoles.isEmpty) return;
                        final data = {
                          'first_name': firstNameCtrl.text.trim(),
                          'last_name':  lastNameCtrl.text.trim(),
                          'name': '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}'.trim(),
                          'department': selectedDept,
                          'roles': selectedRoles.map((r) => r.apiName).toList(),
                          if (phoneCtrl.text.isNotEmpty) 'phone': phoneCtrl.text.trim(),
                        };
                        try {
                          await AuthApiService.instance.updateUser(_user.id, data);
                          await DataService().reloadUsers();
                          final updated = DataService().users.where((u) => u.id == _user.id).firstOrNull;
                          if (mounted && updated != null) setState(() => _user = updated);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(l10n.usersModified),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        } catch (_) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) _showErrorSnackBar();
                        }
                      },
                      child: Text(l10n.commonSave),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.of(context)!.commonApiError),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Color _getRoleColor(UserRole role) => switch (role) {
    UserRole.admin                => AppColors.error,
    UserRole.supervisor           => AppColors.warning,
    UserRole.technicianBiomedical => AppColors.success,
    UserRole.technicianIt         => AppColors.primary,
    UserRole.technicianInfra      => AppColors.warning,
    UserRole.technician           => AppColors.success,
    UserRole.hospitalStaff        => AppColors.primary,
  };

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

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  // ── Build principal ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Text(_user.fullName),
        actions: [
          if (!isMobile) ...[
            if (_togglingStatus)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _user.isActive ? l10n.usersActive : l10n.usersInactive,
                      style: TextStyle(fontSize: 13, color: _user.isActive ? AppColors.success : AppColors.error),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _user.isActive,
                      onChanged: (_) => _toggleStatus(),
                      activeThumbColor: AppColors.success,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(isMobile: true, l10n: l10n),
                  const SizedBox(height: 16),
                  _buildAlertsSection(l10n),
                  const SizedBox(height: 16),
                  _buildInfoSection(l10n),
                  const SizedBox(height: 16),
                  _buildActionsSection(l10n),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileHeader(isMobile: false, l10n: l10n),
                        const SizedBox(height: 16),
                        _buildAlertsSection(l10n),
                        const SizedBox(height: 16),
                        _buildInfoSection(l10n),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 280,
                    child: _buildActionsSection(l10n),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Section 1 : Header du profil ─────────────────────────────────────────

  Widget _buildProfileHeader({required bool isMobile, required AppLocalizations l10n}) {
    final primaryRole = _primaryRoleOf(_user);
    final roleColor   = _getRoleColor(primaryRole);
    final initials    = _user.fullName.trim().isEmpty
        ? '?'
        : _user.fullName.trim().split(RegExp(r'\s+')).take(2)
            .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
            .join();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: isMobile ? 28 : 36,
                  backgroundColor: roleColor.withValues(alpha: 0.15),
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: roleColor,
                      fontSize: isMobile ? 20 : 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user.fullName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.email_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(child: Text(_user.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _user.roles.where(kAssignableRoles.contains).map(_buildRoleBadge).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Switch statut — visible uniquement sur mobile (sur desktop il est dans l'AppBar)
            if (isMobile) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _user.isActive ? l10n.usersActive : l10n.usersInactive,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _user.isActive ? AppColors.success : AppColors.error,
                    ),
                  ),
                  _togglingStatus
                      ? const SizedBox(width: 36, height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      : Switch(
                          value: _user.isActive,
                          onChanged: (_) => _toggleStatus(),
                          activeThumbColor: AppColors.success,
                        ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Section 2 : Alertes ───────────────────────────────────────────────────

  Widget _buildAlertsSection(AppLocalizations l10n) {
    final alerts = <Widget>[];

    // Bannière téléphone manquant
    if (_user.phone == null || _user.phone!.isEmpty) {
      alerts.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Numéro de téléphone manquant',
                style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
          ],
        ),
      ));
    }

    // Carte demande de changement de département en attente
    if (_loadingDeptRequest) {
      alerts.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ));
    } else if (_pendingDeptRequest != null) {
      final req = _pendingDeptRequest!;
      alerts.add(Card(
        color: AppColors.warningLight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.swap_horiz, color: AppColors.warning, size: 18),
                SizedBox(width: 8),
                Text('Demande de changement de département', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.warning)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildDeptChip(req.currentDepartment, label: 'Actuel')),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 16, color: AppColors.textMuted),
                ),
                Expanded(child: _buildDeptChip(req.requestedDepartment, label: 'Demandé', isTarget: true)),
              ]),
              const SizedBox(height: 12),
              _resolvingRequest
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _resolveDeptRequest('rejected'),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Rejeter'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _resolveDeptRequest('approved'),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Approuver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ]),
            ],
          ),
        ),
      ));
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Alertes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        ...alerts.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)),
      ],
    );
  }

  Widget _buildDeptChip(String dept, {required String label, bool isTarget = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isTarget ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isTarget ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: isTarget ? AppColors.primary : AppColors.textMuted, fontWeight: FontWeight.w500)),
          Text(dept, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isTarget ? AppColors.primary : AppColors.textPrimary)),
        ],
      ),
    );
  }

  // ── Section 3 : Informations du profil ───────────────────────────────────

  Widget _buildInfoSection(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informations du profil', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.business_outlined, l10n.commonDepartment,
                _user.department.isNotEmpty ? _user.department : '—'),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone_outlined, l10n.usersPhone,
                _user.phone?.isNotEmpty == true ? _user.phone! : '—'),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today_outlined, 'Membre depuis',
                _formatDate(_user.createdAt)),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.fingerprint_outlined, 'UUID Keycloak',
                _user.id.isNotEmpty ? _user.id : '—', monospace: true),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool monospace = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontFamily: monospace ? 'monospace' : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Section 4 : Actions d'administration ─────────────────────────────────

  Widget _buildActionsSection(AppLocalizations l10n) {
    final isSelf = _user.id == AuthService().currentUser?.id;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // Modifier le profil
            ElevatedButton.icon(
              onPressed: _showEditDialog,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Modifier le profil'),
            ),
            const SizedBox(height: 8),

            // Voir les logs d'activité (LogsScreen sans filtre pour l'instant)
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LogsScreen(
                    filteredUserId: _user.id,
                    filteredUserName: _user.fullName,
                  ),
                ),
              ),
              icon: const Icon(Icons.history_outlined, size: 18),
              label: const Text('Voir les logs d\'activité'),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Supprimer l'utilisateur — désactivé si c'est son propre compte
            Tooltip(
              message: isSelf ? 'Impossible de supprimer son propre compte' : '',
              child: ElevatedButton.icon(
                onPressed: (isSelf || _deletingUser) ? null : _confirmAndDeleteUser,
                icon: _deletingUser
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.delete_outline, size: 18),
                label: const Text('Supprimer l\'utilisateur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textMuted.withValues(alpha: 0.3),
                  disabledForegroundColor: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
