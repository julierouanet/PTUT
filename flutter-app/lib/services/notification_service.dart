import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../models/issue.dart';
import '../models/user_role.dart';
import '../models/inventory_item.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  List<AppNotification> _notifications = [];

  List<AppNotification> get all => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.read).length;

  void addNotification(AppNotification notification) {
    if (_notifications.any((n) => n.id == notification.id)) return;
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].read) {
      _notifications[index] = _notifications[index].copyWith(read: true);
      notifyListeners();
    }
  }

  void markAllAsRead() {
    if (_notifications.any((n) => !n.read)) {
      _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
      notifyListeners();
    }
  }

  void generateFromLoadedData() {
    final user = AuthService().currentUser;
    if (user == null) return;

    final issues  = DataService().issues;
    final now     = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final isManager = user.role == UserRole.admin || user.role == UserRole.supervisor;

    final List<AppNotification> generated = [];

    for (final issue in issues) {
      DateTime issueDate;
      try {
        issueDate = DateTime.parse(issue.createdAt);
      } catch (_) {
        issueDate = now;
      }

      if (isManager && issue.status == IssueStatus.open) {
        if (issueDate.isAfter(weekAgo)) {
          generated.add(AppNotification(
            id:            'notif-new-${issue.id}',
            type:          NotificationType.newIssue,
            equipmentName: issue.equipmentName,
            department:    issue.department,
            createdAt:     issueDate,
            linkedIssueId: issue.id,
          ));
        }
      }

      final isReporter = (issue.reporterId != null && issue.reporterId!.isNotEmpty)
          ? issue.reporterId == user.id
          : issue.reporter == user.name;

      if (isReporter) {
        if (issue.status == IssueStatus.inProgress) {
          generated.add(AppNotification(
            id:            'notif-progress-${issue.id}',
            type:          NotificationType.issueInProgress,
            equipmentName: issue.equipmentName,
            department:    issue.department,
            createdAt:     issueDate,
            linkedIssueId: issue.id,
          ));
        } else if (issue.status == IssueStatus.resolved) {
          generated.add(AppNotification(
            id:            'notif-resolved-${issue.id}',
            type:          NotificationType.issueResolved,
            equipmentName: issue.equipmentName,
            department:    issue.department,
            createdAt:     issueDate,
            linkedIssueId: issue.id,
          ));
        }
      }
    }
// ── Alertes de stock ──
    if (isManager) {
      for (final item in DataService().inventory) {
        if (item.status == StockStatus.outOfStock) {
          generated.add(AppNotification(
            id:            'notif-outofstock-${item.id}',
            type:          NotificationType.outOfStock,
            equipmentName: item.name,
            department:    item.category.displayName,
            createdAt:     now,
          ));
        } else if (item.status == StockStatus.low) {
          generated.add(AppNotification(
            id:            'notif-lowstock-${item.id}',
            type:          NotificationType.lowStock,
            equipmentName: item.name,
            department:    item.category.displayName,
            createdAt:     now,
          ));
        }
      }

      // ── Demandes de changement de département ──
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
    generated.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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