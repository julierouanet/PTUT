import 'dart:typed_data';
import 'package:flutter/material.dart';
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
  final _reporterController = TextEditingController();
  
  // Photo handling
  final List<_PhotoItem> _photos = [];
  static const int _maxPhotos = 5;

  final List<String> _problemTypes = [
    'Panne',
    'Dysfonctionnement',
    'Usure',
    'Bruit anormal',
    'Fuite',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _selectedEquipmentId = widget.equipmentId;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _reporterController.dispose();
    super.dispose();
  }

  Equipment? get _selectedEquipment {
    if (_selectedEquipmentId == null) return null;
    return DataService().equipment.where((e) => e.id == _selectedEquipmentId).firstOrNull;
  }

  void _pickPhoto() {
    if (_photos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $_maxPhotos photos autorisées'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Signaler un problème',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Remplissez le formulaire pour signaler un problème d'équipement",
            style: TextStyle(color: AppColors.textSecondary),
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
                    const Text(
                      'Équipement concerné *',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedEquipmentId,
                      decoration: const InputDecoration(
                        hintText: 'Sélectionnez un équipement',
                      ),
                      items: DataService().equipment.map((eq) => DropdownMenuItem(
                        value: eq.id,
                        child: Text('${eq.name} (${eq.serialNumber})'),
                      )).toList(),
                      onChanged: (value) => setState(() => _selectedEquipmentId = value),
                      validator: (value) => value == null ? 'Sélectionnez un équipement' : null,
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
                    const Text(
                      'Type de problème *',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _problemType,
                      items: _problemTypes.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      )).toList(),
                      onChanged: (value) => setState(() => _problemType = value!),
                    ),
                    const SizedBox(height: 24),

                    // Description
                    const Text(
                      'Description du problème *',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Décrivez le problème en détail...',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La description est obligatoire';
                        }
                        if (value.length < 10) {
                          return 'La description doit contenir au moins 10 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Photo upload section
                    const Text(
                      'Photos (optionnel)',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ajoutez jusqu\'à $_maxPhotos photos pour illustrer le problème',
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

                    // Reporter name
                    const Text(
                      'Votre nom *',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reporterController,
                      decoration: const InputDecoration(
                        hintText: 'Ex: Dr. Martin',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Votre nom est obligatoire';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitForm,
                        icon: const Icon(Icons.send),
                        label: Text('Soumettre le signalement${_photos.isNotEmpty ? ' (${_photos.length} photo${_photos.length > 1 ? 's' : ''})' : ''}'),
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
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, color: AppColors.primary, size: 28),
            SizedBox(height: 4),
            Text(
              'Ajouter',
              style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final equipment = _selectedEquipment!;
    final issueData = {
      'id':             'issue-${DateTime.now().millisecondsSinceEpoch}',
      'equipment_id':   equipment.id,
      'equipment_name': equipment.name,
      'department':     equipment.department,
      'type':           _problemType,
      'description':    _descriptionController.text.trim(),
      'reporter':       _reporterController.text.trim().isNotEmpty
                          ? _reporterController.text.trim()
                          : AuthService().currentUser?.name ?? 'Inconnu',
    };

    try {
      await DbApiService.instance.createIssue(issueData);
      await DataService().reloadIssues();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Text('Signalement envoyé !${_photos.isNotEmpty ? ' (${_photos.length} photo${_photos.length > 1 ? "s" : ""})' : ''}'),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      setState(() {
        _selectedEquipmentId = null;
        _problemType = 'Panne';
        _descriptionController.clear();
        _reporterController.clear();
        _photos.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur lors de l\'envoi: $e'),
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
