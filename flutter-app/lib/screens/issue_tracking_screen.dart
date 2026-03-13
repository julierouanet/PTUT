import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../models/issue.dart';
import '../widgets/status_badge.dart';

/// Issue tracking screen - view and manage all issues
class IssueTrackingScreen extends StatefulWidget {
  final Function(int, {String? issueId}) onNavigate;

  const IssueTrackingScreen({super.key, required this.onNavigate});

  @override
  State<IssueTrackingScreen> createState() => _IssueTrackingScreenState();
}

class _IssueTrackingScreenState extends State<IssueTrackingScreen> {
  String _statusFilter = 'Tous';

  final List<String> _statuses = ['Tous', 'Ouvert', 'En cours', 'Résolu'];

  List<Issue> get _filteredIssues {
    if (_statusFilter == 'Tous') return mockIssues;
    return mockIssues.where((i) => i.status.displayName == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Summary stats
    final openCount = mockIssues.where((i) => i.status == IssueStatus.open).length;
    final inProgressCount = mockIssues.where((i) => i.status == IssueStatus.inProgress).length;
    final resolvedCount = mockIssues.where((i) => i.status == IssueStatus.resolved).length;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Suivi des incidents',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gérer et suivre les incidents des équipements',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Mini Summary Cards
            Row(
              children: [
                _buildMiniStat('Ouverts', openCount, AppColors.error),
                const SizedBox(width: 12),
                _buildMiniStat('En cours', inProgressCount, AppColors.warning),
                const SizedBox(width: 12),
                _buildMiniStat('Résolus', resolvedCount, AppColors.success),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => widget.onNavigate(3),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Signaler un incident'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter chips
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text('Filtrer par statut: ', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    ..._statuses.map((status) {
                      final isSelected = _statusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(status),
                          onSelected: (_) => setState(() => _statusFilter = status),
                          selectedColor: AppColors.primaryLight,
                          checkmarkColor: AppColors.primary,
                        ),
                      );
                    }),
                    const Spacer(),
                    Text(
                      '${_filteredIssues.length} incident(s)',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Issues List - FULL WIDTH
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Column(
                  children: _filteredIssues.map((issue) => _buildIssueItem(issue)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildIssueItem(Issue issue) {
    return InkWell(
      onTap: () => _showIssueDetail(issue),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getStatusColor(issue.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: _getStatusColor(issue.status),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.equipmentName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    issue.description,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Signalé par ${issue.reporter} • ${issue.createdAt}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            IssueStatusBadge(status: issue.status.displayName),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: () => _showIssueDetail(issue),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(IssueStatus status) {
    switch (status) {
      case IssueStatus.open:
        return AppColors.error;
      case IssueStatus.inProgress:
        return AppColors.warning;
      case IssueStatus.resolved:
        return AppColors.success;
    }
  }

  void _showIssueDetail(Issue issue) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Incident #${issue.id}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              IssueStatusBadge(status: issue.status.displayName),
              const SizedBox(height: 20),
              _buildDetailRow('Équipement', issue.equipmentName),
              _buildDetailRow('Type', issue.type),
              _buildDetailRow('Description', issue.description),
              _buildDetailRow('Signalé par', issue.reporter),
              _buildDetailRow('Date de signalement', issue.createdAt),
              if (issue.assignedTechnician != null)
                _buildDetailRow('Technicien assigné', issue.assignedTechnician!),
              if (issue.diagnosis != null)
                _buildDetailRow('Diagnostic', issue.diagnosis!),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onNavigate(4, issueId: issue.id);
                      },
                      icon: const Icon(Icons.build),
                      label: const Text('Mettre à jour'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
