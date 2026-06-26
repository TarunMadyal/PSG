import 'package:flutter_test/flutter_test.dart';
import 'package:psg_pos/core/security/pin_hasher.dart';

void main() {
  // Fewer iterations keep the test fast; behaviour is identical.
  const hasher = PinHasher(iterations: 1000);

  group('PinHasher', () {
    test('verifies the correct PIN', () {
      final stored = hasher.hash('1234');
      expect(hasher.verify('1234', stored), isTrue);
    });

    test('rejects an incorrect PIN', () {
      final stored = hasher.hash('1234');
      expect(hasher.verify('0000', stored), isFalse);
      expect(hasher.verify('12345', stored), isFalse);
    });

    test('never stores the raw secret and is self-describing', () {
      final stored = hasher.hash('secret-pass');
      expect(stored, isNot(contains('secret-pass')));
      expect(stored, startsWith('pbkdf2_sha256\$1000\$'));
      expect(stored.split(r'$'), hasLength(4));
    });

    test('produces a different hash each time (random salt)', () {
      expect(hasher.hash('1234'), isNot(hasher.hash('1234')));
    });

    test('rejects malformed stored values', () {
      expect(hasher.verify('1234', 'not-a-hash'), isFalse);
      expect(hasher.verify('1234', r'md5$1$a$b'), isFalse);
    });

    test('verifies across differing iteration counts (stored value wins)', () {
      const writer = PinHasher(iterations: 2000);
      final stored = writer.hash('9999');
      // A reader configured with different iterations still verifies, because
      // the iteration count is read from the stored hash.
      const reader = PinHasher(iterations: 500);
      expect(reader.verify('9999', stored), isTrue);
    });
  });
}
