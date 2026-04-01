import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';

/// Hashing and verification for PINs and security-question answers.
///
/// **Algorithm**: bcrypt with work factor 10 (≈ 100 ms on mid-range mobile).
/// Work factor 10 provides ~1000x resistance against brute-force
/// while remaining fast enough for interactive use.
///
/// **Isolation**: [hash] and [verify] run bcrypt in a background isolate via
/// [compute] so the UI thread is never blocked.
abstract final class PinHasher {
  /// Hashes [input] with bcrypt (work factor 10) in a background isolate.
  /// Returns the full bcrypt string (includes algorithm, factor, and salt).
  ///
  /// **Note**: BCrypt silently truncates inputs longer than 72 bytes.
  /// All current callers pass 4-digit PINs or short security-question answers
  /// well within this limit — do not pass unbounded user text directly.
  static Future<String> hash(String input) => compute(_hashSync, input);

  /// Verifies [input] against [storedHash] (bcrypt) in a background isolate.
  static Future<bool> verify(String input, String storedHash) =>
      compute(_verifySync, [input, storedHash]);

  static String _hashSync(String input) =>
      BCrypt.hashpw(input, BCrypt.gensalt(logRounds: 10));

  static bool _verifySync(List<String> args) =>
      BCrypt.checkpw(args[0], args[1]);
}
