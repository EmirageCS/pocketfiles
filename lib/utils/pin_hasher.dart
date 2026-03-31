import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Hashing and verification for PINs and security-question answers.
///
/// **Algorithm**: bcrypt with work factor 10 (≈ 100 ms on mid-range mobile).
/// Work factor 10 provides ~1000x resistance over SHA-256 against brute-force
/// while remaining fast enough for interactive use.
///
/// **Isolation**: [hash] and [verify] run their bcrypt operations inside a
/// background isolate via [compute] so the UI thread is never blocked.
///
/// **Legacy migration**: [verify] transparently falls back to SHA-256
/// (with optional salt) for hashes created by older app versions.  On first
/// successful verify the caller should re-hash with bcrypt and persist the
/// new hash.
abstract final class PinHasher {
  /// Returns true if [hash] is a bcrypt hash (starts with `$2`).
  static bool isBcrypt(String hash) => hash.startsWith(r'$2');

  /// Hashes [input] with bcrypt (work factor 10) in a background isolate.
  /// Returns the full bcrypt string (includes algorithm, factor, and salt).
  ///
  /// **Note**: BCrypt silently truncates inputs longer than 72 bytes.
  /// All current callers pass 4-digit PINs or short security-question answers
  /// well within this limit — do not pass unbounded user text directly.
  static Future<String> hash(String input) => compute(_hashSync, input);

  /// Verifies [input] against [storedHash].
  ///
  /// - If [storedHash] starts with `$2` it is treated as a bcrypt hash and
  ///   verified in a background isolate.
  /// - Otherwise falls back to SHA-256: if [legacySalt] is provided the data
  ///   to hash is `"$legacySalt:$input"`, otherwise just `input`.
  static Future<bool> verify(
    String input,
    String storedHash, {
    String? legacySalt,
  }) async {
    if (isBcrypt(storedHash)) {
      return compute(_verifySync, [input, storedHash]);
    }
    // Legacy SHA-256 path — kept for transparent migration from v1 hashes
    final data = legacySalt != null ? '$legacySalt:$input' : input;
    return sha256.convert(utf8.encode(data)).toString() == storedHash;
  }

  static String _hashSync(String input) =>
      BCrypt.hashpw(input, BCrypt.gensalt(logRounds: 10));

  static bool _verifySync(List<String> args) =>
      BCrypt.checkpw(args[0], args[1]);
}
