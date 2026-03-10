import 'package:flutter_test/flutter_test.dart';
import 'package:equipment_management/services/auth_service.dart';
import 'package:equipment_management/models/user_role.dart';
import 'package:equipment_management/data/mock_data.dart';

void main() {
  late AuthService authService;

  setUp(() {
    // Get the singleton and reset state
    authService = AuthService();
    authService.logout();
  });

  group('initDemo', () {
    test('sets current user to admin', () {
      expect(authService.isLoggedIn, isFalse);

      authService.initDemo();

      expect(authService.isLoggedIn, isTrue);
      expect(authService.currentRole, UserRole.admin);
    });

    test('does not overwrite existing user', () {
      final technician = mockUsers.firstWhere((u) => u.role == UserRole.technician);
      authService.switchUser(technician);

      authService.initDemo();

      // Should keep the technician, not switch to admin
      expect(authService.currentUser?.role, UserRole.technician);
    });
  });

  group('login', () {
    test('succeeds with valid email', () {
      final result = authService.login('admin@kabutare.rw');

      expect(result, isTrue);
      expect(authService.isLoggedIn, isTrue);
      expect(authService.currentUser?.name, 'Admin Système');
    });

    test('fails with invalid email', () {
      final result = authService.login('nonexistent@kabutare.rw');

      expect(result, isFalse);
      expect(authService.isLoggedIn, isFalse);
    });

    test('fails with empty email', () {
      final result = authService.login('');

      expect(result, isFalse);
      expect(authService.isLoggedIn, isFalse);
    });
  });

  group('logout', () {
    test('clears current user', () {
      authService.initDemo();
      expect(authService.isLoggedIn, isTrue);

      authService.logout();

      expect(authService.isLoggedIn, isFalse);
      expect(authService.currentUser, isNull);
      expect(authService.currentRole, isNull);
    });
  });

  group('switchUser', () {
    test('changes to specified user', () {
      authService.initDemo();
      final technician = mockUsers.firstWhere((u) => u.role == UserRole.technician);

      authService.switchUser(technician);

      expect(authService.currentUser?.id, technician.id);
      expect(authService.currentRole, UserRole.technician);
    });
  });

  group('hasPermission', () {
    test('returns false when no user logged in', () {
      expect(authService.hasPermission(Permission.viewEquipment), isFalse);
    });

    test('admin has all permissions', () {
      authService.initDemo(); // Admin

      for (final permission in Permission.values) {
        expect(
          authService.hasPermission(permission),
          isTrue,
          reason: 'Admin should have ${permission.name}',
        );
      }
    });

    test('hospitalStaff has only basic permissions', () {
      final staff = mockUsers.firstWhere((u) => u.role == UserRole.hospitalStaff);
      authService.switchUser(staff);

      expect(authService.hasPermission(Permission.viewEquipment), isTrue);
      expect(authService.hasPermission(Permission.reportIssue), isTrue);
      expect(authService.hasPermission(Permission.trackIssues), isTrue);

      expect(authService.hasPermission(Permission.manageUsers), isFalse);
      expect(authService.hasPermission(Permission.updateRepairs), isFalse);
      expect(authService.hasPermission(Permission.approveRequests), isFalse);
      expect(authService.hasPermission(Permission.generateReports), isFalse);
    });

    test('technician can update repairs but not manage users', () {
      final tech = mockUsers.firstWhere((u) => u.role == UserRole.technician);
      authService.switchUser(tech);

      expect(authService.hasPermission(Permission.updateRepairs), isTrue);
      expect(authService.hasPermission(Permission.registerParts), isTrue);
      expect(authService.hasPermission(Permission.manageUsers), isFalse);
      expect(authService.hasPermission(Permission.approveRequests), isFalse);
    });

    test('supervisor can approve requests but not update repairs', () {
      final supervisor = mockUsers.firstWhere((u) => u.role == UserRole.supervisor);
      authService.switchUser(supervisor);

      expect(authService.hasPermission(Permission.approveRequests), isTrue);
      expect(authService.hasPermission(Permission.assignTasks), isTrue);
      expect(authService.hasPermission(Permission.updateRepairs), isFalse);
      expect(authService.hasPermission(Permission.manageUsers), isFalse);
    });
  });

  group('hasAllPermissions', () {
    test('returns true when user has all listed permissions', () {
      authService.initDemo(); // Admin

      expect(
        authService.hasAllPermissions([Permission.viewEquipment, Permission.manageUsers]),
        isTrue,
      );
    });

    test('returns false when user lacks one permission', () {
      final staff = mockUsers.firstWhere((u) => u.role == UserRole.hospitalStaff);
      authService.switchUser(staff);

      expect(
        authService.hasAllPermissions([Permission.viewEquipment, Permission.manageUsers]),
        isFalse,
      );
    });
  });

  group('hasAnyPermission', () {
    test('returns true when user has at least one listed permission', () {
      final staff = mockUsers.firstWhere((u) => u.role == UserRole.hospitalStaff);
      authService.switchUser(staff);

      expect(
        authService.hasAnyPermission([Permission.viewEquipment, Permission.manageUsers]),
        isTrue,
      );
    });

    test('returns false when user has none of the listed permissions', () {
      final staff = mockUsers.firstWhere((u) => u.role == UserRole.hospitalStaff);
      authService.switchUser(staff);

      expect(
        authService.hasAnyPermission([Permission.manageUsers, Permission.manageDepartments]),
        isFalse,
      );
    });
  });

  group('convenience getters', () {
    test('match hasPermission results for admin', () {
      authService.initDemo();

      expect(authService.canViewEquipment, isTrue);
      expect(authService.canReportIssue, isTrue);
      expect(authService.canManageUsers, isTrue);
      expect(authService.canGenerateReports, isTrue);
    });

    test('match hasPermission results for hospitalStaff', () {
      final staff = mockUsers.firstWhere((u) => u.role == UserRole.hospitalStaff);
      authService.switchUser(staff);

      expect(authService.canViewEquipment, isTrue);
      expect(authService.canReportIssue, isTrue);
      expect(authService.canManageUsers, isFalse);
      expect(authService.canUpdateRepairs, isFalse);
    });
  });
}
