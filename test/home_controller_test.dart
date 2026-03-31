import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfiles/controllers/home_controller.dart';
import 'package:pocketfiles/models/file_model.dart';
import 'package:pocketfiles/models/folder_model.dart';
import 'package:pocketfiles/services/i_storage_service.dart';

// ---------------------------------------------------------------------------
// Minimal in-memory mock — only the methods used by HomeController
// ---------------------------------------------------------------------------

class _MockStorage implements IStorageService {
  List<FolderModel> folders = [];
  Map<int, int>     fileCounts = {};
  bool              onboardingDone = false;
  int               _nextId = 1;

  @override Future<List<FolderModel>> getFolders()     async => List.from(folders);
  @override Future<Map<int, int>>     getFileCounts()  async => Map.from(fileCounts);
  @override Future<Map<int, int>>     getFileSizes()   async => {};
  @override Future<List<({FileModel file, String folderName})>> searchFiles(String q) => throw UnimplementedError();
  @override Future<bool> isOnboardingDone()            async => onboardingDone;
  @override Future<void> setOnboardingDone()           async { onboardingDone = true; }

  @override Future<int> insertFolder(FolderModel folder) async {
    final id = _nextId++;
    folders.add(FolderModel(
      id: id, name: folder.name, color: folder.color, createdAt: folder.createdAt,
    ));
    return id;
  }

  @override Future<void> renameFolder(int id, String name) async {
    folders = folders.map((f) => f.id == id ? f.copyWith(name: name) : f).toList();
  }

  @override Future<void> deleteFolder(int id) async {
    folders = folders.where((f) => f.id != id).toList();
  }

  @override Future<void> updateFolderColor(int id, String color) async {
    folders = folders.map((f) => f.id == id ? f.copyWith(color: color) : f).toList();
  }

  bool throwOnReorder = false;

  @override Future<void> updateFolderOrder(List<FolderModel> fs) async {
    if (throwOnReorder) throw Exception('DB write failed');
    folders = List.from(fs);
  }

  @override Future<void> updateFolderLock(int id, bool isLocked, String? pin,
      {String? pinHint, String? securityQuestion, String? securityAnswer}) async {
    folders = folders
        .map((f) => f.id == id ? f.copyWith(isLocked: isLocked) : f)
        .toList();
  }

  // Unused by HomeController — throw to catch accidental calls
  @override Future<int>            insertFile(FileModel file)              => throw UnimplementedError();
  @override Future<List<FileModel>> getFiles(int folderId)                 => throw UnimplementedError();
  @override Future<void>           deleteFile(int id)                      => throw UnimplementedError();
  @override Future<bool>           fileExists(int folderId, String name)   => throw UnimplementedError();
  @override Future<int>            getFileCount(int folderId)              => throw UnimplementedError();
  @override Future<void>           updateFileOrder(List<FileModel> files)  => throw UnimplementedError();
  @override Future<void>           renameFile(int id, String n, String p)  => throw UnimplementedError();
  @override Future<String?>        getSetting(String key)                  => throw UnimplementedError();
  @override Future<void>           setSetting(String key, String value)    => throw UnimplementedError();
  @override Future<void>           setMasterPin(String pin)                => throw UnimplementedError();
  @override Future<({String hash, String? salt})?>  getMasterPinInfo()     => throw UnimplementedError();
  @override Future<int>            incrementMasterPinAttempts()            => throw UnimplementedError();
  @override Future<void>           resetMasterPinAttempts()                => throw UnimplementedError();
  @override Future<({int count, DateTime? lastAttempt})> logFailedAttemptAndGet(int folderId) => throw UnimplementedError();
  @override Future<List<DateTime>> getFailedAttempts(int folderId)         async => [];
  @override Future<({int count, DateTime? lastAttempt})> getRecentAttemptInfo(int folderId) => throw UnimplementedError();
  @override Future<void>           clearFailedAttempts(int folderId)       async {}
  @override Future<void>           pruneOldFailedAttempts()                => throw UnimplementedError();
  @override Future<void>           recordSuccessfulUnlock(int folderId)    async {}
  @override Future<void>           migratePinToBcrypt(int id, String h)    => throw UnimplementedError();
  @override Future<void>           migrateAnswerToBcrypt(int id, String h) => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FolderModel _folder(int id, String name) => FolderModel(
      id: id,
      name: name,
      color: 'ff6c63ff',
      createdAt: DateTime(2024, 1, 1),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockStorage storage;
  late HomeController controller;

  setUp(() {
    storage    = _MockStorage();
    controller = HomeController(storage);
  });

  tearDown(() => controller.dispose());

  // ── Load ──────────────────────────────────────────────────────────────────

  group('loadFolders', () {
    test('sets isLoading then resolves with folders', () async {
      storage.folders = [_folder(1, 'Work'), _folder(2, 'Personal')];

      bool loadingDuringLoad = false;
      controller.addListener(() {
        if (controller.isLoading) loadingDuringLoad = true;
      });

      await controller.loadFolders(showLoading: true);

      expect(loadingDuringLoad, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.folders.length, 2);
    });

    test('preserves active search query across reloads', () async {
      storage.folders = [_folder(1, 'Work'), _folder(2, 'Personal')];
      await controller.loadFolders();
      controller.applySearch('work');
      expect(controller.filteredFolders.length, 1);

      // Add another folder and reload
      storage.folders.add(_folder(3, 'Archive'));
      await controller.loadFolders();

      // Search still active — only 'Work' matches
      expect(controller.filteredFolders.length, 1);
      expect(controller.filteredFolders.first.name, 'Work');
    });
  });

  // ── Search ────────────────────────────────────────────────────────────────

  group('applySearch', () {
    setUp(() async {
      storage.folders = [_folder(1, 'Work'), _folder(2, 'Personal'), _folder(3, 'Archive')];
      await controller.loadFolders();
    });

    test('filters folders by name (case-insensitive)', () {
      controller.applySearch('work');
      expect(controller.filteredFolders.map((f) => f.name), ['Work']);
    });

    test('empty query shows all folders', () {
      controller.applySearch('x');
      expect(controller.filteredFolders, isEmpty);
      controller.applySearch('');
      expect(controller.filteredFolders.length, 3);
    });

    test('partial match works', () {
      controller.applySearch('a');
      // 'Personal' and 'Archive' both contain 'a'
      expect(controller.filteredFolders.length, 2);
    });
  });

  // ── Edit mode ─────────────────────────────────────────────────────────────

  group('edit mode', () {
    test('enterEditMode clears search and shows all folders', () async {
      storage.folders = [_folder(1, 'Work'), _folder(2, 'Personal')];
      await controller.loadFolders();
      controller.applySearch('work');
      expect(controller.filteredFolders.length, 1);

      controller.enterEditMode();

      expect(controller.isEditMode, isTrue);
      expect(controller.filteredFolders.length, 2);
    });

    test('exitEditMode clears edit mode flag', () {
      controller.enterEditMode();
      controller.exitEditMode();
      expect(controller.isEditMode, isFalse);
    });

    test('lockAll exits edit mode and clears unlocked folders', () async {
      storage.folders = [_folder(1, 'Work')];
      await controller.loadFolders();

      controller.markUnlocked(1);
      controller.enterEditMode();
      expect(controller.isFolderUnlocked(1), isTrue);

      controller.lockAll();

      expect(controller.isEditMode, isFalse);
      expect(controller.isFolderUnlocked(1), isFalse);
    });
  });

  // ── Onboarding ────────────────────────────────────────────────────────────

  group('checkAndMarkOnboardingDone', () {
    test('returns true and marks done on first launch', () async {
      storage.onboardingDone = false;
      final shouldShow = await controller.checkAndMarkOnboardingDone();
      expect(shouldShow, isTrue);
      expect(storage.onboardingDone, isTrue);
    });

    test('returns false when already done', () async {
      storage.onboardingDone = true;
      final shouldShow = await controller.checkAndMarkOnboardingDone();
      expect(shouldShow, isFalse);
    });
  });

  // ── CRUD ──────────────────────────────────────────────────────────────────

  group('folder CRUD', () {
    test('addFolder inserts and reloads', () async {
      await controller.loadFolders();
      expect(controller.folders, isEmpty);

      await controller.addFolder(
          FolderModel(name: 'New', color: 'ff6c63ff', createdAt: DateTime.now()));

      expect(controller.folders.length, 1);
      expect(controller.folders.first.name, 'New');
    });

    test('renameFolder updates name', () async {
      storage.folders = [_folder(1, 'Old')];
      await controller.loadFolders();

      await controller.renameFolder(1, 'New');

      expect(controller.folders.first.name, 'New');
    });

    test('deleteFolder removes folder', () async {
      storage.folders = [_folder(1, 'Work'), _folder(2, 'Personal')];
      await controller.loadFolders();

      await controller.deleteFolder(1);

      expect(controller.folders.length, 1);
      expect(controller.folders.first.name, 'Personal');
    });
  });

  // ── Reorder ───────────────────────────────────────────────────────────────

  group('reorder', () {
    test('moves folder to new position', () async {
      storage.folders = [_folder(1, 'A'), _folder(2, 'B'), _folder(3, 'C')];
      await controller.loadFolders();

      await controller.reorder(0, 2); // Move A after B → B, A, C
      expect(controller.folders.map((f) => f.name), ['B', 'A', 'C']);
    });

    test('rolls back when DB write fails', () async {
      storage.folders = [_folder(1, 'A'), _folder(2, 'B'), _folder(3, 'C')];
      await controller.loadFolders();
      storage.throwOnReorder = true;

      await controller.reorder(0, 2); // Optimistic move then DB throws → rollback
      expect(controller.folders.map((f) => f.name), ['A', 'B', 'C']);
    });
  });

  // ── Unlock tracking ───────────────────────────────────────────────────────

  group('unlock tracking', () {
    test('markUnlocked and isFolderUnlocked', () {
      expect(controller.isFolderUnlocked(42), isFalse);
      controller.markUnlocked(42);
      expect(controller.isFolderUnlocked(42), isTrue);
    });
  });
}
