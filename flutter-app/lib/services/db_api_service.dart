import 'dart:convert';
import 'dart:typed_data';
import 'api_client.dart';
import 'api_config.dart';
import '../models/equipment.dart';
import '../models/equipment_document.dart';
import '../models/issue.dart';
import '../models/issue_detail.dart';

/// Résultat paginé générique pour les listes en pagination serveur
/// (GET /api/equipment et GET /api/issues avec ?page=).
class PagedResult<T> {
  final List<T> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const PagedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
}

/// Service de données — communique avec db-service.
///
/// Retourne des `Map<String, dynamic>` bruts pour rester découplé des modèles.
/// Les écrans peuvent parser avec leurs modèles existants ou utiliser les maps directement.
class DbApiService {
  DbApiService._();
  static final DbApiService instance = DbApiService._();

  /// Construit une query string à partir d'une map de paramètres, en omettant
  /// les valeurs `null` et les chaînes vides. Encode chaque valeur (`Uri.encodeComponent`).
  /// Utilisé par les méthodes de pagination serveur (getEquipmentPaged/getIssuesPaged).
  String _buildQuery(Map<String, dynamic> params) {
    final parts = <String>[];
    params.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      parts.add('$key=${Uri.encodeComponent(value.toString())}');
    });
    return parts.join('&');
  }

  // ── ÉQUIPEMENTS ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getEquipment({
    String? department,
    String? status,
    String? category,
    bool includeDisposed = false,
    bool light = false,
  }) async {
    var url = ApiConfig.equipmentUrl;
    final params = <String>[];
    if (department != null) params.add('department=${Uri.encodeComponent(department)}');
    if (status     != null) params.add('status=${Uri.encodeComponent(status)}');
    if (category   != null) params.add('category=${Uri.encodeComponent(category)}');
    // Par défaut le serveur masque les équipements réformés (Disposed).
    if (includeDisposed)    params.add('include_disposed=true');
    // Mode léger : tableaux maintenanceHistory/futureMaintenance/tags vides
    // (toutes les colonnes scalaires restent présentes). Utilisé au login.
    if (light)               params.add('light=true');
    if (params.isNotEmpty)  url += '?${params.join('&')}';

    // Cache conditionnel ETag/304 (ApiClient) : réservé à l'appel exact du
    // login (light, sans autre filtre) — un GET filtré reste toujours frais.
    final conditional = light && department == null && status == null &&
        category == null && !includeDisposed;
    final response = await ApiClient.get(url, conditional: conditional);
    _checkStatus(response, url);
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  /// Pagination serveur (page/limit/search/tri) — utilisée par
  /// EquipmentListScreen. Ne remplace pas [getEquipment] (cache DataService).
  Future<PagedResult<Equipment>> getEquipmentPaged({
    int page = 1,
    int limit = 20,
    String? search,
    String? sortBy,
    String? sortDir,
    String? department,
    String? status,
    String? category,
    String? macroCategory,
    int? macroCategoryId,
    int? subcategoryId,
    int? brandId,
    int? modelId,
    bool includeDisposed = false,
  }) async {
    final query = _buildQuery({
      'page': page,
      'limit': limit,
      'search': search,
      'sort_by': sortBy,
      'sort_dir': sortDir,
      'department': department,
      'status': status,
      'category': category,
      'macro_category': macroCategory,
      'macro_category_id': macroCategoryId,
      'subcategory_id': subcategoryId,
      'brand_id': brandId,
      'model_id': modelId,
      'include_disposed': includeDisposed ? true : null,
    });
    final url = '${ApiConfig.equipmentUrl}?$query';
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((j) => Equipment.fromApiJson(j as Map<String, dynamic>))
        .toList();
    return PagedResult<Equipment>(
      items: items,
      total: data['total'] as int,
      page: data['page'] as int,
      limit: data['limit'] as int,
      totalPages: data['total_pages'] as int,
    );
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
    await _checkEquipmentMutation(response, ApiConfig.equipmentUrl);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateEquipment(String id, Map<String, dynamic> data) async {
    final url = '${ApiConfig.equipmentUrl}/$id';
    final response = await ApiClient.put(url, data);
    await _checkEquipmentMutation(response, url);
  }

  Future<void> updateEquipmentStatus(String id, String status) async {
    final url = '${ApiConfig.equipmentUrl}/$id';
    final response = await ApiClient.put(url, {'status': status});
    await _checkEquipmentMutation(response, url);
  }

  /// Suppression définitive (hard delete). Lève une ApiException 409 si
  /// l'équipement a un historique et que [force] est false → l'UI propose
  /// alors la réforme. [force] (admin only) purge l'équipement et son historique.
  Future<void> deleteEquipment(String id, {String? reason, bool force = false}) async {
    var url = '${ApiConfig.equipmentUrl}/$id';
    final params = <String>[];
    if (reason != null && reason.isNotEmpty) params.add('reason=${Uri.encodeComponent(reason)}');
    if (force) params.add('force=true');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final response = await ApiClient.delete(url);
    await _checkEquipmentMutation(response, url);
  }

  /// Étape 1 du workflow de réforme : proposition de mise au rebut.
  /// Passe l'équipement en 'To be disposal' (reste visible en liste active).
  Future<void> proposeDisposal(String id, String reason) async {
    final url = '${ApiConfig.equipmentUrl}/$id/propose-disposal';
    final response = await ApiClient.post(url, {'decommission_reason': reason});
    await _checkEquipmentMutation(response, url);
  }

  /// Étape 2 (admin) : réforme effective (soft delete → status 'Disposed').
  /// L'équipement conserve tout son historique pour l'audit.
  Future<void> decommissionEquipment(
    String id, {
    required String reason,
    required String method,
    String? notes,
    String? replacedById,
  }) async {
    final url = '${ApiConfig.equipmentUrl}/$id/decommission';
    final response = await ApiClient.post(url, {
      'decommission_reason': reason,
      'disposal_method': method,
      if (notes != null && notes.isNotEmpty) 'decommission_notes': notes,
      if (replacedById != null && replacedById.isNotEmpty) 'replaced_by_id': replacedById,
    });
    await _checkEquipmentMutation(response, url);
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
    await _checkEquipmentMutation(response, url);
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
    await _checkEquipmentMutation(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Met à jour (UPSERT) la fréquence PM d'un équipement.
  Future<void> updatePmPlan(String equipmentId, int frequencyMonths) async {
    final url = ApiConfig.equipmentPmPlanUrl(equipmentId);
    final response = await ApiClient.put(url, {'frequency_months': frequencyMonths});
    await _checkEquipmentMutation(response, url);
  }

  // ── LIEUX ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLocations() async {
    final response = await ApiClient.get(ApiConfig.locationsUrl, conditional: true);
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

  /// Pagination serveur (page/limit/search/filtres avancés/tri) — utilisée par
  /// IssueTrackingScreen et TechnicianUpdateScreen. Ne remplace pas [getIssues].
  Future<PagedResult<Issue>> getIssuesPaged({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? statusNe,
    String? urgency,
    String? assignedGroup,
    String? assignedGroupIn,
    String? assignedTechnician,
    String? reporterId,
    String? createdAfter,
    String? createdBefore,
    String? department,
    String? equipmentId,
    String? sortBy,
    String? sortDir,
  }) async {
    final query = _buildQuery({
      'page': page,
      'limit': limit,
      'search': search,
      'status': status,
      'status_ne': statusNe,
      'urgency': urgency,
      'assigned_group': assignedGroup,
      'assigned_group_in': assignedGroupIn,
      'assigned_technician': assignedTechnician,
      'reporter_id': reporterId,
      'created_after': createdAfter,
      'created_before': createdBefore,
      'department': department,
      'equipment_id': equipmentId,
      'sort_by': sortBy,
      'sort_dir': sortDir,
    });
    final url = '${ApiConfig.issuesUrl}?$query';
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((j) => Issue.fromApiJson(j as Map<String, dynamic>))
        .toList();
    return PagedResult<Issue>(
      items: items,
      total: data['total'] as int,
      page: data['page'] as int,
      limit: data['limit'] as int,
      totalPages: data['total_pages'] as int,
    );
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

  /// Prise en charge d'un incident par un technicien : passe l'incident en
  /// « In Progress », l'assigne au technicien et horodate la prise en charge.
  /// L'audit trail est assuré côté backend par PUT /api/issues/:id.
  Future<void> takeOverIssue(String id, String technicianName) async {
    await updateIssue(id, {
      'status':              'In Progress',
      'assigned_technician': technicianName,
      'taken_at':            DateTime.now().toIso8601String(),
    });
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

  Future<void> closeIssueAsDisposed(
      String issueId, String reason, String disposalMethod) async {
    final url = '${ApiConfig.issuesUrl}/$issueId/close-as-disposed';
    final response = await ApiClient.patch(url, {
      'reason': reason,
      'disposal_method': disposalMethod,
    });
    _checkStatus(response, url);
  }

  /// Rejette un incident en file de validation (statut 'Reported' requis serveur).
  /// [reasonCode] ∈ REJECT_REASONS ; [comment] obligatoire si reasonCode == 'other'.
  Future<void> rejectIssue(String id, String reasonCode, String? comment) async {
    final url = '${ApiConfig.issuesUrl}/$id/reject';
    final response = await ApiClient.patch(url, {
      'reason_code': reasonCode,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    _checkStatus(response, url);
  }

  /// Détache l'appelant d'un incident 'In Progress' qui lui est assigné →
  /// l'incident retourne au pool (statut 'Acknowledged'). [reason] : min 10 car.
  Future<void> detachIssue(String id, String reason) async {
    final url = '${ApiConfig.issuesUrl}/$id/detach';
    final response = await ApiClient.patch(url, {'reason': reason});
    _checkStatus(response, url);
  }

  /// Lie tardivement un incident créé sans équipement (cas "Autre"/
  /// "Infrastructure") à un équipement du catalogue. Pose equipment_id/
  /// equipment_name/equipment_linked_at côté serveur.
  Future<void> linkEquipment(String issueId, String equipmentId) async {
    final url = '${ApiConfig.issuesUrl}/$issueId/link-equipment';
    final response = await ApiClient.patch(url, {'equipment_id': equipmentId});
    _checkStatus(response, url);
  }

  // ── RAPPORT D'INTERVENTION (1:1 avec incident) ─────────────────────────────

  /// Rapport d'intervention d'un incident (brouillon vide si inexistant).
  /// La réponse inclut les champs live de l'incident (diagnosis/actions/...).
  Future<Map<String, dynamic>> getInterventionReport(String issueId) async {
    final url = '${ApiConfig.issuesUrl}/$issueId/report';
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Enregistre (UPSERT) le rapport d'intervention.
  Future<Map<String, dynamic>> saveInterventionReport(
    String issueId,
    Map<String, dynamic> data,
  ) async {
    final url = '${ApiConfig.issuesUrl}/$issueId/report';
    final response = await ApiClient.put(url, data);
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Fige le rapport (incident résolu requis côté serveur).
  Future<Map<String, dynamic>> finalizeInterventionReport(String issueId) async {
    final url = '${ApiConfig.issuesUrl}/$issueId/report/finalize';
    final response = await ApiClient.post(url, {});
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Rouvre un rapport figé (admin uniquement côté serveur).
  Future<Map<String, dynamic>> reopenInterventionReport(String issueId) async {
    final url = '${ApiConfig.issuesUrl}/$issueId/report/reopen';
    final response = await ApiClient.patch(url, {});
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Archive le PDF du rapport sur l'incident (POST /api/issues/:id/documents,
  /// type 'intervention'). Le serveur rattache aussi le document à l'équipement
  /// si l'incident en a un — sinon il reste consultable via l'incident seul.
  Future<void> archiveInterventionPdf(
    String issueId,
    Uint8List pdfBytes,
    String fileName,
  ) async {
    await ApiClient.postMultipart(
      '${ApiConfig.issuesUrl}/$issueId/documents',
      pdfBytes,
      fileName,
      'application/pdf',
      {'type': 'intervention'},
      fileField: 'files',
    );
  }

  /// Liste les documents PDF d'intervention archivés sur un incident.
  Future<List<EquipmentDocument>> getInterventionDocuments(String issueId) async {
    final url = '${ApiConfig.issuesUrl}/$issueId/documents';
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((j) => EquipmentDocument.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Upload de documents complémentaires (PDF/JPEG/PNG, 5 max) sur un incident.
  Future<void> uploadInterventionDocuments(
    String issueId,
    List<({Uint8List bytes, String name, String mimeType})> files,
  ) async {
    await ApiClient.postMultipartFiles(
      '${ApiConfig.issuesUrl}/$issueId/documents',
      files,
      fileField: 'files',
      fields: const {'type': 'completion'},
    );
  }

  /// Télécharge le contenu binaire d'un document d'intervention pour visualisation.
  Future<Uint8List> downloadInterventionDocument(String issueId, int docId) async {
    final url = '${ApiConfig.issuesUrl}/$issueId/documents/$docId/download';
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return response.bodyBytes;
  }

  // ── BOUCLES D'INTERVENTION (1:N par incident) ──────────────────────────────

  Future<List<dynamic>> getInterventionSessions(String issueId) async {
    final url = '${ApiConfig.issuesUrl}/$issueId/sessions';
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> saveActiveInterventionSession(
      String issueId, Map<String, dynamic> payload) async {
    final url = '${ApiConfig.issuesUrl}/$issueId/sessions/active';
    final response = await ApiClient.put(url, payload);
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeActiveInterventionSession(
      String issueId, Map<String, dynamic> payload) async {
    final url = '${ApiConfig.issuesUrl}/$issueId/sessions/active/close';
    final response = await ApiClient.post(url, payload);
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
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
    await _checkEquipmentMutation(response, url);
  }

  Future<void> restoreEquipmentState(String id, Map<String, dynamic> oldValues) async {
    final url = '${ApiConfig.equipmentUrl}/$id';
    final response = await ApiClient.put(url, oldValues);
    await _checkEquipmentMutation(response, url);
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

  // ── DEBUG ──────────────────────────────────────────────────────────────────

  /// Envoie une notification email de test immédiate à l'utilisateur connecté.
  Future<Map<String, dynamic>> debugNotifyNow() async {
    final url = '${ApiConfig.dbBaseUrl}/api/debug/notify-now';
    final response = await ApiClient.post(url, {});
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Active ou désactive les notifications email automatiques de test.
  ///
  /// [interval] : 'minute' | 'hour' | 'stop'
  Future<Map<String, dynamic>> debugNotifySchedule(String interval) async {
    final url = '${ApiConfig.dbBaseUrl}/api/debug/notify-schedule';
    final response = await ApiClient.post(url, {'interval': interval});
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Réinitialise les données d'instance (équipements, incidents, inventaire,
  /// lieux) avec le jeu de données de démo (seed.js) — réservé admin.
  /// Ne touche pas aux tables de référence/catalogue (catégories, fabricants...).
  Future<Map<String, dynamic>> debugReseedDatabase() async {
    final url = '${ApiConfig.dbBaseUrl}/api/debug/reseed';
    final response = await ApiClient.post(url, {});
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Vide les équipements/incidents existants puis réimporte intégralement
  /// depuis un fichier XLSX (format "Equipment Migration Template") — réservé
  /// admin. Lève une [Exception] avec le message d'erreur serveur en cas
  /// d'échec (feuille manquante, fichier illisible, etc.).
  Future<Map<String, dynamic>> debugReseedFromFile(
    Uint8List fileBytes,
    String fileName,
  ) async {
    final url = '${ApiConfig.dbBaseUrl}/api/debug/reseed-from-file';
    return ApiClient.postMultipart(
      url,
      fileBytes,
      fileName,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      const {},
    );
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

  /// Valide le statut d'une mutation équipement puis purge le cache conditionnel
  /// de la liste légère (ApiClient) — toute mutation equipment doit invalider.
  Future<void> _checkEquipmentMutation(dynamic response, String url) async {
    _checkStatus(response, url);
    await ApiClient.invalidateEquipmentCache();
  }

  String _extractError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['error'] as String? ?? body;
    } catch (_) {
      return body;
    }
  }

  // ── DÉPARTEMENTS ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getDepartments() async {
    final response = await ApiClient.get(ApiConfig.departmentsUrl);
    _checkStatus(response, ApiConfig.departmentsUrl);
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  Future<Map<String, dynamic>> createDepartment(Map<String, dynamic> data) async {
    final response = await ApiClient.post(ApiConfig.departmentsUrl, data);
    _checkStatus(response, ApiConfig.departmentsUrl);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateDepartment(int id, Map<String, dynamic> data) async {
    final url = '${ApiConfig.departmentsUrl}/$id';
    final response = await ApiClient.put(url, data);
    _checkStatus(response, url);
  }

  Future<void> deleteDepartment(int id) async {
    final url = '${ApiConfig.departmentsUrl}/$id';
    final response = await ApiClient.delete(url);
    _checkStatus(response, url);
  }

  Future<Map<String, dynamic>> checkDepartmentDeps(int id) async {
    final url = ApiConfig.departmentCheckDepsUrl(id);
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Dashboard d'un département : KPIs parc + équipements + incidents ouverts.
  Future<Map<String, dynamic>> getDepartmentDetail(int id) async {
    final url = ApiConfig.departmentDetailUrl(id);
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── CATÉGORIES (macro + sous) ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMacroCategories() async {
    final response = await ApiClient.get(ApiConfig.categoriesMacroUrl);
    _checkStatus(response, ApiConfig.categoriesMacroUrl);
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  Future<List<Map<String, dynamic>>> getSubCategories({int? macroId}) async {
    final url = macroId != null
        ? ApiConfig.categoriesSubByMacroUrl(macroId)
        : ApiConfig.categoriesSubUrl;
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  Future<Map<String, dynamic>> createSubCategory(Map<String, dynamic> data) async {
    final response = await ApiClient.post(ApiConfig.categoriesSubUrl, data);
    _checkStatus(response, ApiConfig.categoriesSubUrl);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateSubCategory(int id, Map<String, dynamic> data) async {
    final url = ApiConfig.categoriesSubItemUrl(id);
    final response = await ApiClient.put(url, data);
    _checkStatus(response, url);
  }

  Future<void> deleteSubCategory(int id) async {
    final url = ApiConfig.categoriesSubItemUrl(id);
    final response = await ApiClient.delete(url);
    _checkStatus(response, url);
  }

  /// Saisit la durée de vie de référence (en années) d'une sous-catégorie.
  /// [years] null = durée non définie. Réservé admin côté serveur.
  Future<void> updateSubCategoryLifespan(int id, int? years) async {
    final url = ApiConfig.categoriesSubLifespanUrl(id);
    final response = await ApiClient.put(url, {'expected_lifespan_years': years});
    _checkStatus(response, url);
  }

  /// Détail complet d'une sous-catégorie (protocoles + équipements + fabricants).
  Future<Map<String, dynamic>> getSubCategoryDetail(int id) async {
    final url = ApiConfig.categoriesSubItemUrl(id);
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Détail d'une catégorie standard (par nom) : équipements + fabricants présents.
  Future<Map<String, dynamic>> getCategoryDetail(String name) async {
    final url = ApiConfig.categoryDetailUrl(name);
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── CATALOGUE FABRICANT → MODÈLE ───────────────────────────────────────────

  /// Liste des fabricants. [subcategoryId] : restreint à ceux présents dans la sous-cat.
  Future<List<Map<String, dynamic>>> getBrands({int? subcategoryId}) async {
    final url = subcategoryId != null
        ? ApiConfig.brandsBySubUrl(subcategoryId)
        : ApiConfig.brandsUrl;
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  /// Détail d'un fabricant + ses modèles (filtrables par sous-catégorie).
  Future<Map<String, dynamic>> getBrandDetail(int id, {int? subcategoryId}) async {
    final url = subcategoryId != null
        ? ApiConfig.brandItemBySubUrl(id, subcategoryId)
        : ApiConfig.brandItemUrl(id);
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createBrand(String name) async {
    final response = await ApiClient.post(ApiConfig.brandsUrl, {'name': name});
    _checkStatus(response, ApiConfig.brandsUrl);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateBrand(int id, String name) async {
    final url = ApiConfig.brandItemUrl(id);
    final response = await ApiClient.put(url, {'name': name});
    _checkStatus(response, url);
  }

  Future<void> deleteBrand(int id) async {
    final url = ApiConfig.brandItemUrl(id);
    final response = await ApiClient.delete(url);
    _checkStatus(response, url);
  }

  /// Liste des modèles (filtrables par sous-catégorie et/ou fabricant).
  Future<List<Map<String, dynamic>>> getModels({int? subcategoryId, int? brandId}) async {
    final url = ApiConfig.modelsFilteredUrl(subcategoryId: subcategoryId, brandId: brandId);
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  /// Fiche complète d'un modèle (équipements + documents + protocoles PM).
  Future<Map<String, dynamic>> getModelDetail(int id) async {
    final url = ApiConfig.modelItemUrl(id);
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createModel({
    required int brandId,
    int? subcategoryId,
    required String name,
  }) async {
    final response = await ApiClient.post(ApiConfig.modelsUrl, {
      'brand_id': brandId,
      'subcategory_id': subcategoryId,
      'name': name,
    });
    _checkStatus(response, ApiConfig.modelsUrl);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateModel(int id, {int? brandId, int? subcategoryId, String? name}) async {
    final url = ApiConfig.modelItemUrl(id);
    final body = <String, dynamic>{};
    if (brandId != null) body['brand_id'] = brandId;
    if (subcategoryId != null) body['subcategory_id'] = subcategoryId;
    if (name != null) body['name'] = name;
    final response = await ApiClient.put(url, body);
    _checkStatus(response, url);
  }

  Future<void> deleteModel(int id) async {
    final url = ApiConfig.modelItemUrl(id);
    final response = await ApiClient.delete(url);
    _checkStatus(response, url);
  }

  /// Documents d'un modèle (liste). [type] optionnel filtre par type de document.
  Future<List<Map<String, dynamic>>> getModelDocuments(int modelId, {String? type}) async {
    final base = ApiConfig.modelDocumentsUrl(modelId);
    final url = type != null ? '$base?type=$type' : base;
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  /// Upload d'un document de modèle (multipart). [type] : technical/intervention/certification.
  Future<Map<String, dynamic>> uploadModelDocument(
    int modelId,
    Uint8List bytes,
    String fileName,
    String mimeType, {
    String type = 'technical',
  }) async {
    return ApiClient.postMultipart(
      ApiConfig.modelDocumentsUrl(modelId),
      bytes,
      fileName,
      mimeType,
      {'type': type},
    );
  }

  Future<void> deleteModelDocument(int modelId, int docId) async {
    final url = ApiConfig.modelDocumentItemUrl(modelId, docId);
    final response = await ApiClient.delete(url);
    _checkStatus(response, url);
  }

  /// Lie un protocole PM existant à un modèle.
  Future<void> linkModelProtocol(int modelId, int protocolId) async {
    final url = ApiConfig.modelProtocolUrl(modelId, protocolId);
    final response = await ApiClient.post(url, {});
    _checkStatus(response, url);
  }

  Future<void> unlinkModelProtocol(int modelId, int protocolId) async {
    final url = ApiConfig.modelProtocolUrl(modelId, protocolId);
    final response = await ApiClient.delete(url);
    _checkStatus(response, url);
  }

  // ── PLAN DE REMPLACEMENT BIOMÉDICAL (RA3 S5) ───────────────────────────────

  /// Récupère le plan de remplacement { summary, items } des équipements
  /// biomédicaux (calcul serveur). Réservé admin/supervisor côté serveur.
  Future<Map<String, dynamic>> getReplacementPlan() async {
    final url = ApiConfig.replacementPlanUrl;
    final response = await ApiClient.get(url);
    _checkStatus(response, url);
    return jsonDecode(response.body) as Map<String, dynamic>;
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

  /// Récupère l'ordre de la sidebar pour TOUS les rôles en un seul appel
  /// (remplace 6 requêtes GET /api/sidebar/config?role=...). Retourne
  /// { role: order[] } ; rôles sans config explicite → liste vide.
  Future<Map<String, List<String>>> getAllSidebarConfigs() async {
    final response = await ApiClient.get(ApiConfig.sidebarAllUrl);
    _checkStatus(response, ApiConfig.sidebarAllUrl);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data.map((role, order) => MapEntry(role, List<String>.from(order as List)));
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
