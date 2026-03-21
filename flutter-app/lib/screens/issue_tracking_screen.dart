import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
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
  final AuthService _authService = AuthService();

  // ── Filtres ────────────────────────────────────────────────────────────────

  List<Issue> get _myIssues {
    final user = _authService.currentUser;
    if (user == null) return [];
    return DataService().issues.where((i) {
      // Priorité : reporter_id si disponible, sinon match par nom
      if (i.reporterId != null && i.reporterId!.isNotEmpty) {
        return i.reporterId == user.id;
      }
      return i.reporter == user.name;
    }).toList();
  }

  List<Issue> get _deptIssues {
    final dept = _authService.currentUser?.department ?? '';
    if (dept.isEmpty) return [];
    return DataService().issues.where((i) => i.department == dept).toList();
  }

  List<Issue> get _filteredIssues {
    final l10n = AppLocalizations.of(context)!;
    if (_statusFilter == l10n.commonAll) return DataService().issues;
    return DataService().issues.where((i) => i.status.displayName == _statusFilter).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    if (_statusFilter == 'Tous') _statusFilter = l10n.commonAll;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statuses = [l10n.commonAll, 'Ouvert', 'En cours', 'Résolu'];

    final openCount     = DataService().issues.where((i) => i.status == IssueStatus.open).length;
    final inProgressCount = DataService().issues.where((i) => i.status == IssueStatus.inProgress).length;
    final resolvedCount = DataService().issues.where((i) => i.status == IssueStatus.resolved).length;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Text(l10n.issuesTitle, style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(l10n.issuesSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),

            // ── Stats + bouton ────────────────────────────────────────────────
            if (isMobile) ...[
              Wrap(spacing: 8, runSpacing: 8, children: [
                _buildMiniStat(l10n.issuesOpen,       openCount,       AppColors.error),
                _buildMiniStat(l10n.issuesInProgress, inProgressCount, AppColors.warning),
                _buildMiniStat(l10n.issuesResolved,   resolvedCount,   AppColors.success),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => widget.onNavigate(3),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.issuesReport),
                ),
              ),
            ] else
              Row(children: [
                _buildMiniStat(l10n.issuesOpen,       openCount,       AppColors.error),
                const SizedBox(width: 12),
                _buildMiniStat(l10n.issuesInProgress, inProgressCount, AppColors.warning),
                const SizedBox(width: 12),
                _buildMiniStat(l10n.issuesResolved,   resolvedCount,   AppColors.success),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => widget.onNavigate(3),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.issuesReport),
                ),
              ]),
            const SizedBox(height: 24),

            // ── Encadré : Mes incidents ───────────────────────────────────────
            _buildPersonalCard(l10n),
            const SizedBox(height: 16),

            // ── Encadré : Incidents de mon département ────────────────────────
            _buildDeptCard(l10n),
            const SizedBox(height: 24),

            // ── Séparateur ───────────────────────────────────────────────────
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(l10n.issuesAllIssues, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),

            // ── Filtres ───────────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: isMobile
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l10n.issuesFilterByStatus, style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: statuses.map((status) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: _statusFilter == status,
                              label: Text(status),
                              onSelected: (_) => setState(() => _statusFilter = status),
                              selectedColor: AppColors.primaryLight,
                              checkmarkColor: AppColors.primary,
                            ),
                          )).toList()),
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.issuesCount(_filteredIssues.length), style: const TextStyle(color: AppColors.textSecondary)),
                      ])
                    : Row(children: [
                        Text(l10n.issuesFilterByStatus, style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 12),
                        ...statuses.map((status) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: _statusFilter == status,
                            label: Text(status),
                            onSelected: (_) => setState(() => _statusFilter = status),
                            selectedColor: AppColors.primaryLight,
                            checkmarkColor: AppColors.primary,
                          ),
                        )),
                        const Spacer(),
                        Text(l10n.issuesCount(_filteredIssues.length), style: const TextStyle(color: AppColors.textSecondary)),
                      ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Liste complète ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Column(
                  children: _filteredIssues.isEmpty
                      ? [Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(l10n.issuesNoMyIssues, style: const TextStyle(color: AppColors.textSecondary)),
                        )]
                      : _filteredIssues.map((issue) => _buildIssueItem(issue)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Encadré "Mes incidents" ────────────────────────────────────────────────

  Widget _buildPersonalCard(AppLocalizations l10n) {
    final myIssues = _myIssues;
    const maxVisible = 3;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.person_outline, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.issuesMyIssues, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                  Text(l10n.issuesMyIssuesSubtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                child: Text('${myIssues.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ]),
          ),
          const Divider(height: 1),

          // Contenu
          if (myIssues.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text(l10n.issuesNoMyIssues, style: const TextStyle(color: AppColors.textSecondary)),
              ]),
            )
          else ...[
            ...myIssues.take(maxVisible).map((issue) => _buildCompactIssueRow(issue)),
            if (myIssues.length > maxVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  l10n.issuesAndMore(myIssues.length - maxVisible),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ── Encadré "Incidents de mon département" ─────────────────────────────────

  Widget _buildDeptCard(AppLocalizations l10n) {
    final deptIssues = _deptIssues;
    final dept = _authService.currentUser?.department ?? '';
    const maxVisible = 3;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.business_outlined, color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.issuesDeptIssues, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                  Text(
                    dept.isNotEmpty ? l10n.issuesDeptIssuesSubtitle(dept) : l10n.issuesNoDeptIssues,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(12)),
                child: Text('${deptIssues.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning)),
              ),
            ]),
          ),
          const Divider(height: 1),

          // Contenu
          if (deptIssues.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text(l10n.issuesNoDeptIssues, style: const TextStyle(color: AppColors.textSecondary)),
              ]),
            )
          else ...[
            ...deptIssues.take(maxVisible).map((issue) => _buildCompactIssueRow(issue)),
            if (deptIssues.length > maxVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  l10n.issuesAndMore(deptIssues.length - maxVisible),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ── Ligne compacte pour les encadrés ──────────────────────────────────────

  Widget _buildCompactIssueRow(Issue issue) {
    return InkWell(
      onTap: () => _showIssueDetail(issue),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getStatusColor(issue.status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(issue.equipmentName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              Text(
                issue.description,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const SizedBox(width: 8),
          IssueStatusBadge(status: issue.status.displayName),
        ]),
      ),
    );
  }

  // ── Ligne complète (liste principale) ─────────────────────────────────────

  Widget _buildMiniStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildIssueItem(Issue issue) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () => _showIssueDetail(issue),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getStatusColor(issue.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.warning_amber_rounded, color: _getStatusColor(issue.status), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(issue.equipmentName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(issue.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(l10n.issuesReportedByDate(issue.reporter, issue.createdAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 16),
          IssueStatusBadge(status: issue.status.displayName),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 16), onPressed: () => _showIssueDetail(issue)),
        ]),
      ),
    );
  }

  Color _getStatusColor(IssueStatus status) {
    switch (status) {
      case IssueStatus.open:       return AppColors.error;
      case IssueStatus.inProgress: return AppColors.warning;
      case IssueStatus.resolved:   return AppColors.success;
    }
  }

  void _showIssueDetail(Issue issue) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.issuesIncidentId(issue.id), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              IssueStatusBadge(status: issue.status.displayName),
              const SizedBox(height: 20),
              _buildDetailRow(l10n.issuesEquipment,   issue.equipmentName),
              _buildDetailRow(l10n.issuesType,         issue.type),
              _buildDetailRow(l10n.issuesDescription,  issue.description),
              _buildDetailRow(l10n.issuesReportedBy,   issue.reporter),
              if (issue.reporterEmail != null && issue.reporterEmail!.isNotEmpty)
                _buildDetailRow(l10n.commonEmail,      issue.reporterEmail!),
              _buildDetailRow(l10n.issuesReportDate,   issue.createdAt),
              if (issue.assignedTechnician != null) _buildDetailRow(l10n.issuesAssignedTech, issue.assignedTechnician!),
              if (issue.diagnosis != null)          _buildDetailRow(l10n.issuesDiagnosis,    issue.diagnosis!),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(context); widget.onNavigate(4, issueId: issue.id); },
                    icon: const Icon(Icons.build),
                    label: Text(l10n.issuesUpdate),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 140, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
