import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/equipment.dart';
import '../models/issue.dart';
import '../utils/file_picker.dart';
import '../widgets/urgency_badge.dart';

/// Issue form screen - report a new equipment problem
class IssueFormScreen extends StatefulWidget {
  final String? equipmentId;
  final VoidCallback? onCancel;
  final List<String>? categoryFilter;

  const IssueFormScreen({
    super.key,
    this.equipmentId,
    this.onCancel,
    this.categoryFilter,
  });

  @override
  State<IssueFormScreen> createState() => IssueFormScreenState();
}

class IssueFormScreenState extends State<IssueFormScreen> {
  final _formKey = GlobalKey<FormState>();
  // Source : 'equipment' ou 'location'
  String _issueSource = 'equipment';
  String? _selectedEquipmentId;
  String? _selectedLocationId;
  String _problemType = 'Panne';
  IssueUrgency _urgency = IssueUrgency.moyen;
  final _descriptionController = TextEditingController();
  bool _equipmentError = false;
  int _autocompleteResetKey = 0;

  // Photo handling
  final List<_PhotoItem> _photos = [];
  static const int _maxPhotos = 5;

  /// Retourne true si l'utilisateur a commencé à remplir le formulaire.
  bool get hasUnsavedData =>
      _selectedEquipmentId != null ||
      _selectedLocationId != null ||
      _descriptionController.text.isNotEmpty ||
      _photos.isNotEmpty;

  List<String> _problemTypes(AppLocalizations l10n) => [
    l10n.issueFormBreakdown,
    l10n.issueFormMalfunction,
    l10n.issueFormWear,
    l10n.issueFormAbnormalNoise,
    l10n.issueFormLeak,
    l10n.issueFormOther,
  ];

  @override
  void initState() {
    super.initState();
    _selectedEquipmentId = widget.equipmentId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    // Initialize _problemType with the localized value if still default
    if (_problemType == 'Panne') {
      _problemType = l10n.issueFormBreakdown;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Equipment? get _selectedEquipment {
    if (_selectedEquipmentId == null) return null;
    return DataService().equipment.where((e) => e.id == _selectedEquipmentId).firstOrNull;
  }

  List<Equipment> get _filteredEquipmentList {
    final all = DataService().equipment;
    final filter = widget.categoryFilter;
    if (filter == null || filter.isEmpty) return all;
    return all
        .where((eq) => filter.any((f) => f.toLowerCase() == eq.category.toLowerCase()))
        .toList();
  }

  void _pickPhoto() {
    final l10n = AppLocalizations.of(context)!;
    if (_photos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.issueFormMaxPhotos(_maxPhotos)),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    pickImageFile((String fileName, Uint8List bytes) {
      setState(() {
        _photos.add(_PhotoItem(
          name: fileName,
          bytes: bytes,
        ));
      });
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final problemTypes = _problemTypes(l10n);

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
          const SizedBox(height: 32),

          // Form
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Toggle source : équipement ou lieu/infrastructure
                    Text(
                      l10n.issueFormSourceLabel,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'equipment',
                          label: Text(l10n.issueFormSourceEquipment),
                          icon: const Icon(Icons.medical_services_outlined),
                        ),
                        ButtonSegment(
                          value: 'location',
                          label: Text(l10n.issueFormSourceLocation),
                          icon: const Icon(Icons.location_on_outlined),
                        ),
                      ],
                      selected: {_issueSource},
                      onSelectionChanged: (Set<String> v) {
                        setState(() {
                          _issueSource = v.first;
                          if (_issueSource == 'equipment') {
                            _selectedLocationId = null;
                          } else {
                            _selectedEquipmentId = null;
                            _equipmentError = false;
                            _autocompleteResetKey++;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Sélection équipement ou lieu selon le toggle
                    if (_issueSource == 'equipment') ...[
                      Text(
                        l10n.issueFormEquipment,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Autocomplete<Equipment>(
                        key: ValueKey(_autocompleteResetKey),
                        displayStringForOption: (eq) => '${eq.name} - SN: ${eq.serialNumber}',
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final query = textEditingValue.text.toLowerCase().trim();
                          if (query.isEmpty) return const Iterable<Equipment>.empty();
                          return _filteredEquipmentList.where((eq) =>
                            eq.name.toLowerCase().contains(query) ||
                            eq.serialNumber.toLowerCase().contains(query),
                          );
                        },
                        onSelected: (Equipment eq) {
                          setState(() {
                            _selectedEquipmentId = eq.id;
                            _equipmentError = false;
                          });
                        },
                        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: textController,
                            focusNode: focusNode,
                            onSubmitted: (_) => onFieldSubmitted(),
                            decoration: InputDecoration(
                              hintText: l10n.issueFormSelectEquipment,
                              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                              suffixIcon: _selectedEquipmentId != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      textController.clear();
                                      setState(() {
                                        _selectedEquipmentId = null;
                                        _equipmentError = false;
                                      });
                                    },
                                  )
                                : null,
                              errorText: _equipmentError ? l10n.issueFormSelectEquipment : null,
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
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
                          );
                        },
                      ),
                      if (widget.categoryFilter != null && _filteredEquipmentList.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.warning,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(context)!
                                        .issueFormNoEquipmentInCategory,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_selectedEquipment != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedEquipment!.name,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      '${_selectedEquipment!.department} • ${_selectedEquipment!.location}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      Text(
                        l10n.issueFormSourceLocation,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedLocationId,
                        hint: Text(l10n.issueFormSelectLocation),
                        items: DataService().locations.map((loc) => DropdownMenuItem(
                          value: loc.id,
                          child: Text(loc.label, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedLocationId = v),
                        validator: (_) => _selectedLocationId == null
                            ? l10n.issueFormLocationRequired
                            : null,
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Problem type
                    Text(
                      l10n.issueFormProblemType,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _problemType,
                      items: problemTypes.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      )).toList(),
                      onChanged: (value) => setState(() => _problemType = value!),
                    ),
                    const SizedBox(height: 24),

                    // Urgency
                    const SizedBox(height: 24),
                    Text(
                      l10n.issueUrgencyLabel,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: IssueUrgency.values.map((u) {
                        final selected = _urgency == u;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => setState(() => _urgency = u),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? _urgencyColor(u).withValues(alpha: 0.15) : AppColors.background,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected ? _urgencyColor(u) : AppColors.border,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  UrgencyBadge(urgency: u, isCompact: true),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Description
                    Text(
                      l10n.issueFormDescription,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: l10n.issueFormDescriptionHint,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.issueFormDescriptionRequired;
                        }
                        if (value.length < 10) {
                          return l10n.issueFormDescriptionMinLength;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Photo upload section
                    Text(
                      l10n.issueFormPhotos,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.issueFormPhotosHint(_maxPhotos),
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),

                    // Photo grid
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        // Existing photos
                        ..._photos.asMap().entries.map((entry) {
                          final index = entry.key;
                          final photo = entry.value;
                          return _buildPhotoThumbnail(photo, index);
                        }),

                        // Add photo button
                        if (_photos.length < _maxPhotos)
                          _buildAddPhotoButton(),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Reporter — auto-filled from logged-in user
                    Text(
                      l10n.issueFormYourName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      final user = AuthService().currentUser;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
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
                                    Text(
                                      user!.email,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  if (user?.department != null && user!.department.isNotEmpty)
                                    Text(
                                      user.department,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.verified_user, color: AppColors.success, size: 18),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 32),

                    // Boutons Annuler / Soumettre
                    Row(
                      children: [
                        if (widget.onCancel != null) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onCancel,
                              icon: const Icon(Icons.close, color: AppColors.error),
                              label: Text(l10n.commonCancel, style: const TextStyle(color: AppColors.error)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _submitForm,
                            icon: const Icon(Icons.send),
                            label: Text(_photos.isNotEmpty ? l10n.issueFormSubmitWithPhotos(_photos.length) : l10n.issueFormSubmit),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildPhotoThumbnail(_PhotoItem photo, int index) {
    return Stack(
      children: [
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
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.background,
                child: const Icon(Icons.broken_image, color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton() {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary, style: BorderStyle.solid, width: 2),
          color: AppColors.primaryLight,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo, color: AppColors.primary, size: 28),
            const SizedBox(height: 4),
            Text(
              l10n.issueFormAddPhoto,
              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    final l10n = AppLocalizations.of(context)!;

    // Validation source
    if (_issueSource == 'equipment' && _selectedEquipmentId == null) {
      setState(() => _equipmentError = true);
    }
    if (!_formKey.currentState!.validate()) return;
    if (_issueSource == 'equipment' && _selectedEquipmentId == null) return;

    final currentUser = AuthService().currentUser;
    final Map<String, dynamic> issueData;

    if (_issueSource == 'equipment') {
      final equipment = _selectedEquipment!;
      issueData = {
        'id':             'issue-${DateTime.now().millisecondsSinceEpoch}',
        'equipment_id':   equipment.id,
        'equipment_name': equipment.name,
        'department':     equipment.department,
        'type':           _problemType,
        'description':    _descriptionController.text.trim(),
        'reporter':       currentUser?.fullName ?? 'Inconnu',
        'reporter_id':    currentUser?.id ?? '',
        'reporter_email': currentUser?.email ?? '',
        'urgency':        _urgency.displayName,
        'issue_category': 'Biomédical',
        'assigned_group': 'Biomédical',
      };
    } else {
      final location = DataService().locations.firstWhere((l) => l.id == _selectedLocationId!);
      issueData = {
        'id':             'issue-${DateTime.now().millisecondsSinceEpoch}',
        'location_id':    location.id,
        'department':     location.department,
        'type':           _problemType,
        'description':    _descriptionController.text.trim(),
        'reporter':       currentUser?.fullName ?? 'Inconnu',
        'reporter_id':    currentUser?.id ?? '',
        'reporter_email': currentUser?.email ?? '',
        'urgency':        _urgency.displayName,
        'issue_category': 'Infrastructure',
        'assigned_group': 'Infrastructure',
      };
    }

    try {
      await DbApiService.instance.createIssue(issueData);
      await DataService().reloadIssues();
      NotificationService().generateFromLoadedData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Text(_photos.isNotEmpty ? l10n.issueFormSuccessWithPhotos(_photos.length) : l10n.issueFormSuccess),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      setState(() {
        _issueSource = 'equipment';
        _selectedEquipmentId = null;
        _selectedLocationId = null;
        _equipmentError = false;
        _autocompleteResetKey++;
        _problemType = l10n.issueFormBreakdown;
        _urgency = IssueUrgency.moyen;
        _descriptionController.clear();
        _photos.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.issueFormError(e.toString())),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Color _urgencyColor(IssueUrgency u) {
    switch (u) {
      case IssueUrgency.faible:   return AppColors.textSecondary;
      case IssueUrgency.moyen:    return AppColors.warning;
      case IssueUrgency.urgent:   return AppColors.error;
      case IssueUrgency.critique: return AppColors.critical;
    }
  }
}

/// Photo item model
class _PhotoItem {
  final String name;
  final Uint8List bytes;

  _PhotoItem({required this.name, required this.bytes});
}
