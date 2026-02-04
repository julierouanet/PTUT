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

  List<Issue> get _filteredIssues {
    if (_statusFilter == 'Tous') return mockIssues;
    return mockIssues.where((i) {
      switch (_statusFilter) {
        case 'Ouvert':
          return i.status == IssueStatus.open;
        case 'En cours':
          return i.status == IssueStatus.inProgress;
        case 'Résolu':
          return i.status == IssueStatus.resolved;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
                    'Suivi des incidents',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Gérer et suivre tous les incidents signalés',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => widget.onNavigate(3),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau signalement'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filter tabs
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  _buildFilterChip('Tous', mockIssues.length),
                  _buildFilterChip('Ouvert', mockIssues.where((i) => i.status == IssueStatus.open).length),
                  _buildFilterChip('En cours', mockIssues.where((i) => i.status == IssueStatus.inProgress).length),
                  _buildFilterChip('Résolu', mockIssues.where((i) => i.status == IssueStatus.resolved).length),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Issues list
          ..._filteredIssues.map((issue) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _showIssueDetail(issue),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      issue.equipmentName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '${issue.id} • ${issue.department}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IssueStatusBadge(status: issue.status.displayName),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      issue.description,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Signalé par ${issue.reporter}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          issue.createdAt,
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                        if (issue.assignedTechnician != null) ...[
                          const SizedBox(width: 16),
                          const Icon(Icons.build, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            issue.assignedTechnician!,
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _statusFilter == label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        selected: isSelected,
        label: Text('$label ($count)'),
        onSelected: (_) => setState(() => _statusFilter = label),
        selectedColor: AppColors.primaryLight,
        checkmarkColor: AppColors.primary,
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
          width: 600,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Incident ${issue.id}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),
                IssueStatusBadge(status: issue.status.displayName),
                const SizedBox(height: 24),
                _buildDetailRow('Équipement', issue.equipmentName),
                _buildDetailRow('Département', issue.department),
                _buildDetailRow('Type', issue.type),
                _buildDetailRow('Signalé par', issue.reporter),
                _buildDetailRow('Date', issue.createdAt),
                const Divider(height: 32),
                const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(issue.description),
                if (issue.assignedTechnician != null) ...[
                  const Divider(height: 32),
                  _buildDetailRow('Technicien assigné', issue.assignedTechnician!),
                ],
                if (issue.diagnosis != null) ...[
                  const SizedBox(height: 16),
                  const Text('Diagnostic', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(issue.diagnosis!),
                ],
                if (issue.actions != null) ...[
                  const SizedBox(height: 16),
                  const Text('Actions', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(issue.actions!),
                ],
                if (issue.partsReplaced != null && issue.partsReplaced!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDetailRow('Pièces remplacées', issue.partsReplaced!),
                ],
                const SizedBox(height: 24),
                if (issue.status != IssueStatus.resolved)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onNavigate(4, issueId: issue.id);
                      },
                      child: const Text('Mettre à jour'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
