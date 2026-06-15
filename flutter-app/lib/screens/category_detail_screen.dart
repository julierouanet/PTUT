import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/db_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/detail_breadcrumb.dart';
import 'detail_screen_helpers.dart';

/// Fiche d'une catégorie standard (champ texte `equipment.category`).
///
/// Lecture seule : liste des équipements de la catégorie (chaque tuile ouvre
/// [EquipmentDetailScreen]) + fabricants présents (informatif). Pas de section
/// durée de vie / remplacement (réservée aux sous-catégories biomédicales).
class CategoryDetailScreen extends StatefulWidget {
  final String categoryName;

  const CategoryDetailScreen({super.key, required this.categoryName});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _equipment = [];
  List<Map<String, dynamic>> _brands = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await DbApiService.instance.getCategoryDetail(widget.categoryName);
      if (mounted) setState(() {
        _equipment = List<Map<String, dynamic>>.from((detail['equipment'] as List?) ?? const []);
        _brands = List<Map<String, dynamic>>.from((detail['brands'] as List?) ?? const []);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.categoryDetailTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error))))
              : Column(
                  children: [
                    // Fil d'Ariane : [Catégorie, page courante] → masqué (un seul segment connu).
                    DetailBreadcrumb(segments: [
                      BreadcrumbSegment(widget.categoryName),
                    ]),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(widget.categoryName,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 16),

                          // ── Équipements ─────────────────────────────────────
                          detailSectionHeader(
                              Icons.inventory_2_outlined, l10n.subcategoryEquipmentSection),
                          const SizedBox(height: 8),
                          detailEquipmentTileList(context, _equipment,
                              emptyLabel: l10n.settingsEmptyList, subtitleKey: 'department'),
                          const SizedBox(height: 16),

                          // ── Fabricants présents ─────────────────────────────
                          detailSectionHeader(Icons.factory_outlined, l10n.subcategoryBrandsSection),
                          const SizedBox(height: 8),
                          _buildBrandsList(l10n),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // Fabricants présents dans la catégorie : informatif (pas de contexte
  // sous-catégorie disponible ici → pas de navigation vers la fiche fabricant).
  Widget _buildBrandsList(AppLocalizations l10n) {
    if (_brands.isEmpty) return detailEmptyCard(l10n.subcategoryNoBrands);
    return Card(
      child: Column(
        children: _brands.map((b) {
          final modelCount = (b['model_count'] as int?) ?? 0;
          final eqCount = (b['equipment_count'] as int?) ?? 0;
          return ListTile(
            dense: true,
            leading: const Icon(Icons.factory_outlined, size: 18, color: AppColors.primary),
            title: Text(b['name'] as String? ?? '—', style: const TextStyle(fontSize: 14)),
            subtitle: Text(l10n.catalogBrandCounts(modelCount, eqCount),
                style: const TextStyle(fontSize: 12)),
          );
        }).toList(),
      ),
    );
  }
}
