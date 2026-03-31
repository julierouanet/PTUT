import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/issue.dart';
import '../widgets/status_badge.dart';

/// Technician update screen - two tabs: available incidents & my interventions
class TechnicianUpdateScreen extends StatefulWidget {
  final String? issueId;

  const TechnicianUpdateScreen({super.key, this.issueId});

  @override
  State<TechnicianUpdateScreen> createState() => _TechnicianUpdateScreenState();
}

class _TechnicianUpdateScreenState extends State<TechnicianUpdateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Onglet "Mes interventions" ──────────────────────────────────────────────
  String? _selectedIssueId;
  String _repairStatus = 'Diagnostic en cours';
  final _diagnosisController = TextEditingController();
  final _actionsController   = TextEditingController();
  final _partsController     = TextEditingController();
  bool _isSaving = false;

  final List<String> _repairStatuses = [
    'Diagnostic en cours',
    'Pièces commandées',
    'Réparation en cours',
    'Test en cours',
    'Réparé',
  ];

  // ── Données ─────────────────────────────────────────────────────────────────

  String get _currentTechnicianName => AuthService().currentUser?.fullName ?? '';

  /// Incidents approuvés (non encore assignés) — disponibles à prendre en charge
  List<Issue> get _availableIssues => DataService().issues
      .where((i) => i.status == IssueStatus.approved)
      .toList();

  /// Incidents en cours assignés à ce technicien
  List<Issue> get _myIssues => DataService().issues
      .where((i) =>
          i.status == IssueStatus.inProgress &&
          i.assignedTechnician == _currentTechnicianName)
      .toList();

  Issue? get _selectedIssue {
    if (_selectedIssueId == null) return null;
    return DataService().issues.where((i) => i.id == _selectedIssueId).firstOrNull;
  }

  // ── Init / Dispose ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Si on arrive avec un issueId (depuis détail), ouvrir directement "Mes interventions"
    final startTab = widget.issueId != null ? 1 : 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: startTab);
    if (widget.issueId != null) {
      _selectedIssueId = widget.issueId;
      _loadIssueData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _diagnosisController.dispose();
    _actionsController.dispose();
    _partsController.dispose();
    super.dispose();
  }

  void _loadIssueData() {
    final issue = DataService().issues.where((i) => i.id == _selectedIssueId).firstOrNull;
    if (issue != null) {
      _diagnosisController.text = issue.diagnosis     ?? '';
      _actionsController.text   = issue.actions       ?? '';
      _partsController.text     = issue.partsReplaced ?? '';
    }
  }

  String _getRepairStatusDisplay(String status, AppLocalizations l10n) {
    switch (status) {
      case 'Diagnostic en cours': return l10n.techDiagnosisInProgress;
      case 'Pièces commandées':   return l10n.techPartsOrdered;
      case 'Réparation en cours': return l10n.techRepairInProgress;
      case 'Test en cours':       return l10n.techTestInProgress;
      case 'Réparé':              return l10n.techRepaired;
      default:                    return status;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n    = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      children: [
        // ── TabBar ──────────────────────────────────────────────────────────
        Material(
          color: Theme.of(context).cardColor,
          elevation: 1,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(
                icon: Badge(
                  isLabelVisible: _availableIssues.isNotEmpty,
                  label: Text('${_availableIssues.length}'),
                  child: const Icon(Icons.inbox_outlined, size: 18),
                ),
                text: 'Incidents disponibles',
              ),
              Tab(
                icon: Badge(
                  isLabelVisible: _myIssues.isNotEmpty,
                  label: Text('${_myIssues.length}'),
                  child: const Icon(Icons.build_outlined, size: 18),
                ),
                text: 'Mes interventions',
              ),
            ],
          ),
        ),

        // ── TabBarView ──────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAvailableTab(l10n, isMobile),
              _buildMyInterventionsTab(l10n, isMobile),
            ],
          ),
        ),
      ],
    );
  }

  // ── Onglet 0 : Incidents disponibles ────────────────────────────────────────

  Widget _buildAvailableTab(AppLocalizations l10n, bool isMobile) {
    final issues = _availableIssues;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incidents disponibles',
              style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Incidents approuvés en attente d\'un technicien — prenez en charge ceux que vous souhaitez traiter.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: Card(
                child: issues.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.check_circle_outline, color: AppColors.success, size: 24),
                          SizedBox(width: 12),
                          Text('Aucun incident approuvé disponible.', style: TextStyle(color: AppColors.textSecondary)),
                        ]),
                      )
                    : Column(
                        children: issues.map((issue) => _buildAvailableIssueItem(issue, isMobile)).toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableIssueItem(Issue issue, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(issue.equipmentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(issue.department, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                ),
                IssueStatusBadge(status: issue.status.displayName),
              ]),
              const SizedBox(height: 8),
              Text(issue.type, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(issue.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('Signalé par ${issue.reporter} • ${issue.createdAt}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showTakeOverDialog(issue),
                  icon: const Icon(Icons.handyman_outlined, size: 16),
                  label: const Text('Prendre en charge'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ),
            ])
          : Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(issue.equipmentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(4)),
                      child: Text(issue.department, style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4)),
                      child: Text(issue.type, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(issue.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('Signalé par ${issue.reporter} • ${issue.createdAt}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 16),
              IssueStatusBadge(status: issue.status.displayName),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showTakeOverDialog(issue),
                icon: const Icon(Icons.handyman_outlined, size: 16),
                label: const Text('Prendre en charge'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ]),
    );
  }

  void _showTakeOverDialog(Issue issue) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prendre en charge l\'incident'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Vous allez prendre en charge l\'incident sur :'),
          const SizedBox(height: 8),
          Text(issue.equipmentName, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(issue.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          const Text(
            'L\'incident passera au statut "En cours" et vous sera assigné. Vous pourrez le retrouver dans "Mes interventions".',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _takeOverIssue(issue);
            },
            icon: const Icon(Icons.handyman_outlined, size: 16),
            label: const Text('Confirmer'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _takeOverIssue(Issue issue) async {
    try {
      await DbApiService.instance.updateIssue(issue.id, {
        'status':              'En cours',
        'assigned_technician': _currentTechnicianName,
      });
      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
      if (!mounted) return;
      setState(() {
        // Pré-sélectionner l'incident dans "Mes interventions" et basculer l'onglet
        _selectedIssueId = issue.id;
        _loadIssueData();
        _tabController.animateTo(1);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Incident "${issue.equipmentName}" pris en charge. Bonne réparation !'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Onglet 1 : Mes interventions ─────────────────────────────────────────────

  Widget _buildMyInterventionsTab(AppLocalizations l10n, bool isMobile) {
    final myIssues = _myIssues;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.techTitle,
              style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(l10n.techSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            if (myIssues.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: isMobile
                      ? const Column(children: [
                          Icon(Icons.inbox_outlined, size: 48, color: AppColors.textSecondary),
                          SizedBox(height: 12),
                          Text('Aucune intervention en cours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          Text('Rendez-vous dans "Incidents disponibles" pour prendre en charge un incident.', style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                        ])
                      : const Row(children: [
                          Icon(Icons.inbox_outlined, size: 48, color: AppColors.textSecondary),
                          SizedBox(width: 20),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Aucune intervention en cours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                              Text('Rendez-vous dans "Incidents disponibles" pour prendre en charge un incident.', style: TextStyle(color: AppColors.textSecondary)),
                            ]),
                          ),
                        ]),
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
                        // Sélection de l'incident
                        Text(l10n.techSelectIssue, style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedIssueId,
                          decoration: InputDecoration(hintText: l10n.techSelectIssueHint),
                          items: myIssues.map((issue) => DropdownMenuItem(
                            value: issue.id,
                            child: Text('${issue.id} — ${issue.equipmentName}'),
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
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_selectedIssue!.equipmentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(_selectedIssue!.description, style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 8),
                              Text(
                                l10n.techReportedByDate(_selectedIssue!.reporter, _selectedIssue!.createdAt),
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 24),

                          // Statut de réparation
                          Text(l10n.techRepairStatus, style: const TextStyle(fontWeight: FontWeight.w500)),
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

                          // Diagnostic
                          Text(l10n.techDiagnosis, style: const TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _diagnosisController,
                            maxLines: 3,
                            decoration: InputDecoration(hintText: l10n.techDiagnosisHint),
                          ),
                          const SizedBox(height: 24),

                          // Actions
                          Text(l10n.techActionsTaken, style: const TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _actionsController,
                            maxLines: 3,
                            decoration: InputDecoration(hintText: l10n.techActionsHint),
                          ),
                          const SizedBox(height: 24),

                          // Pièces
                          Text(l10n.techPartsReplaced, style: const TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _partsController,
                            decoration: InputDecoration(hintText: l10n.techPartsHint),
                          ),
                          const SizedBox(height: 32),

                          // Boutons
                          Row(children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving ? null : _saveProgress,
                                child: Text(l10n.techSave),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (_repairStatus == 'Réparé' && !_isSaving) ? _markResolved : null,
                                icon: const Icon(Icons.check),
                                label: Text(l10n.techMarkResolved),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                              ),
                            ),
                          ]),
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

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _saveProgress() async {
    if (_selectedIssueId == null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      await DbApiService.instance.updateIssue(_selectedIssueId!, {
        'status':              'En cours',
        'assigned_technician': _currentTechnicianName,
        'diagnosis':           _diagnosisController.text.trim().isNotEmpty ? _diagnosisController.text.trim() : null,
        'actions':             _actionsController.text.trim().isNotEmpty   ? _actionsController.text.trim()   : null,
        'parts_replaced':      _partsController.text.trim().isNotEmpty     ? _partsController.text.trim()     : null,
      });
      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _markResolved() async {
    if (_selectedIssueId == null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      await DbApiService.instance.updateIssue(_selectedIssueId!, {
        'status':              'Résolu',
        'assigned_technician': _currentTechnicianName,
        'diagnosis':           _diagnosisController.text.trim().isNotEmpty ? _diagnosisController.text.trim() : null,
        'actions':             _actionsController.text.trim().isNotEmpty   ? _actionsController.text.trim()   : null,
        'parts_replaced':      _partsController.text.trim().isNotEmpty     ? _partsController.text.trim()     : null,
      });
      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
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
        _repairStatus = 'Diagnostic en cours';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
