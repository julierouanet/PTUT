import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
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

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Mise à jour technicien',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mettre à jour le statut de réparation',
              style: TextStyle(color: AppColors.textSecondary),
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aucun incident en cours',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Tous les incidents ont été résolus',
                            style: TextStyle(color: AppColors.textSecondary),
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
                        const Text(
                          'Incident à mettre à jour',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedIssueId,
                          decoration: const InputDecoration(
                            hintText: 'Sélectionnez un incident',
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
                                  'Signalé par ${_selectedIssue!.reporter} le ${_selectedIssue!.createdAt}',
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
                          const Text(
                            'Statut de réparation',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _repairStatus,
                            items: _repairStatuses.map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            )).toList(),
                            onChanged: (value) => setState(() => _repairStatus = value!),
                          ),
                          const SizedBox(height: 24),

                          // Diagnosis
                          const Text(
                            'Diagnostic',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _diagnosisController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Décrivez le diagnostic...',
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Actions taken
                          const Text(
                            'Actions effectuées',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _actionsController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Décrivez les actions effectuées...',
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Parts replaced
                          const Text(
                            'Pièces remplacées',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _partsController,
                            decoration: const InputDecoration(
                              hintText: 'Ex: Capteur O2, Pompe à vide...',
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Submit buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saveProgress,
                                  child: const Text('Sauvegarder'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _repairStatus == 'Réparé' ? _markResolved : null,
                                  icon: const Icon(Icons.check),
                                  label: const Text('Marquer résolu'),
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

  void _saveProgress() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.save, color: Colors.white),
            SizedBox(width: 12),
            Text('Progression sauvegardée'),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _markResolved() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Incident marqué comme résolu!'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _selectedIssueId = null;
      _diagnosisController.clear();
      _actionsController.clear();
      _partsController.clear();
    });
  }
}
