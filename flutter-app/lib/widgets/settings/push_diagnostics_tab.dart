import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/db_api_service.dart';
import '../../models/push_subscription_admin.dart';
import '../../theme/app_theme.dart';

class PushDiagnosticsTab extends StatefulWidget {
  const PushDiagnosticsTab({super.key});

  @override
  State<PushDiagnosticsTab> createState() => _PushDiagnosticsTabState();
}

class _PushDiagnosticsTabState extends State<PushDiagnosticsTab> {
  List<PushSubscriptionAdmin> _subs = [];
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final subs = await DbApiService.instance.getPushSubscriptions();
      if (mounted) setState(() { _subs = subs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                Expanded(child: Text(l10n.pushDiagLegend,
                    style: const TextStyle(fontSize: 12, color: AppColors.primary))),
              ]),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_error)
              Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.commonApiError, style: const TextStyle(color: AppColors.error)),
              ))
            else if (_subs.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.pushDiagEmpty, style: const TextStyle(color: AppColors.textSecondary)),
              ))
            else
              ..._subs.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildSubCard(s, l10n),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCard(PushSubscriptionAdmin s, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(s.userName ?? s.userId,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              _statusBadge(
                icon: Icons.cloud_done_outlined,
                active: s.serverAccepted,
                neverSent: s.neverSent,
                label: l10n.pushDiagServerLabel,
              ),
              const SizedBox(width: 6),
              _statusBadge(
                icon: Icons.phone_iphone,
                active: s.deviceConfirmed,
                neverSent: s.neverSent,
                label: l10n.pushDiagDeviceLabel,
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 12, runSpacing: 4, children: [
              if (s.platform != null) _infoChip(Icons.devices, s.platform!),
              if (s.userRoles != null) _infoChip(Icons.badge_outlined, s.userRoles!),
              _infoChip(Icons.schedule, s.createdAt),
            ]),
            if (s.lastSentAt != null || s.lastSuccessAt != null || s.lastDeliveredAt != null) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 12, runSpacing: 4, children: [
                if (s.lastSentAt != null) Text('Envoyé : ${s.lastSentAt}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                if (s.lastSuccessAt != null) Text('Accepté : ${s.lastSuccessAt}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                if (s.lastDeliveredAt != null) Text('Confirmé : ${s.lastDeliveredAt}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ],
            if (s.lastError != null) ...[
              const SizedBox(height: 6),
              Text(s.lastError!, style: const TextStyle(fontSize: 12, color: AppColors.error)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge({required IconData icon, required bool active, required bool neverSent, required String label}) {
    final color = neverSent ? AppColors.textSecondary : (active ? AppColors.success : AppColors.error);
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]);
  }
}
