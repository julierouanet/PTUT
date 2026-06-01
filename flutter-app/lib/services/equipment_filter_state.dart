/// Persistance de session des filtres de EquipmentListScreen.
///
/// Singleton pur (sans ChangeNotifier) — mémoire passive lue par initState
/// et écrite à chaque setState. Se réinitialise au logout via [reset].
class EquipmentFilterState {
  static final EquipmentFilterState _i = EquipmentFilterState._();
  factory EquipmentFilterState() => _i;
  EquipmentFilterState._();

  // ── Filtres textuels ─────────────────────────────────────────────────────
  /// '' = valeur par défaut (résolu en l10n.commonAll dans didChangeDependencies)
  String  searchTerm       = '';
  String  departmentFilter = '';
  String  statusFilter     = '';
  String  categoryFilter   = '';
  String? macroCategoryFilter;
  /// Filtre "Mon unité / Ma salle" — réservé au rôle hospitalStaff
  String? locationFilter;

  // ── Filtres PM (techniciens / superviseurs) ───────────────────────────────
  bool filterPmOverdue = false;
  bool filterPmSoon    = false;

  // ── Tri ──────────────────────────────────────────────────────────────────
  /// Index dans l'enum _SortCol (défini dans equipment_list_screen.dart)
  int  sortColIndex = 0;
  bool sortAsc      = true;

  // ── Mode d'affichage (desktop uniquement) ────────────────────────────────
  bool isGridView = false;

  /// Réinitialise tous les filtres — à appeler dans logoutApi().
  void reset() {
    searchTerm          = '';
    departmentFilter    = '';
    statusFilter        = '';
    categoryFilter      = '';
    macroCategoryFilter = null;
    locationFilter      = null;
    filterPmOverdue     = false;
    filterPmSoon        = false;
    sortColIndex        = 0;
    sortAsc             = true;
    isGridView          = false;
  }
}
