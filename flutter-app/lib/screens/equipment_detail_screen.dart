import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/equipment.dart';
import '../models/issue.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
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

  bool get _isStaffView {
    final primary = AuthService().primaryRole;
    return primary == UserRole.hospitalStaff;
  }

  @override
  void initState() {
    super.initState();
    _equipment = widget.initialEquipment;
    _fetchDetails();
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
            if (auth.canManageEquipment)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.commonDelete,
                color: AppColors.error,
                onPressed: () => _showDeleteDialog(eq),
              ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            isScrollable: false,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: [
              Tab(text: l10n.equipDetailTabInfo),
              Tab(text: l10n.equipDetailTabMaintenance),
              Tab(text: l10n.equipDetailTabIncidents),
              Tab(text: l10n.equipDetailTabDocuments),
            ],
          ),
        ),
        body: Column(
          children: [
            // Bannière critique persistante au-dessus des onglets
            EquipmentCriticalBanner(equipment: eq),
            Expanded(
              child: TabBarView(
                children: [
                  // ── Onglet 1 : Informations ──────────────────────
                  EquipmentInfoTab(equipment: eq),

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

  Future<void> _deleteEquipment(Equipment eq, String? reason) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await DbApiService.instance
          .deleteEquipment(eq.id, reason: reason);
      await DataService().reloadEquipment();
      if (mounted) Navigator.pop(context);
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
