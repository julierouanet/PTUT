import 'package:flutter/material.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

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

    final formattedDate = _formatDate(timestamp);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône action
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
                      ),
                      Text(formattedDate, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 2),
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

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1)  return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24)   return 'Il y a ${diff.inHours} h';
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
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
