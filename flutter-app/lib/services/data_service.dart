import 'package:flutter/foundation.dart';
import '../models/equipment.dart';
import '../models/issue.dart';
import '../models/inventory_item.dart';
import '../models/user.dart';
import '../data/mock_data.dart';
import 'db_api_service.dart';
import 'auth_api_service.dart';

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

  List<Equipment>     equipment = [];
  List<Issue>         issues    = [];
  List<InventoryItem> inventory = [];
  List<User>          users     = [];

  bool isLoading = false;
  bool isLoaded  = false;

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

    isLoading = false;
    isLoaded  = true;
    notifyListeners();
  }

  Future<void> _loadEquipment() async {
    try {
      final raw = await DbApiService.instance.getEquipment();
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
    try {
      final raw = await AuthApiService.instance.getUsers();
      users = raw.map(User.fromApiJson).toList();
    } catch (e) {
      debugPrint('DataService: utilisateurs — fallback mock ($e)');
    }
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
}
