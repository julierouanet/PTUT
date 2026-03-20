import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/auth_service.dart';
import '../models/issue.dart';

/// Technician update screen - update repair progress
class TechnicianUpdateScreen extends StatefulWidget {
  final String? issueId;

  const TechnicianUpdateScreen({super.key, this.issueId});

  @override
  State<TechnicianUpdateScreen> createState() => _TechnicianUpdateScreenState();
}

class _TechnicianUpdateScreenState extends State<TechnicianUpdateScreen> {
  String? _selectedIssueId;
  String _repairStatus = 'Diagnostic en cours';
  final _diagnosisController = TextEditingController();
  final _actionsController = TextEditingController();
  final _partsController = TextEditingController();

  final List<String> _repairStatuses = [
    'Diagnostic en cours',
    'Pièces commandées',
    'Réparation en cours',
    'Test en cours',
    'Réparé',
  ];

  List<Issue> get _openIssues => DataService().issues.where((i) =>
    i.status != IssueStatus.resolved
  ).toList();

  @override
  void initState() {
    super.initState();
    _selectedIssueId = widget.issueId;
    if (_selectedIssueId != null) {
      _loadIssueData();
    }
  }

  void _loadIssueData() {
    final issue = DataService().issues.where((i) => i.id == _selectedIssueId).firstOrNull;
    if (issue != null) {
      _diagnosisController.text = issue.diagnosis ?? '';
      _actionsController.text = issue.actions ?? '';
      _partsController.text = issue.partsReplaced ?? '';
    }
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _actionsController.dispose();
    _partsController.dispose();
    super.dispose();
  }

  Issue? get _selectedIssue {
    if (_selectedIssueId == null) return null;
    return DataService().issues.where((i) => i.id == _selectedIssueId).firstOrNull;
  }

  String _getRepairStatusDisplay(String status, AppLocalizations l10n) {
    switch (status) {
      case 'Diagnostic en cours': return l10n.techDiagnosisInProgress;
      case 'Pièces commandées': return l10n.techPartsOrdered;
      case 'Réparation en cours': return l10n.techRepairInProgress;
      case 'Test en cours': return l10n.techTestInProgress;
      case 'Réparé': return l10n.techRepaired;
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              l10n.techTitle,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.techSubtitle,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            if (_openIssues.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.techNoIssues,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            l10n.techAllResolved,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Issue selection
                        Text(
                          l10n.techSelectIssue,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedIssueId,
                          decoration: InputDecoration(
                            hintText: l10n.techSelectIssueHint,
                          ),
                          items: _openIssues.map((issue) => DropdownMenuItem(
                            value: issue.id,
                            child: Text('${issue.id} - ${issue.equipmentName}'),
                          )).toList(),
                          onChanged: (value) {
                            setState(() => _selectedIssueId = value);
                            _loadIssueData();
                          },
                        ),

                        if (_selectedIssue != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedIssue!.equipmentName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedIssue!.description,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.techReportedByDate(_selectedIssue!.reporter, _selectedIssue!.createdAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Repair status
                          Text(
                            l10n.techRepairStatus,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _repairStatus,
                            items: _repairStatuses.map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(_getRepairStatusDisplay(status, l10n)),
                            )).toList(),
                            onChanged: (value) => setState(() => _repairStatus = value!),
                          ),
                          const SizedBox(height: 24),

                          // Diagnosis
                          Text(
                            l10n.techDiagnosis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _diagnosisController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: l10n.techDiagnosisHint,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Actions taken
                          Text(
                            l10n.techActionsTaken,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _actionsController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: l10n.techActionsHint,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Parts replaced
                          Text(
                            l10n.techPartsReplaced,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _partsController,
                            decoration: InputDecoration(
                              hintText: l10n.techPartsHint,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Submit buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saveProgress,
                                  child: Text(l10n.techSave),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _repairStatus == 'Réparé' ? _markResolved : null,
                                  icon: const Icon(Icons.check),
                                  label: Text(l10n.techMarkResolved),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProgress() async {
    if (_selectedIssueId == null) return;
    final l10n = AppLocalizations.of(context)!;
    final technicianName = AuthService().currentUser?.name ?? 'Technicien';
    try {
      await DbApiService.instance.updateIssue(_selectedIssueId!, {
        'status':               'En cours',
        'assigned_technician':  technicianName,
        'diagnosis':            _diagnosisController.text.trim().isNotEmpty ? _diagnosisController.text.trim() : null,
        'actions':              _actionsController.text.trim().isNotEmpty ? _actionsController.text.trim() : null,
        'parts_replaced':       _partsController.text.trim().isNotEmpty ? _partsController.text.trim() : null,
      });
      await DataService().reloadIssues();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.save, color: Colors.white),
          const SizedBox(width: 12),
          Text(l10n.techProgressSaved),
        ]),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _markResolved() async {
    if (_selectedIssueId == null) return;
    final l10n = AppLocalizations.of(context)!;
    final technicianName = AuthService().currentUser?.name ?? 'Technicien';
    try {
      await DbApiService.instance.updateIssue(_selectedIssueId!, {
        'status':               'Résolu',
        'assigned_technician':  technicianName,
        'diagnosis':            _diagnosisController.text.trim().isNotEmpty ? _diagnosisController.text.trim() : null,
        'actions':              _actionsController.text.trim().isNotEmpty ? _actionsController.text.trim() : null,
        'parts_replaced':       _partsController.text.trim().isNotEmpty ? _partsController.text.trim() : null,
      });
      await DataService().reloadIssues();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Text(l10n.techIssueResolved),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      setState(() {
        _selectedIssueId = null;
        _diagnosisController.clear();
        _actionsController.clear();
        _partsController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}
