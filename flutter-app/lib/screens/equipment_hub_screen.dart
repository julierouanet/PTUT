import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/settings/categories_tab.dart';
import 'equipment_list_screen.dart';

/// Conteneur du menu « Équipements » avec deux onglets :
///  • « Liste »      → [EquipmentListScreen] (inchangé)
///  • « Catégories » → [CategoriesTab], visible uniquement avec la permission
///                     [Permission.manageCategories].
///
/// Si l'utilisateur n'a pas la permission, un seul onglet est affiché sans
/// TabBar (la liste occupe tout l'espace).
class EquipmentHubScreen extends StatefulWidget {
  /// Navigation principale héritée de [MainScaffold] (transmise à la liste).
  final Function(int, {String? equipmentId}) onNavigate;

  const EquipmentHubScreen({super.key, required this.onNavigate});

  @override
  State<EquipmentHubScreen> createState() => _EquipmentHubScreenState();
}

class _EquipmentHubScreenState extends State<EquipmentHubScreen>
    with SingleTickerProviderStateMixin {
  late final bool _canManageCategories;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _canManageCategories =
        AuthService().hasPermission(Permission.manageCategories);
    // Onglet Catégories seulement si la permission est présente.
    if (_canManageCategories) {
      _tabController = TabController(length: 2, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = EquipmentListScreen(onNavigate: widget.onNavigate);

    // Sans permission : pas de TabBar, la liste occupe tout l'écran.
    if (!_canManageCategories) return list;

    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < AppBreakpoints.tablet;
    final hPad = isMobile ? 16.0 : 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── TabBar style pilule (identique à SettingsScreen) ──────────────────
        Container(
          margin: EdgeInsets.fromLTRB(hPad, hPad, hPad, 0),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.all(3),
            tabs: [
              Tab(
                height: 34,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.inventory_2_outlined, size: 15),
                  const SizedBox(width: 6),
                  Text(l10n.equipmentTabList, style: const TextStyle(fontSize: 12)),
                ]),
              ),
              Tab(
                height: 34,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.category, size: 15),
                  const SizedBox(width: 6),
                  Text(l10n.equipmentTabCategories, style: const TextStyle(fontSize: 12)),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              list,
              const CategoriesTab(),
            ],
          ),
        ),
      ],
    );
  }
}
