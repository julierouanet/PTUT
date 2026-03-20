import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/auth_service.dart';
import '../models/equipment.dart';
import '../utils/file_picker.dart';

/// Issue form screen - report a new equipment problem
class IssueFormScreen extends StatefulWidget {
  final String? equipmentId;

  const IssueFormScreen({super.key, this.equipmentId});

  @override
  State<IssueFormScreen> createState() => _IssueFormScreenState();
}

class _IssueFormScreenState extends State<IssueFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedEquipmentId;
  String _problemType = 'Panne';
  final _descriptionController = TextEditingController();

  // Photo handling
  final List<_PhotoItem> _photos = [];
  static const int _maxPhotos = 5;

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
                    // Equipment selection
                    Text(
                      l10n.issueFormEquipment,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedEquipmentId,
                      decoration: InputDecoration(
                        hintText: l10n.issueFormSelectEquipment,
                      ),
                      items: DataService().equipment.map((eq) => DropdownMenuItem(
                        value: eq.id,
                        child: Text('${eq.name} (${eq.serialNumber})'),
                      )).toList(),
                      onChanged: (value) => setState(() => _selectedEquipmentId = value),
                      validator: (value) => value == null ? l10n.issueFormSelectEquipment : null,
                    ),

                    // Show selected equipment info
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
                                    user?.name ?? '',
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

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitForm,
                        icon: const Icon(Icons.send),
                        label: Text(_photos.isNotEmpty ? l10n.issueFormSubmitWithPhotos(_photos.length) : l10n.issueFormSubmit),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
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
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;
    final equipment = _selectedEquipment!;
    final currentUser = AuthService().currentUser;
    final issueData = {
      'id':              'issue-${DateTime.now().millisecondsSinceEpoch}',
      'equipment_id':    equipment.id,
      'equipment_name':  equipment.name,
      'department':      equipment.department,
      'type':            _problemType,
      'description':     _descriptionController.text.trim(),
      'reporter':        currentUser?.name ?? 'Inconnu',
      'reporter_id':     currentUser?.id ?? '',
      'reporter_email':  currentUser?.email ?? '',
    };

    try {
      await DbApiService.instance.createIssue(issueData);
      await DataService().reloadIssues();
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
        _selectedEquipmentId = null;
        _problemType = l10n.issueFormBreakdown;
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
}

/// Photo item model
class _PhotoItem {
  final String name;
  final Uint8List bytes;

  _PhotoItem({required this.name, required this.bytes});
}
