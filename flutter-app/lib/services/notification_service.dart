import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../models/issue.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/os_notification_service.dart';

/// Service de notifications in-app — singleton + ChangeNotifier
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  List<AppNotification> _notifications = [];

  /// Toutes les notifications (plus récentes en premier)
  List<AppNotification> get all => List.unmodifiable(_notifications);

  /// Nombre de notifications non lues
  int get unreadCount => _notifications.where((n) => !n.read).length;

  /// Ajouter une notification en tête de liste
  void addNotification(AppNotification notification) {
    // Évite les doublons (même id)
    if (_notifications.any((n) => n.id == notification.id)) return;
    _notifications.insert(0, notification);
    notifyListeners();
  }

  /// Marquer une notification comme lue
  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].read) {
      _notifications[index] = _notifications[index].copyWith(read: true);
      notifyListeners();
    }
  }

  /// Marquer toutes comme lues — met aussi à jour le backend
  void markAllAsRead() {
    if (_notifications.any((n) => !n.read)) {
      _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
      notifyListeners();
    }
    // Synchronisation backend (fire-and-forget, erreur silencieuse)
    _markAllReadBackend();
  }

  Future<void> _markAllReadBackend() async {
    try {
      await ApiClient.patch('${ApiConfig.dbBaseUrl}/api/notifications/read-all', {});
    } catch (e) {
      debugPrint('[NotificationService] markAllAsRead erreur backend: $e');
    }
  }

  /// Récupère les notifications depuis l'API et fusionne avec les notifs locales.
  /// Appelé après un fetch ou un notify-now pour mettre à jour le badge cloche.
  Future<void> fetchFromApi() async {
    try {
      final response = await ApiClient.get(
        '${ApiConfig.dbBaseUrl}/api/notifications?limit=50',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        final apiNotifs = data
            .map((e) => AppNotification.fromApiJson(e as Map<String, dynamic>))
            .toList();

        // Fusionne : les notifs API (préfixe 'api-') s'ajoutent aux notifs locales
        final existingIds = _notifications.map((n) => n.id).toSet();
        for (final n in apiNotifs) {
          if (!existingIds.contains(n.id)) {
            _notifications.add(n);
          }
        }
        // Trie par date décroissante
        _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();

        // Déclenche une notification OS pour les nouvelles notifs non lues
        final unread = _notifications.where((n) => !n.read).toList();
        if (unread.isNotEmpty) {
          await OsNotificationService.showIfPermitted(
            title: unread.first.title ?? unread.first.equipmentName,
            body: unread.length > 1
                ? '${unread.length} nouvelles notifications'
                : (unread.first.body ?? ''),
          );
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] fetchFromApi erreur: $e');
    }
  }

  /// Réinitialise et régénère les notifications selon l'état courant des données.
  /// Appelé au chargement initial et après chaque mise à jour d'un incident.
  void generateFromLoadedData() {
    final user = AuthService().currentUser;
    if (user == null) return;

    final issues    = DataService().issues;
    final now       = DateTime.now();
    final weekAgo   = now.subtract(const Duration(days: 7));
    final isManager = user.hasRole(UserRole.admin) || user.hasRole(UserRole.supervisor);

    final List<AppNotification> generated = [];

    for (final issue in issues) {
      // Lire la date de création de l'incident
      DateTime issueDate;
      try {
        issueDate = DateTime.parse(issue.createdAt);
      } catch (_) {
        issueDate = now;
      }

      // ── Admins / Superviseurs : tous les incidents OUVERTS des 7 derniers jours ──
      if (isManager && issue.status == IssueStatus.reported) {
        if (issueDate.isAfter(weekAgo)) {
          generated.add(AppNotification(
            id:            'notif-new-${issue.id}',
            type:          NotificationType.newIssue,
            equipmentName: issue.displayName,
            department:    issue.department,
            createdAt:     issueDate,
            linkedIssueId: issue.id,
          ));
        }
      }

      // ── Déclarant : mises à jour de SES incidents ──
      final isReporter = (issue.reporterId != null && issue.reporterId!.isNotEmpty)
          ? issue.reporterId == user.id
          : issue.reporter == user.name;

      if (isReporter) {
        if (issue.status == IssueStatus.inProgress) {
          generated.add(AppNotification(
            id:            'notif-progress-${issue.id}',
            type:          NotificationType.issueInProgress,
            equipmentName: issue.displayName,
            department:    issue.department,
            createdAt:     issueDate,
            linkedIssueId: issue.id,
          ));
        } else if (issue.status == IssueStatus.completed) {
          generated.add(AppNotification(
            id:            'notif-resolved-${issue.id}',
            type:          NotificationType.issueResolved,
            equipmentName: issue.displayName,
            department:    issue.department,
            createdAt:     issueDate,
            linkedIssueId: issue.id,
          ));
        }
      }
    }

    // ── Admins : demandes de changement de département en attente ──
    if (isManager) {
      for (final req in DataService().deptRequests) {
        DateTime reqDate;
        try {
          reqDate = DateTime.parse(req['created_at'] as String? ?? '');
        } catch (_) {
          reqDate = now;
        }
        generated.add(AppNotification(
          id:            'notif-dept-${req['id']}',
          type:          NotificationType.deptRequest,
          equipmentName: req['requested_department'] as String? ?? '',
          department:    req['current_department']   as String? ?? '',
          userName:      req['user_name']            as String?,
          createdAt:     reqDate,
        ));
      }
    }

    // Les plus récents en premier
    generated.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Conserver l'état "lu" des notifications locales existantes
    final Map<String, bool> previousReadState = {
      for (final n in _notifications) n.id: n.read,
    };

    // Remplace uniquement les notifs locales (préfixe 'notif-'), garde les API ('api-')
    final apiNotifs = _notifications.where((n) => n.id.startsWith('api-')).toList();
    final mergedLocal = generated.map((n) {
      final wasRead = previousReadState[n.id] ?? false;
      return wasRead ? n.copyWith(read: true) : n;
    }).toList();

    _notifications = [...mergedLocal, ...apiNotifs];
    _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    notifyListeners();
  }
}
