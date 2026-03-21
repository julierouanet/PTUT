import 'dart:convert';
import 'api_client.dart';
import 'api_config.dart';

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

  Future<void> deleteEquipment(String id) async {
    final url = '${ApiConfig.equipmentUrl}/$id';
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

  // ── INCIDENTS ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getIssues({
    String? status,
    String? department,
  }) async {
    var url = ApiConfig.issuesUrl;
    final params = <String>[];
    if (status     != null) params.add('status=${Uri.encodeComponent(status)}');
    if (department != null) params.add('department=${Uri.encodeComponent(department)}');
    if (params.isNotEmpty)  url += '?${params.join('&')}';

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

  Future<Map<String, dynamic>> getEquipmentById(String id) async {
    final url = '${ApiConfig.equipmentUrl}/$id';
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
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
