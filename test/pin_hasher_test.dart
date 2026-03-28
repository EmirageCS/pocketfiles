import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:pocketfiles/utils/pin_hasher.dart';

void main() {
  group('PinHasher', () {
    test('hash() produces a bcrypt string', () async {
      final hash = await PinHasher.hash('1234');
      expect(PinHasher.isBcrypt(hash), isTrue);
    });

    test('verify() returns true for the correct input', () async {
      final hash = await PinHasher.hash('1234');
      expect(await PinHasher.verify('1234', hash), isTrue);
    });

    test('verify() returns false for a wrong input', () async {
      final hash = await PinHasher.hash('1234');
      expect(await PinHasher.verify('0000', hash), isFalse);
    });

    test('isBcrypt() returns false for a non-bcrypt string', () {
      expect(PinHasher.isBcrypt('abc123'), isFalse);
      expect(PinHasher.isBcrypt('notabcrypt'), isFalse);
    });

    test('isBcrypt() returns true for a real bcrypt hash', () async {
      final hash = await PinHasher.hash('test');
      expect(PinHasher.isBcrypt(hash), isTrue);
      expect(hash.startsWith(r'$2'), isTrue);
    });

    test('verify() falls back to legacy SHA-256 (no salt)', () async {
      // SHA-256 of "test" — matches the legacy code path
      final sha256Hash =
          sha256.convert(utf8.encode('test')).toString();
      expect(await PinHasher.verify('test', sha256Hash), isTrue);
      expect(await PinHasher.verify('wrong', sha256Hash), isFalse);
    });

    test('verify() falls back to legacy SHA-256 (with salt)', () async {
      const salt  = 'mysalt';
      const input = 'test';
      final sha256Hash =
          sha256.convert(utf8.encode('$salt:$input')).toString();
      expect(await PinHasher.verify(input, sha256Hash, legacySalt: salt), isTrue);
      expect(await PinHasher.verify(input, sha256Hash), isFalse);
    });

    test('two hashes of the same input differ (bcrypt uses random salt)', () async {
      final h1 = await PinHasher.hash('1234');
      final h2 = await PinHasher.hash('1234');
      expect(h1, isNot(equals(h2)));
    });
  });
}
