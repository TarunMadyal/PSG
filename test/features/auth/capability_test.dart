import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/enums.dart';
import 'package:psg_pos/features/auth/domain/app_user.dart';
import 'package:psg_pos/features/auth/domain/capability.dart';

void main() {
  group('capabilitiesFor', () {
    test('owner has every capability', () {
      final caps = capabilitiesFor(UserRole.owner);
      expect(caps, containsAll(Capability.values));
    });

    test('staff can bill and look up, but not manage or delete', () {
      final caps = capabilitiesFor(UserRole.staff);

      // Allowed
      expect(caps, contains(Capability.createBill));
      expect(caps, contains(Capability.printBill));
      expect(caps, contains(Capability.searchProducts));
      expect(caps, contains(Capability.viewStock));

      // Denied
      expect(caps, isNot(contains(Capability.manageProducts)));
      expect(caps, isNot(contains(Capability.manageSettings)));
      expect(caps, isNot(contains(Capability.manageUsers)));
      expect(caps, isNot(contains(Capability.viewReports)));
      expect(caps, isNot(contains(Capability.deleteData)));
      expect(caps, isNot(contains(Capability.manageBackups)));
    });
  });

  group('AppUser', () {
    test('isOwner reflects role', () {
      const owner = AppUser(id: '1', name: 'Asha', role: UserRole.owner);
      const staff = AppUser(id: '2', name: 'Ravi Kumar', role: UserRole.staff);
      expect(owner.isOwner, isTrue);
      expect(staff.isOwner, isFalse);
    });

    test('initials handle single and multi-word names', () {
      const a = AppUser(id: '1', name: 'Asha', role: UserRole.owner);
      const b = AppUser(id: '2', name: 'Ravi Kumar', role: UserRole.staff);
      expect(a.initials, 'A');
      expect(b.initials, 'RK');
    });
  });
}
