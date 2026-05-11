import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';

// ── Métadonnées des actions ───────────────────────────────────────────────────

const _kActionVisual = <String, (IconData, Color)>{
  'login':                (Icons.login,                    AppColors.success),
  'login_failed':         (Icons.no_accounts_outlined,     AppColors.error),
  'logout':               (Icons.logout,                   AppColors.textSecondary),
  'create_equipment':     (Icons.add_box_outlined,         AppColors.primary),
  'update_equipment':     (Icons.edit_outlined,            AppColors.warning),
  'delete_equipment':     (Icons.delete_outline,           AppColors.error),
  'restore_equipment':    (Icons.restore,                  AppColors.success),
  'add_maintenance':      (Icons.build_outlined,           AppColors.primary),
  'schedule_maintenance': (Icons.schedule,                 AppColors.primary),
  'create_issue':         (Icons.report_problem_outlined,  AppColors.warning),
  'update_issue':         (Icons.edit_outlined,            AppColors.warning),
  'delete_issue':         (Icons.delete_outline,           AppColors.error),
  'create_inventory':     (Icons.add_box_outlined,         AppColors.primary),
  'update_inventory':     (Icons.edit_outlined,            AppColors.warning),
  'restock_inventory':    (Icons.inventory_outlined,       AppColors.success),
  'delete_inventory':     (Icons.delete_outline,           AppColors.error),
  'create_user':          (Icons.person_add_outlined,      AppColors.primary),
  'update_user':          (Icons.manage_accounts_outlined, AppColors.warning),
  'delete_user':          (Icons.person_remove_outlined,   AppColors.error),
  'restore_user':         (Icons.person_add_alt_1,         AppColors.success),
  'change_password':      (Icons.lock_outline,             AppColors.warning),
  'change_name':          (Icons.badge_outlined,           AppColors.warning),
  'change_email':         (Icons.email_outlined,           AppColors.warning),
  'change_phone':         (Icons.phone_outlined,           AppColors.warning),
  'activate_user':        (Icons.check_circle_outline,     AppColors.success),
  'suspend_user':         (Icons.block_outlined,           AppColors.error),
};

String _actionLabel(String action, AppLocalizations l10n) => switch (action) {
  'login'                => l10n.logsActionLogin,
  'login_failed'         => l10n.logsActionLoginFailed,
  'logout'               => l10n.logsActionLogout,
  'create_equipment'     => l10n.logsActionCreateEquipment,
  'update_equipment'     => l10n.logsActionUpdateEquipment,
  'delete_equipment'     => l10n.logsActionDeleteEquipment,
  'restore_equipment'    => l10n.logsActionRestoreEquipment,
  'add_maintenance'      => l10n.logsActionAddMaintenance,
  'schedule_maintenance' => l10n.logsActionScheduleMaintenance,
  'create_issue'         => l10n.logsActionCreateIssue,
  'update_issue'         => l10n.logsActionUpdateIssue,
  'delete_issue'         => l10n.logsActionDeleteIssue,
  'create_inventory'     => l10n.logsActionCreateInventory,
  'update_inventory'     => l10n.logsActionUpdateInventory,
  'restock_inventory'    => l10n.logsActionRestockInventory,
  'delete_inventory'     => l10n.logsActionDeleteInventory,
  'create_user'          => l10n.logsActionCreateUser,
  'update_user'          => l10n.logsActionUpdateUser,
  'delete_user'          => l10n.logsActionDeleteUser,
  'restore_user'         => l10n.logsActionRestoreUser,
  'change_password'      => l10n.logsActionChangePassword,
  'change_name'          => l10n.logsActionChangeName,
  'change_email'         => l10n.logsActionChangeEmail,
  'change_phone'         => l10n.logsActionChangePhone,
  'activate_user'        => l10n.logsActionActivateUser,
  'suspend_user'         => l10n.logsActionSuspendUser,
  _                      => action,
};

const _kRestorableActions = {
  'delete_equipment', 'update_equipment',
  'delete_user', 'suspend_user',
  'change_name', 'change_email', 'change_phone', 'update_user',
};

/// Label du bouton "Restaurer" selon l'action
String _restoreLabelFor(String action, AppLocalizations l10n) => switch (action) {
  'delete_equipment' => l10n.logsRestoreEquipmentLabel,
  'update_equipment' => l10n.logsRestorePreviousState,
  'delete_user'      => l10n.logsRestoreUserAccount,
  'suspend_user'     => l10n.logsReactivateUserAccount,
  'change_name'      => l10n.logsRestoreOldName,
  'change_email'     => l10n.logsRestoreOldEmail,
  'change_phone'     => l10n.logsRestoreOldPhone,
  'update_user'      => l10n.logsRestorePreviousValues,
  _                  => l10n.logsRestoreGeneric,
};

/// Logique de restauration partagée entre la tuile et la fiche détail.
/// Retourne un message de succès, lève une exception en cas d'erreur.
Future<String> _executeRestore(Map<String, dynamic> log, AppLocalizations l10n) async {
  final action   = log['action']    as String? ?? '';
  final targetId = log['target_id'] as String?;

  Map<String, dynamic>? details;
  final raw = log['details'] as String?;
  if (raw != null) {
    try { details = Map<String, dynamic>.from(jsonDecode(raw) as Map); } catch (_) {}
  }

  switch (action) {
    case 'delete_equipment':
      final snap = details?['snapshot'];
      if (snap == null) throw l10n.logsErrSnapshotMissing;
      await DbApiService.instance.restoreEquipment(Map<String, dynamic>.from(snap as Map));
      return l10n.logsEquipmentRestored;

    case 'update_equipment':
      final snap = details?['snapshot_before'];
      if (snap == null || targetId == null) throw l10n.logsErrInsufficientData;
      await DbApiService.instance.restoreEquipmentState(targetId, Map<String, dynamic>.from(snap as Map));
      return l10n.logsEquipmentRestoredState;

    case 'delete_user':
      final snap = details?['snapshot'];
      if (snap == null) throw l10n.logsErrSnapshotMissing;
      final res = await DbApiService.instance.restoreDeletedUser(Map<String, dynamic>.from(snap as Map));
      final pwd = res['tempPassword'] as String? ?? '—';
      return l10n.logsUserAccountRestored(pwd);

    case 'suspend_user':
      if (targetId == null) throw l10n.logsErrUserIdMissing;
      await DbApiService.instance.toggleUser(targetId);
      return l10n.logsUserAccountReactivated;

    case 'change_name':
      if (targetId == null) throw l10n.logsErrUserIdMissing;
      final old = details?['old'] as String?;
      if (old == null) throw l10n.logsErrOldValueMissing;
      await DbApiService.instance.updateUser(targetId, {'name': old});
      return l10n.logsNameRestored(old);

    case 'change_email':
      if (targetId == null) throw l10n.logsErrUserIdMissing;
      final old = details?['old'] as String?;
      if (old == null) throw l10n.logsErrOldValueMissing;
      await DbApiService.instance.updateUser(targetId, {'email': old});
      return l10n.logsEmailRestored(old);

    case 'change_phone':
      if (targetId == null) throw l10n.logsErrUserIdMissing;
      final old = details?['old'] as String?;
      if (old == null) throw l10n.logsErrOldValueMissing;
      await DbApiService.instance.updateUser(targetId, {'phone': old});
      return l10n.logsPhoneRestored(old);

    case 'update_user':
      if (targetId == null) throw l10n.logsErrUserIdMissing;
      final restoreData = <String, dynamic>{};
      if (details?['role']       is Map) restoreData['role']       = (details!['role'] as Map)['old'];
      if (details?['department'] is Map) restoreData['department'] = (details!['department'] as Map)['old'];
      if (restoreData.isEmpty) throw l10n.logsErrNothingToRestore;
      await DbApiService.instance.updateUser(targetId, restoreData);
      return l10n.logsPreviousValuesRestored;

    default:
      throw l10n.logsErrNotRestorable;
  }
}

// ── Écran principal ───────────────────────────────────────────────────────────

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String? _error;

  String? _filterAction;
  String? _filterTargetType;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final logs = await DbApiService.instance.getLogs(
        action: _filterAction,
        targetType: _filterTargetType,
        limit: 500,
      );
      setState(() { _logs = logs; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _logs;
    return _logs.where((log) {
      final name   = (log['user_name']   as String? ?? '').toLowerCase();
      final target = (log['target_name'] as String? ?? '').toLowerCase();
      final action = (log['action']      as String? ?? '').toLowerCase();
      return name.contains(q) || target.contains(q) || action.contains(q);
    }).toList();
  }

  /// Vérifie si une action restaurable a déjà été restaurée (log de restauration
  /// trouvé APRÈS ce log pour le même target_id).
  bool _isAlreadyRestored(Map<String, dynamic> log) {
    final action   = log['action']    as String? ?? '';
    final targetId = log['target_id'] as String?;
    final ts       = log['timestamp'] as String? ?? '';
    if (targetId == null) return false;

    final restoreAction = switch (action) {
      'delete_equipment' || 'update_equipment' => 'restore_equipment',
      'delete_user'                            => 'restore_user',
      'suspend_user'                           => 'activate_user',
      _                                        => null,
    };
    if (restoreAction == null) return false;

    return _logs.any((l) =>
        l['action'] == restoreAction &&
        l['target_id'] == targetId &&
        (l['timestamp'] as String? ?? '').compareTo(ts) > 0);
  }

  /// Restauration rapide depuis la tuile (dialog de confirmation + snackbar résultat).
  Future<void> _quickRestore(BuildContext context, Map<String, dynamic> log) async {
    final l10n   = AppLocalizations.of(context)!;
    final action = log['action'] as String? ?? '';
    final label  = _restoreLabelFor(action, l10n);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logsConfirmRestoreTitle),
        content: Text(l10n.logsConfirmRestoreShort(label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.logsRestoreButton)),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      final msg = await _executeRestore(log, l10n);
      _load();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// Détecte les connexions depuis une nouvelle IP pour chaque utilisateur.
  /// Compare chronologiquement — la 1ère occurrence d'une IP par utilisateur
  /// est marquée comme nouvelle.
  Set<String> get _newIpLoginIds {
    final loginLogs = _logs
        .where((l) => l['action'] == 'login' && l['ip_address'] != null)
        .toList()
      ..sort((a, b) => (a['timestamp'] as String? ?? '')
          .compareTo(b['timestamp'] as String? ?? ''));

    final result = <String>{};
    final seenIps = <String, Set<String>>{}; // userId → IPs déjà vues

    for (final log in loginLogs) {
      final userId = log['user_id'] as String?;
      final ip     = log['ip_address'] as String?;
      final id     = log['id']?.toString();
      if (userId == null || ip == null || id == null) continue;

      seenIps[userId] ??= {};
      if (!seenIps[userId]!.contains(ip)) {
        result.add(id);
        seenIps[userId]!.add(ip);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n     = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final hPad     = isMobile ? 16.0 : 24.0;
    final filtered = _filtered;
    final newIpIds = _newIpLoginIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, hPad, hPad, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.logsTitle,
                        style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text(l10n.logsEntriesCount(filtered.length),
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: l10n.logsRefresh,
                style: IconButton.styleFrom(backgroundColor: AppColors.primaryLight, foregroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Filtres
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: isMobile
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildSearchBar(),
                  const SizedBox(height: 8),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: _buildFilterChips()),
                ])
              : Row(children: [
                  Expanded(child: _buildSearchBar()),
                  const SizedBox(width: 12),
                  _buildFilterChips(),
                ]),
        ),
        const SizedBox(height: 12),
        // En-tête colonnes (desktop uniquement)
        if (!isMobile)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 200, child: Text(l10n.logsColAction,       style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  const SizedBox(width: 16),
                  Expanded(flex: 2,   child: Text(l10n.logsColUser,          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  const SizedBox(width: 16),
                  Expanded(flex: 2,   child: Text(l10n.logsColResource,      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  const SizedBox(width: 16),
                  SizedBox(width: 160, child: Text(l10n.logsColIpDevice,     style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  const SizedBox(width: 16),
                  SizedBox(width: 130, child: Text(l10n.logsColTimestamp,    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                ],
              ),
            ),
          ),
        // Liste
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : filtered.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final log             = filtered[i];
                            final isNewIp         = newIpIds.contains(log['id']?.toString());
                            final alreadyRestored = _isAlreadyRestored(log);
                            return _buildLogTile(log, isMobile, isNewIp, alreadyRestored);
                          },
                        ),
        ),
      ],
    );
  }

  // ── Widgets filtres ──────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: l10n.logsSearchHint,
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        isDense: true,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildFilterChips() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        _chip(l10n.logsFilterAll,        _filterAction == null && _filterTargetType == null, () { setState(() { _filterAction = null; _filterTargetType = null; }); _load(); }),
        const SizedBox(width: 6),
        _chip(l10n.logsFilterAuth,       _filterTargetType == 'auth',      () { setState(() { _filterAction = null; _filterTargetType = _filterTargetType == 'auth'      ? null : 'auth'; });      _load(); }),
        const SizedBox(width: 6),
        _chip(l10n.logsFilterEquipment,  _filterTargetType == 'equipment', () { setState(() { _filterAction = null; _filterTargetType = _filterTargetType == 'equipment' ? null : 'equipment'; }); _load(); }),
        const SizedBox(width: 6),
        _chip(l10n.logsFilterIncidents,  _filterTargetType == 'issue',     () { setState(() { _filterAction = null; _filterTargetType = _filterTargetType == 'issue'     ? null : 'issue'; });     _load(); }),
        const SizedBox(width: 6),
        _chip(l10n.logsFilterInventory,  _filterTargetType == 'inventory', () { setState(() { _filterAction = null; _filterTargetType = _filterTargetType == 'inventory' ? null : 'inventory'; }); _load(); }),
        const SizedBox(width: 6),
        _chip(l10n.logsFilterUsers,      _filterTargetType == 'user',      () { setState(() { _filterAction = null; _filterTargetType = _filterTargetType == 'user'      ? null : 'user'; });      _load(); }),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryLight,
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  // ── Tuile de log ──────────────────────────────────────────────────────────────

  Widget _buildLogTile(Map<String, dynamic> log, bool isMobile, bool isNewIp, bool alreadyRestored) {
    final l10n       = AppLocalizations.of(context)!;
    final action     = log['action']      as String? ?? '';
    final visual     = _kActionVisual[action];
    final label      = _actionLabel(action, l10n);
    final icon       = visual?.$1 ?? Icons.info_outline;
    final color      = visual?.$2 ?? AppColors.textSecondary;
    final userName   = log['user_name']   as String? ?? '?';
    final userRole   = log['user_role']   as String? ?? '';
    final userId     = log['user_id']     as String?;
    final targetName = log['target_name'] as String?;
    final targetId   = log['target_id']   as String?;
    final timestamp  = log['timestamp']   as String? ?? '';
    final details    = log['details']     as String?;
    final ipAddress  = log['ip_address']  as String?;
    final userAgent  = log['user_agent']  as String?;

    final formattedDate = _formatDate(timestamp, l10n);
    final deviceType    = _parseDeviceType(userAgent);

    final actionIcon = Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );

    // Badge "nouvelle IP"
    final newIpBadge = isNewIp
        ? Tooltip(
            message: l10n.logsNewIpTooltip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 10, color: AppColors.warning),
                  const SizedBox(width: 3),
                  Text(l10n.logsNewIp, style: const TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
        : null;

    void onTap() => _showLogDetail(context, log, isNewIp, alreadyRestored);

    final canRestore   = _kRestorableActions.contains(action) && !alreadyRestored;
    final shortUserId  = userId  != null && userId.length  > 14 ? '${userId.substring(0, 14)}…'  : userId;
    final shortTargetId= targetId != null && targetId.length > 14 ? '${targetId.substring(0, 14)}…' : targetId;

    // Bouton restauration rapide
    Widget? restoreBtn;
    if (_kRestorableActions.contains(action)) {
      restoreBtn = Tooltip(
        message: alreadyRestored ? l10n.logsAlreadyRestored : _restoreLabelFor(action, l10n),
        child: IconButton(
          icon: Icon(
            alreadyRestored ? Icons.check_circle_outline : Icons.restore,
            size: 18,
            color: alreadyRestored ? AppColors.success : AppColors.primary,
          ),
          onPressed: canRestore ? () => _quickRestore(context, log) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      );
    }

    if (isMobile) {
      return Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                actionIcon,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13))),
                          if (newIpBadge != null) ...[newIpBadge, const SizedBox(width: 4)],
                          Text(formattedDate, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                children: [
                                  TextSpan(text: userName, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                                  TextSpan(text: ' · $userRole'),
                                  if (targetName != null) ...[
                                    const TextSpan(text: ' → '),
                                    TextSpan(text: targetName, style: const TextStyle(fontStyle: FontStyle.italic)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (restoreBtn != null) restoreBtn,
                        ],
                      ),
                      if (shortUserId != null || shortTargetId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [if (shortUserId != null) 'uid:$shortUserId', if (shortTargetId != null) 'rid:$shortTargetId'].join('  '),
                            style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontFamily: 'monospace'),
                          ),
                        ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(ipAddress ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          const SizedBox(width: 8),
                          Icon(deviceType == 'mobile' ? Icons.smartphone : Icons.computer, size: 11, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(deviceType == 'mobile' ? l10n.logsDeviceMobile : deviceType == 'desktop' ? l10n.logsDevicePc : '—',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                      if (details != null && details.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(_formatDetailsSummary(details, l10n), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Desktop
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Col 1 : icône + action
              SizedBox(
                width: 200,
                child: Row(
                  children: [
                    actionIcon,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          if (details != null && details.isNotEmpty)
                            Text(_formatDetailsSummary(details, l10n),
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Col 2 : utilisateur + rôle + ID + badge nouvelle IP
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(userName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis)),
                        if (newIpBadge != null) ...[const SizedBox(width: 6), newIpBadge],
                      ],
                    ),
                    Text(userRole, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    if (shortUserId != null)
                      Text(shortUserId, style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontFamily: 'monospace')),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Col 3 : ressource cible + ID
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    targetName != null
                        ? Text(targetName, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis)
                        : const Text('—', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    if (shortTargetId != null)
                      Text(shortTargetId, style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontFamily: 'monospace')),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Col 4 : IP + appareil
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Expanded(child: Text(ipAddress ?? '—',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                    Row(children: [
                      Icon(deviceType == 'mobile' ? Icons.smartphone : Icons.computer, size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(deviceType == 'mobile' ? l10n.logsDeviceMobile : deviceType == 'desktop' ? l10n.logsDevicePc : '—',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Col 5 : horodatage
              SizedBox(
                width: 130,
                child: Text(formattedDate,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    textAlign: TextAlign.right),
              ),
              // Col 6 : bouton restaurer
              SizedBox(
                width: 36,
                child: restoreBtn ?? const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom sheet détail ───────────────────────────────────────────────────────

  void _showLogDetail(BuildContext context, Map<String, dynamic> log, bool isNewIp, bool alreadyRestored) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _LogDetailSheet(log: log, isNewIp: isNewIp, alreadyRestored: alreadyRestored, onRestored: _load),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _parseDeviceType(String? ua) {
    if (ua == null) return 'unknown';
    final u = ua.toLowerCase();
    if (u.contains('mobile') || u.contains('android') || u.contains('iphone') ||
        u.contains('ipad')   || u.contains('ipod')    || u.contains('blackberry') ||
        u.contains('windows phone')) return 'mobile';
    return 'desktop';
  }

  String _formatDate(String iso, AppLocalizations l10n) {
    try {
      final dt   = DateTime.parse(iso.replaceFirst(' ', 'T')).toLocal();
      final now  = DateTime.now();
      final diff = now.difference(dt);
      final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      if (diff.inSeconds < 10)  return l10n.logsTimeJustNow;
      if (diff.inMinutes < 60)  return l10n.logsTimeWithMinutes(time, diff.inMinutes);
      if (diff.inHours   < 24)  return l10n.logsTimeWithHours(time, diff.inHours);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $time';
    } catch (_) {
      return iso;
    }
  }

  /// Résumé court des détails pour la liste (1 ligne)
  String _formatDetailsSummary(String json, AppLocalizations l10n) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      if (map.containsKey('old') && map.containsKey('new')) {
        return '${map['old']} → ${map['new']}';
      }
      if (map.containsKey('snapshot')) return l10n.logsDetailsSnapshotAvailable;
      if (map.containsKey('snapshot_before')) return l10n.logsDetailsPreviousAvailable;
      final parts = map.entries
          .where((e) => e.value is! Map)
          .map((e) => '${e.key}: ${e.value}')
          .take(3)
          .join(' · ');
      return parts;
    } catch (_) {
      return json.length > 60 ? '${json.substring(0, 60)}…' : json;
    }
  }

  Widget _buildError() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(l10n.logsLoadError, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_error ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: Text(l10n.logsRetry)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.list_alt_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(l10n.logsNoLogs, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(l10n.logsNoLogsSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Bottom sheet : détail d'un log ───────────────────────────────────────────

class _LogDetailSheet extends StatefulWidget {
  final Map<String, dynamic> log;
  final bool isNewIp;
  final bool alreadyRestored;
  final VoidCallback onRestored;

  const _LogDetailSheet({required this.log, required this.isNewIp, required this.alreadyRestored, required this.onRestored});

  @override
  State<_LogDetailSheet> createState() => _LogDetailSheetState();
}

class _LogDetailSheetState extends State<_LogDetailSheet> {
  bool _restoring = false;
  String? _restoreMessage;
  bool _restoreSuccess = false;

  Map<String, dynamic>? get _details {
    final raw = widget.log['details'] as String?;
    if (raw == null || raw.isEmpty) return null;
    try { return Map<String, dynamic>.from(jsonDecode(raw) as Map); } catch (_) { return null; }
  }

  String _restoreLabelOf(AppLocalizations l10n) =>
      _restoreLabelFor(widget.log['action'] as String? ?? '', l10n);

  Future<void> _doRestore() async {
    final l10n = AppLocalizations.of(context)!;
    final label = _restoreLabelOf(l10n);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logsConfirmRestoreTitle),
        content: Text(l10n.logsConfirmRestoreLong(label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.logsRestoreButton)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() { _restoring = true; _restoreMessage = null; });

    try {
      final msg = await _executeRestore(widget.log, l10n);
      setState(() { _restoreSuccess = true; _restoreMessage = msg; });
      widget.onRestored();
    } catch (e) {
      setState(() { _restoreSuccess = false; _restoreMessage = l10n.logsRestoreErrorPrefix(e.toString()); });
    } finally {
      setState(() { _restoring = false; });
    }
  }

  // ── Affichage des détails ────────────────────────────────────────────────────

  Widget _buildDetailsSection() {
    final l10n = AppLocalizations.of(context)!;
    final details = _details;
    if (details == null) return const SizedBox.shrink();
    final action = widget.log['action'] as String? ?? '';

    final rows = <Widget>[];

    // Snapshot (delete) : affiche tous les champs
    final snapshot = details['snapshot'] ?? details['snapshot_before'];
    if (snapshot is Map) {
      final snap = Map<String, dynamic>.from(snapshot);
      snap.remove('updated_at'); snap.remove('created_at'); snap.remove('password_hash');
      for (final e in snap.entries) {
        if (e.value == null || e.value.toString().isEmpty) continue;
        rows.add(_detailRow(_fieldLabel(e.key, l10n), e.value.toString()));
      }
    }
    // Changement old → new simple
    else if (details.containsKey('old') && details.containsKey('new')) {
      rows.add(_detailRow(l10n.logsDetailsBefore, details['old'].toString()));
      rows.add(_detailRow(l10n.logsDetailsAfter,  details['new'].toString()));
    }
    // Changements multiples (update_user : {role: {old,new}, department: {old,new}})
    else {
      for (final e in details.entries) {
        if (e.value is Map && (e.value as Map).containsKey('old')) {
          final m = e.value as Map;
          rows.add(_detailRow(_fieldLabel(e.key, l10n), '${m['old']} → ${m['new']}'));
        } else if (e.value != null) {
          rows.add(_detailRow(_fieldLabel(e.key, l10n), e.value.toString()));
        }
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return _section(
      icon: Icons.info_outline,
      title: _detailsSectionTitle(action, l10n),
      children: rows,
    );
  }

  String _detailsSectionTitle(String action, AppLocalizations l10n) => switch (action) {
    'delete_equipment' || 'delete_user' => l10n.logsSectionDeleteSnapshot,
    'update_equipment'                  => l10n.logsSectionStateBeforeChange,
    'suspend_user'                      => l10n.logsSectionUserStatus,
    _                                   => l10n.logsSectionDetails,
  };

  String _fieldLabel(String key, AppLocalizations l10n) => switch (key) {
    'id'            => l10n.logsFieldId,
    'name'          => l10n.commonName,
    'email'         => l10n.commonEmail,
    'role'          => l10n.commonRole,
    'department'    => l10n.commonDepartment,
    'phone'         => l10n.logsFieldPhone,
    'category'      => l10n.commonCategory,
    'status'        => l10n.logsFieldStatus,
    'serial_number' => l10n.logsFieldSerial,
    'supplier'      => l10n.logsFieldSupplier,
    'location'      => l10n.logsFieldLocation,
    'is_active'     => l10n.logsFieldActive,
    'new_status'    => l10n.logsFieldNewStatus,
    'reason'        => l10n.logsFieldReason,
    _               => key,
  };

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ── Vue utilisateur ──────────────────────────────────────────────────────────

  Future<void> _showUserDetail() async {
    final userId = widget.log['user_id'] as String?;
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => _UserDetailDialog(userId: userId),
    );
  }

  // ── Vue ressource ────────────────────────────────────────────────────────────

  Future<void> _showResourceDetail() async {
    final targetType = widget.log['target_type'] as String?;
    final targetId   = widget.log['target_id']   as String?;
    if (targetId == null) return;

    if (targetType == 'equipment') {
      showDialog(context: context, builder: (ctx) => _EquipmentDetailDialog(equipmentId: targetId));
    } else if (targetType == 'user') {
      showDialog(context: context, builder: (ctx) => _UserDetailDialog(userId: targetId));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n       = AppLocalizations.of(context)!;
    final action     = widget.log['action']      as String? ?? '';
    final visual     = _kActionVisual[action];
    final label      = _actionLabel(action, l10n);
    final icon       = visual?.$1 ?? Icons.info_outline;
    final color      = visual?.$2 ?? AppColors.textSecondary;
    final userName   = widget.log['user_name']   as String? ?? '?';
    final userRole   = widget.log['user_role']   as String? ?? '';
    final targetName = widget.log['target_name'] as String?;
    final targetType = widget.log['target_type'] as String?;
    final timestamp  = widget.log['timestamp']   as String? ?? '';
    final ipAddress  = widget.log['ip_address']  as String?;
    final userAgent  = widget.log['user_agent']  as String?;
    final userId     = widget.log['user_id']     as String?;
    final targetId   = widget.log['target_id']   as String?;

    final canViewUser     = userId != null;
    final canViewResource = targetId != null && (targetType == 'equipment' || targetType == 'user');

    final fullDate    = _fullDate(timestamp);
    final deviceLabel = _deviceLabel(userAgent, l10n);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Poignée
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          // En-tête : icône + label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
                      Text(fullDate, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          // Alerte nouvelle IP
          if (widget.isNewIp) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.logsAlertNewIpFull,
                        style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Divider(thickness: 1, color: AppColors.textMuted.withValues(alpha: 0.15)),
          // Corps scrollable
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section utilisateur
                  _section(
                    icon: Icons.person_outline,
                    title: l10n.logsUserLabel,
                    action: canViewUser ? TextButton.icon(
                      onPressed: _showUserDetail,
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: Text(l10n.logsViewProfile, style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ) : null,
                    children: [
                      _detailRow(l10n.commonName, userName),
                      _detailRow(l10n.commonRole, userRole),
                      if (userId != null) _detailRow(l10n.logsFieldId, userId),
                    ],
                  ),
                  // Section ressource
                  if (targetName != null || targetId != null)
                    _section(
                      icon: _targetIcon(targetType),
                      title: _targetTitle(targetType, l10n),
                      action: canViewResource ? TextButton.icon(
                        onPressed: _showResourceDetail,
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: Text(l10n.logsViewDetails, style: const TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      ) : null,
                      children: [
                        if (targetName != null) _detailRow(l10n.commonName,   targetName),
                        if (targetId   != null) _detailRow(l10n.logsFieldId,  targetId),
                        if (targetType != null) _detailRow(l10n.logsFieldType, targetType),
                      ],
                    ),
                  // Section détails spécifiques
                  _buildDetailsSection(),
                  // Section métadonnées
                  _section(
                    icon: Icons.dns_outlined,
                    title: l10n.logsMetadata,
                    children: [
                      _detailRow(l10n.logsFieldTimestamp,   fullDate),
                      _detailRow(l10n.logsFieldIp,          ipAddress ?? l10n.logsFieldIpUnknown),
                      _detailRow(l10n.logsFieldDeviceLabel, deviceLabel),
                      if (userAgent != null) _detailRow(l10n.logsFieldUserAgent, userAgent),
                    ],
                  ),
                  // Message de résultat de restauration
                  if (_restoreMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_restoreSuccess ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: (_restoreSuccess ? AppColors.success : AppColors.error).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_restoreSuccess ? Icons.check_circle_outline : Icons.error_outline,
                              color: _restoreSuccess ? AppColors.success : AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              _restoreMessage!,
                              style: TextStyle(fontSize: 13, color: _restoreSuccess ? AppColors.success : AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Bouton restaurer
                  if (_kRestorableActions.contains(widget.log['action'] as String? ?? '')) ...[
                    const SizedBox(height: 16),
                    if (widget.alreadyRestored)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                            const SizedBox(width: 8),
                            Text(l10n.logsAlreadyRestored, style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _restoring ? null : _doRestore,
                          icon: _restoring
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.restore),
                          label: Text(_restoring ? l10n.logsRestoring : _restoreLabelOf(l10n)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers UI ───────────────────────────────────────────────────────────────

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
              const Spacer(),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.12)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }

  String _fullDate(String iso) {
    try {
      final dt = DateTime.parse(iso.replaceFirst(' ', 'T')).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
             '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  String _deviceLabel(String? ua, AppLocalizations l10n) {
    if (ua == null) return l10n.logsDeviceUnknown;
    final u = ua.toLowerCase();
    if (u.contains('mobile') || u.contains('android') || u.contains('iphone')) return l10n.logsDeviceMobile;
    return l10n.logsDevicePc;
  }


  IconData _targetIcon(String? type) => switch (type) {
    'equipment' => Icons.medical_services_outlined,
    'user'      => Icons.person_outline,
    'issue'     => Icons.report_problem_outlined,
    'inventory' => Icons.inventory_outlined,
    'auth'      => Icons.lock_outline,
    _           => Icons.link,
  };

  String _targetTitle(String? type, AppLocalizations l10n) => switch (type) {
    'equipment' => l10n.logsTargetEquipment,
    'user'      => l10n.logsTargetUser,
    'issue'     => l10n.logsTargetIncident,
    'inventory' => l10n.logsTargetInventory,
    'auth'      => l10n.logsTargetAuth,
    _           => l10n.logsTargetResource,
  };
}

// ── Dialog : profil utilisateur ───────────────────────────────────────────────

class _UserDetailDialog extends StatefulWidget {
  final String userId;
  const _UserDetailDialog({required this.userId});

  @override
  State<_UserDetailDialog> createState() => _UserDetailDialogState();
}

class _UserDetailDialogState extends State<_UserDetailDialog> {
  Map<String, dynamic>? _user;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await DbApiService.instance.getUserById(widget.userId);
      if (mounted) setState(() => _user = user);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.person_outline, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(l10n.logsUserProfileTitle),
        ],
      ),
      content: _error != null
          ? Text(l10n.logsErrorLoading(_error!), style: const TextStyle(color: AppColors.error))
          : _user == null
              ? const SizedBox(width: 200, height: 80, child: Center(child: CircularProgressIndicator()))
              : _buildUserCard(l10n),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonClose)),
      ],
    );
  }

  Widget _buildUserCard(AppLocalizations l10n) {
    final u = _user!;
    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(l10n.commonName,         u['name']       as String? ?? '—'),
          _row(l10n.commonEmail,        u['email']      as String? ?? '—'),
          _row(l10n.commonRole,         u['role']       as String? ?? '—'),
          _row(l10n.commonDepartment,   u['department'] as String? ?? '—'),
          _row(l10n.logsFieldPhone,     u['phone']      as String? ?? '—'),
          _row(l10n.logsFieldStatus,    (u['is_active'] == 1 || u['is_active'] == true) ? l10n.logsUserStatusActive : l10n.logsUserStatusSuspended),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
      ],
    ),
  );
}

// ── Dialog : détail équipement ────────────────────────────────────────────────

class _EquipmentDetailDialog extends StatefulWidget {
  final String equipmentId;
  const _EquipmentDetailDialog({required this.equipmentId});

  @override
  State<_EquipmentDetailDialog> createState() => _EquipmentDetailDialogState();
}

class _EquipmentDetailDialogState extends State<_EquipmentDetailDialog> {
  Map<String, dynamic>? _equipment;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final eq = await DbApiService.instance.getEquipmentById(widget.equipmentId);
      if (mounted) setState(() => _equipment = eq);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.medical_services_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(l10n.logsEquipmentTitle),
        ],
      ),
      content: _error != null
          ? Text(
              _error!.contains('404') ? l10n.logsEquipmentNotFound : l10n.logsErrorLoading(_error!),
              style: const TextStyle(color: AppColors.error),
            )
          : _equipment == null
              ? const SizedBox(width: 200, height: 80, child: Center(child: CircularProgressIndicator()))
              : _buildEquipmentCard(l10n),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonClose)),
      ],
    );
  }

  Widget _buildEquipmentCard(AppLocalizations l10n) {
    final e = _equipment!;
    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(l10n.commonName,          e['name']          as String? ?? '—'),
          _row(l10n.commonCategory,      e['category']      as String? ?? '—'),
          _row(l10n.commonDepartment,    e['department']    as String? ?? '—'),
          _row(l10n.logsFieldStatus,     e['status']        as String? ?? '—'),
          _row(l10n.logsFieldSerial,     e['serial_number'] as String? ?? '—'),
          _row(l10n.logsFieldSupplier,   e['supplier']      as String? ?? '—'),
          _row(l10n.logsFieldLocation,   e['location']      as String? ?? '—'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
      ],
    ),
  );
}
