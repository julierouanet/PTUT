import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/user_role.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Écran Debug & Test — réservé aux administrateurs.
/// Permet d'exécuter des scénarios de test et de manipuler l'état des données.
class DebugTestScreen extends StatefulWidget {
  const DebugTestScreen({super.key});

  @override
  State<DebugTestScreen> createState() => _DebugTestScreenState();
}

class _DebugTestScreenState extends State<DebugTestScreen> {
  bool _isClearingIssues = false;

  // ── État des tests de notifications ─────────────────────────────────────────
  bool   _isScheduleActive = false;
  String? _scheduleInterval; // 'minute' | 'hour' | null
  bool   _loadingNotifyNow  = false;
  bool   _loadingSchedule   = false;

  // Mini-historique des 3 derniers envois (in-memory Flutter)
  final List<String> _notifyHistory = [];

  // ── Nettoyage de tous les incidents ─────────────────────────────────────────
  Future<void> _clearAllIssues() async {
    final l10n = AppLocalizations.of(context)!;

    // Dialogue de confirmation obligatoire — action destructive
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Text(l10n.debugClearIssuesTitle),
          ],
        ),
        content: Text(l10n.debugClearIssuesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.debugClearIssuesConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClearingIssues = true);
    try {
      final response = await ApiClient.post(
        '${ApiConfig.dbBaseUrl}/api/debug/clear-issues',
        {},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final deleted = body['deleted'] as int? ?? 0;
        await DataService().reloadIssues();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.debugClearIssuesSuccess(deleted)),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final error = body['error'] as String? ?? 'Erreur ${response.statusCode}';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.debugClearIssuesError(error)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.debugClearIssuesError(e.toString())),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isClearingIssues = false);
    }
  }

  // ── Tests de notifications ────────────────────────────────────────────────────

  Future<void> _sendNotifyNow() async {
    setState(() => _loadingNotifyNow = true);
    try {
      final result = await DbApiService.instance.debugNotifyNow();
      final msg = result['message'] as String? ?? 'Notification envoyée';
      _addHistory(msg);
      _showSnackBar(msg, success: true);
      // Recharge les notifs in-app pour mettre à jour le badge cloche
      await NotificationService().fetchFromApi();
    } catch (e) {
      _showSnackBar('Erreur : $e', success: false);
    } finally {
      if (mounted) setState(() => _loadingNotifyNow = false);
    }
  }

  Future<void> _startSchedule(String interval) async {
    // Capture avant l'await pour éviter l'utilisation de context après une gap asynchrone
    final startedMsg = AppLocalizations.of(context)!.debugNotifyStarted(interval);
    setState(() => _loadingSchedule = true);
    try {
      final result = await DbApiService.instance.debugNotifySchedule(interval);
      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            _isScheduleActive  = true;
            _scheduleInterval  = interval;
          });
        }
        _addHistory('Scheduling démarré ($interval)');
        _showSnackBar(startedMsg, success: true);
      }
    } catch (e) {
      _showSnackBar('Erreur : $e', success: false);
    } finally {
      if (mounted) setState(() => _loadingSchedule = false);
    }
  }

  Future<void> _stopSchedule() async {
    // Capture avant l'await pour éviter l'utilisation de context après une gap asynchrone
    final stoppedMsg       = AppLocalizations.of(context)!.debugNotifyStopped;
    final alreadyStoppedMsg = AppLocalizations.of(context)!.debugNotifyAlreadyStopped;
    setState(() => _loadingSchedule = true);
    try {
      final result = await DbApiService.instance.debugNotifySchedule('stop');
      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            _isScheduleActive = false;
            _scheduleInterval = null;
          });
        }
        final status = result['status'] as String? ?? 'stopped';
        final msg = status == 'already_stopped' ? alreadyStoppedMsg : stoppedMsg;
        _addHistory(msg);
        _showSnackBar(msg, success: true);
      }
    } catch (e) {
      _showSnackBar('Erreur : $e', success: false);
    } finally {
      if (mounted) setState(() => _loadingSchedule = false);
    }
  }

  /// Ajoute une entrée à l'historique (max 3 entrées).
  void _addHistory(String message) {
    if (!mounted) return;
    setState(() {
      _notifyHistory.insert(0, message);
      if (_notifyHistory.length > 3) _notifyHistory.removeLast();
    });
  }

  void _showSnackBar(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = AuthService().primaryRole == UserRole.admin;

    // Protection RBAC côté UI — double vérification après celle du nav
    if (!isAdmin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80, color: AppColors.error.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            Text(
              l10n.accessDenied,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(l10n.accessDeniedMessage, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Bandeau d'avertissement administrateur ───────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bug_report_outlined, color: AppColors.error, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.debugTitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(l10n.debugSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Section : Gestion de la Base de Données ──────────────────────────
          Text(
            l10n.debugDbSection,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.delete_sweep_outlined, color: AppColors.error, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.debugClearIssuesLabel,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.debugClearIssuesDesc,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isClearingIssues ? null : _clearAllIssues,
                    icon: _isClearingIssues
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.delete_forever),
                    label: Text(_isClearingIssues ? l10n.debugClearIssuesLoading : l10n.debugClearIssuesButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Section : Tests de Notifications ─────────────────────────────────
          Text(
            l10n.debugNotifySection,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avertissement scheduling in-memory
                  if (_isScheduleActive) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Text(
                        l10n.debugNotifyWarning(_scheduleInterval ?? ''),
                        style: TextStyle(fontSize: 12, color: AppColors.warning),
                      ),
                    ),
                  ],

                  // Bouton 1 : Notification immédiate
                  _buildNotifyButton(
                    label: l10n.debugNotifyNow,
                    icon: Icons.send_outlined,
                    loading: _loadingNotifyNow,
                    onPressed: _sendNotifyNow,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),

                  // Bouton 2 : Notif auto toutes les minutes
                  _buildNotifyButton(
                    label: l10n.debugNotifyMinute,
                    icon: Icons.timer_outlined,
                    loading: _loadingSchedule,
                    onPressed: () => _startSchedule('minute'),
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),

                  // Bouton 3 : Notif auto toutes les heures
                  _buildNotifyButton(
                    label: l10n.debugNotifyHour,
                    icon: Icons.schedule_outlined,
                    loading: _loadingSchedule,
                    onPressed: () => _startSchedule('hour'),
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),

                  // Bouton 4 : Stopper (grisé si aucune notif active)
                  _buildNotifyButton(
                    label: l10n.debugNotifyStop,
                    icon: Icons.stop_circle_outlined,
                    loading: _loadingSchedule,
                    onPressed: _isScheduleActive ? _stopSchedule : null,
                    color: AppColors.error,
                  ),

                  // Mini-historique des 3 derniers envois
                  if (_notifyHistory.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Derniers envois :',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._notifyHistory.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '• $e',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifyButton({
    required String label,
    required IconData icon,
    required bool loading,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed == null ? AppColors.border : color,
          foregroundColor: Colors.white,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
