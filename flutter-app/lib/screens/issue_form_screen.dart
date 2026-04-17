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
import '../models/issue.dart';
import '../utils/file_picker.dart';
import '../widgets/urgency_badge.dart';

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
  String _problemType = 'Panne';
  IssueUrgency _urgency = IssueUrgency.moyen;
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
  String _speechLang = 'fr-FR';
  html.SpeechRecognition? _recognition;

  // QR Scanner
  bool _isScanning = false;

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
    _recognition?.stop();
    _descriptionController.dispose();
    _equipmentSearchController.dispose();
    super.dispose();
  }

  Equipment? get _selectedEquipment {
    if (_selectedEquipmentId == null) return null;
    return DataService().equipment.where((e) => e.id == _selectedEquipmentId).firstOrNull;
  }

  // ─── QR Scanner ──────────────────────────────────────────────
  void _startQRScan() async {
    setState(() => _isScanning = true);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _QRScanDialog(
        onScanned: (String qrData) {
          Navigator.of(context).pop();
          _handleQRResult(qrData);
        },
        onCancel: () {
          Navigator.of(context).pop();
          setState(() => _isScanning = false);
        },
      ),
    );

    setState(() => _isScanning = false);
  }

  void _handleQRResult(String qrData) {
    final equipment = DataService().equipment.where((eq) =>
      eq.id == qrData ||
      eq.serialNumber == qrData ||
      eq.name.toLowerCase() == qrData.toLowerCase()
    ).firstOrNull;

    if (equipment != null) {
      setState(() => _selectedEquipmentId = equipment.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Text('Équipement trouvé : ${equipment.name}'),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text('Aucun équipement trouvé pour ce QR code : $qrData')),
        ]),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ─── Speech to text ──────────────────────────────────────────
  void _toggleListening() {
    if (_isListening) {
      _recognition?.stop();
      setState(() => _isListening = false);
    } else {
      _recognition = html.SpeechRecognition();
      _recognition!.lang = _speechLang;
      _recognition!.continuous = true;
      _recognition!.interimResults = false;

      _recognition!.addEventListener('result', (event) {
        try {
          final jsResults = js.JsObject.fromBrowserObject(event)['results'];
          final jsResult = jsResults[jsResults['length'] - 1];
          final transcript = jsResult[0]['transcript'] as String;
          if (transcript.isNotEmpty) {
            setState(() {
              final existing = _descriptionController.text.trim();
              _descriptionController.text = existing.isEmpty
                  ? transcript
                  : '$existing $transcript';
              _descriptionController.selection = TextSelection.fromPosition(
                TextPosition(offset: _descriptionController.text.length),
              );
            });
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

  // ─── Photos ──────────────────────────────────────────────────
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
    setState(() => _photos.removeAt(index));
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

                    // ── Équipement ──────────────────────────────
                    Text(l10n.issueFormEquipment, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Barre de recherche
                        Expanded(
                          child: Autocomplete<Equipment>(
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
                                validator: (value) => _selectedEquipmentId == null
                                    ? l10n.issueFormSelectEquipment
                                    : null,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Bouton QR Code
                        Tooltip(
                          message: 'Scanner le QR code de l\'équipement',
                          child: InkWell(
                            onTap: _isScanning ? null : _startQRScan,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 52,
                              width: 52,
                              decoration: BoxDecoration(
                                color: _isScanning ? AppColors.primaryLight : AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _isScanning
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : const Icon(Icons.qr_code_scanner, color: Colors.white, size: 26),
                            ),
                          ),
                        ),
                      ],
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

                    // ── Domaine ─────────────────────────────────
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

                    // ── Type de problème (cascade) ───────────────
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

                    // ── Urgence ─────────────────────────────────
                    Text(l10n.issueUrgencyLabel, style: const TextStyle(fontWeight: FontWeight.w500)),
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

                    // ── Description + sélecteur langue + micro ──
                    Row(
                      children: [
                        Text(l10n.issueFormDescription, style: const TextStyle(fontWeight: FontWeight.w500)),
                        const Spacer(),
                        // Sélecteur langue dictée
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _speechLang,
                              isDense: true,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                              icon: const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
                              items: const [
                                DropdownMenuItem(value: 'fr-FR', child: Text('🇫🇷 Français')),
                                DropdownMenuItem(value: 'en-US', child: Text('🇺🇸 English (US)')),
                                DropdownMenuItem(value: 'en-GB', child: Text('🇬🇧 English (UK)')),
                                DropdownMenuItem(value: 'rw-RW', child: Text('🇷🇼 Kinyarwanda')),
                              ],
                              onChanged: (val) => setState(() => _speechLang = val ?? 'fr-FR'),
                            ),
                          ),
                        ),
                      ],
                    ),
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

                    // ── Photos ──────────────────────────────────
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

                    // ── Reporter auto-rempli ─────────────────────
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
                                  Text(
                                    user?.fullName ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
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

                    // ── Boutons ─────────────────────────────────
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
                            label: Text(_photos.isNotEmpty
                                ? l10n.issueFormSubmitWithPhotos(_photos.length)
                                : l10n.issueFormSubmit),
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
          width: 100, height: 100,
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
      'id':             'issue-${DateTime.now().millisecondsSinceEpoch}',
      'equipment_id':   equipment.id,
      'equipment_name': equipment.name,
      'department':     equipment.department,
      'type':           _selectedProblemType ?? _selectedDomain ?? '',
      'description':    _descriptionController.text.trim(),
      'reporter':       currentUser?.fullName ?? 'Inconnu',
      'reporter_id':    currentUser?.id ?? '',
      'reporter_email': currentUser?.email ?? '',
      'urgency':        _urgency.displayName,
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
          Text(_photos.isNotEmpty
              ? l10n.issueFormSuccessWithPhotos(_photos.length)
              : l10n.issueFormSuccess),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      setState(() {
        _selectedEquipmentId = null;
        _selectedDomain = null;
        _selectedProblemType = null;
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
      case IssueUrgency.faible: return AppColors.textSecondary;
      case IssueUrgency.moyen:  return AppColors.warning;
      case IssueUrgency.urgent: return AppColors.error;
    }
  }
}

// ─── Dialog QR Scanner ────────────────────────────────────────────────────────

class _QRScanDialog extends StatefulWidget {
  final void Function(String) onScanned;
  final VoidCallback onCancel;

  const _QRScanDialog({required this.onScanned, required this.onCancel});

  @override
  State<_QRScanDialog> createState() => _QRScanDialogState();
}
class _QRScanDialogState extends State<_QRScanDialog> {
  html.VideoElement? _video;
  html.DivElement? _videoContainer;
  bool _cameraReady = false;
  bool _cameraError = false;
  String _errorMessage = '';
  bool _scanned = false;

  // Clé pour trouver le container Flutter dans le DOM
  final _containerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // On attend que le widget soit rendu avant de démarrer la caméra
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  void _startCamera() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {'facingMode': 'environment', 'width': 640, 'height': 480},
      });

      _video = html.VideoElement()
        ..srcObject = stream
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.display = 'block';

      // Crée un container pour la vidéo
      _videoContainer = html.DivElement()
        ..style.position = 'fixed'
        ..style.zIndex = '10000'
        ..style.overflow = 'hidden'
        ..style.borderRadius = '12px'
        ..style.backgroundColor = 'black';

      _videoContainer!.append(_video!);
      html.document.body!.append(_videoContainer!);

      // Positionne le container sur la zone noire du dialog
      _updateVideoPosition();

      // Met à jour la position si la fenêtre change
      html.window.onResize.listen((_) => _updateVideoPosition());

      _video!.onLoadedMetadata.listen((_) {
        if (mounted) {
          setState(() => _cameraReady = true);
          _startDecoding();
        }
      });

      // Fallback
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_cameraReady) {
          setState(() => _cameraReady = true);
          _startDecoding();
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = true;
          _errorMessage = 'Caméra non disponible.\nVérifiez les permissions du navigateur.';
        });
      }
    }
  }

  void _updateVideoPosition() {
    final ctx = _containerKey.currentContext;
    if (ctx == null || _videoContainer == null) return;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;

    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    _videoContainer!.style.left = '${offset.dx}px';
    _videoContainer!.style.top = '${offset.dy}px';
    _videoContainer!.style.width = '${size.width}px';
    _videoContainer!.style.height = '${size.height}px';
  }

  void _stopCamera() {
    _video?.srcObject?.getTracks().forEach((t) => t.stop());
    _videoContainer?.remove();
    _videoContainer = null;
  }

  void _startDecoding() {
    Future.doWhile(() async {
      if (!mounted || _scanned) return false;
      if (_video == null) {
        await Future.delayed(const Duration(milliseconds: 300));
        return true;
      }

      try {
        final w = _video!.videoWidth;
        final h = _video!.videoHeight;
        if (w == 0 || h == 0) {
          await Future.delayed(const Duration(milliseconds: 300));
          return true;
        }

        final canvas = html.CanvasElement(width: w, height: h);
        canvas.context2D.drawImage(_video!, 0, 0);
        final imageData = canvas.context2D.getImageData(0, 0, w, h);

        final result = js.context.callMethod('jsQR', [
          imageData.data,
          w,
          h,
          js.JsObject.jsify({'inversionAttempts': 'dontInvert'}),
        ]);

        if (result != null) {
          final data = result['data'] as String? ?? '';
          if (data.isNotEmpty && !_scanned) {
            _scanned = true;
            _stopCamera();
            if (mounted) widget.onScanned(data);
            return false;
          }
        }
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 150));
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Titre
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text('Scanner QR Code',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _stopCamera();
                    widget.onCancel();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Pointez la caméra vers le QR code de l\'équipement',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Zone caméra
            if (_cameraError)
              Container(
                height: 260,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.no_photography, size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(_errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              )
            else
              // Ce container sert de "marqueur" — on lit ses coordonnées
              // pour positionner la vidéo native exactement dessus
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    key: _containerKey,   // ← clé pour lire la position
                    height: 260,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // Indicateur chargement par-dessus le fond noir
                    child: !_cameraReady
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 12),
                              Text('Démarrage caméra...',
                                  style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Cadre de visée (par-dessus la vidéo native)
                  if (_cameraReady)
                    IgnorePointer(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primary, width: 2.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _stopCamera();
                  widget.onCancel();
                },
                icon: const Icon(Icons.close, color: AppColors.error),
                label: const Text('Annuler', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ─── Modèle photo ─────────────────────────────────────────────────────────────

class _PhotoItem {
  final String name;
  final Uint8List bytes;
  _PhotoItem({required this.name, required this.bytes});
}