import 'package:flutter_test/flutter_test.dart';
import 'package:equipment_management/models/user_role.dart';

void main() {
  group('UserRole', () {
    test('has exactly 4 roles', () {
      expect(UserRole.values.length, 4);
    });

    test('displayName returns expected labels', () {
      expect(UserRole.admin.displayName, 'Administrateur ICT');
      expect(UserRole.supervisor.displayName, 'Superviseur');
      expect(UserRole.technician.displayName, 'Technicien');
      expect(UserRole.hospitalStaff.displayName, 'Personnel hospitalier');
    });

    test('description is not empty for all roles', () {
      for (final role in UserRole.values) {
        expect(role.description.isNotEmpty, isTrue, reason: '${role.name} should have a description');
      }
    });
  });

  group('Permission', () {
    test('has 12 permissions', () {
      expect(Permission.values.length, 12);
    });

    test('displayName is not empty for all permissions', () {
      for (final perm in Permission.values) {
        expect(perm.displayName.isNotEmpty, isTrue, reason: '${perm.name} should have a displayName');
      }
    });
  });

  group('getPermissionsForRole', () {
    test('admin gets all permissions', () {
      final adminPerms = getPermissionsForRole(UserRole.admin);
      expect(adminPerms, Permission.values);
    });

    test('hospitalStaff gets exactly 3 basic permissions', () {
      final staffPerms = getPermissionsForRole(UserRole.hospitalStaff);

      expect(staffPerms.length, 3);
      expect(staffPerms, contains(Permission.viewEquipment));
      expect(staffPerms, contains(Permission.reportIssue));
      expect(staffPerms, contains(Permission.trackIssues));
    });

    test('hospitalStaff does NOT get admin permissions', () {
      final staffPerms = getPermissionsForRole(UserRole.hospitalStaff);

      expect(staffPerms, isNot(contains(Permission.manageUsers)));
      expect(staffPerms, isNot(contains(Permission.manageDepartments)));
      expect(staffPerms, isNot(contains(Permission.updateRepairs)));
    });

    test('technician gets repair-related permissions', () {
      final techPerms = getPermissionsForRole(UserRole.technician);

      expect(techPerms.length, 5);
      expect(techPerms, contains(Permission.updateRepairs));
      expect(techPerms, contains(Permission.registerParts));
      expect(techPerms, contains(Permission.viewEquipment));
    });

    test('technician does NOT get supervisor/admin permissions', () {
      final techPerms = getPermissionsForRole(UserRole.technician);

      expect(techPerms, isNot(contains(Permission.approveRequests)));
      expect(techPerms, isNot(contains(Permission.assignTasks)));
      expect(techPerms, isNot(contains(Permission.manageUsers)));
    });

    test('supervisor gets approval-related permissions', () {
      final supPerms = getPermissionsForRole(UserRole.supervisor);

      expect(supPerms.length, 5);
      expect(supPerms, contains(Permission.approveRequests));
      expect(supPerms, contains(Permission.assignTasks));
      expect(supPerms, contains(Permission.viewEquipment));
    });

    test('supervisor does NOT get technician/admin permissions', () {
      final supPerms = getPermissionsForRole(UserRole.supervisor);

      expect(supPerms, isNot(contains(Permission.updateRepairs)));
      expect(supPerms, isNot(contains(Permission.manageUsers)));
    });

    test('all roles include viewEquipment', () {
      for (final role in UserRole.values) {
        final perms = getPermissionsForRole(role);
        expect(perms, contains(Permission.viewEquipment),
            reason: '${role.name} should have viewEquipment');
      }
    });

    test('only admin has manageUsers', () {
      for (final role in UserRole.values) {
        final perms = getPermissionsForRole(role);
        if (role == UserRole.admin) {
          expect(perms, contains(Permission.manageUsers));
        } else {
          expect(perms, isNot(contains(Permission.manageUsers)),
              reason: '${role.name} should NOT have manageUsers');
        }
      }
    });
  });
}
