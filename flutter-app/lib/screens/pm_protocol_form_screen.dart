import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/pm_protocol.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';

/// Formulaire de création/édition d'un protocole PM pour une sous-catégorie.
class PmProtocolFormScreen extends StatefulWidget {
  final int subcategoryId;
  final PmProtocol? existing;

  const PmProtocolFormScreen({
    super.key,
    required this.subcategoryId,
    this.existing,
  });

  @override
  State<PmProtocolFormScreen> createState() => _PmProtocolFormScreenState();
}

class _PmProtocolFormScreenState extends State<PmProtocolFormScreen> {
  static const List<int> _frequencyOptions = PmProtocol.frequencyOptions;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  int? _frequencyMonths;
  final List<TextEditingController> _taskControllers = [];
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _frequencyMonths = _frequencyOptions.contains(existing.frequencyMonths)
          ? existing.frequencyMonths
          : null;
      if (existing.estimatedDurationHours != null) {
        _durationController.text = existing.estimatedDurationHours!.toString();
      }
      for (final task in existing.checklist) {
        _taskControllers.add(TextEditingController(text: task));
      }
    }
    if (_taskControllers.isEmpty) {
      _taskControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    for (final c in _taskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addTask() {
    setState(() => _taskControllers.add(TextEditingController()));
  }

  void _removeTask(int index) {
    setState(() {
      final removed = _taskControllers.removeAt(index);
      removed.dispose();
    });
  }

  void _reorderTasks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _taskControllers.removeAt(oldIndex);
      _taskControllers.insert(newIndex, item);
    });
  }

  Future<void> _save(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;

    final tasks = _taskControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.commonApiError),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final durationText = _durationController.text.trim();
    final duration = durationText.isEmpty ? null : double.tryParse(durationText);

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await DbApiService.instance.updatePmProtocol(
          widget.existing!.id,
          name: _nameController.text.trim(),
          frequencyMonths: _frequencyMonths,
          estimatedDurationHours: duration,
          checklist: tasks,
        );
      } else {
        await DbApiService.instance.createPmProtocol(
          subcategoryId: widget.subcategoryId,
          name: _nameController.text.trim(),
          frequencyMonths: _frequencyMonths!,
          estimatedDurationHours: duration,
          checklist: tasks,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.pmProtocolSaved),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.commonApiError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.pmProtocolEdit : l10n.pmProtocolAdd),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.pmProtocolNameLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.pmProtocolNameLabel : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _frequencyMonths,
              decoration: InputDecoration(
                labelText: l10n.pmProtocolFrequencyLabel,
                border: const OutlineInputBorder(),
              ),
              items: _frequencyOptions
                  .map((m) => DropdownMenuItem<int>(
                        value: m,
                        child: Text(l10n.pmFrequencyValue(m)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _frequencyMonths = v),
              validator: (v) => v == null ? l10n.pmProtocolFrequencyLabel : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _durationController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.pmProtocolDurationLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed <= 0) {
                  return l10n.pmProtocolDurationLabel;
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text(
              l10n.pmProtocolChecklistLabel,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: _reorderTasks,
              children: [
                for (int i = 0; i < _taskControllers.length; i++)
                  Padding(
                    key: ValueKey(_taskControllers[i]),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.drag_handle, size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _taskControllers[i],
                            decoration: InputDecoration(
                              hintText: l10n.pmProtocolTaskHint,
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                          onPressed: _taskControllers.length > 1
                              ? () => _removeTask(i)
                              : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            TextButton.icon(
              onPressed: _addTask,
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.pmProtocolAddTask),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : () => _save(l10n),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.commonSave),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
