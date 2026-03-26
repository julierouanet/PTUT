import 'dart:typed_data';
import 'dart:js' as js;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../models/equipment.dart';
import '../services/auth_service.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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
  final _descriptionController = TextEditingController();
  final _reporterController = TextEditingController();
  final TextEditingController _equipmentSearchController = TextEditingController();
  
  // Photo handling
  final List<_PhotoItem> _photos = [];
  static const int _maxPhotos = 5;

  final Map<String, List<String>> _problemCategories = {
    'ICT': [
      'Panne réseau',
      'Panne matériel informatique',
      'Problème logiciel',
      'Problème de connexion',
      'Autre ICT',
    ],
    'Biomédical': [
      'Panne',
      'Dysfonctionnement',
      'Calibration requise',
      'Usure',
      'Autre biomédical',
    ],
    'Électrique': [
      'Court-circuit',
      'Surchauffe',
      'Fuite électrique',
      'Panne alimentation',
      'Autre électrique',
    ],
    'Hygiène': [
      'Contamination',
      'Nettoyage requis',
      'Désinfection requise',
      'Autre hygiène',
    ],
    'Général': [
      'Usure',
      'Bruit anormal',
      'Fuite',
      'Autre',
    ],
  };

  bool _isListening = false;
  html.SpeechRecognition? _recognition;

  String? _selectedDomain;
  String? _selectedProblemType;

  @override
  void initState() {
    super.initState();
    _selectedEquipmentId = widget.equipmentId;
    
    // Auto-remplir le nom avec l'utilisateur connecté
    final currentUser = AuthService().currentUser;
    if (currentUser != null) {
      _reporterController.text = currentUser.name;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _reporterController.dispose();
    _equipmentSearchController.dispose();
    super.dispose();
  }

  Equipment? get _selectedEquipment {
    if (_selectedEquipmentId == null) return null;
    return mockEquipment.where((e) => e.id == _selectedEquipmentId).firstOrNull;
  }

  void _pickPhoto() async {
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

    // Create file input for web
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        
        reader.onLoadEnd.listen((event) {
          if (reader.result != null) {
            final bytes = reader.result as Uint8List;
            setState(() {
              _photos.add(_PhotoItem(
                name: file.name,
                bytes: bytes,
              ));
            });
          }
        });
        
        reader.readAsArrayBuffer(file);
      }
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  void _toggleListening() {
    if (_isListening) {
      _recognition?.stop();
      setState(() => _isListening = false);
    } else {
      _recognition = html.SpeechRecognition();
      _recognition!.lang = 'fr-FR';
      _recognition!.continuous = false;
      _recognition!.interimResults = false;

      _recognition!.addEventListener('result', (event) {
        try {
          final jsResults = js.JsObject.fromBrowserObject(event)['results'];
          final jsResult = jsResults[jsResults['length'] - 1];
          final transcript = jsResult[0]['transcript'] as String;
          if (transcript.isNotEmpty) {
            setState(() => _descriptionController.text = transcript);
          }
        } catch (e) {
          print('Speech result error: $e');
        }
      });

      _recognition!.onError.listen((_) {
        setState(() => _isListening = false);
      });

      _recognition!.onEnd.listen((_) {
        setState(() => _isListening = false);
      });

      _recognition!.start();
      setState(() => _isListening = true);
    }
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
                    Autocomplete<Equipment>(
                      displayStringForOption: (eq) => '${eq.name} (${eq.serialNumber})',
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return mockEquipment;
                        }
                        return mockEquipment.where((eq) =>
                          eq.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                          eq.serialNumber.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                          eq.department.toLowerCase().contains(textEditingValue.text.toLowerCase())
                        );
                      },
                      onSelected: (Equipment eq) {
                        setState(() => _selectedEquipmentId = eq.id);
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        _equipmentSearchController.text = controller.text;
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            hintText: 'Recherchez par nom, numéro de série ou département...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          validator: (value) => _selectedEquipmentId == null ? 'Sélectionnez un équipement' : null,
                        );
                      },
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

                    // Domaine
                    const Text(
                      'Domaine *',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedDomain,
                      decoration: const InputDecoration(
                        hintText: 'Sélectionnez un domaine',
                      ),
                      items: _problemCategories.keys.map((domain) => DropdownMenuItem(
                        value: domain,
                        child: Text(domain),
                      )).toList(),
                      onChanged: (value) => setState(() {
                        _selectedDomain = value;
                        _selectedProblemType = null; // reset le type quand domaine change
                      }),
                      validator: (value) => value == null ? 'Sélectionnez un domaine' : null,
                    ),
                    const SizedBox(height: 24),

                    // Type de problème (apparaît après sélection du domaine)
                    if (_selectedDomain != null) ...[
                      const Text(
                        'Type de problème *',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedProblemType,
                        decoration: const InputDecoration(
                          hintText: 'Sélectionnez un type de problème',
                        ),
                        items: _problemCategories[_selectedDomain]!.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedProblemType = value),
                        validator: (value) => value == null ? 'Sélectionnez un type de problème' : null,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Description
                    const Text(
                      'Description du problème *',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Décrivez le problème en détail...',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? Colors.red : AppColors.primary,
                          ),
                          onPressed: _toggleListening,
                        ),
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
                      readOnly: AuthService().currentUser != null,
                      decoration: InputDecoration(
                        hintText: 'Ex: Dr. Martin',
                        suffixIcon: AuthService().currentUser != null 
                          ? const Icon(Icons.lock_outline, color: Colors.grey)
                          : null,
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

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Signalement envoyé avec succès!${_photos.isNotEmpty ? ' (${_photos.length} photo${_photos.length > 1 ? 's' : ''} jointe${_photos.length > 1 ? 's' : ''})' : ''}'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Clear form
      setState(() {
        _selectedEquipmentId = null;
        _selectedDomain = null;
        _selectedProblemType = null;
        _descriptionController.clear();
        _reporterController.clear();
        _photos.clear();
      });
    }
  }
}

/// Photo item model
class _PhotoItem {
  final String name;
  final Uint8List bytes;

  _PhotoItem({required this.name, required this.bytes});
}
