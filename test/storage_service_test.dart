import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pocketfiles/models/file_model.dart';
import 'package:pocketfiles/models/folder_model.dart';
import 'package:pocketfiles/services/storage_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FolderModel _newFolder(String name) => FolderModel(
      name: name,
      color: 'ff6c63ff',
      createdAt: DateTime.now(),
    );

FileModel _newFile({required int folderId, String name = 'file.pdf'}) =>
    FileModel(
      folderId: folderId,
      name: name,
      path: '/tmp/$name',
      size: 1024,
      createdAt: DateTime.now(),
    );

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Mock path_provider so deleteFolder's getApplicationDocumentsDirectory works
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') return '/tmp';
        return null;
      },
    );
  });

  setUp(() {
    // Each test gets a fresh in-memory database.
    StorageService.setDatabasePathForTesting(inMemoryDatabasePath);
  });

  tearDown(() async {
    await StorageService.resetForTesting();
    // resetForTesting clears the path override — re-set it for the next test.
    StorageService.setDatabasePathForTesting(inMemoryDatabasePath);
  });

  // --------------------------------------------------------------------------
  // Folders
  // --------------------------------------------------------------------------

  group('StorageService — folders', () {
    test('insertFolder returns a positive id', () async {
      final id = await StorageService().insertFolder(_newFolder('Alpha'));
      expect(id, greaterThan(0));
    });

    test('getFolders returns inserted folder', () async {
      final s = StorageService();
      final id = await s.insertFolder(_newFolder('Alpha'));
      final folders = await s.getFolders();
      expect(folders.length, 1);
      expect(folders.first.name, 'Alpha');
      expect(folders.first.id, id);
    });

    test('getFolders orders by orderIndex ascending', () async {
      final s = StorageService();
      await s.insertFolder(_newFolder('B'));
      await s.insertFolder(_newFolder('A'));
      final folders = await s.getFolders();
      expect(folders[0].name, 'B'); // inserted first → orderIndex 0
      expect(folders[1].name, 'A'); // inserted second → orderIndex 1
    });

    test('renameFolder updates name', () async {
      final s = StorageService();
      final id = await s.insertFolder(_newFolder('Old'));
      await s.renameFolder(id, 'New');
      final folders = await s.getFolders();
      expect(folders.first.name, 'New');
    });

    test('deleteFolder removes folder', () async {
      final s = StorageService();
      final id = await s.insertFolder(_newFolder('ToDelete'));
      await s.deleteFolder(id);
      expect(await s.getFolders(), isEmpty);
    });

    test('deleteFolder cascades to files', () async {
      final s = StorageService();
      final fid = await s.insertFolder(_newFolder('Parent'));
      await s.insertFile(_newFile(folderId: fid));
      await s.deleteFolder(fid);
      expect(await s.getFiles(fid), isEmpty);
    });

    test('updateFolderColor persists new color', () async {
      final s = StorageService();
      final id = await s.insertFolder(_newFolder('Folder'));
      await s.updateFolderColor(id, 'ff43a047');
      final folders = await s.getFolders();
      expect(folders.first.color, 'ff43a047');
    });

    test('getFileCounts returns correct per-folder counts', () async {
      final s = StorageService();
      final f1 = await s.insertFolder(_newFolder('F1'));
      final f2 = await s.insertFolder(_newFolder('F2'));
      await s.insertFile(_newFile(folderId: f1, name: 'a.pdf'));
      await s.insertFile(_newFile(folderId: f1, name: 'b.pdf'));
      await s.insertFile(_newFile(folderId: f2, name: 'c.pdf'));
      final counts = await s.getFileCounts();
      expect(counts[f1], 2);
      expect(counts[f2], 1);
    });

    test('updateFolderOrder reorders correctly', () async {
      final s = StorageService();
      await s.insertFolder(_newFolder('First'));
      await s.insertFolder(_newFolder('Second'));
      final folders = await s.getFolders();
      await s.updateFolderOrder([folders[1], folders[0]]);
      final reordered = await s.getFolders();
      expect(reordered[0].name, 'Second');
      expect(reordered[1].name, 'First');
    });
  });

  // --------------------------------------------------------------------------
  // Files
  // --------------------------------------------------------------------------

  group('StorageService — files', () {
    late int folderId;

    setUp(() async {
      folderId = await StorageService().insertFolder(_newFolder('Folder'));
    });

    test('insertFile returns a positive id', () async {
      final id = await StorageService().insertFile(_newFile(folderId: folderId));
      expect(id, greaterThan(0));
    });

    test('getFiles returns inserted file', () async {
      final s = StorageService();
      await s.insertFile(_newFile(folderId: folderId));
      final files = await s.getFiles(folderId);
      expect(files.length, 1);
      expect(files.first.name, 'file.pdf');
    });

    test('insertFile assigns sequential orderIndex', () async {
      final s = StorageService();
      await s.insertFile(_newFile(folderId: folderId, name: 'first.pdf'));
      await s.insertFile(_newFile(folderId: folderId, name: 'second.pdf'));
      final files = await s.getFiles(folderId);
      expect(files[0].orderIndex, 0);
      expect(files[1].orderIndex, 1);
    });

    test('deleteFile removes the file', () async {
      final s = StorageService();
      final id = await s.insertFile(_newFile(folderId: folderId));
      await s.deleteFile(id);
      expect(await s.getFiles(folderId), isEmpty);
    });

    test('fileExists returns true for existing file', () async {
      final s = StorageService();
      await s.insertFile(_newFile(folderId: folderId, name: 'doc.pdf'));
      expect(await s.fileExists(folderId, 'doc.pdf'), isTrue);
    });

    test('fileExists returns false for missing file', () async {
      expect(await StorageService().fileExists(folderId, 'ghost.pdf'), isFalse);
    });

    test('renameFile updates name and path', () async {
      final s = StorageService();
      final id = await s.insertFile(_newFile(folderId: folderId));
      await s.renameFile(id, 'new.pdf', '/tmp/new.pdf');
      final files = await s.getFiles(folderId);
      expect(files.first.name, 'new.pdf');
      expect(files.first.path, '/tmp/new.pdf');
    });

    test('getFileCount returns 0 for empty folder', () async {
      expect(await StorageService().getFileCount(folderId), 0);
    });

    test('getFileCount returns correct count', () async {
      final s = StorageService();
      await s.insertFile(_newFile(folderId: folderId, name: 'a.pdf'));
      await s.insertFile(_newFile(folderId: folderId, name: 'b.pdf'));
      expect(await s.getFileCount(folderId), 2);
    });

    test('updateFileOrder reorders correctly', () async {
      final s = StorageService();
      await s.insertFile(_newFile(folderId: folderId, name: 'first.pdf'));
      await s.insertFile(_newFile(folderId: folderId, name: 'second.pdf'));
      final files = await s.getFiles(folderId);
      await s.updateFileOrder([files[1], files[0]]);
      final reordered = await s.getFiles(folderId);
      expect(reordered[0].name, 'second.pdf');
      expect(reordered[1].name, 'first.pdf');
    });
  });

  // --------------------------------------------------------------------------
  // Settings
  // --------------------------------------------------------------------------

  group('StorageService — settings', () {
    test('getSetting returns null for missing key', () async {
      expect(await StorageService().getSetting('missing'), isNull);
    });

    test('setSetting and getSetting round-trip', () async {
      final s = StorageService();
      await s.setSetting('key1', 'value1');
      expect(await s.getSetting('key1'), 'value1');
    });

    test('setSetting overwrites existing value', () async {
      final s = StorageService();
      await s.setSetting('key', 'first');
      await s.setSetting('key', 'second');
      expect(await s.getSetting('key'), 'second');
    });

    test('isOnboardingDone returns false initially', () async {
      expect(await StorageService().isOnboardingDone(), isFalse);
    });

    test('setOnboardingDone marks it as done', () async {
      final s = StorageService();
      await s.setOnboardingDone();
      expect(await s.isOnboardingDone(), isTrue);
    });
  });

  // --------------------------------------------------------------------------
  // Master PIN
  // --------------------------------------------------------------------------

  group('StorageService — master PIN', () {
    test('getMasterPinInfo returns null when not set', () async {
      expect(await StorageService().getMasterPinInfo(), isNull);
    });

    test('incrementMasterPinAttempts increments from 0', () async {
      final s = StorageService();
      expect(await s.incrementMasterPinAttempts(), 1);
      expect(await s.incrementMasterPinAttempts(), 2);
      expect(await s.incrementMasterPinAttempts(), 3);
    });

    test('resetMasterPinAttempts resets counter to 0', () async {
      final s = StorageService();
      await s.incrementMasterPinAttempts();
      await s.incrementMasterPinAttempts();
      await s.resetMasterPinAttempts();
      expect(await s.incrementMasterPinAttempts(), 1);
    });
  });

  // --------------------------------------------------------------------------
  // Failed attempts & lockout
  // --------------------------------------------------------------------------

  group('StorageService — failed attempts', () {
    late int folderId;

    setUp(() async {
      folderId = await StorageService().insertFolder(_newFolder('Locked'));
    });

    test('logFailedAttemptAndGet increments count', () async {
      final s = StorageService();
      final r1 = await s.logFailedAttemptAndGet(folderId);
      expect(r1.count, 1);
      final r2 = await s.logFailedAttemptAndGet(folderId);
      expect(r2.count, 2);
      expect(r2.lastAttempt, isNotNull);
    });

    test('getFailedAttempts returns recent entries', () async {
      final s = StorageService();
      await s.logFailedAttemptAndGet(folderId);
      await s.logFailedAttemptAndGet(folderId);
      final attempts = await s.getFailedAttempts(folderId);
      expect(attempts.length, 2);
    });

    test('clearFailedAttempts empties the list', () async {
      final s = StorageService();
      await s.logFailedAttemptAndGet(folderId);
      await s.clearFailedAttempts(folderId);
      expect(await s.getFailedAttempts(folderId), isEmpty);
    });

    test('getRecentAttemptInfo returns correct count and timestamp', () async {
      final s = StorageService();
      await s.logFailedAttemptAndGet(folderId);
      await s.logFailedAttemptAndGet(folderId);
      final info = await s.getRecentAttemptInfo(folderId);
      expect(info.count, 2);
      expect(info.lastAttempt, isNotNull);
    });

    test('getRecentAttemptInfo returns zero count when no attempts', () async {
      final info = await StorageService().getRecentAttemptInfo(folderId);
      expect(info.count, 0);
      expect(info.lastAttempt, isNull);
    });

    test('recordSuccessfulUnlock hides prior attempts from getFailedAttempts', () async {
      final s = StorageService();
      await s.logFailedAttemptAndGet(folderId);
      await s.logFailedAttemptAndGet(folderId);
      await s.recordSuccessfulUnlock(folderId);
      // Wait 1ms so the next attempt's timestamp is strictly after lastUnlockedAt
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await s.logFailedAttemptAndGet(folderId); // one new attempt after unlock
      final attempts = await s.getFailedAttempts(folderId);
      expect(attempts.length, 1);
    });

    test('pruneOldFailedAttempts removes entries older than 30 days', () async {
      final s = StorageService();
      // Insert a recent attempt
      await s.logFailedAttemptAndGet(folderId);
      // Insert a stale attempt directly via the database
      final db = await s.database;
      await db.insert('failed_attempts', {
        'folderId': folderId,
        'attemptedAt': DateTime.now()
            .subtract(const Duration(days: 31))
            .toIso8601String(),
      });
      await s.pruneOldFailedAttempts();
      final attempts = await s.getFailedAttempts(folderId);
      expect(attempts.length, 1); // stale one pruned, recent one kept
    });
  });

  // --------------------------------------------------------------------------
  // Onboarding
  // --------------------------------------------------------------------------

  group('StorageService — onboarding', () {
    test('setOnboardingDone is idempotent', () async {
      final s = StorageService();
      await s.setOnboardingDone();
      await s.setOnboardingDone(); // should not throw
      expect(await s.isOnboardingDone(), isTrue);
    });
  });
}
