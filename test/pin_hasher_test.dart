import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfiles/utils/pin_hasher.dart';

void main() {
  group('PinHasher', () {
    test('hash() produces a bcrypt string', () async {
      final hash = await PinHasher.hash('1234');
      expect(hash.startsWith(r'$2'), isTrue);
    });

    test('verify() returns true for the correct input', () async {
      final hash = await PinHasher.hash('1234');
      expect(await PinHasher.verify('1234', hash), isTrue);
    });

    test('verify() returns false for a wrong input', () async {
      final hash = await PinHasher.hash('1234');
      expect(await PinHasher.verify('0000', hash), isFalse);
    });

    test('two hashes of the same input differ (bcrypt uses random salt)', () async {
      final h1 = await PinHasher.hash('1234');
      final h2 = await PinHasher.hash('1234');
      expect(h1, isNot(equals(h2)));
    });
  });
}
