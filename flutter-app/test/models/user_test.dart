import 'package:flutter_test/flutter_test.dart';
import 'package:equipment_management/models/user.dart';
import 'package:equipment_management/models/user_role.dart';

void main() {
  late User adminUser;
  late User staffUser;

  setUp(() {
    adminUser = User(
      id: 'test-admin',
      name: 'Test Admin',
      email: 'admin@test.com',
      department: 'IT',
      roles: const [UserRole.admin],
      permissions: getPermissionsForRole(UserRole.admin),
      createdAt: '2024-01-01',
    );

    staffUser = User(
      id: 'test-staff',
      name: 'Test Staff',
      email: 'staff@test.com',
      department: 'Urgences',
      roles: const [UserRole.hospitalStaff],
      permissions: getPermissionsForRole(UserRole.hospitalStaff),
      createdAt: '2024-01-01',
    );
  });

  group('hasPermission', () {
    test('admin has all permissions', () {
      for (final perm in Permission.values) {
        expect(adminUser.hasPermission(perm), isTrue,
            reason: 'Admin should have ${perm.name}');
      }
    });

    test('staff has only basic permissions', () {
      expect(staffUser.hasPermission(Permission.viewEquipment), isTrue);
      expect(staffUser.hasPermission(Permission.reportIssue), isTrue);
      expect(staffUser.hasPermission(Permission.manageUsers), isFalse);
    });
  });

  group('hasRole', () {
    test('admin user has admin role', () {
      expect(adminUser.hasRole(UserRole.admin), isTrue);
      expect(adminUser.hasRole(UserRole.supervisor), isFalse);
    });

    test('multi-role user matches all its roles', () {
      final multi = User(
        id: 'multi',
        name: 'Multi',
        email: 'm@test.com',
        department: 'IT',
        roles: const [
          UserRole.technicianBiomedical,
          UserRole.technicianIt,
        ],
        permissions: getPermissionsForRoles(const [
          UserRole.technicianBiomedical,
          UserRole.technicianIt,
        ]),
        createdAt: '2024-01-01',
      );
      expect(multi.hasRole(UserRole.technicianBiomedical), isTrue);
      expect(multi.hasRole(UserRole.technicianIt), isTrue);
      expect(multi.hasRole(UserRole.technicianInfra), isFalse);
      expect(multi.canUpdateRepairs(), isTrue);
    });
  });

  group('convenience methods', () {
    test('canViewEquipment matches hasPermission', () {
      expect(adminUser.canViewEquipment(), adminUser.hasPermission(Permission.viewEquipment));
      expect(staffUser.canViewEquipment(), staffUser.hasPermission(Permission.viewEquipment));
    });

    test('canManageUsers is true for admin only', () {
      expect(adminUser.canManageUsers(), isTrue);
      expect(staffUser.canManageUsers(), isFalse);
    });

    test('canUpdateRepairs is false for staff', () {
      expect(staffUser.canUpdateRepairs(), isFalse);
    });
  });

  group('copyWith', () {
    test('returns identical copy with no arguments', () {
      final copy = adminUser.copyWith();

      expect(copy.id, adminUser.id);
      expect(copy.name, adminUser.name);
      expect(copy.email, adminUser.email);
      expect(copy.department, adminUser.department);
      expect(copy.roles, adminUser.roles);
      expect(copy.isActive, adminUser.isActive);
    });

    test('overrides specified fields', () {
      final copy = adminUser.copyWith(
        name: 'New Name',
        department: 'New Dept',
        isActive: false,
      );

      expect(copy.name, 'New Name');
      expect(copy.department, 'New Dept');
      expect(copy.isActive, isFalse);
      // Unchanged fields
      expect(copy.id, adminUser.id);
      expect(copy.email, adminUser.email);
    });

    test('can change roles and permissions', () {
      final newPerms = getPermissionsForRole(UserRole.technicianBiomedical);
      final copy = adminUser.copyWith(
        roles: const [UserRole.technicianBiomedical],
        permissions: newPerms,
      );

      expect(copy.roles, const [UserRole.technicianBiomedical]);
      expect(copy.canUpdateRepairs(), isTrue);
      expect(copy.canManageUsers(), isFalse);
    });
  });

  group('isActive', () {
    test('defaults to true', () {
      expect(adminUser.isActive, isTrue);
    });

    test('can be set to false', () {
      final inactive = adminUser.copyWith(isActive: false);
      expect(inactive.isActive, isFalse);
    });
  });

  group('fromApiJson', () {
    test('parses roles array correctly', () {
      final u = User.fromApiJson({
        'id': 'u-1',
        'name': 'Tech Multi',
        'email': 't@test.com',
        'department': 'IT',
        'roles': ['technician_biomedical', 'technician_it'],
        'is_active': 1,
        'created_at': '2024-01-01',
      });
      expect(u.roles, contains(UserRole.technicianBiomedical));
      expect(u.roles, contains(UserRole.technicianIt));
      expect(u.roles, isNot(contains(UserRole.technicianInfra)));
    });

    test('ignores unknown role names', () {
      final u = User.fromApiJson({
        'id': 'u-2',
        'name': 'X',
        'email': 'x@test.com',
        'department': 'IT',
        'roles': ['admin', 'bogus_role'],
        'is_active': 1,
        'created_at': '2024-01-01',
      });
      expect(u.roles, const [UserRole.admin]);
    });
  });
}
