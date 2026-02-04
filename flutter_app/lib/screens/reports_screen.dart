import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../models/equipment.dart';

/// Reports screen - view reports and analytics
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Calculate statistics
    final total = mockEquipment.length;
    final disponible = mockEquipment.where((e) => e.status == EquipmentStatus.disponible).length;
    final enUsage = mockEquipment.where((e) => e.status == EquipmentStatus.enUsage).length;
    final enMaintenance = mockEquipment.where((e) => e.status == EquipmentStatus.enMaintenance).length;
    final horsService = mockEquipment.where((e) => e.status == EquipmentStatus.horsService).length;

    // Equipment by department
    final byDepartment = <String, int>{};
    for (final eq in mockEquipment) {
      byDepartment[eq.department] = (byDepartment[eq.department] ?? 0) + 1;
    }

    // Equipment by category
    final byCategory = <String, int>{};
    for (final eq in mockEquipment) {
      byCategory[eq.category] = (byCategory[eq.category] ?? 0) + 1;
    }

    // Issues statistics
    final totalIssues = mockIssues.length;
    final openIssues = mockIssues.where((i) => i.status.displayName == 'Ouvert').length;
    final resolvedIssues = mockIssues.where((i) => i.status.displayName == 'Résolu').length;

    return SingleChildScrollView(
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
                    'Rapports et Analyses',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Vue d'ensemble des statistiques",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showExportDialog(context),
                icon: const Icon(Icons.file_download),
                label: const Text('Exporter'),
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
                  _buildSummaryCard('Total équipements', '$total', Icons.inventory_2, AppColors.primary),
                  _buildSummaryCard('Taux disponibilité', '${((disponible + enUsage) / total * 100).round()}%', Icons.check_circle, AppColors.success),
                  _buildSummaryCard('Total incidents', '$totalIssues', Icons.warning_amber, AppColors.warning),
                  _buildSummaryCard('Incidents résolus', '$resolvedIssues', Icons.task_alt, AppColors.success),
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
                    Expanded(child: _buildStatusReport(total, disponible, enUsage, enMaintenance, horsService)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildDepartmentReport(byDepartment)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildStatusReport(total, disponible, enUsage, enMaintenance, horsService),
                  const SizedBox(height: 24),
                  _buildDepartmentReport(byDepartment),
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
                    Expanded(child: _buildCategoryReport(byCategory)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildIssuesReport(totalIssues, openIssues, resolvedIssues)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildCategoryReport(byCategory),
                  const SizedBox(height: 24),
                  _buildIssuesReport(totalIssues, openIssues, resolvedIssues),
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

  Widget _buildStatusReport(int total, int disponible, int enUsage, int enMaintenance, int horsService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Répartition par statut',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _buildStatRow('Disponible', disponible, total, AppColors.success),
            _buildStatRow('En usage', enUsage, total, AppColors.primary),
            _buildStatRow('En maintenance', enMaintenance, total, AppColors.warning),
            _buildStatRow('Hors service', horsService, total, AppColors.error),
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

  Widget _buildDepartmentReport(Map<String, int> byDepartment) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Équipements par département',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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

  Widget _buildCategoryReport(Map<String, int> byCategory) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Équipements par catégorie',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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

  Widget _buildIssuesReport(int total, int open, int resolved) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistiques des incidents',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _buildStatRow('Ouverts', open, total, AppColors.error),
            _buildStatRow('En cours', total - open - resolved, total, AppColors.warning),
            _buildStatRow('Résolus', resolved, total, AppColors.success),
          ],
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exporter les données'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart, color: AppColors.success),
              title: const Text('Exporter en Excel'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Export Excel en cours...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: AppColors.error),
              title: const Text('Exporter en PDF'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Export PDF en cours...'),
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
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}
