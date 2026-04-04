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
      role: UserRole.admin,
      permissions: getPermissionsForRole(UserRole.admin),
      createdAt: '2024-01-01',
    );

    staffUser = User(
      id: 'test-staff',
      name: 'Test Staff',
      email: 'staff@test.com',
      department: 'Urgences',
      role: UserRole.hospitalStaff,
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
      expect(copy.role, adminUser.role);
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

    test('can change role and permissions', () {
      final newPerms = getPermissionsForRole(UserRole.technician);
      final copy = adminUser.copyWith(
        role: UserRole.technician,
        permissions: newPerms,
      );

      expect(copy.role, UserRole.technician);
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
}
