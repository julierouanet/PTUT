import 'package:flutter/material.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String? _error;

  // Filtres
  String? _filterAction;
  String? _filterTargetType;
  final _searchController = TextEditingController();

  static const _actionLabels = {
    'login':              ('Connexion',        Icons.login,               AppColors.success),
    'login_failed':       ('Échec connexion',  Icons.login,               AppColors.error),
    'logout':             ('Déconnexion',      Icons.logout,              AppColors.textSecondary),
    'create_equipment':   ('Créer équipement', Icons.add_box_outlined,    AppColors.primary),
    'update_equipment':   ('Modif. équipement',Icons.edit_outlined,       AppColors.warning),
    'delete_equipment':   ('Suppr. équipement',Icons.delete_outline,      AppColors.error),
    'add_maintenance':    ('Maintenance',      Icons.build_outlined,      AppColors.primary),
    'schedule_maintenance':('Planif. maint.',  Icons.schedule,            AppColors.primary),
    'create_issue':       ('Signaler incident',Icons.report_problem_outlined, AppColors.warning),
    'update_issue':       ('Modif. incident',  Icons.edit_outlined,       AppColors.warning),
    'delete_issue':       ('Suppr. incident',  Icons.delete_outline,      AppColors.error),
    'create_inventory':   ('Créer article',    Icons.add_box_outlined,    AppColors.primary),
    'update_inventory':   ('Modif. stock',     Icons.edit_outlined,       AppColors.warning),
    'restock_inventory':  ('Réappro. stock',   Icons.inventory_outlined,  AppColors.success),
    'delete_inventory':   ('Suppr. article',   Icons.delete_outline,      AppColors.error),
    'create_user':        ('Créer compte',     Icons.person_add_outlined,  AppColors.primary),
    'update_user':        ('Modif. compte',    Icons.manage_accounts_outlined, AppColors.warning),
    'delete_user':        ('Suppr. compte',    Icons.person_remove_outlined, AppColors.error),
    'change_password':    ('Modif. mot de passe', Icons.lock_outline,     AppColors.warning),
    'change_name':        ('Modif. nom',       Icons.badge_outlined,      AppColors.warning),
    'change_email':       ('Modif. email',     Icons.email_outlined,      AppColors.warning),
    'change_phone':       ('Modif. téléphone', Icons.phone_outlined,      AppColors.warning),
    'activate_user':      ('Compte activé',    Icons.check_circle_outline, AppColors.success),
    'suspend_user':       ('Compte suspendu',  Icons.block_outlined,      AppColors.error),
  };

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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final hPad = isMobile ? 16.0 : 24.0;
    final filtered = _filtered;

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
                    Text('Journaux d\'activité', style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text('${filtered.length} entrée${filtered.length > 1 ? 's' : ''}', style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualiser',
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
        // En-tête colonnes desktop
        if (!isMobile)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 200, child: Text('Action', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  SizedBox(width: 16),
                  Expanded(flex: 2, child: Text('Utilisateur', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  SizedBox(width: 16),
                  Expanded(flex: 2, child: Text('Ressource', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  SizedBox(width: 16),
                  SizedBox(width: 160, child: Text('IP / Appareil', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  SizedBox(width: 16),
                  SizedBox(width: 130, child: Text('Horodatage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary), textAlign: TextAlign.right)),
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
                          itemBuilder: (ctx, i) => _buildLogTile(filtered[i], isMobile),
                        ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        hintText: 'Rechercher (utilisateur, ressource…)',
        prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
        isDense: true,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        _chip('Tout', _filterAction == null && _filterTargetType == null, () {
          setState(() { _filterAction = null; _filterTargetType = null; });
          _load();
        }),
        const SizedBox(width: 6),
        _chip('Auth', _filterTargetType == 'auth', () {
          setState(() { _filterAction = null; _filterTargetType = _filterTargetType == 'auth' ? null : 'auth'; });
          _load();
        }),
        const SizedBox(width: 6),
        _chip('Équipements', _filterTargetType == 'equipment', () {
          setState(() { _filterAction = null; _filterTargetType = _filterTargetType == 'equipment' ? null : 'equipment'; });
          _load();
        }),
        const SizedBox(width: 6),
        _chip('Incidents', _filterTargetType == 'issue', () {
          setState(() { _filterAction = null; _filterTargetType = _filterTargetType == 'issue' ? null : 'issue'; });
          _load();
        }),
        const SizedBox(width: 6),
        _chip('Inventaire', _filterTargetType == 'inventory', () {
          setState(() { _filterAction = null; _filterTargetType = _filterTargetType == 'inventory' ? null : 'inventory'; });
          _load();
        }),
        const SizedBox(width: 6),
        _chip('Utilisateurs', _filterTargetType == 'user', () {
          setState(() { _filterAction = null; _filterTargetType = _filterTargetType == 'user' ? null : 'user'; });
          _load();
        }),
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
      labelStyle: TextStyle(color: selected ? AppColors.primary : AppColors.textPrimary, fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log, bool isMobile) {
    final action  = log['action'] as String? ?? '';
    final meta    = _actionLabels[action];
    final label   = meta?.$1 ?? action;
    final icon    = meta?.$2 ?? Icons.info_outline;
    final color   = meta?.$3 ?? AppColors.textSecondary;

    final userName   = log['user_name']   as String? ?? '?';
    final userRole   = log['user_role']   as String? ?? '';
    final targetName = log['target_name'] as String?;
    final timestamp  = log['timestamp']   as String? ?? '';
    final details    = log['details']     as String?;
    final ipAddress  = log['ip_address']  as String?;
    final userAgent  = log['user_agent']  as String?;

    final formattedDate = _formatDate(timestamp);
    final deviceType    = _parseDeviceType(userAgent);

    // Icône colorée commune aux deux layouts
    final actionIcon = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );

    if (isMobile) {
      // ── Layout mobile : colonne verticale ──────────────────────────────────
      return Card(
        margin: const EdgeInsets.only(bottom: 6),
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
                        Text(formattedDate, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    RichText(
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
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(ipAddress ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(width: 8),
                        Icon(deviceType == 'mobile' ? Icons.smartphone : Icons.computer, size: 11, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(deviceType == 'mobile' ? 'Mobile' : deviceType == 'desktop' ? 'PC' : '—', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    if (details != null && details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(_formatDetails(details), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Layout desktop : ligne horizontale avec colonnes fixes ────────────────
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Col 1 : icône + action (200px)
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
                        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13), overflow: TextOverflow.ellipsis),
                        if (details != null && details.isNotEmpty)
                          Text(_formatDetails(details), style: const TextStyle(fontSize: 10, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Col 2 : utilisateur + rôle (flex 2)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                  Text(userRole, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Col 3 : ressource cible (flex 2)
            Expanded(
              flex: 2,
              child: targetName != null
                  ? Text(targetName, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis)
                  : const Text('—', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ),
            const SizedBox(width: 16),
            // Col 4 : IP + appareil (160px)
            SizedBox(
              width: 160,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Expanded(child: Text(ipAddress ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.textMuted), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(deviceType == 'mobile' ? Icons.smartphone : Icons.computer, size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(deviceType == 'mobile' ? 'Mobile' : deviceType == 'desktop' ? 'PC' : '—', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Col 5 : horodatage (130px, aligné à droite)
            SizedBox(
              width: 130,
              child: Text(formattedDate, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), textAlign: TextAlign.right),
            ),
          ],
        ),
      ),
    );
  }

  String _parseDeviceType(String? userAgent) {
    if (userAgent == null) return 'unknown';
    final ua = userAgent.toLowerCase();
    if (ua.contains('mobile') || ua.contains('android') || ua.contains('iphone') ||
        ua.contains('ipad') || ua.contains('ipod') || ua.contains('blackberry') ||
        ua.contains('windows phone')) return 'mobile';
    return 'desktop';
  }

  String _formatDate(String iso) {
    try {
      // SQLite CURRENT_TIMESTAMP uses space separator — normalize to ISO 8601
      final normalized = iso.replaceFirst(' ', 'T');
      final dt = DateTime.parse(normalized).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      if (diff.inSeconds < 10)  return 'À l\'instant';
      if (diff.inMinutes < 60)  return '$time (il y a ${diff.inMinutes} min)';
      if (diff.inHours < 24)    return '$time (il y a ${diff.inHours} h)';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $time';
    } catch (_) {
      return iso;
    }
  }

  String _formatDetails(String json) {
    try {
      // Transforme {"old_status":"Ouvert","new_status":"Résolu"} → "Ouvert → Résolu"
      final parts = json.replaceAll('{', '').replaceAll('}', '').replaceAll('"', '').split(',');
      return parts.map((p) => p.trim().replaceAll(':', ': ')).join(' · ');
    } catch (_) {
      return json;
    }
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text('Erreur de chargement', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_error ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt_outlined, size: 64, color: AppColors.textMuted),
          SizedBox(height: 16),
          Text('Aucun log trouvé', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          SizedBox(height: 8),
          Text('Les actions des utilisateurs apparaîtront ici.', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
