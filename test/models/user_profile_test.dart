import 'package:flutter_test/flutter_test.dart';
import 'package:metra_it_assets/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('round trips IT manager office assignments', () {
      final profile = UserProfile(
        uid: 'manager-a',
        displayName: 'Manager A',
        email: 'MANAGER@EXAMPLE.COM',
        role: UserProfile.itManagerRole,
        isActive: true,
        officeIds: const ['OFFICE_A', 'OFFICE_B'],
        createdBy: 'admin-1',
      );

      final restored = UserProfile.fromMap(profile.uid, profile.toMap());

      expect(restored.officeIds, ['OFFICE_A', 'OFFICE_B']);
      expect(restored.email, 'manager@example.com');
      expect(restored.createdBy, 'admin-1');
    });

    test('legacy manager profile without officeIds remains readable but unassigned', () {
      final profile = UserProfile.fromMap('legacy-manager', {
        'displayName': 'Legacy Manager',
        'email': 'legacy@example.com',
        'role': 'it_manager',
        'isActive': true,
      });

      expect(profile.officeIds, isEmpty);
      expect(profile.canAccessOffice('OFFICE_A'), isFalse);
    });

    test('admin is global without office assignments', () {
      final profile = UserProfile(
        uid: 'admin-1',
        displayName: 'Admin',
        email: 'admin@example.com',
        role: UserProfile.adminRole,
        isActive: true,
      );

      expect(profile.isGlobalAdministrator, isTrue);
      expect(profile.canAccessOffice('OFFICE_A'), isTrue);
      expect(profile.toMap()['officeIds'], isEmpty);
    });

    test('inactive user cannot access an assigned office', () {
      final profile = UserProfile(
        uid: 'inactive-a',
        displayName: 'Inactive',
        email: 'inactive@example.com',
        role: UserProfile.itManagerRole,
        isActive: false,
        officeIds: const ['OFFICE_A'],
      );

      expect(profile.canAccessOffice('OFFICE_A'), isFalse);
    });

    test('rejects unsupported roles', () {
      expect(
        () => UserProfile(
          uid: 'employee-1',
          displayName: 'Employee',
          email: 'employee@example.com',
          role: 'employee',
          isActive: true,
        ),
        throwsArgumentError,
      );
    });

    test('rejects duplicate or empty office IDs', () {
      expect(
        () => UserProfile(
          uid: 'manager-a',
          displayName: 'Manager',
          email: 'manager@example.com',
          role: 'it_manager',
          isActive: true,
          officeIds: const ['OFFICE_A', 'OFFICE_A'],
        ),
        throwsArgumentError,
      );
      expect(
        () => UserProfile(
          uid: 'manager-a',
          displayName: 'Manager',
          email: 'manager@example.com',
          role: 'it_manager',
          isActive: true,
          officeIds: const ['  '],
        ),
        throwsArgumentError,
      );
    });

    test('rejects office assignments on global administrator profiles', () {
      expect(
        () => UserProfile(
          uid: 'admin-1',
          displayName: 'Admin',
          email: 'admin@example.com',
          role: 'admin',
          isActive: true,
          officeIds: const ['OFFICE_A'],
        ),
        throwsArgumentError,
      );
    });

    test('rejects malformed officeIds data', () {
      expect(
        () => UserProfile.fromMap('manager-a', {
          'displayName': 'Manager',
          'email': 'manager@example.com',
          'role': 'it_manager',
          'isActive': true,
          'officeIds': ['OFFICE_A', 42],
        }),
        throwsFormatException,
      );
    });
  });
}
