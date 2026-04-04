import 'dart:typed_data';
import 'dart:js' as js;
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/db_api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/equipment.dart';
import '../utils/file_picker.dart';

/// Issue form screen - report a new equipment problem
class IssueFormScreen extends StatefulWidget {
  final String? equipmentId;
  final VoidCallback? onCancel;

  const IssueFormScreen({super.key, this.equipmentId, this.onCancel});

  @override
  State<IssueFormScreen> createState() => IssueFormScreenState();
}

class IssueFormScreenState extends State<IssueFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedEquipmentId;
  final TextEditingController _equipmentSearchController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Domaines et types de problèmes en cascade
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

  String? _selectedDomain;
  String? _selectedProblemType;

  // Speech to text
  bool _isListening = false;
  html.SpeechRecognition? _recognition;

  // Photo handling
  final List<_PhotoItem> _photos = [];
  static const int _maxPhotos = 5;

  bool get hasUnsavedData =>
      _selectedEquipmentId != null ||
      _descriptionController.text.isNotEmpty ||
      _photos.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedEquipmentId = widget.equipmentId;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _equipmentSearchController.dispose();
    super.dispose();
  }

  Equipment? get _selectedEquipment {
    if (_selectedEquipmentId == null) return null;
    return DataService().equipment.where((e) => e.id == _selectedEquipmentId).firstOrNull;
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
        _photos.add(_PhotoItem(name: fileName, bytes: bytes));
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.issueFormTitle,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(l10n.issueFormSubtitle, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 32),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Recherche équipement avec Autocomplete
                    Text(l10n.issueFormEquipment, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Autocomplete<Equipment>(
                      displayStringForOption: (eq) => '${eq.name} (${eq.serialNumber})',
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return DataService().equipment;
                        return DataService().equipment.where((eq) =>
                          eq.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                          eq.serialNumber.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                          eq.department.toLowerCase().contains(textEditingValue.text.toLowerCase())
                        );
                      },
                      onSelected: (Equipment eq) {
                        setState(() => _selectedEquipmentId = eq.id);
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: l10n.issueFormSelectEquipment,
                            prefixIcon: const Icon(Icons.search),
                          ),
                          validator: (value) => _selectedEquipmentId == null ? l10n.issueFormSelectEquipment : null,
                        );
                      },
                    ),

                    // Info équipement sélectionné
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
                                  Text(_selectedEquipment!.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                  Text(
                                    '${_selectedEquipment!.department} • ${_selectedEquipment!.location}',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                    const Text('Domaine *', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedDomain,
                      decoration: const InputDecoration(hintText: 'Sélectionnez un domaine'),
                      items: _problemCategories.keys.map((domain) => DropdownMenuItem(
                        value: domain,
                        child: Text(domain),
                      )).toList(),
                      onChanged: (value) => setState(() {
                        _selectedDomain = value;
                        _selectedProblemType = null;
                      }),
                      validator: (value) => value == null ? 'Sélectionnez un domaine' : null,
                    ),
                    const SizedBox(height: 24),

                    // Type de problème (cascade)
                    if (_selectedDomain != null) ...[
                      const Text('Type de problème *', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedProblemType,
                        decoration: const InputDecoration(hintText: 'Sélectionnez un type de problème'),
                        items: _problemCategories[_selectedDomain]!.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedProblemType = value),
                        validator: (value) => value == null ? 'Sélectionnez un type de problème' : null,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Description + Speech to text
                    Text(l10n.issueFormDescription, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: l10n.issueFormDescriptionHint,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? Colors.red : AppColors.primary,
                          ),
                          onPressed: _toggleListening,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return l10n.issueFormDescriptionRequired;
                        if (value.length < 10) return l10n.issueFormDescriptionMinLength;
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Photos
                    Text(l10n.issueFormPhotos, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(l10n.issueFormPhotosHint(_maxPhotos), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ..._photos.asMap().entries.map((entry) => _buildPhotoThumbnail(entry.value, entry.key)),
                        if (_photos.length < _maxPhotos) _buildAddPhotoButton(),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Reporter auto-rempli
                    Text(l10n.issueFormYourName, style: const TextStyle(fontWeight: FontWeight.w500)),
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
                                  Text(user?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  if (user?.email != null)
                                    Text(user!.email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  if (user?.department != null && user!.department.isNotEmpty)
                                    Text(user.department, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            const Icon(Icons.verified_user, color: AppColors.success, size: 18),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 32),

                    // Boutons
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
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
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
          width: 100, height: 100,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.memory(photo.bytes, fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: AppColors.background, child: const Icon(Icons.broken_image, color: AppColors.textSecondary))),
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
      ],
    );
  }

  Widget _buildAddPhotoButton() {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 100, height: 100,
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
            Text(l10n.issueFormAddPhoto, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
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
      'type':            _selectedProblemType ?? _selectedDomain ?? '',
      'description':     _descriptionController.text.trim(),
      'reporter':        currentUser?.name ?? 'Inconnu',
      'reporter_id':     currentUser?.id ?? '',
      'reporter_email':  currentUser?.email ?? '',
    };

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
        _selectedEquipmentId = null;
        _selectedDomain = null;
        _selectedProblemType = null;
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

class _PhotoItem {
  final String name;
  final Uint8List bytes;
  _PhotoItem({required this.name, required this.bytes});
}