import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/issue.dart';
import '../models/equipment.dart';
import '../widgets/urgency_badge.dart';
import '../widgets/equipment_detail_dialog.dart';

/// Événement unifié pour l'onglet Agenda du technicien.
class _AgendaEvent {
  final String title;       // Nom de l'équipement
  final String subtitle;    // Type d'incident / intervention
  final String type;        // 'in_progress' | 'resolved' | 'maintenance' | 'future_maintenance'
  final DateTime date;

  const _AgendaEvent({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.date,
  });
}

/// Technician update screen - three tabs: available incidents, my interventions, agenda
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
  String _interventionSearch = '';

  // ── Onglet "Agenda" ─────────────────────────────────────────────────────────
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
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

  /// Incidents approuvés (non encore assignés) — disponibles à prendre en charge.
  /// Triés par urgence décroissante : Urgent → Moyen → Faible.
  List<Issue> get _availableIssues {
    final list = DataService().issues
        .where((i) => i.status == IssueStatus.approved)
        .toList();
    list.sort((a, b) => _urgencyOrder(b.urgency) - _urgencyOrder(a.urgency));
    return list;
  }

  int _urgencyOrder(IssueUrgency u) {
    switch (u) {
      case IssueUrgency.urgent: return 2;
      case IssueUrgency.moyen:  return 1;
      case IssueUrgency.faible: return 0;
    }
  }

  /// Retourne l'équipement lié à un incident (null si introuvable)
  Equipment? _equipmentFor(Issue issue) =>
      DataService().equipment.where((e) => e.id == issue.equipmentId).firstOrNull;

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
    _tabController = TabController(length: 3, vsync: this, initialIndex: startTab);
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
              const Tab(
                icon: Icon(Icons.calendar_today_outlined, size: 18),
                text: 'Agenda',
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
              _buildAgendaTab(isMobile),
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
    final eq = _equipmentFor(issue);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _urgencyBgColor(issue.urgency),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: _urgencyFgColor(issue.urgency), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(issue.equipmentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(issue.department, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                ),
                UrgencyBadge(urgency: issue.urgency, isCompact: true),
              ]),
              const SizedBox(height: 8),
              Text(issue.type, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(issue.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (eq != null) ...[
                const SizedBox(height: 4),
                Wrap(spacing: 8, children: [
                  if (eq.category.isNotEmpty) _miniChip(Icons.category, eq.category),
                  if (eq.location.isNotEmpty) _miniChip(Icons.location_on, eq.location),
                  if (eq.serialNumber.isNotEmpty) _miniChip(Icons.qr_code, eq.serialNumber),
                ]),
              ],
              const SizedBox(height: 4),
              Text('Signalé par ${issue.reporter} • ${issue.createdAt}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              Row(children: [
                if (eq != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => EquipmentDetailDialog.show(context, eq),
                      icon: const Icon(Icons.info_outline, size: 14),
                      label: const Text('Fiche'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _showTakeOverDialog(issue),
                    icon: const Icon(Icons.handyman_outlined, size: 16),
                    label: const Text('Prendre en charge'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  ),
                ),
              ]),
            ])
          : Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _urgencyBgColor(issue.urgency),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warning_amber_rounded, color: _urgencyFgColor(issue.urgency), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(issue.equipmentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    _infoChip(issue.department, AppColors.primaryLight, AppColors.primary),
                    const SizedBox(width: 6),
                    _infoChip(issue.type, AppColors.background, AppColors.textSecondary),
                    if (eq != null && eq.category.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _infoChip(eq.category, AppColors.successLight, AppColors.success),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(issue.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('Signalé par ${issue.reporter} • ${issue.createdAt}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    if (eq != null && eq.location.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.location_on, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 2),
                      Text(eq.location, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                    if (eq != null && eq.serialNumber.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.qr_code, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 2),
                      Text(eq.serialNumber, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ]),
                ]),
              ),
              const SizedBox(width: 16),
              UrgencyBadge(urgency: issue.urgency),
              const SizedBox(width: 8),
              if (eq != null)
                OutlinedButton.icon(
                  onPressed: () => EquipmentDetailDialog.show(context, eq),
                  icon: const Icon(Icons.info_outline, size: 14),
                  label: const Text('Fiche'),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showTakeOverDialog(issue),
                icon: const Icon(Icons.handyman_outlined, size: 16),
                label: const Text('Prendre en charge'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ]),
    );
  }

  // ── Onglet 2 : Agenda ────────────────────────────────────────────────────────

  /// Parse une date ISO ou YYYY-MM-DD depuis une chaîne.
  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr.split('T').first);
    } catch (_) {
      return null;
    }
  }

  /// Tous les événements du technicien (incidents + maintenances).
  List<_AgendaEvent> get _allAgendaEvents {
    final events = <_AgendaEvent>[];
    final techName = _currentTechnicianName;

    // Incidents en cours ou résolus assignés à ce technicien
    for (final issue in DataService().issues) {
      if (issue.assignedTechnician != techName) continue;
      if (issue.status != IssueStatus.inProgress && issue.status != IssueStatus.resolved) continue;
      final date = _parseDate(issue.createdAt);
      if (date == null) continue;
      events.add(_AgendaEvent(
        title: issue.equipmentName,
        subtitle: issue.type,
        type: issue.status == IssueStatus.inProgress ? 'in_progress' : 'resolved',
        date: date,
      ));
    }

    // Maintenances passées impliquant ce technicien (par nom)
    for (final eq in DataService().equipment) {
      for (final rec in eq.maintenanceHistory) {
        if (rec.technician != techName) continue;
        final date = _parseDate(rec.date);
        if (date == null) continue;
        events.add(_AgendaEvent(
          title: eq.name,
          subtitle: rec.intervention,
          type: 'maintenance',
          date: date,
        ));
      }
      // Maintenances futures
      for (final rec in eq.futureMaintenance) {
        if (rec.technician != techName) continue;
        final date = _parseDate(rec.date);
        if (date == null) continue;
        events.add(_AgendaEvent(
          title: eq.name,
          subtitle: rec.intervention,
          type: 'future_maintenance',
          date: date,
        ));
      }
    }

    return events;
  }

  /// Événements pour un jour donné.
  List<_AgendaEvent> _eventsForDay(DateTime day) {
    return _allAgendaEvents.where((e) =>
      e.date.year == day.year &&
      e.date.month == day.month &&
      e.date.day == day.day
    ).toList();
  }

  String _monthName(int month) {
    const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    return months[month - 1];
  }

  Widget _buildAgendaTab(bool isMobile) {
    final selectedEvents = _eventsForDay(_selectedDay);
    final allEvents = _allAgendaEvents;

    // Grouper par mois YYYY-MM pour la liste historique
    final Map<String, List<_AgendaEvent>> byMonth = {};
    for (final e in allEvents) {
      final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(e);
    }
    final monthKeys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Text(
            'Agenda',
            style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Votre calendrier d\'interventions et de maintenances planifiées.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // ── Légende ───────────────────────────────────────────────────────
          Wrap(spacing: 12, runSpacing: 4, children: [
            _legendItem(AppColors.warning,  Icons.build_circle_outlined, 'En cours'),
            _legendItem(AppColors.success,  Icons.check_circle_outlined, 'Résolu'),
            _legendItem(AppColors.textSecondary, Icons.build_outlined, 'Maintenance passée'),
            _legendItem(AppColors.primary,  Icons.event_repeat, 'Planifiée'),
          ]),
          const SizedBox(height: 12),

          // ── Calendrier ────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: TableCalendar<_AgendaEvent>(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: _eventsForDay,
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                  todayTextStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  selectedDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  markerDecoration: BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                  outsideDaysVisible: false,
                  markersMaxCount: 3,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay  = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  setState(() => _focusedDay = focusedDay);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Événements du jour sélectionné ───────────────────────────────
          Text(
            'Événements du ${_selectedDay.day.toString().padLeft(2, '0')}/${_selectedDay.month.toString().padLeft(2, '0')}/${_selectedDay.year}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          selectedEvents.isEmpty
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: const [
                      Icon(Icons.event_available, color: AppColors.textSecondary),
                      SizedBox(width: 12),
                      Text('Aucun événement ce jour.', style: TextStyle(color: AppColors.textSecondary)),
                    ]),
                  ),
                )
              : Card(
                  child: Column(
                    children: selectedEvents.asMap().entries.map((entry) {
                      final isLast = entry.key == selectedEvents.length - 1;
                      return Column(children: [
                        _buildEventTile(entry.value),
                        if (!isLast) const Divider(height: 1, indent: 56),
                      ]);
                    }).toList(),
                  ),
                ),
          const SizedBox(height: 24),

          // ── Historique complet ────────────────────────────────────────────
          if (allEvents.isNotEmpty) ...[
            const Text('Historique complet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            ...monthKeys.map((key) {
              final events = List<_AgendaEvent>.from(byMonth[key]!)
                ..sort((a, b) => b.date.compareTo(a.date));
              final parts = key.split('-');
              final monthLabel = '${_monthName(int.parse(parts[1]))} ${parts[0]}';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                        child: Text(monthLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ),
                      const SizedBox(width: 8),
                      Text('${events.length} événement${events.length > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  ),
                  Card(
                    child: Column(
                      children: events.asMap().entries.map((entry) {
                        final isLast = entry.key == events.length - 1;
                        return Column(children: [
                          _buildEventTile(entry.value),
                          if (!isLast) const Divider(height: 1, indent: 56),
                        ]);
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const Icon(Icons.calendar_today_outlined, size: 40, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  const Text('Aucune intervention enregistrée', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  const Text('Les incidents que vous prendrez en charge apparaîtront ici.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventTile(_AgendaEvent event) {
    final IconData icon;
    final Color color;
    final String statusLabel;

    switch (event.type) {
      case 'in_progress':
        icon = Icons.build_circle_outlined;
        color = AppColors.warning;
        statusLabel = 'En cours';
      case 'resolved':
        icon = Icons.check_circle_outline;
        color = AppColors.success;
        statusLabel = 'Résolu';
      case 'future_maintenance':
        icon = Icons.event_repeat;
        color = AppColors.primary;
        statusLabel = 'Planifiée';
      default: // 'maintenance'
        icon = Icons.build_outlined;
        color = AppColors.textSecondary;
        statusLabel = 'Effectuée';
    }

    return ListTile(
      leading: Container(
        width: 36, height: 36,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(
        '${event.subtitle}  ·  $statusLabel',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Text(
        '${event.date.day.toString().padLeft(2, '0')}/${event.date.month.toString().padLeft(2, '0')}/${event.date.year}',
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
    );
  }

  Widget _legendItem(Color color, IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ]);
  }

  // ── Helpers visuels ──────────────────────────────────────────────────────────

  Color _urgencyBgColor(IssueUrgency u) {
    switch (u) {
      case IssueUrgency.urgent: return AppColors.errorLight;
      case IssueUrgency.moyen:  return AppColors.warningLight;
      case IssueUrgency.faible: return AppColors.background;
    }
  }

  Color _urgencyFgColor(IssueUrgency u) {
    switch (u) {
      case IssueUrgency.urgent: return AppColors.error;
      case IssueUrgency.moyen:  return AppColors.warning;
      case IssueUrgency.faible: return AppColors.textSecondary;
    }
  }

  Widget _infoChip(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
  );

  Widget _miniChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: AppColors.textSecondary),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]),
  );

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
        content: Text(AppLocalizations.of(context)!.commonApiError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Onglet 1 : Mes interventions ─────────────────────────────────────────────

  Widget _buildMyInterventionsTab(AppLocalizations l10n, bool isMobile) {
    final myIssues = _myIssues;
    final query = _interventionSearch.toLowerCase();
    final filtered = query.isEmpty
        ? myIssues
        : myIssues.where((i) =>
            i.equipmentName.toLowerCase().contains(query) ||
            i.description.toLowerCase().contains(query) ||
            i.department.toLowerCase().contains(query) ||
            i.type.toLowerCase().contains(query),
          ).toList();

    final crossAxisCount = isMobile ? 1 : 3;

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
            const SizedBox(height: 20),

            // Barre de recherche
            TextField(
              onChanged: (v) => setState(() => _interventionSearch = v),
              decoration: const InputDecoration(
                hintText: 'Rechercher une intervention…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            if (myIssues.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: const [
                      Icon(Icons.inbox_outlined, size: 48, color: AppColors.textSecondary),
                      SizedBox(height: 12),
                      Text('Aucune intervention en cours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      SizedBox(height: 4),
                      Text(
                        'Rendez-vous dans "Incidents disponibles" pour prendre en charge un incident.',
                        style: TextStyle(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Aucun résultat', style: TextStyle(color: AppColors.textSecondary))),
              )
            else ...[
              // Grille de cartes
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isMobile ? 2.4 : 1.6,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final issue = filtered[i];
                  final isSelected = _selectedIssueId == issue.id;
                  return _buildInterventionCard(issue, isSelected, l10n);
                },
              ),

              // Formulaire de mise à jour pour l'incident sélectionné
              if (_selectedIssue != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Récapitulatif de l'incident sélectionné
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(_selectedIssue!.equipmentName, style: const TextStyle(fontWeight: FontWeight.w600))),
                              UrgencyBadge(urgency: _selectedIssue!.urgency, isCompact: true),
                            ]),
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
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInterventionCard(Issue issue, bool isSelected, AppLocalizations l10n) {
    Color urgencyColor;
    switch (issue.urgency) {
      case IssueUrgency.urgent: urgencyColor = AppColors.error;   break;
      case IssueUrgency.moyen:  urgencyColor = AppColors.warning; break;
      case IssueUrgency.faible: urgencyColor = AppColors.success; break;
    }

    return InkWell(
      onTap: () {
        setState(() => _selectedIssueId = issue.id);
        _loadIssueData();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : [const BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: urgencyColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.equipmentName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        issue.department,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                UrgencyBadge(urgency: issue.urgency, isCompact: true),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              issue.description,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 11, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    issue.createdAt,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
              ],
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
        content: Text(AppLocalizations.of(context)!.commonApiError),
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
        content: Text(AppLocalizations.of(context)!.commonApiError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
