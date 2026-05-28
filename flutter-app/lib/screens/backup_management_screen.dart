import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/backup.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';

/// Écran de gestion des sauvegardes — accessible uniquement aux admins (permission manageBackups).
class BackupManagementScreen extends StatefulWidget {
  const BackupManagementScreen({super.key});

  @override
  State<BackupManagementScreen> createState() => _BackupManagementScreenState();
}

class _BackupManagementScreenState extends State<BackupManagementScreen> {
  final BackupService _service = BackupService();

  // État local des paramètres d'automatisation (édition en cours)
  bool _autoEnabled = false;
  String _selectedSchedule = '0 0 * * *';

  // Libellés → expressions cron
  static const Map<String, String> _scheduleOptions = {
    '0 0 * * *':   'daily',   // Tous les jours à minuit
    '0 0 * * 0':   'weekly',  // Chaque semaine le dimanche
  };

  @override
  void initState() {
    super.initState();
    // Charger les données au premier rendu
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _service.loadBackupInfos();
      _syncLocalState();
    });
    _service.addListener(_onServiceChange);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onServiceChange() {
    if (mounted) _syncLocalState();
  }

  void _syncLocalState() {
    if (_service.settings != null) {
      setState(() {
        _autoEnabled       = _service.settings!.isAutomated;
        _selectedSchedule  = _service.settings!.cronSchedule;
        // Si l'expression cron n'est pas dans notre liste, on prend la première option
        if (!_scheduleOptions.containsKey(_selectedSchedule)) {
          _selectedSchedule = _scheduleOptions.keys.first;
        }
      });
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _triggerBackup() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _service.triggerManualBackup();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? l10n.backupTriggerSuccess
          : l10n.backupTriggerError(_service.lastError ?? '')),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _service.updateBackupSettings(
      cronSchedule: _selectedSchedule,
      isAutomated:  _autoEnabled,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? l10n.backupSettingsSaved
          : l10n.backupSettingsSaveError(_service.lastError ?? '')),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _downloadBackup(BackupRecord record) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _service.downloadBackup(record);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? l10n.backupDownloadSuccess
          : l10n.backupDownloadError(_service.lastError ?? '')),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n     = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        if (_service.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.backupLoading,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        if (_service.settings == null && _service.lastError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(l10n.backupLoadError,
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _service.loadBackupInfos,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.backupRetry),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête ──────────────────────────────────────────────────
              _buildHeader(l10n, isMobile),
              const SizedBox(height: 20),

              // ── Bandeau d'alerte critique ─────────────────────────────────
              _buildCriticalAlert(l10n),
              const SizedBox(height: 20),

              // ── Contenu principal : desktop = 2 colonnes / mobile = 1 ─────
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLastBackupCard(l10n),
                        const SizedBox(height: 16),
                        _buildTriggerCard(l10n),
                        const SizedBox(height: 16),
                        _buildAutomationCard(l10n),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Colonne gauche
                        Expanded(
                          child: Column(
                            children: [
                              _buildLastBackupCard(l10n),
                              const SizedBox(height: 16),
                              _buildTriggerCard(l10n),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Colonne droite
                        Expanded(child: _buildAutomationCard(l10n)),
                      ],
                    ),

              const SizedBox(height: 24),

              // ── Historique ────────────────────────────────────────────────
              _buildHistorySection(l10n),
            ],
          ),
        );
      },
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildHeader(AppLocalizations l10n, bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.backup_outlined,
              color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.backupTitle,
              style: TextStyle(
                  fontSize: isMobile ? 18 : 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            Text(
              l10n.backupSubtitle,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  /// Bandeau d'alerte rouge — rappel stockage externe.
  Widget _buildCriticalAlert(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.backupAlertTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                      fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.backupAlertMessage,
                  style: TextStyle(
                      color: AppColors.error.withValues(alpha: 0.85),
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Carte montrant le statut de la dernière sauvegarde.
  Widget _buildLastBackupCard(AppLocalizations l10n) {
    final last = _service.history.isNotEmpty ? _service.history.first : null;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  last == null
                      ? Icons.history_toggle_off
                      : (last.isSuccess
                          ? Icons.check_circle_outline
                          : Icons.error_outline),
                  color: last == null
                      ? AppColors.textSecondary
                      : (last.isSuccess ? AppColors.success : AppColors.error),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.backupLastStatus,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (last == null)
              Text(l10n.backupNoLastBackup,
                  style: const TextStyle(color: AppColors.textSecondary))
            else ...[
              _infoRow(l10n.backupDate, last.createdAt),
              const SizedBox(height: 8),
              _infoRow(
                  l10n.backupSize, last.fileSize ?? '—'),
              const SizedBox(height: 8),
              _infoRow(
                l10n.backupStatusLabel,
                last.isSuccess
                    ? l10n.backupStatusSuccess
                    : l10n.backupStatusError,
                valueColor:
                    last.isSuccess ? AppColors.success : AppColors.error,
              ),
              const SizedBox(height: 8),
              _infoRow(
                l10n.backupColType,
                last.isManual
                    ? l10n.backupTypeManual
                    : l10n.backupTypeAutomated,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Carte avec le bouton de déclenchement manuel.
  Widget _buildTriggerCard(AppLocalizations l10n) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _service.isTriggering ? null : _triggerBackup,
                icon: _service.isTriggering
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.backup_rounded),
                label: Text(
                  _service.isTriggering
                      ? l10n.backupTriggering
                      : l10n.backupTrigger,
                  style: const TextStyle(fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Carte de configuration de l'automatisation.
  Widget _buildAutomationCard(AppLocalizations l10n) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_outlined,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  l10n.backupAutomationSection,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Interrupteur activation
            Row(
              children: [
                Expanded(
                  child: Text(l10n.backupEnableAuto,
                      style: const TextStyle(color: AppColors.textPrimary)),
                ),
                Switch(
                  value: _autoEnabled,
                  activeThumbColor: AppColors.success,
                  activeTrackColor: AppColors.success.withValues(alpha: 0.4),
                  onChanged: (v) => setState(() => _autoEnabled = v),
                ),
              ],
            ),

            if (_autoEnabled) ...[
              const SizedBox(height: 14),
              Text(l10n.backupScheduleLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedSchedule,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                items: _scheduleOptions.entries.map((entry) {
                  final label = entry.value == 'daily'
                      ? l10n.backupScheduleDaily
                      : l10n.backupScheduleWeekly;
                  return DropdownMenuItem(
                      value: entry.key, child: Text(label));
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedSchedule = v);
                },
              ),
            ],

            const SizedBox(height: 16),

            // Bouton Enregistrer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _service.isSavingSettings ? null : _saveSettings,
                icon: _service.isSavingSettings
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(l10n.commonSave),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tableau de l'historique des sauvegardes.
  Widget _buildHistorySection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_outlined,
                color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              l10n.backupHistorySection,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_service.history.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(l10n.backupNoHistory,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          )
        else
          Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.background),
                  columns: [
                    DataColumn(
                        label: Text(l10n.backupColDate,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                fontSize: 12))),
                    DataColumn(
                        label: Text(l10n.backupColType,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                fontSize: 12))),
                    DataColumn(
                        label: Text(l10n.backupColSize,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                fontSize: 12))),
                    DataColumn(
                        label: Text(l10n.backupColStatus,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                fontSize: 12))),
                    DataColumn(
                        label: Text(l10n.backupColAction,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                fontSize: 12))),
                  ],
                  rows: _service.history.map((record) {
                    return DataRow(cells: [
                      DataCell(Text(record.createdAt,
                          style: const TextStyle(fontSize: 13))),
                      DataCell(_typeBadge(l10n, record)),
                      DataCell(Text(record.fileSize ?? '—',
                          style: const TextStyle(fontSize: 13))),
                      DataCell(_statusBadge(l10n, record)),
                      DataCell(
                        record.isSuccess
                            ? TextButton.icon(
                                onPressed: () => _downloadBackup(record),
                                icon: const Icon(Icons.download_outlined,
                                    size: 16),
                                label: Text(l10n.backupDownload,
                                    style: const TextStyle(fontSize: 13)),
                                style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Widgets utilitaires ────────────────────────────────────────────────────

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight:
                      valueColor != null ? FontWeight.w600 : FontWeight.normal)),
        ),
      ],
    );
  }

  Widget _statusBadge(AppLocalizations l10n, BackupRecord record) {
    final ok    = record.isSuccess;
    final label = ok ? l10n.backupStatusSuccess : l10n.backupStatusError;
    final color = ok ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _typeBadge(AppLocalizations l10n, BackupRecord record) {
    final isManual = record.isManual;
    final label    = isManual ? l10n.backupTypeManual : l10n.backupTypeAutomated;
    final color    = isManual ? AppColors.primary : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
