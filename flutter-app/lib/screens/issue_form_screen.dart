import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/equipment.dart';
import '../models/issue.dart';

import '../models/departments.dart';
import '../utils/file_picker.dart';
import '../widgets/urgency_badge.dart';

/// Catalogue infrastructure 3 niveaux : catégorie → sous-catégorie → problèmes.
/// Valeurs en anglais (reference standard hospitalier), stockées telles quelles en DB.
const Map<String, Map<String, List<String>>> _kInfraCatalog = {
  'Electrical System': {
    'Lighting': [
      'Bulb not working', 'Flickering light', 'Switch malfunction',
    ],
    'Power Supply': [
      'No electricity', 'Partial power outage', 'Tripped breaker',
      'Generator failure', 'UPS failure', 'Power surge damage', 'Extension cable damaged',
    ],
    'Electrical Outlets': [
      'Socket not working', 'Loose outlet', 'Burnt outlet',
      'Exposed wiring', 'Sparking outlet', 'Broken cover plate',
    ],
    'Wiring & Distribution': [
      'Exposed cable', 'Damaged conduit', 'Water near electrical line',
    ],
  },
  'Water Supply & Plumbing': {
    'Water Availability': [
      'No water', 'Low water pressure', 'Dirty water',
    ],
    'Faucets & Valves': [
      'Leaking tap', 'Broken tap', 'Loose faucet', 'Valve not closing',
    ],
    'Toilets & Sanitation': [
      'Toilet blocked', 'Toilet not flushing', 'Continuous flushing',
      'Broken toilet seat', 'Urinal blocked', 'Washbasin blocked',
    ],
    'Pipework': [
      'Pipe leakage', 'Burst pipe', 'Underground leakage',
      'Corroded pipe', 'Broken pipe support',
    ],
    'Drainage': [
      'Blocked drainage', 'Overflowing wastewater', 'Septic overflow',
      'Manhole blockage', 'Stormwater blockage',
    ],
    'Water Storage': [
      'Tank leakage', 'Float switch failure', 'Water pump failure',
    ],
  },
  'Doors, Windows & Locks': {
    'Doors': [
      'Door not closing', 'Broken hinges', 'Door misalignment', 'Damaged frame',
    ],
    'Locks & Security': [
      'Lock damaged', 'Key broken', 'Door cannot lock', 'Padlock missing',
    ],
    'Windows': [
      'Broken glass', 'Window cannot open', 'Window cannot close',
      'Damaged mosquito net', 'Curtain/blind damaged',
    ],
  },
  'Furniture': {
    'Office Furniture': [
      'Broken chair', 'Damaged desk', 'Cabinet lock defective',
      'Drawer jammed', 'Shelf damaged',
    ],
    'Hospital Furniture': [
      'Bed wheel damaged', 'Bed crank failure', 'Patient trolley damaged',
    ],
    'Waiting Area Furniture': [
      'Broken bench', 'Loose seating', 'Torn upholstery',
    ],
  },
  'Building & Civil Works': {
    'Walls & Finishes': [
      'Wall cracks', 'Paint peeling', 'Damp wall', 'Mold growth', 'Tile broken',
    ],
    'Floors': [
      'Floor crack', 'Slippery floor', 'Broken tile',
      'Uneven surface', 'Damaged vinyl flooring',
    ],
    'Ceiling': [
      'Ceiling leakage', 'Ceiling collapse risk',
      'Damaged gypsum board', 'Hanging ceiling panel',
    ],
    'Roofing': [
      'Roof leakage', 'Missing roofing sheet', 'Gutter blockage', 'Downpipe broken',
    ],
    'External Works': [
      'Potholes', 'Broken pavement', 'Fence damaged', 'Drainage erosion',
      'Loading ramp damage', 'Parking marking faded',
    ],
  },
  'HVAC & Ventilation': {
    'Air Conditioning': [
      'AC not cooling', 'Water leaking from AC', 'Strange AC noise', 'AC not starting',
    ],
    'Ventilation': [
      'Exhaust fan failure', 'Poor ventilation', 'Air duct blockage',
    ],
    'Heating': [
      'Water heater failure',
    ],
  },
  'Fire & Safety Systems': {
    'Fire Protection': [
      'Fire extinguisher expired', 'Missing extinguisher', 'Fire alarm fault',
      'Smoke detector failure', 'Hose reel leakage',
    ],
    'Safety': [
      'Emergency exit blocked', 'Safety sign missing', 'Handrail damaged',
      'Slip hazard', 'Unsafe wiring',
    ],
  },
  'Specialized Areas': {
    'Medical Utility': [
      'Medical gas leakage', 'Oxygen outlet fault', 'Air compressor issue',
    ],
    'Biomedical Support Infrastructure': [
      'Equipment power issue', 'Equipment mounting failure', 'UPS for equipment failure',
    ],
  },
  'Waste Management': {
    'Waste Infrastructure': [
      'Incinerator malfunction', 'Ash pit overflow', 'Wastewater pit overflow',
    ],
  },
};

/// Valeur de macro_category pour les équipements biomédicaux (champ API).
const String _kBioMacroCategory = 'Biomedical';

/// Valeur de macro_category pour les équipements IT (champ API).
const String _kItMacroCategory = 'IT';

/// Formulaire de signalement d'incident avec 4 onglets de catégorie.
class IssueFormScreen extends StatefulWidget {
  final String? equipmentId;
  final VoidCallback? onCancel;
  /// Onglet pré-sélectionné : 0=Biomédical 1=Infrastructure 2=IT 3=Autre.
  final int initialTab;
  // categoryFilter conservé pour rétrocompatibilité (ignoré)
  final List<String>? categoryFilter;

  const IssueFormScreen({
    super.key,
    this.equipmentId,
    this.onCancel,
    this.initialTab = 0,
    this.categoryFilter,
  });

  @override
  State<IssueFormScreen> createState() => IssueFormScreenState();
}

class IssueFormScreenState extends State<IssueFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Onglet actif ──────────────────────────────────────────────────────────
  int _selectedTab = 0; // 0=Biomédical 1=Infrastructure 2=IT 3=Autre

  // ── Tab 0 : Biomédical ────────────────────────────────────────────────────
  String? _bioEquipmentId;
  int _bioAutocompleteKey = 0;
  bool _bioEquipmentError = false;
  String _bioProblemType = '';

  // ── Tab 1 : Infrastructure ────────────────────────────────────────────────
  String? _infraDepartment;
  final _infraBuildingController  = TextEditingController();
  final _infraLocationController  = TextEditingController();
  final _infraTagController       = TextEditingController();
  String? _infraCategory;
  String? _infraSubcategory;
  String? _infraIssue;
  int _infraSearchKey = 0;

  // ── Tab 2 : IT ────────────────────────────────────────────────────────────
  final _tagController = TextEditingController();
  Equipment? _itEquipment;
  bool _itSearching = false;
  String? _itTagError;
  String _itProblemType = '';

  // ── Tab 3 : Autre ─────────────────────────────────────────────────────────
  String? _autreDepartment;
  String _autreProblemType = '';

  // ── Partagés entre tous les tabs ──────────────────────────────────────────
  IssueUrgency _urgency = IssueUrgency.moyen;
  final _descriptionController = TextEditingController();
  final List<_PhotoItem> _photos = [];
  static const int _maxPhotos = 5;
  bool _isSubmitting = false;

  /// Retourne true si l'utilisateur a commencé à remplir un formulaire.
  bool get hasUnsavedData =>
      _bioEquipmentId != null ||
      _infraBuildingController.text.isNotEmpty ||
      _infraLocationController.text.isNotEmpty ||
      _itEquipment != null ||
      _tagController.text.isNotEmpty ||
      _autreDepartment != null ||
      _descriptionController.text.isNotEmpty ||
      _photos.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    if (widget.equipmentId != null) {
      final eq = DataService().equipment
          .where((e) => e.id == widget.equipmentId)
          .firstOrNull;
      if (eq != null) {
        // Utilise macroCategory si disponible, sinon repli sur category text legacy
        final isIt = eq.macroCategory?.toLowerCase() == _kItMacroCategory.toLowerCase() ||
            eq.category.toLowerCase() == 'informatique' ||
            eq.category.toLowerCase() == 'ict equipment';
        if (isIt) {
          _selectedTab = 2;
          _itEquipment = eq;
        } else {
          _selectedTab = 0;
          _bioEquipmentId = eq.id;
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    if (_bioProblemType.isEmpty) _bioProblemType = l10n.issueFormBreakdown;
    if (_itProblemType.isEmpty)  _itProblemType  = l10n.issueFormBreakdown;
    if (_autreProblemType.isEmpty) _autreProblemType = l10n.issueFormBreakdown;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagController.dispose();
    _infraBuildingController.dispose();
    _infraLocationController.dispose();
    _infraTagController.dispose();
    super.dispose();
  }

  // ── Helpers équipements ───────────────────────────────────────────────────

  Equipment? get _selectedBioEquipment {
    if (_bioEquipmentId == null) return null;
    return DataService().equipment
        .where((e) => e.id == _bioEquipmentId)
        .firstOrNull;
  }

  /// Équipements biomédicaux : filtrés par macro_category='Biomedical' si disponible,
  /// sinon repli sur la valeur category legacy 'Biomedical Equipment'.
  List<Equipment> get _bioEquipmentList => DataService().equipment.where((eq) {
        if (eq.macroCategory != null && eq.macroCategory!.isNotEmpty) {
          return eq.macroCategory!.toLowerCase() == _kBioMacroCategory.toLowerCase();
        }
        return eq.category.toLowerCase() == 'biomedical equipment';
      }).toList();

  // ── Helpers infrastructure ────────────────────────────────────────────────

  List<String> get _infraSubcategories =>
      _infraCategory != null ? _kInfraCatalog[_infraCategory]!.keys.toList() : [];

  List<String> get _infraIssues =>
      (_infraCategory != null && _infraSubcategory != null)
          ? _kInfraCatalog[_infraCategory]![_infraSubcategory] ?? []
          : [];

  Iterable<_InfraSearchResult> _searchInfraCatalog(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    final results = <_InfraSearchResult>[];
    for (final cat in _kInfraCatalog.entries) {
      for (final sub in cat.value.entries) {
        for (final issue in sub.value) {
          if (issue.toLowerCase().contains(q) ||
              sub.key.toLowerCase().contains(q) ||
              cat.key.toLowerCase().contains(q)) {
            results.add(_InfraSearchResult(
              category: cat.key,
              subcategory: sub.key,
              issue: issue,
            ));
          }
        }
      }
    }
    return results;
  }

  // ── Changement d'onglet ───────────────────────────────────────────────────

  void _switchTab(int tab) {
    setState(() {
      _selectedTab = tab;
      _descriptionController.clear();
      _photos.clear();
      _urgency = IssueUrgency.moyen;
      _infraIssue = null;
      _infraSearchKey++;
    });
  }

  // ── Recherche IT par tag ──────────────────────────────────────────────────

  Future<void> _searchByTagNumber() async {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _itSearching = true;
      _itTagError = null;
      _itEquipment = null;
    });
    try {
      final found = await DbApiService.instance.getEquipmentByTagNumber(tag);
      if (!mounted) return;
      setState(() {
        _itEquipment = found;
        _itSearching = false;
        if (found == null) _itTagError = l10n.issueFormTagNotFound;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _itTagError = e.toString();
        _itSearching = false;
      });
    }
  }

  // ── Gestion photos ────────────────────────────────────────────────────────

  void _pickPhoto() {
    final l10n = AppLocalizations.of(context)!;
    if (_photos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.issueFormMaxPhotos(_maxPhotos)),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    pickImageFile((String fileName, Uint8List bytes) {
      setState(() {
        _photos.add(_PhotoItem(name: fileName, bytes: bytes));
      });
    });
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));

  // ── Types de problème (partagés bio + IT + Autre) ─────────────────────────

  List<String> _problemTypes(AppLocalizations l10n) => [
    l10n.issueFormBreakdown,
    l10n.issueFormMalfunction,
    l10n.issueFormWear,
    l10n.issueFormAbnormalNoise,
    l10n.issueFormLeak,
    l10n.issueFormOther,
  ];

  // ── Soumission du formulaire ───────────────────────────────────────────────

  Future<void> _submitForm() async {
    if (_isSubmitting) return;
    final l10n = AppLocalizations.of(context)!;

    // Validation spécifique par tab
    bool extraValid = true;
    if (_selectedTab == 0 && _bioEquipmentId == null) {
      setState(() => _bioEquipmentError = true);
      extraValid = false;
    }
    if (_selectedTab == 2 && _itEquipment == null) extraValid = false;

    if (!_formKey.currentState!.validate() || !extraValid) return;

    final currentUser = AuthService().currentUser;
    final commons = {
      'description':    _descriptionController.text.trim(),
      'reporter':       currentUser?.fullName ?? 'Inconnu',
      'reporter_id':    currentUser?.id ?? '',
      'reporter_email': currentUser?.email ?? '',
      'urgency':        _urgency.displayName,
    };

    final Map<String, dynamic> issueData;

    switch (_selectedTab) {
      case 0: // Biomédical
        final eq = _selectedBioEquipment!;
        issueData = {
          'id':             'issue-${DateTime.now().millisecondsSinceEpoch}',
          'equipment_id':   eq.id,
          'equipment_name': eq.name,
          'department':     eq.department,
          'type':           _bioProblemType,
          'issue_category': 'Biomédical',
          'assigned_group': 'Biomédical',
          ...commons,
        };
      case 1: // Infrastructure
        final infraTag = _infraTagController.text.trim();
        issueData = {
          'id':             'issue-${DateTime.now().millisecondsSinceEpoch}',
          'location_text':  '${_infraBuildingController.text.trim()} — ${_infraLocationController.text.trim()}',
          if (infraTag.isNotEmpty) 'location_tag': infraTag,
          'department':     _infraDepartment!,
          'type':           '$_infraCategory / $_infraSubcategory / $_infraIssue',
          'issue_category': 'Infrastructure',
          'assigned_group': 'Infrastructure',
          ...commons,
        };
      case 2: // IT
        final eq = _itEquipment!;
        issueData = {
          'id':             'issue-${DateTime.now().millisecondsSinceEpoch}',
          'equipment_id':   eq.id,
          'equipment_name': eq.name,
          'department':     eq.department,
          'type':           _itProblemType,
          'issue_category': 'IT',
          'assigned_group': 'IT',
          ...commons,
        };
      default: // Autre
        issueData = {
          'id':             'issue-${DateTime.now().millisecondsSinceEpoch}',
          'department':     _autreDepartment!,
          'type':           _autreProblemType,
          'issue_category': 'Autre',
          ...commons,
        };
    }

    setState(() => _isSubmitting = true);
    try {
      await DbApiService.instance.createIssue(issueData);
      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Text(_photos.isNotEmpty
              ? l10n.issueFormSuccessWithPhotos(_photos.length)
              : l10n.issueFormSuccess),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.issueFormError(e.toString())),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Couleur d'urgence ─────────────────────────────────────────────────────

  Color _urgencyColor(IssueUrgency u) {
    switch (u) {
      case IssueUrgency.faible:   return AppColors.textSecondary;
      case IssueUrgency.moyen:    return AppColors.warning;
      case IssueUrgency.urgent:   return AppColors.error;
      case IssueUrgency.critique: return AppColors.critical;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            l10n.issueFormTitle,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.issueFormSubtitle,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // ── 4 boutons onglets ───────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTabButton(0, CupertinoIcons.heart_circle,    l10n.issueCategoryBiomedical,     AppColors.primary,       l10n),
              _buildTabButton(1, CupertinoIcons.building_2_fill, l10n.issueCategoryInfrastructure, AppColors.warning,       l10n),
              _buildTabButton(2, CupertinoIcons.device_desktop,  l10n.issueCategoryIT,             AppColors.textSecondary, l10n),
              _buildTabButton(3, CupertinoIcons.question_circle, l10n.issueCategoryOther,          AppColors.textMuted,     l10n),
            ],
          ),
          const SizedBox(height: 24),

          // ── Formulaire dynamique ────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sous-formulaire selon l'onglet
                    if (_selectedTab == 0) ..._buildBiomedicalForm(l10n),
                    if (_selectedTab == 1) ..._buildInfrastructureForm(l10n),
                    if (_selectedTab == 2) ..._buildITForm(l10n),
                    if (_selectedTab == 3) ..._buildAutreForm(l10n),

                    const SizedBox(height: 24),

                    // Urgence (partagée)
                    Text(l10n.issueUrgencyLabel, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: IssueUrgency.values.map((u) {
                        final selected = _urgency == u;
                        return GestureDetector(
                          onTap: () => setState(() => _urgency = u),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? _urgencyColor(u).withValues(alpha: 0.15)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? _urgencyColor(u) : AppColors.border,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: UrgencyBadge(urgency: u, isCompact: true),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Description (partagée)
                    Text(l10n.issueFormDescription, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(hintText: l10n.issueFormDescriptionHint),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.issueFormDescriptionRequired;
                        }
                        if (value.length < 10) return l10n.issueFormDescriptionMinLength;
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Photos (partagées)
                    Text(l10n.issueFormPhotos, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                      l10n.issueFormPhotosHint(_maxPhotos),
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ..._photos.asMap().entries.map((e) =>
                            _buildPhotoThumbnail(e.value, e.key)),
                        if (_photos.length < _maxPhotos) _buildAddPhotoButton(l10n),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Reporter (partagé — auto-rempli)
                    Text(l10n.issueFormYourName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _buildReporterInfo(),
                    const SizedBox(height: 32),

                    // Boutons Annuler / Soumettre
                    Row(
                      children: [
                        if (widget.onCancel != null) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onCancel,
                              icon: const Icon(Icons.close, color: AppColors.error),
                              label: Text(l10n.commonCancel,
                                  style: const TextStyle(color: AppColors.error)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.send),
                                      const SizedBox(width: 8),
                                      Text(_photos.isNotEmpty
                                          ? l10n.issueFormSubmitWithPhotos(_photos.length)
                                          : l10n.issueFormSubmit),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bouton onglet ─────────────────────────────────────────────────────────

  Widget _buildTabButton(int index, IconData icon, String label, Color color, AppLocalizations l10n) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () => _switchTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? color : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOUS-FORMULAIRES
  // ══════════════════════════════════════════════════════════════════════════

  // ── Tab 0 : Biomédical ────────────────────────────────────────────────────

  List<Widget> _buildBiomedicalForm(AppLocalizations l10n) {
    final problemTypes = _problemTypes(l10n);
    return [
      Text(l10n.issueFormEquipment, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Autocomplete<Equipment>(
        key: ValueKey(_bioAutocompleteKey),
        displayStringForOption: (eq) => '${eq.name} - SN: ${eq.serialNumber}',
        optionsBuilder: (TextEditingValue value) {
          final query = value.text.toLowerCase().trim();
          if (query.isEmpty) return const Iterable<Equipment>.empty();
          return _bioEquipmentList.where((eq) =>
              eq.name.toLowerCase().contains(query) ||
              eq.serialNumber.toLowerCase().contains(query));
        },
        onSelected: (eq) {
          setState(() {
            _bioEquipmentId = eq.id;
            _bioEquipmentError = false;
          });
        },
        fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
          return TextField(
            controller: textController,
            focusNode: focusNode,
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              hintText: l10n.issueFormSelectEquipment,
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _bioEquipmentId != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        textController.clear();
                        setState(() {
                          _bioEquipmentId = null;
                          _bioEquipmentError = false;
                        });
                      },
                    )
                  : null,
              errorText: _bioEquipmentError ? l10n.issueFormEquipmentRequired : null,
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final eq = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.medical_services_outlined, size: 20),
                    title: Text(eq.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      'SN: ${eq.serialNumber} • ${eq.department}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    onTap: () => onSelected(eq),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      if (_selectedBioEquipment != null) ...[
        const SizedBox(height: 12),
        _buildEquipmentAutoFill(_selectedBioEquipment!, l10n),
      ],
      const SizedBox(height: 20),
      Text(l10n.issueFormProblemType, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _bioProblemType,
        items: problemTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (v) => setState(() => _bioProblemType = v!),
      ),
    ];
  }

  // ── Tab 1 : Infrastructure ────────────────────────────────────────────────

  List<Widget> _buildInfrastructureForm(AppLocalizations l10n) {
    return [
      // Numéro de tag (optionnel)
      Text(l10n.issueFormInfraTagNumber, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _infraTagController,
        decoration: InputDecoration(
          hintText: l10n.issueFormInfraTagHint,
          prefixIcon: const Icon(Icons.tag, color: AppColors.textSecondary),
        ),
      ),
      const SizedBox(height: 16),

      // Département
      Text(l10n.commonDepartment, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _infraDepartment,
        hint: Text(l10n.issueFormSelectDepartment),
        items: Department.values
            .map((d) => DropdownMenuItem(value: d.displayName, child: Text(d.displayName)))
            .toList(),
        onChanged: (v) => setState(() => _infraDepartment = v),
        validator: (_) => _infraDepartment == null ? l10n.issueFormDepartmentRequired : null,
      ),
      const SizedBox(height: 16),

      // Bâtiment — texte libre
      Text(l10n.issueFormBuilding, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _infraBuildingController,
        decoration: InputDecoration(
          hintText: l10n.issueFormBuildingHint,
          prefixIcon: const Icon(CupertinoIcons.building_2_fill, color: AppColors.textSecondary),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? l10n.issueFormBuildingRequired : null,
      ),
      const SizedBox(height: 16),

      // Localisation — texte libre
      Text(l10n.issueFormSourceLocation, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _infraLocationController,
        decoration: InputDecoration(
          hintText: l10n.issueFormLocationHint,
          prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.textSecondary),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? l10n.issueFormLocationRequired2 : null,
      ),
      const SizedBox(height: 16),

      // Recherche rapide
      Text(l10n.issueFormQuickSearch, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Autocomplete<_InfraSearchResult>(
        key: ValueKey(_infraSearchKey),
        displayStringForOption: (r) => '${r.category} / ${r.subcategory} — ${r.issue}',
        optionsBuilder: (TextEditingValue value) => _searchInfraCatalog(value.text),
        onSelected: (result) {
          setState(() {
            _infraCategory    = result.category;
            _infraSubcategory = result.subcategory;
            _infraIssue       = result.issue;
            _infraSearchKey++;
          });
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              hintText: l10n.issueFormQuickSearchHint,
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final r = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.build_outlined, size: 18, color: AppColors.warning),
                    title: Text(r.issue, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      '${r.category} › ${r.subcategory}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    onTap: () => onSelected(r),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Divider(height: 1),
      const SizedBox(height: 16),

      // Catégorie
      Text(l10n.issueFormProblemCategory, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _infraCategory,
        hint: Text(l10n.issueFormSelectProblemCategory),
        items: _kInfraCatalog.keys
            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
            .toList(),
        onChanged: (v) => setState(() {
          _infraCategory    = v;
          _infraSubcategory = null;
          _infraIssue       = null;
        }),
        validator: (_) => _infraCategory == null ? l10n.issueFormCategoryRequired : null,
      ),
      const SizedBox(height: 16),

      // Sous-catégorie
      Text(l10n.issueFormProblemSubcategory, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _infraSubcategory,
        hint: Text(l10n.issueFormSelectProblemSubcategory),
        items: _infraSubcategories
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: (v) => setState(() {
          _infraSubcategory = v;
          _infraIssue       = null;
        }),
        validator: (_) => _infraSubcategory == null ? l10n.issueFormSubcategoryRequired : null,
      ),
      const SizedBox(height: 16),

      // Problème spécifique
      Text(l10n.issueFormSpecificIssue, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _infraIssue,
        hint: Text(l10n.issueFormSelectSpecificIssue),
        items: [
          ..._infraIssues
              .map((issue) => DropdownMenuItem(value: issue, child: Text(issue))),
          DropdownMenuItem(value: 'Other', child: Text(l10n.issueFormOther)),
        ],
        onChanged: (v) => setState(() => _infraIssue = v),
        validator: (_) => _infraIssue == null ? l10n.issueFormIssueRequired : null,
      ),
    ];
  }

  // ── Tab 2 : IT ────────────────────────────────────────────────────────────

  List<Widget> _buildITForm(AppLocalizations l10n) {
    final problemTypes = _problemTypes(l10n);
    return [
      Text(l10n.issueFormTagNumber, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _tagController,
        decoration: InputDecoration(
          hintText: l10n.issueFormTagNumberHint,
          prefixIcon: const Icon(Icons.tag, color: AppColors.textSecondary),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.issueFormSearchEquipmentByTag,
            onPressed: _itSearching ? null : _searchByTagNumber,
          ),
        ),
        onFieldSubmitted: (_) => _searchByTagNumber(),
        validator: (_) {
          if (_itEquipment == null && !_itSearching) {
            return l10n.issueFormTagRequired;
          }
          return null;
        },
      ),
      if (_itSearching) ...[
        const SizedBox(height: 8),
        Row(children: [
          const SizedBox(width: 4),
          const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(l10n.issueFormTagSearching,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ]),
      ],
      if (_itTagError != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(_itTagError!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
          ]),
        ),
      ],
      if (_itEquipment != null) ...[
        const SizedBox(height: 12),
        _buildEquipmentAutoFill(_itEquipment!, l10n),
      ],
      const SizedBox(height: 20),
      Text(l10n.issueFormProblemType, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _itProblemType,
        items: problemTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (v) => setState(() => _itProblemType = v!),
      ),
    ];
  }

  // ── Tab 3 : Autre ─────────────────────────────────────────────────────────

  List<Widget> _buildAutreForm(AppLocalizations l10n) {
    final problemTypes = _problemTypes(l10n);
    return [
      Text(l10n.commonDepartment, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _autreDepartment,
        hint: Text(l10n.issueFormSelectDepartment),
        items: Department.values
            .map((d) => DropdownMenuItem(value: d.displayName, child: Text(d.displayName)))
            .toList(),
        onChanged: (v) => setState(() => _autreDepartment = v),
        validator: (_) => _autreDepartment == null ? l10n.issueFormDepartmentRequired : null,
      ),
      const SizedBox(height: 20),
      Text(l10n.issueFormProblemType, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _autreProblemType,
        items: problemTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (v) => setState(() => _autreProblemType = v!),
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGETS PARTAGÉS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEquipmentAutoFill(Equipment eq, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eq.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${eq.department} • ${eq.location}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                l10n.issueFormAutoFilled,
                style: const TextStyle(fontSize: 11, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildReporterInfo() {
    final user = AuthService().currentUser;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.success.withValues(alpha: 0.2),
          child: const Icon(Icons.person, color: AppColors.success, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.fullName ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              if (user?.email != null)
                Text(user!.email,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (user?.department != null && user!.department.isNotEmpty)
                Text(user.department,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const Icon(Icons.verified_user, color: AppColors.success, size: 18),
      ]),
    );
  }

  Widget _buildPhotoThumbnail(_PhotoItem photo, int index) {
    return Stack(children: [
      Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.memory(
            photo.bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, _) => Container(
              color: AppColors.background,
              child: const Icon(Icons.broken_image, color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
      Positioned(
        top: 4, right: 4,
        child: GestureDetector(
          onTap: () => _removePhoto(index),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 14),
          ),
        ),
      ),
    ]);
  }

  Widget _buildAddPhotoButton(AppLocalizations l10n) {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary, width: 2),
          color: AppColors.primaryLight,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo, color: AppColors.primary, size: 28),
            const SizedBox(height: 4),
            Text(l10n.issueFormAddPhoto,
                style: const TextStyle(
                    color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// Modèle local pour une photo uploadée.
class _PhotoItem {
  final String name;
  final Uint8List bytes;
  _PhotoItem({required this.name, required this.bytes});
}

/// Résultat de recherche rapide dans le catalogue infrastructure.
class _InfraSearchResult {
  final String category;
  final String subcategory;
  final String issue;
  const _InfraSearchResult({
    required this.category,
    required this.subcategory,
    required this.issue,
  });
}
