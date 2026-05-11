import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/db_api_service.dart';
import '../models/issue.dart';
import '../models/user_role.dart';
import '../widgets/status_badge.dart';
import '../widgets/urgency_badge.dart';

/// Issue tracking screen - view and manage all issues
class IssueTrackingScreen extends StatefulWidget {
  final Function(int, {String? issueId}) onNavigate;

  const IssueTrackingScreen({super.key, required this.onNavigate});

  @override
  State<IssueTrackingScreen> createState() => _IssueTrackingScreenState();
}

class _IssueTrackingScreenState extends State<IssueTrackingScreen>
    with SingleTickerProviderStateMixin {
  IssueStatus? _statusFilter; // null = tous
  final AuthService _authService = AuthService();
  TabController? _tabController;
  bool _isValidating = false;

  bool get _isPrivileged {
    final role = _authService.currentRole;
    return role == UserRole.supervisor || role == UserRole.admin;
  }

  @override
  void initState() {
    super.initState();
    if (_isPrivileged) {
      _tabController = TabController(length: 2, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // ── Filtres ────────────────────────────────────────────────────────────────

  List<Issue> get _myIssues {
    final user = _authService.currentUser;
    if (user == null) return [];
    return DataService().issues.where((i) {
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
    if (_statusFilter == null) return DataService().issues;
    return DataService().issues.where((i) => i.status == _statusFilter).toList();
  }

  List<Issue> get _openIssuesForValidation {
    final role = _authService.currentRole;
    final allOpen = DataService().issues.where((i) => i.status == IssueStatus.open).toList();
    if (role == UserRole.admin) return allOpen;
    if (role == UserRole.supervisor) {
      final dept = _authService.currentUser?.department ?? '';
      return allOpen.where((i) => i.department == dept).toList();
    }
    return [];
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_isPrivileged) {
      return _buildMainContent(context);
    }

    return Column(
      children: [
        Material(
          color: Theme.of(context).cardColor,
          elevation: 1,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(icon: const Icon(Icons.list_alt, size: 18), text: AppLocalizations.of(context)!.issueTrackingTab),
              Tab(icon: const Icon(Icons.pending_actions, size: 18), text: AppLocalizations.of(context)!.issueValidationTab),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMainContent(context),
              _buildValidationTab(context),
            ],
          ),
        ),
      ],
    );
  }

  // ── Contenu principal (onglet Suivi) ───────────────────────────────────────

  Widget _buildMainContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statuses = <IssueStatus?>[null, ...IssueStatus.values];
    String labelFor(IssueStatus? s) => s == null ? l10n.commonAll : s.localizedName(l10n);

    final openCount       = DataService().issues.where((i) => i.status == IssueStatus.open).length;
    final approvedCount   = DataService().issues.where((i) => i.status == IssueStatus.approved).length;
    final inProgressCount = DataService().issues.where((i) => i.status == IssueStatus.inProgress).length;
    final resolvedCount   = DataService().issues.where((i) => i.status == IssueStatus.resolved).length;

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
                _buildMiniStat(l10n.issuesApproved,   approvedCount,   AppColors.primary),
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
                _buildMiniStat(l10n.issuesApproved,   approvedCount,   AppColors.primary),
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
                              label: Text(labelFor(status)),
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
                            label: Text(labelFor(status)),
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

  // ── Onglet "À valider" ─────────────────────────────────────────────────────

  Widget _buildValidationTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final issues = _openIssuesForValidation;
    final role = _authService.currentRole;
    final isAdmin = role == UserRole.admin;
    final dept = _authService.currentUser?.department ?? '';

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Text(
              l10n.issueValidationTitle,
              style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              isAdmin
                  ? l10n.issueValidationSubtitleAll
                  : l10n.issueValidationSubtitleDept(dept),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // ── Compteur ─────────────────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${issues.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.error)),
                  const SizedBox(width: 8),
                  Text(l10n.issueValidationOpenCount(issues.length), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Liste ────────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: Card(
                child: issues.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 24),
                          const SizedBox(width: 12),
                          Text(l10n.issueValidationNone, style: const TextStyle(color: AppColors.textSecondary)),
                        ]),
                      )
                    : Column(
                        children: issues.map((issue) => _buildValidationIssueItem(issue, isMobile)).toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationIssueItem(Issue issue, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: isMobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
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
              Text(issue.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Builder(builder: (ctx) => Text(AppLocalizations.of(ctx)!.issueValidationSignaledBy(issue.reporter, issue.createdAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showIssueDetail(issue),
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: Builder(builder: (ctx) => Text(AppLocalizations.of(ctx)!.issueValidationDetails)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isValidating ? null : () => _showValidateDialog(issue),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Builder(builder: (ctx) => Text(AppLocalizations.of(ctx)!.issueValidationValidate)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                  ),
                ),
              ]),
            ])
          : Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(issue.equipmentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(issue.department, style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(issue.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Builder(builder: (ctx) => Text(AppLocalizations.of(ctx)!.issueValidationSignaledBy(issue.reporter, issue.createdAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
                ]),
              ),
              const SizedBox(width: 16),
              IssueStatusBadge(status: issue.status.displayName),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _showIssueDetail(issue),
                icon: const Icon(Icons.info_outline, size: 16),
                label: Builder(builder: (ctx) => Text(AppLocalizations.of(ctx)!.issueValidationDetails)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isValidating ? null : () => _showValidateDialog(issue),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Builder(builder: (ctx) => Text(AppLocalizations.of(ctx)!.issueValidationValidate)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              ),
            ]),
    );
  }

  void _showValidateDialog(Issue issue) {
    final l10n = AppLocalizations.of(context)!;
    IssueUrgency selectedUrgency = issue.urgency;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.issueValidationConfirmTitle),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.issueValidationConfirmContent),
            const SizedBox(height: 8),
            Text(issue.equipmentName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(issue.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            Text(l10n.issueValidationUrgencyLabel, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: IssueUrgency.values.map((u) {
                final sel = selectedUrgency == u;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setDialogState(() => selectedUrgency = u),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? _urgencyColorFor(u).withValues(alpha: 0.15) : AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: sel ? _urgencyColorFor(u) : AppColors.border, width: sel ? 2 : 1),
                      ),
                      child: UrgencyBadge(urgency: u, isCompact: true),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.issueValidationConfirmMessage,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _validateIssue(issue, urgency: selectedUrgency);
              },
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(l10n.commonSave),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Color _urgencyColorFor(IssueUrgency u) {
    switch (u) {
      case IssueUrgency.faible:  return AppColors.textSecondary;
      case IssueUrgency.moyen:   return AppColors.warning;
      case IssueUrgency.urgent:  return AppColors.error;
    }
  }

  Future<void> _validateIssue(Issue issue, {IssueUrgency? urgency}) async {
    setState(() => _isValidating = true);
    try {
      await DbApiService.instance.updateIssue(issue.id, {
        'status': 'Approuvé',
        if (urgency != null) 'urgency': urgency.displayName,
      });
      await DataService().reloadIssues();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.issueValidationSuccess(issue.equipmentName)),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.issueValidationError(l10n.commonApiError)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  // ── Encadré "Mes incidents" ────────────────────────────────────────────────

  Widget _buildPersonalCard(AppLocalizations l10n) {
    final myIssues = _myIssues;
    const maxVisible = 3;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IssueStatusBadge(status: issue.status.displayName),
              const SizedBox(height: 2),
              UrgencyBadge(urgency: issue.urgency, isCompact: true),
            ],
          ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IssueStatusBadge(status: issue.status.displayName),
              const SizedBox(height: 4),
              UrgencyBadge(urgency: issue.urgency, isCompact: true),
            ],
          ),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 16), onPressed: () => _showIssueDetail(issue)),
        ]),
      ),
    );
  }

  Color _getStatusColor(IssueStatus status) {
    switch (status) {
      case IssueStatus.open:       return AppColors.error;
      case IssueStatus.approved:   return AppColors.primary;
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
              Row(children: [
                IssueStatusBadge(status: issue.status.displayName),
                const SizedBox(width: 8),
                UrgencyBadge(urgency: issue.urgency),
              ]),
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
