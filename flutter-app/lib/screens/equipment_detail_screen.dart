import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/equipment.dart';
import '../models/issue.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/detail_breadcrumb.dart';
import '../widgets/replacement_badge.dart';
import 'brand_detail_screen.dart';
import 'category_detail_screen.dart';
import 'department_detail_screen.dart';
import 'model_detail_screen.dart';
import 'subcategory_detail_screen.dart';
import '../widgets/equipment/equipment_decommission_dialog.dart';
import '../widgets/equipment/equipment_critical_banner.dart';
import '../widgets/equipment/equipment_documents_tab.dart';
import '../widgets/equipment/equipment_incidents_tab.dart';
import '../widgets/equipment/equipment_info_tab.dart';
import '../widgets/equipment/equipment_maintenance_tab.dart';
import '../widgets/equipment/equipment_staff_view.dart';

/// Page de détail d'un équipement médical.
///
/// **RBAC** :
///   - [UserRole.hospitalStaff] → vue simplifiée [EquipmentStaffView]
///   - Tous les autres rôles → vue à 4 onglets complète
///
/// Données chargées en parallèle depuis db-service :
///   GET /api/equipment/:id + GET /api/issues?equipment_id=…
///
/// Un [initialEquipment] peut être fourni pour afficher immédiatement
/// les informations de base pendant le chargement réseau.
class EquipmentDetailScreen extends StatefulWidget {
  final String equipmentId;
  final Equipment? initialEquipment;
  final VoidCallback? onEdit;
  final VoidCallback? onReport;

  const EquipmentDetailScreen({
    super.key,
    required this.equipmentId,
    this.initialEquipment,
    this.onEdit,
    this.onReport,
  });

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen> {
  Equipment? _equipment;
  List<Issue> _issues = [];
  bool _loadingDetails = true;
  String? _error;

  // ── Statut de remplacement (RA3 S5) — admin/supervisor uniquement ─────────
  Map<String, dynamic>? _replacementItem;
  bool _replacementLoaded = false;

  bool get _isStaffView {
    final primary = AuthService().primaryRole;
    return primary == UserRole.hospitalStaff;
  }

  // La réforme finale et le hard delete forcé sont réservés à l'admin (miroir RBAC backend).
  bool get _isAdmin => AuthService().primaryRole == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _equipment = widget.initialEquipment;
    _fetchDetails();
    if (AuthService().canGenerateReports) {
      _loadReplacementStatus();
    }
  }

  /// Récupère le statut de remplacement de cet équipement depuis le plan.
  /// Échec silencieux : la section Notifications reste masquée si indisponible.
  Future<void> _loadReplacementStatus() async {
    try {
      final plan  = await DbApiService.instance.getReplacementPlan();
      final items = (plan['items'] as List?) ?? const [];
      Map<String, dynamic>? found;
      for (final it in items) {
        final m = it as Map<String, dynamic>;
        if (m['id'] == widget.equipmentId) { found = m; break; }
      }
      if (mounted) setState(() {
        _replacementItem = found;
        _replacementLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _replacementLoaded = true);
    }
  }

  /// Section « Notifications » : alerte de remplacement de l'équipement.
  /// Visible seulement pour les rôles autorisés (admin/supervisor) une fois
  /// le plan chargé. Affiche « Aucune alerte » si statut `ok` ou absent.
  Widget _buildNotificationsBanner(AppLocalizations l10n) {
    if (!AuthService().canGenerateReports || !_replacementLoaded) {
      return const SizedBox.shrink();
    }

    final item   = _replacementItem;
    final status = item?['status_replacement'] as String? ?? 'ok';
    final hasBadge = ReplacementBadge.colorFor(status) != null;

    final Widget content;
    if (!hasBadge) {
      content = Row(children: [
        const Icon(Icons.check_circle_outline,
            size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(l10n.equipmentDetailNoAlerts,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ]);
    } else {
      final age      = (item?['age'] as num?)?.toInt();
      final lifespan = (item?['lifespan'] as num?)?.toInt();
      final crit     = item?['criticality'] as String?;
      final tooltip  = ReplacementBadge.tooltipFor(l10n, status, age, lifespan, crit);
      final label = switch (status) {
        'a_remplacer'     => l10n.replacementStatusDue,
        'bientot'         => l10n.replacementStatusSoon,
        'donnee_manquante' => l10n.replacementStatusUnknown,
        _                 => '',
      };
      content = Row(children: [
        ReplacementBadge(status: status, tooltip: tooltip),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tooltip.isEmpty ? label : '$label — $tooltip',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
        ),
      ]);
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.notifications_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(l10n.equipmentDetailAlertsTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
            const SizedBox(height: 8),
            content,
          ],
        ),
      ),
    );
  }

  // ── Chargement des données ────────────────────────────────────────────────────

  Future<void> _fetchDetails() async {
    if (!mounted) return;
    setState(() {
      _loadingDetails = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        DbApiService.instance.getEquipmentById(widget.equipmentId),
        DbApiService.instance.getIssues(equipmentId: widget.equipmentId),
      ]);
      final eq =
          Equipment.fromApiJson(results[0] as Map<String, dynamic>);
      final rawIssues =
          (results[1] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _equipment = eq;
        _issues = rawIssues.map(Issue.fromApiJson).toList();
        _loadingDetails = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingDetails = false;
      });
    }
  }

  // ── Build principal ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final eq = _equipment;

    // Chargement initial sans données disponibles
    if (_loadingDetails && eq == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(l10n.commonDetails)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Erreur sans données
    if (eq == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(l10n.commonDetails)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? l10n.equipDetailLoadingError,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Vue selon le rôle
    return _isStaffView
        ? _buildStaffScaffold(l10n, eq)
        : _buildTabbedScaffold(l10n, eq);
  }

  // ── Vue staff médical ─────────────────────────────────────────────────────────

  Widget _buildStaffScaffold(AppLocalizations l10n, Equipment eq) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(eq.name, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          EquipmentCriticalBanner(equipment: eq),
          _buildLifecycleBanner(l10n, eq),
          _buildNotificationsBanner(l10n),
          Expanded(
            child: EquipmentStaffView(
              equipment: eq,
              issues: _issues,
              loading: _loadingDetails,
            ),
          ),
        ],
      ),
    );
  }

  // ── Vue technicien / superviseur / admin ─────────────────────────────────────

  Widget _buildTabbedScaffold(AppLocalizations l10n, Equipment eq) {
    final auth = AuthService();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(eq.name, overflow: TextOverflow.ellipsis),
          actions: [
            if (widget.onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.commonEdit,
                onPressed: () {
                  Navigator.pop(context);
                  widget.onEdit!();
                },
              ),
            // Réforme (soft delete) — admin only, masquée si déjà réformé
            if (_isAdmin && eq.status != EquipmentStatus.disposed)
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: l10n.decommissionButton,
                onPressed: () => _showDecommissionDialog(eq),
              ),
            if (auth.canManageEquipment)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.commonDelete,
                color: AppColors.error,
                onPressed: () => _showDeleteDialog(eq),
              ),
            const SizedBox(width: 4),
          ],
          // TabBar compacte : hauteur 40px et indicateur fin pour maximiser l'espace données
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: TabBar(
              isScrollable: false,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              tabs: [
                Tab(height: 40, text: l10n.equipDetailTabInfo),
                Tab(height: 40, text: l10n.equipDetailTabMaintenance),
                Tab(height: 40, text: l10n.equipDetailTabIncidents),
                Tab(height: 40, text: l10n.equipDetailTabDocuments),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            // Fil d'Ariane cliquable (vue complète) en tête du body.
            // Les bannières de notification (critique + remplacement) ne sont
            // plus rendues ici : elles vivent désormais dans l'onglet Info
            // uniquement, sinon elles réapparaîtraient sur tous les onglets.
            _buildBreadcrumb(eq),
            Expanded(
              child: TabBarView(
                children: [
                  // ── Onglet 1 : Informations ──────────────────────
                  EquipmentInfoTab(
                    equipment: eq,
                    linksEnabled: true,
                    handlers: _buildLinkHandlers(eq),
                    issues: _issues,
                    onRefresh: _fetchDetails,
                    replacementItem: _replacementItem,
                    replacementLoaded: _replacementLoaded,
                    isAdmin: _isAdmin,
                  ),

                  // ── Onglet 2 : Maintenance ───────────────────────
                  EquipmentMaintenanceTab(
                    equipment: eq,
                    issues: _issues,
                    onRefresh: _fetchDetails,
                  ),

                  // ── Onglet 3 : Incidents ─────────────────────────
                  EquipmentIncidentsTab(
                    issues: _issues,
                    loading: _loadingDetails,
                    error: _error,
                    onReport: widget.onReport != null
                        ? _handleReport
                        : null,
                  ),

                  // ── Onglet 4 : Documents ─────────────────────────
                  EquipmentDocumentsTab(equipment: eq),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  void _handleReport() {
    Navigator.pop(context);
    widget.onReport?.call();
  }

  // ── Bannière cycle de vie : badge « Réformé » + liens remplaçant ──────────────
  // Affichée si l'équipement est réformé OU s'il participe à un lien de
  // remplacement (dans un sens ou l'autre). Les liens sont cliquables.
  Widget _buildLifecycleBanner(AppLocalizations l10n, Equipment eq) {
    final isDisposed = eq.status == EquipmentStatus.disposed;
    final hasReplacedBy = (eq.replacedById ?? '').isNotEmpty;
    final hasReplaces = (eq.replacesId ?? '').isNotEmpty;
    if (!isDisposed && !hasReplacedBy && !hasReplaces) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];

    if (isDisposed) {
      final reason = eq.decommissionReason;
      final method = eq.disposalMethod;
      final detail = [
        if (reason != null) decommissionReasonLabel(l10n, reason),
        if (method != null) disposalMethodLabel(l10n, method),
      ].join(' · ');
      children.add(Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.textMuted.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(l10n.decommissionBadge,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(detail,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
      ]));
    }

    if (hasReplacedBy) {
      children.add(_replacementLink(
        l10n.decommissionReplacedBy, eq.replacedByName ?? eq.replacedById!, eq.replacedById!));
    }
    if (hasReplaces) {
      children.add(_replacementLink(
        l10n.decommissionReplaces, eq.replacesName ?? eq.replacesId!, eq.replacesId!));
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  // Lien cliquable vers un équipement lié (remplaçant ou remplacé).
  Widget _replacementLink(String label, String name, String targetId) {
    return Row(children: [
      const Icon(Icons.sync_alt, size: 16, color: AppColors.primary),
      const SizedBox(width: 8),
      Text('$label : ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      Expanded(
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EquipmentDetailScreen(equipmentId: targetId),
              ),
            );
          },
          child: Text(name,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline)),
        ),
      ),
    ]);
  }

  // ── Métadonnées cliquables : drill-down (vue complète uniquement) ─────────────

  /// Construit les callbacks de navigation. Chaque callback est null si la cible
  /// n'est pas navigable (id absent) → la ligne reste un texte simple.
  EquipmentLinkHandlers _buildLinkHandlers(Equipment eq) {
    final hasSub = eq.subcategoryId != null && (eq.subcategoryName ?? '').isNotEmpty;
    return EquipmentLinkHandlers(
      onDepartment: eq.department.isNotEmpty ? () => _openDepartment(eq.department) : null,
      onCategory: eq.category.isNotEmpty
          ? () => _push(CategoryDetailScreen(categoryName: eq.category))
          : null,
      onSubcategory: hasSub ? () => _openSubcategory(eq) : null,
      // Fabricant / modèle : nécessitent le contexte sous-catégorie (ctor des fiches).
      onManufacturer: (eq.brandId != null && (eq.brandName ?? '').isNotEmpty && hasSub)
          ? () => _openBrand(eq)
          : null,
      onModel: (eq.modelId != null && hasSub) ? () => _openModel(eq) : null,
    );
  }

  /// Fil d'Ariane de la fiche équipement : [Département, Sous-catégorie, Équipement].
  /// Les segments dont le parent est inconnu sont omis.
  Widget _buildBreadcrumb(Equipment eq) {
    final segments = <BreadcrumbSegment>[];
    if (eq.department.isNotEmpty) {
      segments.add(BreadcrumbSegment(eq.department, onTap: () => _openDepartment(eq.department)));
    }
    if (eq.subcategoryId != null && (eq.subcategoryName ?? '').isNotEmpty) {
      segments.add(BreadcrumbSegment(eq.subcategoryName!, onTap: () => _openSubcategory(eq)));
    }
    segments.add(BreadcrumbSegment(eq.name));
    return DetailBreadcrumb(segments: segments);
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openSubcategory(Equipment eq) => _push(SubcategoryDetailScreen(
        subcategoryId: eq.subcategoryId!,
        subcategoryName: eq.subcategoryName!,
        isBiomedical: eq.macroCategory == 'Biomedical',
      ));

  void _openBrand(Equipment eq) => _push(BrandDetailScreen(
        brandId: eq.brandId!,
        brandName: eq.brandName!,
        subcategoryId: eq.subcategoryId!,
        subcategoryName: eq.subcategoryName!,
      ));

  void _openModel(Equipment eq) => _push(ModelDetailScreen(
        modelId: eq.modelId!,
        modelName: eq.model ?? '',
        brandName: eq.brandName ?? '',
        subcategoryId: eq.subcategoryId!,
        subcategoryName: eq.subcategoryName!,
      ));

  /// Résout l'id du département à partir de son nom (côté client) puis ouvre
  /// son dashboard. Échec silencieux (snackbar) si le nom n'a pas d'entrée.
  Future<void> _openDepartment(String name) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final depts = await DbApiService.instance.getDepartments();
      final match = depts.firstWhere(
        (d) => (d['name'] as String?) == name,
        orElse: () => const {},
      );
      final id = (match['id'] as num?)?.toInt();
      if (!mounted) return;
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      _push(DepartmentDetailScreen(departmentId: id, departmentName: name));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.commonApiError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Réforme (soft delete) — admin only ────────────────────────────────────────
  Future<void> _showDecommissionDialog(Equipment eq) async {
    final result = await showDecommissionDialog(context, eq);
    if (result == null || !mounted) return;

    final l10n = AppLocalizations.of(context)!;
    try {
      await DbApiService.instance.decommissionEquipment(
        eq.id,
        reason: result.reason,
        method: result.method,
        notes: result.notes,
        replacedById: result.replacedById,
      );
      await DataService().reloadEquipment();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.decommissionSuccess),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : l10n.commonApiError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // Dialog expliquant qu'un équipement avec historique doit être réformé.
  // Propose le hard delete forcé uniquement à l'admin (avec avertissement).
  void _showDeleteBlockedDialog(Equipment eq) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.decommissionDeleteBlockedTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.decommissionDeleteBlockedBody),
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              Text(l10n.decommissionForceDeleteWarning,
                  style: const TextStyle(fontSize: 12, color: AppColors.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          if (_isAdmin)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () {
                Navigator.pop(ctx);
                _deleteEquipment(eq, null, force: true);
              },
              child: Text(l10n.decommissionForceDeleteButton),
            ),
        ],
      ),
    );
  }

  // ── Dialogue de suppression avec double confirmation ─────────────────────────

  void _showDeleteDialog(Equipment eq) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final inputMatchesName = nameController.text.trim() == eq.name;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning_outlined,
                    color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.equipDetailDeleteConfirmTitle,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avertissement irréversibilité
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        l10n.equipDetailDeleteConfirmBody,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nom de l'équipement à recopier
                    Text(
                      l10n.equipDetailDeleteConfirmLabel,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText:
                            l10n.equipDetailDeleteConfirmHint(eq.name),
                        isDense: true,
                        border: const OutlineInputBorder(),
                        errorStyle:
                            const TextStyle(color: AppColors.error),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      validator: (v) {
                        if (v == null || v.trim() != eq.name) {
                          return l10n.equipDetailDeleteConfirmMismatch;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Raison (optionnel)
                    Text(
                      l10n.equipDetailDeleteReasonLabel,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        hintText: l10n.equipDetailDeleteReasonHint,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                // Activé seulement quand le nom est tapé correctement
                onPressed: inputMatchesName
                    ? () async {
                        if (!formKey.currentState!.validate()) return;
                        final reason =
                            reasonController.text.trim();
                        Navigator.pop(ctx);
                        await _deleteEquipment(
                            eq, reason.isEmpty ? null : reason);
                      }
                    : null,
                child: Text(l10n.equipDetailDeleteConfirmButton),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteEquipment(Equipment eq, String? reason, {bool force = false}) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await DbApiService.instance
          .deleteEquipment(eq.id, reason: reason, force: force);
      await DataService().reloadEquipment();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409 : équipement avec historique → on oriente vers la réforme.
      if (e.statusCode == 409) {
        _showDeleteBlockedDialog(eq);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}
