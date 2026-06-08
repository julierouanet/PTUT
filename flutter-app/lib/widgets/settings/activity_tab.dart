import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/db_api_service.dart';
import '../../theme/app_theme.dart';

class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  static const int _pageSize = 20;

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _filterAction;

  // Actions admin courantes pour le filtre
  static const _actionOptions = [
    'create_department', 'update_department', 'delete_department',
    'create_subcategory', 'update_subcategory', 'delete_subcategory',
    'create_user', 'update_user', 'delete_user',
    'create_equipment', 'update_equipment', 'delete_equipment',
    'create_role', 'delete_role', 'update_role_permissions',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() { _isLoading = true; _error = null; _logs = []; _hasMore = true; });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final data = await DbApiService.instance.getLogs(
        action: _filterAction,
        limit: _pageSize,
      );
      if (mounted) setState(() {
        if (reset) {
          _logs = data;
        } else {
          _logs.addAll(data);
        }
        _hasMore = data.length == _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final data = await DbApiService.instance.getLogs(
        action: _filterAction,
        limit: _pageSize,
      );
      if (mounted) setState(() {
        _logs.addAll(data);
        _hasMore = data.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filtre ─────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _filterAction,
                  decoration: InputDecoration(
                    labelText: l10n.settingsActivityFilter,
                    prefixIcon: const Icon(Icons.filter_list, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(l10n.commonAll)),
                    ..._actionOptions.map((a) => DropdownMenuItem<String?>(
                      value: a,
                      child: Text(a, style: const TextStyle(fontSize: 13)),
                    )),
                  ],
                  onChanged: (v) {
                    setState(() => _filterAction = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
                tooltip: 'Actualiser',
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Corps ──────────────────────────────────────────────────────
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(l10n.settingsEmptyList, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Card(
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _buildLogTile(_logs[i]),
            ),
          ),
        ),
        if (_hasMore) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoadingMore ? null : _loadMore,
              icon: _isLoadingMore
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.expand_more),
              label: Text(l10n.settingsLoadMore),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final action     = log['action'] as String? ?? '';
    final userName   = log['user_name'] as String? ?? '—';
    final targetName = log['target_name'] as String?;
    final timestamp  = log['timestamp'] as String? ?? '';
    final color      = _actionColor(action);

    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _actionShort(action),
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        targetName != null ? '$action — $targetName' : action,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$userName · $timestamp',
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }

  Color _actionColor(String action) {
    if (action.startsWith('create_')) return AppColors.success;
    if (action.startsWith('delete_')) return AppColors.error;
    if (action.startsWith('update_')) return AppColors.warning;
    return AppColors.primary;
  }

  String _actionShort(String action) {
    if (action.startsWith('create_')) return 'CRÉÉ';
    if (action.startsWith('delete_')) return 'SUPP.';
    if (action.startsWith('update_')) return 'MÀJ';
    return 'LOG';
  }
}
