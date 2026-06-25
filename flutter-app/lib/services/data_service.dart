import 'package:flutter/foundation.dart';
import '../models/equipment.dart';
import '../models/issue.dart';
import '../models/inventory_item.dart';
import '../models/user.dart';
import '../data/mock_data.dart';
import 'db_api_service.dart';
import 'auth_api_service.dart';
import 'auth_service.dart';
import 'feature_service.dart';
import '../models/user_role.dart';
import '../models/location.dart';

/// Fournit les données métier (équipements, incidents, inventaire, utilisateurs).
///
/// Charge depuis les APIs au login ; repli sur les données mock
/// si le serveur est inaccessible.
class DataService extends ChangeNotifier {
  static final DataService _instance = DataService._();
  factory DataService() => _instance;

  DataService._() {
    // Données mock par défaut (avant chargement API)
    equipment = List.from(mockEquipment);
    issues    = List.from(mockIssues);
    inventory = List.from(mockInventory);
    users     = List.from(mockUsers);
  }

  List<Equipment>             equipment     = [];
  List<Issue>                 issues        = [];
  List<InventoryItem>         inventory     = [];
  List<User>                  users         = [];
  List<Location>              locations     = [];
  List<Map<String, dynamic>>  deptRequests  = [];
  List<Map<String, dynamic>>  roleRequests  = [];

  /// Ordre de la sidebar par rôle : { 'admin': ['dashboard', 'equipment', …] }
  Map<String, List<String>> sidebarOrder = {};

  /// Config des rôles : nom du rôle → ensemble des permissions actives
  Map<String, Set<String>> _rolePermissionsMap = {};

  bool isLoading = false;
  bool isLoaded  = false;

  /// Horodatage du dernier chargement complet réussi (null avant le 1er chargement).
  DateTime? _lastRefresh;
  DateTime? get lastRefresh => _lastRefresh;

  /// Permet aux écrans de déclencher un rebuild après mutation locale.
  void notify() => notifyListeners();

  /// Charge toutes les données depuis l'API, avec fallback mock.
  Future<void> loadAll() async {
    isLoading = true;
    notifyListeners();

    await _loadEquipment();
    await _loadIssues();
    await _loadInventory();
    await _loadUsers();
    await _loadLocations();
    await _loadSidebarConfig();
    await _loadRolesConfig();
    await _loadDeptRequests();
    await _loadRoleRequests();
    await FeatureService().loadFeatures();

    isLoading    = false;
    isLoaded     = true;
    _lastRefresh = DateTime.now();
    notifyListeners();
  }

  Future<void> _loadEquipment() async {
    try {
      // Mode léger au login : la fiche détail (EquipmentDetailScreen) recharge
      // l'objet complet via getEquipmentById à l'ouverture.
      final raw = await DbApiService.instance.getEquipment(light: true);
      equipment = raw.map(Equipment.fromApiJson).toList();
    } catch (e) {
      debugPrint('DataService: équipements — fallback mock ($e)');
    }
  }

  Future<void> _loadIssues() async {
    try {
      final raw = await DbApiService.instance.getIssues();
      issues = raw.map(Issue.fromApiJson).toList();
    } catch (e) {
      debugPrint('DataService: incidents — fallback mock ($e)');
    }
  }

  Future<void> _loadInventory() async {
    try {
      final raw = await DbApiService.instance.getInventory();
      inventory = raw.map(InventoryItem.fromApiJson).toList();
    } catch (e) {
      debugPrint('DataService: inventaire — fallback mock ($e)');
    }
  }

  Future<void> _loadUsers() async {
    final user = AuthService().currentUser;
    if (user == null || !user.hasRole(UserRole.admin)) return;
    try {
      final raw = await AuthApiService.instance.getUsers();
      users = raw.map(User.fromApiJson).toList();
    } catch (e) {
      debugPrint('DataService: utilisateurs — fallback mock ($e)');
    }
  }

  Future<void> _loadDeptRequests() async {
    final user = AuthService().currentUser;
    if (user == null || !user.hasRole(UserRole.admin)) return;
    try {
      deptRequests = await AuthApiService.instance.getDepartmentRequests(status: 'pending');
    } catch (e) {
      debugPrint('DataService: demandes département — erreur ($e)');
      deptRequests = [];
    }
  }

  /// Recharge les demandes de département en attente (admin seulement).
  Future<void> reloadDeptRequests() async {
    await _loadDeptRequests();
    notifyListeners();
  }

  Future<void> _loadRoleRequests() async {
    final user = AuthService().currentUser;
    if (user == null || !user.hasRole(UserRole.admin)) return;
    try {
      roleRequests = await AuthApiService.instance.getRoleRequests(status: 'pending');
    } catch (e) {
      debugPrint('DataService: demandes de rôle — erreur ($e)');
      roleRequests = [];
    }
  }

  /// Recharge les demandes de rôle en attente (admin seulement).
  Future<void> reloadRoleRequests() async {
    await _loadRoleRequests();
    notifyListeners();
  }

  /// Recharge uniquement les équipements depuis l'API.
  Future<void> reloadEquipment() async {
    await _loadEquipment();
    notifyListeners();
  }

  /// Recharge uniquement les incidents depuis l'API.
  Future<void> reloadIssues() async {
    await _loadIssues();
    notifyListeners();
  }

  /// Recharge uniquement l'inventaire depuis l'API.
  Future<void> reloadInventory() async {
    await _loadInventory();
    notifyListeners();
  }

  /// Recharge uniquement les utilisateurs depuis l'API.
  Future<void> reloadUsers() async {
    await _loadUsers();
    notifyListeners();
  }

  Future<void> _loadLocations() async {
    try {
      final raw = await DbApiService.instance.getLocations();
      locations = raw.map(Location.fromApiJson).toList();
    } catch (e) {
      debugPrint('DataService: lieux — fallback vide ($e)');
      locations = [];
    }
  }

  /// Recharge uniquement les lieux depuis l'API.
  Future<void> reloadLocations() async {
    await _loadLocations();
    notifyListeners();
  }

  Future<void> _loadSidebarConfig() async {
    try {
      final all = await DbApiService.instance.getAllSidebarConfigs();
      sidebarOrder = {
        for (final entry in all.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
      };
    } catch (e) {
      debugPrint('DataService: sidebar config — fallback default ($e)');
    }
  }

  /// Sauvegarde l'ordre de la sidebar pour [role] et notifie les listeners.
  Future<void> saveSidebarConfig(String role, List<String> order) async {
    await DbApiService.instance.updateSidebarConfig(role, order);
    sidebarOrder = Map.from(sidebarOrder)..[role] = order;
    notifyListeners();
  }

  Future<void> _loadRolesConfig() async {
    final user = AuthService().currentUser;
    if (user == null || !user.hasRole(UserRole.admin)) return;
    try {
      final raw = await AuthApiService.instance.getRoles();
      final map = <String, Set<String>>{};
      for (final role in raw) {
        final name = role['name'] as String;
        final perms = (role['permissions'] as List?)?.cast<String>().toSet() ?? <String>{};
        map[name] = perms;
      }
      _rolePermissionsMap = map;
    } catch (e) {
      debugPrint('DataService: roles config — fallback default ($e)');
    }
  }

  /// Recharge la configuration des rôles depuis l'API.
  Future<void> reloadRolesConfig() async {
    await _loadRolesConfig();
    notifyListeners();
  }

  /// Retourne les permissions configurées pour un rôle (null si non chargé).
  Set<String>? permissionsForRole(String roleName) => _rolePermissionsMap[roleName];

  /// Sauvegarde les permissions d'un rôle et met à jour la config locale.
  Future<void> saveRolePermissions(String roleName, List<String> permissions) async {
    await AuthApiService.instance.updateRolePermissions(roleName, permissions);
    _rolePermissionsMap = Map.from(_rolePermissionsMap)..[roleName] = permissions.toSet();
    notifyListeners();
  }
}
