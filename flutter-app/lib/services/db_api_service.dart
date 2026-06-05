import 'dart:convert';
import 'api_client.dart';
import 'api_config.dart';
import '../models/equipment.dart';
import '../models/issue_detail.dart';

/// Service de données — communique avec db-service.
///
/// Retourne des Map<String, dynamic> bruts pour rester découplé des modèles.
/// Les écrans peuvent parser avec leurs modèles existants ou utiliser les maps directement.
class DbApiService {
  DbApiService._();
  static final DbApiService instance = DbApiService._();

  // ── ÉQUIPEMENTS ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getEquipment({
    String? department,
    String? status,
    String? category,
  }) async {
    var url = ApiConfig.equipmentUrl;
    final params = <String>[];
    if (department != null) params.add('department=${Uri.encodeComponent(department)}');
    if (status     != null) params.add('status=${Uri.encodeComponent(status)}');
    if (category   != null) params.add('category=${Uri.encodeComponent(category)}');
    if (params.isNotEmpty)  url += '?${params.join('&')}';

    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  Future<Map<String, dynamic>> getEquipmentById(String id) async {
    final url = '${ApiConfig.equipmentUrl}/$id';
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Equipment?> getEquipmentByTagNumber(String tagNumber) async {
    final url = ApiConfig.equipmentByTagUrl(tagNumber);
    final response = await ApiClient.get(url);
    if (response.statusCode == 404) return null;
    _checkStatus(response, url);
    return Equipment.fromApiJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createEquipment(Map<String, dynamic> data) async {
    final response = await ApiClient.post(ApiConfig.equipmentUrl, data);
    _checkStatus(response, ApiConfig.equipmentUrl);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateEquipment(String id, Map<String, dynamic> data) async {
    final url = '${ApiConfig.equipmentUrl}/$id';
    final response = await ApiClient.put(url, data);
    _checkStatus(response, url);
  }

  Future<void> updateEquipmentStatus(String id, String status) async {
    final url = '${ApiConfig.equipmentUrl}/$id';
    final response = await ApiClient.put(url, {'status': status});
    _checkStatus(response, url);
  }

  Future<void> deleteEquipment(String id, {String? reason}) async {
    var url = '${ApiConfig.equipmentUrl}/$id';
    if (reason != null && reason.isNotEmpty) url += '?reason=${Uri.encodeComponent(reason)}';
    final response = await ApiClient.delete(url);
    _checkStatus(response, url);
  }

  Future<void> addMaintenanceRecord(
    String equipmentId, {
    required String date,
    required String intervention,
    required String technician,
    bool isFuture = false,
  }) async {
    final url = '${ApiConfig.equipmentUrl}/$equipmentId/maintenance';
    final response = await ApiClient.post(url, {
      'date': date,
      'intervention': intervention,
      'technician': technician,
      'is_future': isFuture,
    });
    _checkStatus(response, url);
  }

  /// Valide une maintenance préventive (POST enrichi v3).
  /// Retourne la réponse JSON : { maintenance_record_id, next_preventive_maintenance, parts_updated }
  Future<Map<String, dynamic>> validatePreventiveMaintenance(
    String equipmentId, {
    required List<Map<String, dynamic>> checklistSnapshot,
    String? notes,
    int? durationMinutes,
    List<Map<String, dynamic>> partsUsed = const [],
  }) async {
    final url = '${ApiConfig.equipmentUrl}/$equipmentId/maintenance';
    final response = await ApiClient.post(url, {
      'checklist_snapshot': checklistSnapshot,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      'parts_used': partsUsed,
      'maintenance_type': 'preventive',
    });
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Met à jour (UPSERT) la fréquence PM d'un équipement.
  Future<void> updatePmPlan(String equipmentId, int frequencyMonths) async {
    final url = ApiConfig.equipmentPmPlanUrl(equipmentId);
    final response = await ApiClient.put(url, {'frequency_months': frequencyMonths});
    _checkStatus(response, url);
  }

  // ── LIEUX ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLocations() async {
    final response = await ApiClient.get(ApiConfig.locationsUrl);
    _checkStatus(response, ApiConfig.locationsUrl);
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  // ── INCIDENTS ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getIssues({
    String? status,
    String? department,
    String? equipmentId,
  }) async {
    var url = ApiConfig.issuesUrl;
    final params = <String>[];
    if (status      != null) params.add('status=${Uri.encodeComponent(status)}');
    if (department  != null) params.add('department=${Uri.encodeComponent(department)}');
    if (equipmentId != null) params.add('equipment_id=${Uri.encodeComponent(equipmentId)}');
    if (params.isNotEmpty)   url += '?${params.join('&')}';

    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  Future<Map<String, dynamic>> getIssueById(String id) async {
    final url = '${ApiConfig.issuesUrl}/$id';
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Retourne le détail complet d'un incident (enrichi : équipement, audit, maintenance).
  Future<IssueDetail> getIssueDetail(String id) async {
    final data = await getIssueById(id);
    return IssueDetail.fromApiJson(data);
  }

  Future<void> createIssue(Map<String, dynamic> issue) async {
    final response = await ApiClient.post(ApiConfig.issuesUrl, issue);
    _checkStatus(response, ApiConfig.issuesUrl);
  }

  Future<void> updateIssue(String id, Map<String, dynamic> data) async {
    final url = '${ApiConfig.issuesUrl}/$id';
    final response = await ApiClient.put(url, data);
    _checkStatus(response, url);
  }

  Future<void> deleteIssue(String id) async {
    final url = '${ApiConfig.issuesUrl}/$id';
    final response = await ApiClient.delete(url);
    _checkStatus(response, url);
  }

  Future<void> reassignIssue(String id, String newGroup, String reason) async {
    final url = '${ApiConfig.issuesUrl}/$id/reassign';
    final response = await ApiClient.patch(url, {'new_group': newGroup, 'reason': reason});
    _checkStatus(response, url);
  }

  Future<void> escalateIssue(String id, String escalationStatus, String comment) async {
    final url = '${ApiConfig.issuesUrl}/$id/escalate';
    final response = await ApiClient.patch(url, {
      'escalation_status': escalationStatus,
      'escalation_comment': comment,
    });
    _checkStatus(response, url);
  }

  // ── INVENTAIRE ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getInventory({
    String? status,
    String? category,
  }) async {
    var url = ApiConfig.inventoryUrl;
    final params = <String>[];
    if (status   != null) params.add('status=${Uri.encodeComponent(status)}');
    if (category != null) params.add('category=${Uri.encodeComponent(category)}');
    if (params.isNotEmpty) url += '?${params.join('&')}';

    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  Future<Map<String, dynamic>> createInventoryItem(Map<String, dynamic> data) async {
    final response = await ApiClient.post(ApiConfig.inventoryUrl, data);
    _checkStatus(response, ApiConfig.inventoryUrl);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateInventoryItem(String id, Map<String, dynamic> data) async {
    final url = '${ApiConfig.inventoryUrl}/$id';
    final response = await ApiClient.put(url, data);
    _checkStatus(response, url);
  }

  Future<void> updateStock(String id, int newStock) async {
    final url = '${ApiConfig.inventoryUrl}/$id';
    final response = await ApiClient.put(url, {'current_stock': newStock});
    _checkStatus(response, url);
  }

  Future<void> deleteInventoryItem(String id) async {
    final url = '${ApiConfig.inventoryUrl}/$id';
    final response = await ApiClient.delete(url);
    _checkStatus(response, url);
  }

  // ── LOGS ───────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLogs({
    String? action,
    String? userId,
    String? targetType,
    String? from,
    String? to,
    int limit = 500,
  }) async {
    var url = '${ApiConfig.logsUrl}?limit=$limit';
    if (action     != null) url += '&action=${Uri.encodeComponent(action)}';
    if (userId     != null) url += '&user_id=${Uri.encodeComponent(userId)}';
    if (targetType != null) url += '&target_type=${Uri.encodeComponent(targetType)}';
    if (from       != null) url += '&from=${Uri.encodeComponent(from)}';
    if (to         != null) url += '&to=${Uri.encodeComponent(to)}';

    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  // ── RESTAURATION ───────────────────────────────────────────────────────────

  Future<void> restoreEquipment(Map<String, dynamic> snapshot) async {
    final url = '${ApiConfig.equipmentUrl}/restore';
    final response = await ApiClient.post(url, snapshot);
    _checkStatus(response, url);
  }

  Future<void> restoreEquipmentState(String id, Map<String, dynamic> oldValues) async {
    final url = '${ApiConfig.equipmentUrl}/$id';
    final response = await ApiClient.put(url, oldValues);
    _checkStatus(response, url);
  }

  Future<Map<String, dynamic>> restoreDeletedUser(Map<String, dynamic> snapshot) async {
    final url = '${ApiConfig.usersUrl}/restore';
    final response = await ApiClient.post(url, {'snapshot': snapshot});
    _checkStatus(response, url);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> updateUser(String id, Map<String, dynamic> data) async {
    final url = '${ApiConfig.usersUrl}/$id';
    final response = await ApiClient.put(url, data);
    _checkStatus(response, url);
  }

  Future<void> toggleUser(String id) async {
    final url = '${ApiConfig.usersUrl}/$id/toggle';
    final response = await ApiClient.patch(url, {});
    _checkStatus(response, url);
  }

  Future<Map<String, dynamic>> getUserById(String id) async {
    final url = '${ApiConfig.usersUrl}/$id';
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  // ── Utilitaire ─────────────────────────────────────────────────────────────

  void _checkStatus(dynamic response, String url) {
    if (response.statusCode >= 400) {
      throw ApiException(
        statusCode: response.statusCode as int,
        message: _extractError(response.body as String),
        url: url,
      );
    }
  }

  String _extractError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['error'] as String? ?? body;
    } catch (_) {
      return body;
    }
  }

  // ── CONFIGURATION SIDEBAR ─────────────────────────────────────────────────

  /// Récupère l'ordre de la sidebar pour [role].
  /// Retourne une liste de screen_type (strings) dans l'ordre configuré.
  /// Si aucune config, retourne [].
  Future<List<String>> getSidebarConfig(String role) async {
    final url = '${ApiConfig.sidebarUrl}?role=${Uri.encodeComponent(role)}';
    try {
      final response = await ApiClient.get(url);
      if (response.statusCode >= 400) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<String>.from(data['order'] as List? ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Sauvegarde l'ordre de la sidebar pour [role] (admin seulement).
  Future<void> updateSidebarConfig(String role, List<String> order) async {
    final response = await ApiClient.put(
      ApiConfig.sidebarUrl,
      {'role': role, 'order': order},
    );
    _checkStatus(response, ApiConfig.sidebarUrl);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String url;

  const ApiException({
    required this.statusCode,
    required this.message,
    required this.url,
  });

  @override
  String toString() => 'ApiException($statusCode) $url — $message';
}
