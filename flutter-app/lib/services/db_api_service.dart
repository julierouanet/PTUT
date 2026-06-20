import 'dart:convert';
import 'dart:typed_data';
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
    bool includeDisposed = false,
  }) async {
    var url = ApiConfig.equipmentUrl;
    final params = <String>[];
    if (department != null) params.add('department=${Uri.encodeComponent(department)}');
    if (status     != null) params.add('status=${Uri.encodeComponent(status)}');
    if (category   != null) params.add('category=${Uri.encodeComponent(category)}');
    // Par défaut le serveur masque les équipements réformés (Disposed).
    if (includeDisposed)    params.add('include_disposed=true');
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
    _checkStatus(response, url);
  }

  /// Étape 1 du workflow de réforme : proposition de mise au rebut.
  /// Passe l'équipement en 'To be disposal' (reste visible en liste active).
  Future<void> proposeDisposal(String id, String reason) async {
    final url = '${ApiConfig.equipmentUrl}/$id/propose-disposal';
    final response = await ApiClient.post(url, {'decommission_reason': reason});
    _checkStatus(response, url);
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

  /// Archive le PDF du rapport dans l'historique documentaire de l'équipement.
  /// Réutilise POST /api/equipment/:id/documents (type 'intervention').
  Future<void> archiveInterventionPdf(
    String equipmentId,
    Uint8List pdfBytes,
    String fileName,
  ) async {
    await ApiClient.postMultipart(
      '${ApiConfig.equipmentUrl}/$equipmentId/documents',
      pdfBytes,
      fileName,
      'application/pdf',
      {'type': 'intervention'},
    );
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
