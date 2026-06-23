import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/equipment.dart';
import '../models/issue.dart';
import '../models/departments.dart';
import '../utils/file_picker.dart';
import '../utils/image_compressor.dart';
import '../widgets/urgency_badge.dart';
import '../widgets/equipment_picker_field.dart';

/// Catalogue infrastructure 3 niveaux : catégorie → sous-catégorie → problèmes.
/// Valeurs en anglais (référence standard hospitalier), stockées telles quelles en DB.
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

const String _kBioMacroCategory = 'Biomedical';
const String _kItMacroCategory  = 'IT';

/// Formulaire de signalement d'incident en 2 étapes.
/// Étape 1 : catégorie, équipement, urgence.
/// Étape 2 : description, photos.
class IssueFormScreen extends StatefulWidget {
  final String? equipmentId;
  final VoidCallback? onCancel;
  /// Onglet pré-sélectionné : 0=Biomédical 1=Infrastructure 2=IT 3=Autre.
  final int initialTab;
  final List<String>? categoryFilter; // conservé pour rétrocompatibilité

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
  // ── Clés de formulaire par étape ──────────────────────────────────────────
  final _formKey1 = GlobalKey<FormState>(); // étape 1 : catégorie + équipement
  final _formKey2 = GlobalKey<FormState>(); // étape 2 : description + photos

  // ── Stepper ───────────────────────────────────────────────────────────────
  int _currentStep = 0; // 0 = étape 1, 1 = étape 2

  // ── Mode Scan & Block ─────────────────────────────────────────────────────
  bool _scanBlockMode = false;

  // ── Onglet actif ──────────────────────────────────────────────────────────
  int _selectedTab = 0; // 0=Biomédical 1=Infrastructure 2=IT 3=Autre

  // ── Tab 0 : Biomédical ────────────────────────────────────────────────────
  String? _bioEquipmentId;
  int _bioAutocompleteKey = 0;
  bool _bioEquipmentError = false;
  String _bioProblemType = '';
  bool _bioUnlisted = false;
  final _bioUnlistedNameController = TextEditingController();
  final _bioBuildingController = TextEditingController();
  final _bioLocationController = TextEditingController();

  // ── Tab 1 : Infrastructure ────────────────────────────────────────────────
  String? _infraDepartment;
  final _infraBuildingController   = TextEditingController();
  final _infraLocationController   = TextEditingController();
  final _infraTagController        = TextEditingController();
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
  bool _itUnlisted = false;
  final _itUnlistedNameController = TextEditingController();
  final _itBuildingController = TextEditingController();
  final _itLocationController = TextEditingController();

  // ── Tab 3 : Autre ─────────────────────────────────────────────────────────
  String? _autreDepartment;
  String _autreProblemType = '';
  final _autreBuildingController = TextEditingController();
  final _autreLocationController = TextEditingController();

  // ── Partagés entre tous les tabs ──────────────────────────────────────────
  IssueUrgency _urgency = IssueUrgency.moyen;
  final _descriptionController = TextEditingController();
  final List<_PhotoItem> _photos = [];
  static const int _maxPhotos = 5;
  bool _isSubmitting = false;
  bool _equipmentAvailable = true;

  bool get hasUnsavedData =>
      _bioEquipmentId != null ||
      _bioUnlisted ||
      _bioUnlistedNameController.text.isNotEmpty ||
      _bioBuildingController.text.isNotEmpty ||
      _bioLocationController.text.isNotEmpty ||
      _infraBuildingController.text.isNotEmpty ||
      _infraLocationController.text.isNotEmpty ||
      _itEquipment != null ||
      _itUnlisted ||
      _itUnlistedNameController.text.isNotEmpty ||
      _itBuildingController.text.isNotEmpty ||
      _itLocationController.text.isNotEmpty ||
      _tagController.text.isNotEmpty ||
      _autreDepartment != null ||
      _autreBuildingController.text.isNotEmpty ||
      _autreLocationController.text.isNotEmpty ||
      _descriptionController.text.isNotEmpty ||
      _photos.isNotEmpty;

  bool get _hasSharedUnsavedData =>
      _descriptionController.text.isNotEmpty || _photos.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    if (widget.equipmentId != null) {
      final eq = DataService().equipment
          .where((e) => e.id == widget.equipmentId)
          .firstOrNull;
      if (eq != null) {
        final isIt = eq.macroCategory?.toLowerCase() == _kItMacroCategory.toLowerCase() ||
            eq.category.toLowerCase() == 'informatique' ||
            eq.category.toLowerCase() == 'ict equipment';
        if (isIt) {
          _selectedTab = 2;
          _itEquipment = eq;
        } else {
          _selectedTab    = 0;
          _bioEquipmentId = eq.id;
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    if (_bioProblemType.isEmpty)   _bioProblemType   = l10n.issueFormBreakdown;
    if (_itProblemType.isEmpty)    _itProblemType    = l10n.issueFormBreakdown;
    if (_autreProblemType.isEmpty) _autreProblemType = l10n.issueFormBreakdown;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagController.dispose();
    _infraBuildingController.dispose();
    _infraLocationController.dispose();
    _infraTagController.dispose();
    _bioUnlistedNameController.dispose();
    _itUnlistedNameController.dispose();
    _bioBuildingController.dispose();
    _bioLocationController.dispose();
    _itBuildingController.dispose();
    _itLocationController.dispose();
    _autreBuildingController.dispose();
    _autreLocationController.dispose();
    super.dispose();
  }

  // ── Helpers équipements ───────────────────────────────────────────────────

  Equipment? get _selectedBioEquipment {
    if (_bioEquipmentId == null) return null;
    return DataService().equipment
        .where((e) => e.id == _bioEquipmentId)
        .firstOrNull;
  }

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
              category: cat.key, subcategory: sub.key, issue: issue,
            ));
          }
        }
      }
    }
    return results;
  }

  // ── Changement d'onglet avec confirmation ─────────────────────────────────

  Future<void> _switchTab(int tab) async {
    if (tab == _selectedTab) return;
    if (_hasSharedUnsavedData) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.issueFormSwitchTabTitle),
          content: Text(l10n.issueFormSwitchTabMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(l10n.issueFormSwitchTabConfirm,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _selectedTab = tab;
      _descriptionController.clear();
      _photos.clear();
      _urgency           = IssueUrgency.moyen;
      _infraIssue        = null;
      _infraSearchKey++;
      _bioUnlisted       = false;
      _bioUnlistedNameController.clear();
      _bioBuildingController.clear();
      _bioLocationController.clear();
      _itUnlisted        = false;
      _itUnlistedNameController.clear();
      _itBuildingController.clear();
      _itLocationController.clear();
      _autreBuildingController.clear();
      _autreLocationController.clear();
      _scanBlockMode     = false;
      _currentStep       = 0;
    });
  }

  // ── Navigation entre les étapes ───────────────────────────────────────────

  void _goToStep2() {
    bool extraValid = true;
    if (_selectedTab == 0) {
      if (!_bioUnlisted && _bioEquipmentId == null) {
        setState(() => _bioEquipmentError = true);
        extraValid = false;
      }
    }
    if (_selectedTab == 2 && !_itUnlisted && _itEquipment == null) {
      extraValid = false;
    }
    if (!_formKey1.currentState!.validate() || !extraValid) return;
    setState(() => _currentStep = 1);
  }

  // ── Scanner QR classique ──────────────────────────────────────────────────

  Future<void> _openQrScanner(AppLocalizations l10n) async {
    if (kIsWeb) {
      await _showQrFallbackDialog(l10n);
      return;
    }
    MobileScannerController? controller;
    String? scannedCode;
    try {
      controller = MobileScannerController();
      scannedCode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            const Icon(CupertinoIcons.qrcode_viewfinder, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(l10n.issueFormScanQrTitle),
          ]),
          contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          content: SizedBox(
            width: 280, height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  final code = capture.barcodes.firstOrNull?.rawValue;
                  if (code != null && code.isNotEmpty) Navigator.pop(ctx, code);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      );
    } finally {
      controller?.dispose();
    }
    if (scannedCode != null && mounted) _processQrCode(scannedCode, l10n);
  }

  Future<void> _showQrFallbackDialog(AppLocalizations l10n) async {
    final textCtrl = TextEditingController();
    String? result;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(CupertinoIcons.qrcode_viewfinder, color: AppColors.primary),
          const SizedBox(width: 8),
          Flexible(child: Text(l10n.issueFormScanQrFallbackTitle)),
        ]),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.issueFormScanQrFallbackHint,
            prefixIcon: const Icon(Icons.qr_code, color: AppColors.textSecondary),
          ),
          onSubmitted: (v) {
            result = v.trim();
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              result = textCtrl.text.trim();
              Navigator.pop(ctx);
            },
            child: Text(l10n.issueFormScanQrFallbackConfirm),
          ),
        ],
      ),
    );
    textCtrl.dispose();
    if (result != null && result!.isNotEmpty && mounted) _processQrCode(result!, l10n);
  }

  /// Pré-remplit le champ biomédical à partir d'un code QR scanné (mode normal).
  void _processQrCode(String code, AppLocalizations l10n) {
    final trimmed = code.trim();
    final eq = DataService().equipment.where((e) =>
        e.id == trimmed ||
        e.serialNumber.toLowerCase() == trimmed.toLowerCase()
    ).firstOrNull;
    if (eq == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.issueFormScanQrNotFound),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() {
      _bioEquipmentId    = eq.id;
      _bioEquipmentError = false;
      _bioAutocompleteKey++;
    });
  }

  // ── Scanner QR mode Scan & Block ──────────────────────────────────────────

  Future<void> _openScanBlockQr(AppLocalizations l10n) async {
    if (kIsWeb) {
      await _showScanBlockFallbackDialog(l10n);
      return;
    }
    MobileScannerController? controller;
    String? scannedCode;
    try {
      controller = MobileScannerController();
      scannedCode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            const Icon(CupertinoIcons.qrcode_viewfinder, color: AppColors.error),
            const SizedBox(width: 8),
            Flexible(child: Text(l10n.issueFormScanBlock)),
          ]),
          contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          content: SizedBox(
            width: 280, height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  final code = capture.barcodes.firstOrNull?.rawValue;
                  if (code != null && code.isNotEmpty) Navigator.pop(ctx, code);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      );
    } finally {
      controller?.dispose();
    }
    if (scannedCode != null && mounted) _processScanBlock(scannedCode, l10n);
  }

  Future<void> _showScanBlockFallbackDialog(AppLocalizations l10n) async {
    final textCtrl = TextEditingController();
    String? result;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(CupertinoIcons.qrcode_viewfinder, color: AppColors.error),
          const SizedBox(width: 8),
          Flexible(child: Text(l10n.issueFormScanBlock)),
        ]),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.issueFormScanQrFallbackHint,
            prefixIcon: const Icon(Icons.qr_code, color: AppColors.textSecondary),
          ),
          onSubmitted: (v) {
            result = v.trim();
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () { result = textCtrl.text.trim(); Navigator.pop(ctx); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    textCtrl.dispose();
    if (result != null && result!.isNotEmpty && mounted) _processScanBlock(result!, l10n);
  }

  /// Scan & Block : scanner → urgence Critique → sauter à l'étape 2.
  void _processScanBlock(String code, AppLocalizations l10n) {
    final trimmed = code.trim();
    final eq = DataService().equipment.where((e) =>
        e.id == trimmed || e.serialNumber.toLowerCase() == trimmed.toLowerCase()
    ).firstOrNull;
    if (eq == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.issueFormScanQrNotFound),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final isIt = eq.macroCategory?.toLowerCase() == _kItMacroCategory.toLowerCase() ||
        eq.category.toLowerCase() == 'informatique' ||
        eq.category.toLowerCase() == 'ict equipment';
    setState(() {
      if (isIt) {
        _selectedTab  = 2;
        _itEquipment  = eq;
        _itUnlisted   = false;
      } else {
        _selectedTab       = 0;
        _bioEquipmentId    = eq.id;
        _bioEquipmentError = false;
        _bioAutocompleteKey++;
        _bioUnlisted = false;
      }
      _urgency       = IssueUrgency.critique;
      _scanBlockMode = true;
      _currentStep   = 1; // sauter directement à la description
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.issueFormScanBlockUrgencySet),
      backgroundColor: AppColors.critical,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Recherche IT par tag ──────────────────────────────────────────────────

  Future<void> _searchByTagNumber() async {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() { _itSearching = true; _itTagError = null; _itEquipment = null; });
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
      setState(() { _itTagError = e.toString(); _itSearching = false; });
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
      setState(() => _photos.add(_PhotoItem(name: fileName, bytes: bytes)));
    });
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));

  void _openPhotoPreview(_PhotoItem photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: const BoxDecoration(color: Colors.black),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5.0,
                  child: Image.memory(
                    photo.bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
            Positioned(
              bottom: 12, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text(photo.name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SLA et modale de succès ───────────────────────────────────────────────

  String _slaLabel(AppLocalizations l10n) => switch (_urgency) {
    IssueUrgency.critique => l10n.issueFormSla2h,
    IssueUrgency.urgent   => l10n.issueFormSla12h,
    IssueUrgency.moyen    => l10n.issueFormSla48h,
    IssueUrgency.faible   => l10n.issueFormSla1week,
  };

  Future<void> _showSuccessDialog(
    String ticketId,
    AppLocalizations l10n, {
    String? photoUploadError,
  }) async {
    final sla = _slaLabel(l10n);
    final displayId = ticketId.startsWith('issue-')
        ? ticketId.substring('issue-'.length) : ticketId;
    String? error = photoUploadError;
    bool retrying = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> retryPhotoUpload() async {
            setDialogState(() => retrying = true);
            final result = await _uploadPhotos(ticketId);
            setDialogState(() {
              retrying = false;
              error = result;
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
                ),
                const SizedBox(height: 16),
                Text(l10n.issueFormSuccessTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.confirmation_number, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Flexible(child: Text(l10n.issueFormSuccessTicketId(displayId),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    ]),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.schedule, color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l10n.issueFormSuccessSlaLabel,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text(sla, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                // Échec d'upload photo : visible et réessayable, sans recréer l'incident.
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l10n.issueFormPhotoUploadFailedTitle,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      ]),
                      const SizedBox(height: 6),
                      Text(l10n.issueFormPhotoUploadFailedMessage(error!),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: retrying ? null : retryPhotoUpload,
                          icon: retrying
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh, size: 16),
                          label: Text(
                              retrying ? l10n.issueFormPhotoUploadRetrying : l10n.issueFormPhotoUploadRetry,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ]),
                  ),
                ] else if (photoUploadError != null) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                    const SizedBox(width: 8),
                    Flexible(child: Text(l10n.issueFormPhotoUploadRetrySuccess,
                        style: const TextStyle(fontSize: 12, color: AppColors.success))),
                  ]),
                ],
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l10n.issueFormSuccessClose),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Compresse et envoie les photos jointes pour [ticketId]. Retourne `null` en
  /// cas de succès, ou un message d'erreur exploitable côté UI sinon (jamais
  /// d'exception avalée silencieusement — voir `_showSuccessDialog`).
  Future<String?> _uploadPhotos(String ticketId) async {
    final photosUrl =
        '${ApiConfig.dbBaseUrl}/api/issues/${Uri.encodeComponent(ticketId)}/photos';
    // Compression sur isolates séparés (ImageCompressor.compress → compute()) :
    // les jusqu'à 5 photos sont traitées en parallèle plutôt que séquentiellement.
    final compressedPhotos = await Future.wait(_photos.map((photo) {
      final originalMime =
          photo.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      return ImageCompressor.compress(photo.bytes, originalMime);
    }));
    final files = [
      for (var i = 0; i < _photos.length; i++)
        (
          bytes: compressedPhotos[i].bytes,
          name: _photos[i].name,
          mimeType: compressedPhotos[i].mimeType,
        ),
    ];
    try {
      await ApiClient.postMultipartFiles(photosUrl, files);
      return null;
    } catch (e) {
      debugPrint('[IssueForm] Échec upload photos : $e');
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // ── Types de problème ─────────────────────────────────────────────────────

  List<String> _problemTypes(AppLocalizations l10n) => [
    l10n.issueFormBreakdown, l10n.issueFormMalfunction, l10n.issueFormWear,
    l10n.issueFormAbnormalNoise, l10n.issueFormLeak, l10n.issueFormOther,
  ];

  // ── Soumission du formulaire ───────────────────────────────────────────────

  Future<void> _submitForm() async {
    if (_isSubmitting) return;
    final l10n = AppLocalizations.of(context)!;

    // Validation étape 2
    bool extraValid = true;
    if (_selectedTab == 0 && !_bioUnlisted && _bioEquipmentId == null) {
      extraValid = false;
    }
    if (_selectedTab == 2 && !_itUnlisted && _itEquipment == null) {
      extraValid = false;
    }
    if (!_formKey2.currentState!.validate() || !extraValid) return;

    final currentUser = AuthService().currentUser;
    final String descRaw = _descriptionController.text.trim();
    // Repli pour les signalements "équipement non répertorié" : le département
    // de l'utilisateur, ou une valeur par défaut si non renseigné (jamais vide).
    final String unlistedDepartment = (currentUser?.department.isNotEmpty ?? false)
        ? currentUser!.department
        : 'Non spécifié';

    final commons = {
      'description':         descRaw,
      'reporter':            currentUser?.fullName ?? 'Inconnu',
      'reporter_id':         currentUser?.id ?? '',
      'reporter_email':      currentUser?.email ?? '',
      'reporter_phone':      currentUser?.phone ?? '',
      'urgency':             _urgency.displayName,
      'equipment_available': _equipmentAvailable,
    };

    final String ticketId = 'issue-${DateTime.now().millisecondsSinceEpoch}';
    final Map<String, dynamic> issueData;

    switch (_selectedTab) {
      case 0: // Biomédical
        if (_bioUnlisted) {
          final name = _bioUnlistedNameController.text.trim();
          issueData = {
            'id':             ticketId,
            'equipment_name': name,
            'department':     unlistedDepartment,
            'type':           _bioProblemType,
            'issue_category': 'Biomédical',
            'assigned_group': 'Biomédical',
            'location_text':  _locationText(_bioBuildingController, _bioLocationController),
            ...commons,
            // Le préfixe permet au technicien d'identifier l'équipement sur site
            'description': '[NON RÉPERTORIÉ: $name] — $descRaw',
          };
        } else {
          final eq = _selectedBioEquipment!;
          issueData = {
            'id':             ticketId,
            'equipment_id':   eq.id,
            'equipment_name': eq.name,
            'department':     eq.department,
            'type':           _bioProblemType,
            'issue_category': 'Biomédical',
            'assigned_group': 'Biomédical',
            'location_text':  _locationText(_bioBuildingController, _bioLocationController),
            ...commons,
          };
        }
      case 1: // Infrastructure
        final infraTag = _infraTagController.text.trim();
        issueData = {
          'id':            ticketId,
          'location_text': '${_infraBuildingController.text.trim()} — ${_infraLocationController.text.trim()}',
          if (infraTag.isNotEmpty) 'location_tag': infraTag,
          'department':    _infraDepartment!,
          'type':          '$_infraCategory / $_infraSubcategory / $_infraIssue',
          'issue_category': 'Infrastructure',
          'assigned_group': 'Infrastructure',
          ...commons,
        };
      case 2: // IT
        if (_itUnlisted) {
          final name = _itUnlistedNameController.text.trim();
          issueData = {
            'id':             ticketId,
            'equipment_name': name,
            'department':     unlistedDepartment,
            'type':           _itProblemType,
            'issue_category': 'IT',
            'assigned_group': 'IT',
            'location_text':  _locationText(_itBuildingController, _itLocationController),
            ...commons,
            'description': '[NON RÉPERTORIÉ: $name] — $descRaw',
          };
        } else {
          final eq = _itEquipment!;
          issueData = {
            'id':             ticketId,
            'equipment_id':   eq.id,
            'equipment_name': eq.name,
            'department':     eq.department,
            'type':           _itProblemType,
            'issue_category': 'IT',
            'assigned_group': 'IT',
            'location_text':  _locationText(_itBuildingController, _itLocationController),
            ...commons,
          };
        }
      default: // Autre
        issueData = {
          'id':             ticketId,
          'department':     _autreDepartment!,
          'type':           _autreProblemType,
          'issue_category': 'Autre',
          'location_text':  _locationText(_autreBuildingController, _autreLocationController),
          ...commons,
        };
    }

    setState(() => _isSubmitting = true);
    try {
      await DbApiService.instance.createIssue(issueData);

      // Upload des photos après création de l'incident (multipart, max 5).
      // L'incident reste créé même en cas d'échec — l'utilisateur en est
      // informé et peut réessayer depuis le dialogue de succès.
      final String? photoUploadError =
          _photos.isNotEmpty ? await _uploadPhotos(ticketId) : null;

      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
      if (!mounted) return;
      await _showSuccessDialog(ticketId, l10n, photoUploadError: photoUploadError);
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

  // ── Concaténation Bâtiment — Lieu pour location_text ─────────────────────

  String _locationText(
      TextEditingController building, TextEditingController location) =>
      '${building.text.trim()} — ${location.text.trim()}';

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
  // BUILD PRINCIPAL
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Bouton Scan & Block ─────────────────────────────────────────
          _buildScanBlockButton(l10n),
          const SizedBox(height: 20),

          // ── En-tête ─────────────────────────────────────────────────────
          Text(l10n.issueFormTitle,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(l10n.issueFormSubtitle,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // ── Indicateur d'étapes ─────────────────────────────────────────
          _buildStepIndicator(l10n),
          const SizedBox(height: 20),

          // ── Carte de l'étape courante ────────────────────────────────────
          if (_currentStep == 0) _buildStep1Card(l10n),
          if (_currentStep == 1) _buildStep2Card(l10n),
        ],
      ),
    );
  }

  // ── Bouton rouge Scan & Block ─────────────────────────────────────────────

  Widget _buildScanBlockButton(AppLocalizations l10n) {
    return Tooltip(
      message: l10n.issueFormScanBlockTooltip,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _openScanBlockQr(l10n),
          icon: const Icon(CupertinoIcons.qrcode_viewfinder, size: 22),
          label: Text(l10n.issueFormScanBlock),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // ── Indicateur 2 étapes ───────────────────────────────────────────────────

  Widget _buildStepIndicator(AppLocalizations l10n) {
    return Column(
      children: [
        Row(children: [
          _stepCircle(1, _currentStep >= 0),
          Expanded(
            child: Container(
              height: 2,
              color: _currentStep >= 1 ? AppColors.primary : AppColors.border,
            ),
          ),
          _stepCircle(2, _currentStep >= 1),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Text(
              l10n.issueFormStep1Label,
              style: TextStyle(
                fontSize: 11,
                color: _currentStep == 0 ? AppColors.primary : AppColors.textMuted,
                fontWeight: _currentStep == 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              l10n.issueFormStep2Label,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                color: _currentStep == 1 ? AppColors.primary : AppColors.textMuted,
                fontWeight: _currentStep == 1 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _stepCircle(int n, bool active) {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.background,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? AppColors.primary : AppColors.border, width: 2,
        ),
      ),
      child: Center(
        child: Text('$n', style: TextStyle(
          color: active ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.bold, fontSize: 14,
        )),
      ),
    );
  }

  // ── Carte étape 1 : Catégorie + Équipement + Urgence ─────────────────────

  Widget _buildStep1Card(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Onglets de catégorie
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _buildTabButton(0, CupertinoIcons.heart_circle,    l10n.issueCategoryBiomedical,     AppColors.primary,       l10n),
                  _buildTabButton(1, CupertinoIcons.building_2_fill, l10n.issueCategoryInfrastructure, AppColors.warning,       l10n),
                  _buildTabButton(2, CupertinoIcons.device_desktop,  l10n.issueCategoryIT,             AppColors.textSecondary, l10n),
                  _buildTabButton(3, CupertinoIcons.question_circle, l10n.issueCategoryOther,          AppColors.textMuted,     l10n),
                ],
              ),
              const SizedBox(height: 24),

              // Sous-formulaire selon l'onglet
              if (_selectedTab == 0) ..._buildBiomedicalForm(l10n),
              if (_selectedTab == 1) ..._buildInfrastructureForm(l10n),
              if (_selectedTab == 2) ..._buildITForm(l10n),
              if (_selectedTab == 3) ..._buildAutreForm(l10n),

              const SizedBox(height: 24),

              // Urgence (visible dès l'étape 1)
              Text(l10n.issueUrgencyLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 8),
              _buildUrgencySelector(),
              const SizedBox(height: 16),

              // Disponibilité pour intervention
              _buildEquipmentAvailableSwitch(l10n),
              const SizedBox(height: 24),

              // Bouton Suivant
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _goToStep2,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(l10n.commonNext),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Carte étape 2 : Description + Photos ─────────────────────────────────

  Widget _buildStep2Card(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description
              Text(l10n.issueFormDescription,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(hintText: l10n.issueFormDescriptionHint),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.issueFormDescriptionRequired;
                  }
                  // Mode Scan & Block : description courte acceptée (1 char min)
                  if (!_scanBlockMode && value.trim().length < 10) {
                    return l10n.issueFormDescriptionMinLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Photos
              Text(l10n.issueFormPhotos,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),

              // Guide visuel photo
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.tips_and_updates_outlined,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l10n.issueFormPhotoGuide,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ),
                ]),
              ),
              const SizedBox(height: 10),

              Text(l10n.issueFormPhotosHint(_maxPhotos),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),

              Wrap(
                spacing: 12, runSpacing: 12,
                children: [
                  ..._photos.asMap().entries.map(
                      (e) => _buildPhotoThumbnail(e.value, e.key)),
                  if (_photos.length < _maxPhotos) _buildAddPhotoButton(l10n),
                ],
              ),
              const SizedBox(height: 24),

              // Reporter (auto-rempli)
              Text(l10n.issueFormYourName,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _buildReporterInfo(),
              const SizedBox(height: 32),

              // Boutons Retour / Annuler / Soumettre
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _currentStep = 0),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(l10n.commonBack),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                if (widget.onCancel != null) ...[
                  const SizedBox(width: 10),
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
                ],
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.send),
                            const SizedBox(width: 8),
                            Text(_photos.isNotEmpty
                                ? l10n.issueFormSubmitWithPhotos(_photos.length)
                                : l10n.issueFormSubmit),
                          ]),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bouton onglet catégorie ───────────────────────────────────────────────

  Widget _buildTabButton(int index, IconData icon, String label,
      Color color, AppLocalizations l10n) {
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: selected ? color : AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? color : AppColors.textSecondary,
          )),
        ]),
      ),
    );
  }

  // ── Sélecteur d'urgence ───────────────────────────────────────────────────

  Widget _buildUrgencySelector() {
    return Wrap(
      spacing: 10, runSpacing: 8,
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
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOUS-FORMULAIRES
  // ══════════════════════════════════════════════════════════════════════════

  // ── Tab 0 : Biomédical ────────────────────────────────────────────────────

  List<Widget> _buildBiomedicalForm(AppLocalizations l10n) {
    final problemTypes = _problemTypes(l10n);
    return [
      Text(l10n.issueFormEquipment,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),

      // Champ de recherche OU nom libre selon le mode
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: _bioUnlisted
              ? TextFormField(
                  controller: _bioUnlistedNameController,
                  decoration: InputDecoration(
                    labelText: l10n.issueFormUnlistedEquipmentNameLabel,
                    hintText: l10n.issueFormUnlistedEquipmentHint,
                    prefixIcon: const Icon(Icons.help_outline,
                        color: AppColors.warning),
                  ),
                  validator: (v) =>
                      (_bioUnlisted && (v == null || v.trim().isEmpty))
                          ? l10n.issueFormUnlistedEquipmentRequired
                          : null,
                )
              : EquipmentPickerField(
                  key: ValueKey(_bioAutocompleteKey),
                  equipmentList: _bioEquipmentList,
                  selectedEquipmentId: _bioEquipmentId,
                  errorText: _bioEquipmentError
                      ? l10n.issueFormEquipmentRequired
                      : null,
                  onSelected: (eq) {
                    setState(() {
                      _bioEquipmentId    = eq.id;
                      _bioEquipmentError = false;
                    });
                  },
                  onClear: () {
                    setState(() {
                      _bioEquipmentId    = null;
                      _bioEquipmentError = false;
                    });
                  },
                ),
        ),
        if (!_bioUnlisted) ...[
          const SizedBox(width: 8),
          _buildQrScanButton(l10n),
        ],
      ]),

      // Aperçu équipement sélectionné
      if (!_bioUnlisted && _selectedBioEquipment != null) ...[
        const SizedBox(height: 12),
        _buildEquipmentAutoFill(_selectedBioEquipment!, l10n),
      ],

      // Avertissement mode non répertorié
      if (_bioUnlisted) ...[
        const SizedBox(height: 8),
        _buildUnlistedWarning(l10n),
      ],

      // Toggle "Équipement non répertorié"
      const SizedBox(height: 10),
      _buildUnlistedToggle(
        unlisted: _bioUnlisted,
        label: l10n.issueFormUnlistedEquipment,
        onToggle: () => setState(() {
          _bioUnlisted = !_bioUnlisted;
          if (_bioUnlisted) {
            _bioEquipmentId    = null;
            _bioEquipmentError = false;
            _bioAutocompleteKey++;
          } else {
            _bioUnlistedNameController.clear();
          }
        }),
      ),

      const SizedBox(height: 20),
      ..._buildLocationFields(
        buildingController: _bioBuildingController,
        locationController: _bioLocationController,
        l10n: l10n,
      ),
      Text(l10n.issueFormProblemType,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _bioProblemType,
        items: problemTypes
            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
            .toList(),
        onChanged: (v) => setState(() => _bioProblemType = v!),
      ),
    ];
  }

  // ── Tab 1 : Infrastructure ────────────────────────────────────────────────

  List<Widget> _buildInfrastructureForm(AppLocalizations l10n) {
    return [
      Text(l10n.issueFormInfraTagNumber,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _infraTagController,
        decoration: InputDecoration(
          hintText: l10n.issueFormInfraTagHint,
          prefixIcon:
              const Icon(Icons.tag, color: AppColors.textSecondary),
        ),
      ),
      const SizedBox(height: 16),

      Text(l10n.commonDepartment,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _infraDepartment,
        hint: Text(l10n.issueFormSelectDepartment),
        items: Department.values
            .map((d) =>
                DropdownMenuItem(value: d.displayName, child: Text(d.displayName)))
            .toList(),
        onChanged: (v) => setState(() => _infraDepartment = v),
        validator: (_) => _infraDepartment == null
            ? l10n.issueFormDepartmentRequired
            : null,
      ),
      const SizedBox(height: 16),

      Text(l10n.issueFormBuilding,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _infraBuildingController,
        decoration: InputDecoration(
          hintText: l10n.issueFormBuildingHint,
          prefixIcon: const Icon(CupertinoIcons.building_2_fill,
              color: AppColors.textSecondary),
        ),
        validator: (v) => (v == null || v.trim().isEmpty)
            ? l10n.issueFormBuildingRequired
            : null,
      ),
      const SizedBox(height: 16),

      Text(l10n.issueFormSourceLocation,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _infraLocationController,
        decoration: InputDecoration(
          hintText: l10n.issueFormLocationHint,
          prefixIcon: const Icon(Icons.location_on_outlined,
              color: AppColors.textSecondary),
        ),
        validator: (v) => (v == null || v.trim().isEmpty)
            ? l10n.issueFormLocationRequired2
            : null,
      ),
      const SizedBox(height: 16),

      Text(l10n.issueFormQuickSearch,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Autocomplete<_InfraSearchResult>(
        key: ValueKey(_infraSearchKey),
        displayStringForOption: (r) =>
            '${r.category} / ${r.subcategory} — ${r.issue}',
        optionsBuilder: (TextEditingValue value) =>
            _searchInfraCatalog(value.text),
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
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textSecondary),
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
                    leading: const Icon(Icons.build_outlined,
                        size: 18, color: AppColors.warning),
                    title: Text(r.issue,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text('${r.category} › ${r.subcategory}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
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

      Text(l10n.issueFormProblemCategory,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _infraCategory,
        hint: Text(l10n.issueFormSelectProblemCategory),
        items: _kInfraCatalog.keys
            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
            .toList(),
        onChanged: (v) => setState(() {
          _infraCategory    = v;
          _infraSubcategory = null;
          _infraIssue       = null;
        }),
        validator: (_) =>
            _infraCategory == null ? l10n.issueFormCategoryRequired : null,
      ),
      const SizedBox(height: 16),

      Text(l10n.issueFormProblemSubcategory,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _infraSubcategory,
        hint: Text(l10n.issueFormSelectProblemSubcategory),
        items: _infraSubcategories
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: (v) =>
            setState(() { _infraSubcategory = v; _infraIssue = null; }),
        validator: (_) => _infraSubcategory == null
            ? l10n.issueFormSubcategoryRequired
            : null,
      ),
      const SizedBox(height: 16),

      Text(l10n.issueFormSpecificIssue,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _infraIssue,
        hint: Text(l10n.issueFormSelectSpecificIssue),
        items: [
          ..._infraIssues.map(
              (issue) => DropdownMenuItem(value: issue, child: Text(issue))),
          DropdownMenuItem(value: 'Other', child: Text(l10n.issueFormOther)),
        ],
        onChanged: (v) => setState(() => _infraIssue = v),
        validator: (_) =>
            _infraIssue == null ? l10n.issueFormIssueRequired : null,
      ),
    ];
  }

  // ── Tab 2 : IT ────────────────────────────────────────────────────────────

  List<Widget> _buildITForm(AppLocalizations l10n) {
    final problemTypes = _problemTypes(l10n);
    return [
      // Mode répertorié : recherche par tag
      if (!_itUnlisted) ...[
        Text(l10n.issueFormTagNumber,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _tagController,
          decoration: InputDecoration(
            hintText: l10n.issueFormTagNumberHint,
            prefixIcon:
                const Icon(Icons.tag, color: AppColors.textSecondary),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.issueFormSearchEquipmentByTag,
              onPressed: _itSearching ? null : _searchByTagNumber,
            ),
          ),
          onFieldSubmitted: (_) => _searchByTagNumber(),
          validator: (_) {
            if (_itUnlisted) return null;
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
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ]),
        ],
        if (_itTagError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline,
                  color: AppColors.error, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_itTagError!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 13)),
              ),
            ]),
          ),
        ],
        if (_itEquipment != null) ...[
          const SizedBox(height: 12),
          _buildEquipmentAutoFill(_itEquipment!, l10n),
        ],
      ],

      // Mode non répertorié : nom libre
      if (_itUnlisted) ...[
        Text(l10n.issueFormUnlistedEquipmentNameLabel,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _itUnlistedNameController,
          decoration: InputDecoration(
            hintText: l10n.issueFormUnlistedEquipmentHint,
            prefixIcon: const Icon(Icons.help_outline,
                color: AppColors.warning),
          ),
          validator: (v) =>
              (_itUnlisted && (v == null || v.trim().isEmpty))
                  ? l10n.issueFormUnlistedEquipmentRequired
                  : null,
        ),
        const SizedBox(height: 8),
        _buildUnlistedWarning(l10n),
      ],

      // Toggle non répertorié IT
      const SizedBox(height: 10),
      _buildUnlistedToggle(
        unlisted: _itUnlisted,
        label: l10n.issueFormUnlistedEquipment,
        onToggle: () => setState(() {
          _itUnlisted = !_itUnlisted;
          if (_itUnlisted) {
            _itEquipment = null;
            _itTagError  = null;
            _tagController.clear();
          } else {
            _itUnlistedNameController.clear();
          }
        }),
      ),

      const SizedBox(height: 20),
      ..._buildLocationFields(
        buildingController: _itBuildingController,
        locationController: _itLocationController,
        l10n: l10n,
      ),
      Text(l10n.issueFormProblemType,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _itProblemType,
        items: problemTypes
            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
            .toList(),
        onChanged: (v) => setState(() => _itProblemType = v!),
      ),
    ];
  }

  // ── Tab 3 : Autre ─────────────────────────────────────────────────────────

  List<Widget> _buildAutreForm(AppLocalizations l10n) {
    final problemTypes = _problemTypes(l10n);
    return [
      Text(l10n.commonDepartment,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _autreDepartment,
        hint: Text(l10n.issueFormSelectDepartment),
        items: Department.values
            .map((d) =>
                DropdownMenuItem(value: d.displayName, child: Text(d.displayName)))
            .toList(),
        onChanged: (v) => setState(() => _autreDepartment = v),
        validator: (_) => _autreDepartment == null
            ? l10n.issueFormDepartmentRequired
            : null,
      ),
      const SizedBox(height: 16),
      ..._buildLocationFields(
        buildingController: _autreBuildingController,
        locationController: _autreLocationController,
        l10n: l10n,
      ),
      Text(l10n.issueFormProblemType,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _autreProblemType,
        items: problemTypes
            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
            .toList(),
        onChanged: (v) => setState(() => _autreProblemType = v!),
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGETS PARTAGÉS
  // ══════════════════════════════════════════════════════════════════════════

  /// Champs Bâtiment + Lieu précis — réutilisés sur les onglets Bio/IT/Autre.
  /// Toujours visibles (équipement répertorié ou non) : il peut avoir été déplacé.
  List<Widget> _buildLocationFields({
    required TextEditingController buildingController,
    required TextEditingController locationController,
    required AppLocalizations l10n,
  }) {
    return [
      Text(l10n.issueFormBuilding,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
        controller: buildingController,
        decoration: InputDecoration(
          hintText: l10n.issueFormBuildingHint,
          prefixIcon: const Icon(CupertinoIcons.building_2_fill,
              color: AppColors.textSecondary),
        ),
        validator: (v) => (v == null || v.trim().isEmpty)
            ? l10n.issueFormBuildingRequired
            : null,
      ),
      const SizedBox(height: 16),

      Text(l10n.issueFormPreciseLocation,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
        controller: locationController,
        decoration: InputDecoration(
          hintText: l10n.issueFormLocationHint,
          prefixIcon: const Icon(Icons.location_on_outlined,
              color: AppColors.textSecondary),
        ),
        validator: (v) => (v == null || v.trim().isEmpty)
            ? l10n.issueFormLocationRequired2
            : null,
      ),
      const SizedBox(height: 16),
    ];
  }

  /// Bandeau d'avertissement pour un équipement non répertorié.
  Widget _buildUnlistedWarning(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber, color: AppColors.warning, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(l10n.issueFormUnlistedWarning,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
      ]),
    );
  }

  /// Case à cocher "Équipement non répertorié".
  Widget _buildUnlistedToggle({
    required bool unlisted,
    required String label,
    required VoidCallback onToggle,
  }) {
    return GestureDetector(
      onTap: onToggle,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          unlisted ? Icons.check_box : Icons.check_box_outline_blank,
          size: 18,
          color: unlisted ? AppColors.warning : AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
          fontSize: 13,
          color: unlisted ? AppColors.warning : AppColors.textSecondary,
          fontWeight: unlisted ? FontWeight.w600 : FontWeight.normal,
        )),
      ]),
    );
  }

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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(eq.name,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('${eq.department} • ${eq.location}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            Text(l10n.issueFormAutoFilled,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.primary)),
          ]),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user?.fullName ?? '',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            if (user?.email != null)
              Text(user!.email,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            if (user?.department != null && user!.department.isNotEmpty)
              Text(user.department,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
        const Icon(Icons.verified_user, color: AppColors.success, size: 18),
      ]),
    );
  }

  Widget _buildPhotoThumbnail(_PhotoItem photo, int index) {
    return Stack(children: [
      GestureDetector(
        onTap: () => _openPhotoPreview(photo),
        child: Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(fit: StackFit.expand, children: [
              Image.memory(
                photo.bytes,
                fit: BoxFit.cover,
                errorBuilder: (context, error, _) => Container(
                  color: AppColors.background,
                  child: const Icon(Icons.broken_image,
                      color: AppColors.textSecondary),
                ),
              ),
              Positioned(
                bottom: 4, right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.zoom_in,
                      color: Colors.white, size: 12),
                ),
              ),
            ]),
          ),
        ),
      ),
      Positioned(
        top: 4, right: 4,
        child: GestureDetector(
          onTap: () => _removePhoto(index),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
                color: AppColors.error, shape: BoxShape.circle),
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
        width: 100, height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary, width: 2),
          color: AppColors.primaryLight,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.add_a_photo, color: AppColors.primary, size: 28),
          const SizedBox(height: 4),
          Text(l10n.issueFormAddPhoto,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _buildEquipmentAvailableSwitch(AppLocalizations l10n) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _equipmentAvailable
            ? AppColors.successLight
            : AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (_equipmentAvailable ? AppColors.success : AppColors.error)
              .withValues(alpha: 0.4),
        ),
      ),
      child: SwitchListTile(
        value: _equipmentAvailable,
        onChanged: (v) => setState(() => _equipmentAvailable = v),
        title: Text(l10n.issueFormEquipmentAvailableLabel,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: Text(l10n.issueFormEquipmentAvailableHint,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        activeThumbColor: AppColors.success,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildQrScanButton(AppLocalizations l10n) {
    return Tooltip(
      message: l10n.issueFormScanQrTooltip,
      child: InkWell(
        onTap: () => _openQrScanner(l10n),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary),
          ),
          child: const Icon(CupertinoIcons.qrcode_viewfinder,
              color: AppColors.primary, size: 24),
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
