import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../models/equipment.dart';

/// Reports screen - view reports and analytics
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Calculate statistics
    final total = DataService().equipment.length;
    final operational = DataService().equipment.where((e) => e.status == EquipmentStatus.operational).length;
    final maintenance = DataService().equipment.where((e) => e.status == EquipmentStatus.maintenance).length;
    final outOfService = DataService().equipment.where((e) => e.status == EquipmentStatus.outOfService).length;

    // Equipment by department
    final byDepartment = <String, int>{};
    for (final eq in DataService().equipment) {
      byDepartment[eq.department] = (byDepartment[eq.department] ?? 0) + 1;
    }

    // Equipment by category
    final byCategory = <String, int>{};
    for (final eq in DataService().equipment) {
      byCategory[eq.category] = (byCategory[eq.category] ?? 0) + 1;
    }

    // Issues statistics
    final totalIssues = DataService().issues.length;
    final openIssues = DataService().issues.where((i) => i.status.displayName == 'Ouvert').length;
    final resolvedIssues = DataService().issues.where((i) => i.status.displayName == 'Résolu').length;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (isMobile) ...[
            Text(l10n.reportsTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(l10n.reportsSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showExportDialog(context),
                icon: const Icon(Icons.file_download),
                label: Text(l10n.reportsExport),
              ),
            ),
          ] else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.reportsTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(l10n.reportsSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showExportDialog(context),
                  icon: const Icon(Icons.file_download),
                  label: Text(l10n.reportsExport),
                ),
              ],
            ),
          const SizedBox(height: 32),

          // Summary cards
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildSummaryCard(l10n.reportsTotalEquipment, '$total', Icons.inventory_2, AppColors.primary),
                  _buildSummaryCard(l10n.reportsAvailabilityRate, '${total == 0 ? 0 : (operational / total * 100).round()}%', Icons.check_circle, AppColors.success),
                  _buildSummaryCard(l10n.reportsTotalIssues, '$totalIssues', Icons.warning_amber, AppColors.warning),
                  _buildSummaryCard(l10n.reportsResolvedIssues, '$resolvedIssues', Icons.task_alt, AppColors.success),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Two column layout
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildStatusReport(l10n, total, operational, maintenance, outOfService)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildDepartmentReport(l10n, byDepartment)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildStatusReport(l10n, total, operational, maintenance, outOfService),
                  const SizedBox(height: 24),
                  _buildDepartmentReport(l10n, byDepartment),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Category and Issues reports
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildCategoryReport(l10n, byCategory)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildIssuesReport(l10n, totalIssues, openIssues, resolvedIssues)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildCategoryReport(l10n, byCategory),
                  const SizedBox(height: 24),
                  _buildIssuesReport(l10n, totalIssues, openIssues, resolvedIssues),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusReport(AppLocalizations l10n, int total, int operational, int maintenance, int outOfService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reportsStatusBreakdown,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _buildStatRow(l10n.reportsOperational, operational, total, AppColors.success),
            _buildStatRow(l10n.reportsInMaintenance, maintenance, total, AppColors.warning),
            _buildStatRow(l10n.reportsOutOfService, outOfService, total, AppColors.error),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int count, int total, Color color) {
    final percentage = (count / total * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('($percentage%)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDepartmentReport(AppLocalizations l10n, Map<String, int> byDepartment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reportsByDepartment,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            ...byDepartment.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${e.value}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryReport(AppLocalizations l10n, Map<String, int> byCategory) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reportsByCategory,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            ...byCategory.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${e.value}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesReport(AppLocalizations l10n, int total, int open, int resolved) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reportsIssueStats,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _buildStatRow(l10n.reportsOpenIssues, open, total, AppColors.error),
            _buildStatRow(l10n.reportsInProgressIssues, total - open - resolved, total, AppColors.warning),
            _buildStatRow(l10n.reportsResolvedIssuesLabel, resolved, total, AppColors.success),
          ],
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.reportsExportData),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart, color: AppColors.success),
              title: Text(l10n.reportsExportExcel),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.reportsExportExcelProgress),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: AppColors.error),
              title: Text(l10n.reportsExportPDF),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.reportsExportPDFProgress),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }
}
