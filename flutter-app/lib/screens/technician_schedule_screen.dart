import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/auth_service.dart';
import '../models/equipment.dart';
import '../models/issue.dart';

// ── Modèle interne ────────────────────────────────────────────────────────────

/// Événement unifié pour le planning du technicien.
class _AgendaEvent {
  final String title;
  final String subtitle;
  final String type; // 'in_progress' | 'resolved' | 'maintenance' | 'future_maintenance'
  final DateTime date;

  const _AgendaEvent({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.date,
  });
}

// ── Écran ─────────────────────────────────────────────────────────────────────

/// Planning du technicien — calendrier des interventions et maintenances.
///
/// Cet écran était auparavant un onglet de [TechnicianUpdateScreen]. Il est
/// désormais autonome et atteint via le bouton calendrier de la page technicien.
class TechnicianScheduleScreen extends StatefulWidget {
  const TechnicianScheduleScreen({super.key});

  @override
  State<TechnicianScheduleScreen> createState() =>
      _TechnicianScheduleScreenState();
}

class _TechnicianScheduleScreenState extends State<TechnicianScheduleScreen> {
  DateTime _focusedDay  = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // DataService().equipment est chargé en mode léger (maintenanceHistory/
  // futureMaintenance vides) — ce calendrier a besoin de l'historique complet,
  // donc on recharge le parc en entier (full) à l'ouverture de cet écran.
  List<Equipment> _fullEquipment = [];
  bool _loadingEquipment = true;

  String get _currentTechnicianName => AuthService().currentUser?.fullName ?? '';

  @override
  void initState() {
    super.initState();
    _loadFullEquipment();
  }

  Future<void> _loadFullEquipment() async {
    try {
      final raw = await DbApiService.instance.getEquipment();
      _fullEquipment = raw.map(Equipment.fromApiJson).toList();
    } catch (_) {
      _fullEquipment = [];
    }
    if (mounted) setState(() => _loadingEquipment = false);
  }

  // ── Construction des événements ─────────────────────────────────────────────

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(dateStr.split('T').first);
    } catch (_) {
      return null;
    }
  }

  List<_AgendaEvent> get _allAgendaEvents {
    final events   = <_AgendaEvent>[];
    final techName = _currentTechnicianName;

    for (final issue in DataService().issues) {
      if (issue.assignedTechnician != techName) continue;
      if (issue.status != IssueStatus.inProgress &&
          issue.status != IssueStatus.completed) continue;
      final dateStr = issue.takenAt ?? issue.createdAt;
      final date    = _parseDate(dateStr);
      if (date == null) continue;
      events.add(_AgendaEvent(
        title:    issue.displayName,
        subtitle: issue.type,
        type:
            issue.status == IssueStatus.inProgress ? 'in_progress' : 'resolved',
        date: date,
      ));
    }

    for (final eq in _fullEquipment) {
      for (final rec in eq.maintenanceHistory) {
        if (rec.technician != techName) continue;
        final date = _parseDate(rec.date);
        if (date == null) continue;
        events.add(_AgendaEvent(
            title:    eq.name,
            subtitle: rec.intervention,
            type:     'maintenance',
            date:     date));
      }
      for (final rec in eq.futureMaintenance) {
        if (rec.technician != techName) continue;
        final date = _parseDate(rec.date);
        if (date == null) continue;
        events.add(_AgendaEvent(
            title:    eq.name,
            subtitle: rec.intervention,
            type:     'future_maintenance',
            date:     date));
      }
    }

    return events;
  }

  // Filtre la liste pré-calculée — évite de rescanner toutes les données pour
  // chaque cellule du calendrier (eventLoader est appelé par jour visible).
  List<_AgendaEvent> _eventsForDay(List<_AgendaEvent> events, DateTime day) {
    return events
        .where((e) =>
            e.date.year  == day.year &&
            e.date.month == day.month &&
            e.date.day   == day.day)
        .toList();
  }

  String _monthName(int month, AppLocalizations l10n) {
    switch (month) {
      case 1:  return l10n.monthJanuary;
      case 2:  return l10n.monthFebruary;
      case 3:  return l10n.monthMarch;
      case 4:  return l10n.monthApril;
      case 5:  return l10n.monthMay;
      case 6:  return l10n.monthJune;
      case 7:  return l10n.monthJuly;
      case 8:  return l10n.monthAugust;
      case 9:  return l10n.monthSeptember;
      case 10: return l10n.monthOctober;
      case 11: return l10n.monthNovember;
      case 12: return l10n.monthDecember;
      default: return '';
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.techScheduleTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loadingEquipment) {
      return const Center(child: CircularProgressIndicator());
    }
    final isMobile = MediaQuery.of(context).size.width < AppBreakpoints.tablet;
    // Calculé une seule fois par build puis filtré localement (cf. _eventsForDay)
    final allEvents      = _allAgendaEvents;
    final selectedEvents = _eventsForDay(allEvents, _selectedDay);

    final Map<String, List<_AgendaEvent>> byMonth = {};
    for (final e in allEvents) {
      final key =
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(e);
    }
    final monthKeys = byMonth.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.techScheduleTitle,
              style: TextStyle(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(l10n.techScheduleSubtitle,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),

          // Légende
          Wrap(spacing: 12, runSpacing: 4, children: [
            _legendItem(AppColors.warning, Icons.build_circle_outlined,
                l10n.techLegendInProgress),
            _legendItem(AppColors.success, Icons.check_circle_outlined,
                l10n.techLegendResolved),
            _legendItem(AppColors.textSecondary, Icons.build_outlined,
                l10n.techLegendPastMaintenance),
            _legendItem(
                AppColors.primary, Icons.event_repeat, l10n.techLegendPlanned),
          ]),
          const SizedBox(height: 12),

          // Calendrier
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: TableCalendar<_AgendaEvent>(
                firstDay:
                    DateTime.now().subtract(const Duration(days: 365)),
                lastDay:
                    DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) =>
                    isSameDay(_selectedDay, day),
                eventLoader: (day) => _eventsForDay(allEvents, day),
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle),
                  todayTextStyle: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold),
                  selectedDecoration: BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  markerDecoration: BoxDecoration(
                      color: AppColors.warning, shape: BoxShape.circle),
                  outsideDaysVisible: false,
                  markersMaxCount: 3,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay  = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) =>
                    setState(() => _focusedDay = focusedDay),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            l10n.techEventsOn(
              '${_selectedDay.day.toString().padLeft(2, '0')}/'
              '${_selectedDay.month.toString().padLeft(2, '0')}/'
              '${_selectedDay.year}',
            ),
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          selectedEvents.isEmpty
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const Icon(Icons.event_available,
                          color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(l10n.techNoEventsToday,
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                    ]),
                  ),
                )
              : Card(
                  child: Column(
                    children: selectedEvents.asMap().entries.map((entry) {
                      final isLast =
                          entry.key == selectedEvents.length - 1;
                      return Column(children: [
                        _buildEventTile(entry.value, l10n),
                        if (!isLast)
                          const Divider(height: 1, indent: 56),
                      ]);
                    }).toList(),
                  ),
                ),
          const SizedBox(height: 24),

          if (allEvents.isNotEmpty) ...[
            Text(l10n.techFullHistory,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            ...monthKeys.map((key) {
              final events = List<_AgendaEvent>.from(byMonth[key]!)
                ..sort((a, b) => b.date.compareTo(a.date));
              final parts      = key.split('-');
              final monthLabel =
                  '${_monthName(int.parse(parts[1]), l10n)} ${parts[0]}';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(monthLabel,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.techEventCount(events.length),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ]),
                  ),
                  Card(
                    child: Column(
                      children: events.asMap().entries.map((entry) {
                        final isLast =
                            entry.key == events.length - 1;
                        return Column(children: [
                          _buildEventTile(entry.value, l10n),
                          if (!isLast)
                            const Divider(height: 1, indent: 56),
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
                  const Icon(Icons.calendar_today_outlined,
                      size: 40, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(l10n.techNoInterventions,
                      style:
                          const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(l10n.techNoInterventionsHint,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventTile(_AgendaEvent event, AppLocalizations l10n) {
    final IconData icon;
    final Color    color;
    final String   statusLabel;

    switch (event.type) {
      case 'in_progress':
        icon        = Icons.build_circle_outlined;
        color       = AppColors.warning;
        statusLabel = l10n.techLegendInProgress;
      case 'resolved':
        icon        = Icons.check_circle_outline;
        color       = AppColors.success;
        statusLabel = l10n.techLegendResolved;
      case 'future_maintenance':
        icon        = Icons.event_repeat;
        color       = AppColors.primary;
        statusLabel = l10n.techLegendPlanned;
      default: // 'maintenance'
        icon        = Icons.build_outlined;
        color       = AppColors.textSecondary;
        statusLabel = l10n.techEventStatusCompleted;
    }

    return ListTile(
      leading: Container(
        width:   36,
        height:  36,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(event.title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(
        '${event.subtitle}  ·  $statusLabel',
        style:
            const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Text(
        '${event.date.day.toString().padLeft(2, '0')}/'
        '${event.date.month.toString().padLeft(2, '0')}/'
        '${event.date.year}',
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
}
