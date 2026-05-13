import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../models/issue.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';

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

  /// Marquer toutes comme lues
  void markAllAsRead() {
    if (_notifications.any((n) => !n.read)) {
      _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
      notifyListeners();
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

    // Conserver l'état "lu" des notifications existantes
    final Map<String, bool> previousReadState = {
      for (final n in _notifications) n.id: n.read,
    };
    _notifications = generated.map((n) {
      final wasRead = previousReadState[n.id] ?? false;
      return wasRead ? n.copyWith(read: true) : n;
    }).toList();

    notifyListeners();
  }
}
