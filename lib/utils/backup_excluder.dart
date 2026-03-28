import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Marks a file or directory as excluded from iCloud/iTunes backup on iOS.
///
/// On iOS, [NSURLIsExcludedFromBackupKey] is set on the given path — this is
/// recursive, so marking a directory also excludes all of its contents.
///
/// On Android, backup is disabled app-wide via `android:allowBackup="false"`
/// in AndroidManifest.xml, so this is a no-op on that platform.
abstract final class BackupExcluder {
  static const _channel = MethodChannel('com.pocketfiles/storage');

  /// Exclude [path] from iCloud/iTunes backup. Safe to call multiple times
  /// on the same path (idempotent). Silently ignored on non-iOS platforms.
  static Future<void> exclude(String path) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('excludeFromBackup', path);
    } catch (e) {
      debugPrint('BackupExcluder.exclude failed for "$path": $e');
    }
  }
}
