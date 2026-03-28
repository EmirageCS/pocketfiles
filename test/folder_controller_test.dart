import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfiles/controllers/folder_controller.dart';
import 'package:pocketfiles/models/file_model.dart';
import 'package:pocketfiles/models/folder_model.dart';
import 'package:pocketfiles/services/i_file_service.dart';
import 'package:pocketfiles/services/i_storage_service.dart';
import 'package:pocketfiles/services/file_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockStorage implements IStorageService {
  List<FileModel> files = [];
  Map<String, String> settings = {};
  int _nextId = 1;

  @override Future<List<FileModel>> getFiles(int folderId) async => List.from(files);
  @override Future<bool>           fileExists(int folderId, String name) async =>
      files.any((f) => f.folderId == folderId && f.name == name);
  @override Future<int>            insertFile(FileModel file) async {
    final id = _nextId++;
    files.add(file.copyWith(id: id));
    return id;
  }
  @override Future<void>           deleteFile(int id) async {
    files = files.where((f) => f.id != id).toList();
  }
  bool throwOnReorder = false;

  @override Future<void>           updateFileOrder(List<FileModel> updated) async {
    if (throwOnReorder) throw Exception('DB write failed');
    files = List.from(updated);
  }
  @override Future<void>           renameFile(int id, String n, String p) async {
    files = files.map((f) => f.id == id ? f.copyWith(name: n, path: p) : f).toList();
  }
  @override Future<int>            getFileCount(int folderId) async =>
      files.where((f) => f.folderId == folderId).length;
  @override Future<String?>        getSetting(String key) async => settings[key];
  @override Future<void>           setSetting(String key, String value) async {
    settings[key] = value;
  }

  // Unused by FolderController — throw to catch accidental calls
  @override Future<int>            insertFolder(FolderModel folder)           => throw UnimplementedError();
  @override Future<List<FolderModel>> getFolders()                             => throw UnimplementedError();
  @override Future<Map<int, int>>  getFileCounts()                             => throw UnimplementedError();
  @override Future<Map<int, int>>  getFileSizes()                              => throw UnimplementedError();
  @override Future<List<({FileModel file, String folderName})>> searchFiles(String q) => throw UnimplementedError();
  @override Future<void>           deleteFolder(int id)                        => throw UnimplementedError();
  @override Future<void>           renameFolder(int id, String name)           => throw UnimplementedError();
  @override Future<void>           updateFolderLock(int id, bool l, String? p, {String? pinHint, String? securityQuestion, String? securityAnswer}) => throw UnimplementedError();
  @override Future<void>           updateFolderOrder(List<FolderModel> fs)     => throw UnimplementedError();
  @override Future<void>           updateFolderColor(int id, String color)     => throw UnimplementedError();
  @override Future<bool>           isOnboardingDone()                          => throw UnimplementedError();
  @override Future<void>           setOnboardingDone()                         => throw UnimplementedError();
  @override Future<void>           setMasterPin(String pin)                    => throw UnimplementedError();
  @override Future<({String hash, String? salt})?>  getMasterPinInfo()         => throw UnimplementedError();
  @override Future<int>            incrementMasterPinAttempts()                => throw UnimplementedError();
  @override Future<void>           resetMasterPinAttempts()                    => throw UnimplementedError();
  @override Future<({int count, DateTime? lastAttempt})> logFailedAttemptAndGet(int folderId) => throw UnimplementedError();
  @override Future<List<DateTime>> getFailedAttempts(int folderId)             async => [];
  @override Future<({int count, DateTime? lastAttempt})> getRecentAttemptInfo(int folderId) => throw UnimplementedError();
  @override Future<void>           clearFailedAttempts(int folderId)           async {}
  @override Future<void>           pruneOldFailedAttempts()                    => throw UnimplementedError();
  @override Future<void>           recordSuccessfulUnlock(int folderId)        async {}
  @override Future<void>           migratePinToBcrypt(int id, String h)        => throw UnimplementedError();
  @override Future<void>           migrateAnswerToBcrypt(int id, String h)     => throw UnimplementedError();
}

// ---------------------------------------------------------------------------

enum _PickBehavior { returnFile, returnNull, throwDuplicate, throwGeneric }

class _MockFileService implements IFileService {
  _PickBehavior pickBehavior = _PickBehavior.returnFile;
  bool openShouldThrow  = false;
  bool shareShouldThrow = false;
  bool renameShouldThrow = false;
  bool renameIsDuplicate = false;
  bool deleteShouldThrow = false;

  @override
  Future<FileModel?> pickAndSaveFile(int folderId, {bool deleteOriginal = false}) async {
    switch (pickBehavior) {
      case _PickBehavior.returnNull:
        return null;
      case _PickBehavior.throwDuplicate:
        throw const FileAlreadyExistsException();
      case _PickBehavior.throwGeneric:
        throw Exception('disk full');
      case _PickBehavior.returnFile:
        return FileModel(
          id: 99,
          folderId: folderId,
          name: 'picked.pdf',
          path: '/tmp/picked.pdf',
          size: 1024,
          createdAt: DateTime(2024, 6, 1),
        );
    }
  }

  @override
  Future<({List<FileModel> saved, int duplicates, int errors})?> pickAndSaveFiles(
    int folderId, {
    bool deleteOriginal = false,
  }) async => null;

  @override
  Future<void> openFile(FileModel file) async {
    if (openShouldThrow) throw Exception('no app');
  }

  @override
  Future<void> shareFile(FileModel file) async {
    if (shareShouldThrow) throw Exception('share failed');
  }

  @override
  Future<FileModel> renameFile(FileModel file, String newBaseName) async {
    if (renameShouldThrow) throw Exception('io error');
    if (renameIsDuplicate) throw const FileAlreadyExistsException();
    return file.copyWith(name: '$newBaseName.pdf', path: '/tmp/$newBaseName.pdf');
  }

  @override
  Future<void> deleteFile(FileModel file) async {
    if (deleteShouldThrow) throw Exception('delete failed');
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FolderModel _testFolder() => FolderModel(
      id: 1,
      name: 'Work',
      color: 'ff6c63ff',
      createdAt: DateTime(2024, 1, 1),
    );

FileModel _file(int id, String name) => FileModel(
      id: id,
      folderId: 1,
      name: name,
      path: '/tmp/$name',
      size: 512,
      orderIndex: id - 1,
      createdAt: DateTime(2024, 1, id),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockStorage storage;
  late _MockFileService fileService;
  late FolderController controller;

  setUp(() {
    storage     = _MockStorage();
    fileService = _MockFileService();
    controller  = FolderController(_testFolder(), storage, fileService);
  });

  tearDown(() => controller.dispose());

  // ── Init ──────────────────────────────────────────────────────────────────

  group('init', () {
    test('loads files and resolves isLoading', () async {
      storage.files = [_file(1, 'a.pdf'), _file(2, 'b.pdf')];
      await controller.init();
      expect(controller.isLoading, isFalse);
      expect(controller.files.length, 2);
    });

    test('restores saved sort mode from settings', () async {
      storage.settings['sortMode_1'] = 'name';
      await controller.init();
      expect(controller.sortBy, SortMode.name);
    });

    test('defaults to custom sort when no saved preference', () async {
      await controller.init();
      expect(controller.sortBy, SortMode.custom);
    });
  });

  // ── loadFiles ─────────────────────────────────────────────────────────────

  group('loadFiles', () {
    test('sets isLoading then resolves', () async {
      storage.files = [_file(1, 'x.pdf')];
      bool sawLoading = false;
      controller.addListener(() {
        if (controller.isLoading) sawLoading = true;
      });
      await controller.loadFiles();
      expect(sawLoading, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.files.length, 1);
    });
  });

  // ── applySearch ───────────────────────────────────────────────────────────

  group('applySearch', () {
    setUp(() async {
      storage.files = [_file(1, 'report.pdf'), _file(2, 'photo.jpg'), _file(3, 'notes.txt')];
      await controller.loadFiles();
    });

    test('filters displayFiles by name (case-insensitive)', () {
      controller.applySearch('REPORT');
      expect(controller.displayFiles.map((f) => f.name), ['report.pdf']);
    });

    test('empty query shows all files', () {
      controller.applySearch('zzz');
      expect(controller.displayFiles, isEmpty);
      controller.applySearch('');
      expect(controller.displayFiles.length, 3);
    });

    test('partial match works', () {
      // 'ph' matches only 'photo.jpg'
      controller.applySearch('ph');
      expect(controller.displayFiles.map((f) => f.name), ['photo.jpg']);
    });
  });

  // ── setSortMode ───────────────────────────────────────────────────────────

  group('setSortMode', () {
    setUp(() async {
      storage.files = [
        _file(1, 'beta.pdf'),
        _file(2, 'alpha.pdf'),
        _file(3, 'gamma.pdf'),
      ];
      await controller.loadFiles();
    });

    test('name sort orders alphabetically', () {
      controller.setSortMode(SortMode.name);
      final names = controller.displayFiles.map((f) => f.name).toList();
      expect(names, ['alpha.pdf', 'beta.pdf', 'gamma.pdf']);
    });

    test('size sort orders descending', () async {
      // All files have the same size (512) in our helper — add unique sizes
      storage.files = [
        FileModel(id: 1, folderId: 1, name: 'big.pdf',    path: '/tmp/big.pdf',    size: 3000, orderIndex: 0, createdAt: DateTime(2024, 1, 1)),
        FileModel(id: 2, folderId: 1, name: 'medium.pdf', path: '/tmp/medium.pdf', size: 2000, orderIndex: 1, createdAt: DateTime(2024, 1, 2)),
        FileModel(id: 3, folderId: 1, name: 'small.pdf',  path: '/tmp/small.pdf',  size: 1000, orderIndex: 2, createdAt: DateTime(2024, 1, 3)),
      ];
      await controller.loadFiles();
      controller.setSortMode(SortMode.size);
      final sizes = controller.displayFiles.map((f) => f.size).toList();
      expect(sizes, [3000, 2000, 1000]);
    });

    test('persists sort mode to settings', () {
      controller.setSortMode(SortMode.date);
      expect(storage.settings['sortMode_1'], 'date');
    });

    test('custom sort returns to original order', () {
      controller.setSortMode(SortMode.name);
      controller.setSortMode(SortMode.custom);
      // Custom preserves insertion order
      expect(controller.displayFiles.first.name, 'beta.pdf');
    });
  });

  // ── reorder ───────────────────────────────────────────────────────────────

  group('reorder', () {
    setUp(() async {
      storage.files = [_file(1, 'a.pdf'), _file(2, 'b.pdf'), _file(3, 'c.pdf')];
      await controller.loadFiles();
    });

    test('moves item from old to new index', () async {
      // Move 'a.pdf' (index 0) to end (index 3 → becomes 2 after adjustment)
      await controller.reorder(0, 3);
      expect(controller.displayFiles.map((f) => f.name).toList(),
          ['b.pdf', 'c.pdf', 'a.pdf']);
    });

    test('moves item forward', () async {
      // Move 'c.pdf' (index 2) to front (index 0)
      await controller.reorder(2, 0);
      expect(controller.displayFiles.first.name, 'c.pdf');
    });

    test('persists new order to storage', () async {
      await controller.reorder(0, 2);
      // storage.files is updated via updateFileOrder
      expect(storage.files.first.name, 'b.pdf');
    });

    test('rolls back when DB write fails', () async {
      storage.throwOnReorder = true;
      await controller.reorder(0, 3); // Optimistic move then DB throws → rollback
      expect(controller.displayFiles.map((f) => f.name).toList(),
          ['a.pdf', 'b.pdf', 'c.pdf']);
    });
  });

  // ── pickFile ──────────────────────────────────────────────────────────────

  group('pickFile', () {
    setUp(() async {
      await controller.loadFiles();
    });

    test('success returns PickResult.success with fileName', () async {
      final result = await controller.pickFile();
      expect(result.isSuccess, isTrue);
      expect(result.fileName, 'picked.pdf');
    });

    test('cancelled returns PickResult.cancelled', () async {
      fileService.pickBehavior = _PickBehavior.returnNull;
      final result = await controller.pickFile();
      expect(result.isCancelled, isTrue);
    });

    test('duplicate throws → returns PickResult.duplicate', () async {
      fileService.pickBehavior = _PickBehavior.throwDuplicate;
      final result = await controller.pickFile();
      expect(result.isDuplicate, isTrue);
    });

    test('generic error → returns PickResult.error', () async {
      fileService.pickBehavior = _PickBehavior.throwGeneric;
      final result = await controller.pickFile();
      expect(result.isError, isTrue);
    });

    test('isImporting is true during pick then false after', () async {
      bool sawImporting = false;
      controller.addListener(() {
        if (controller.isImporting) sawImporting = true;
      });
      await controller.pickFile();
      expect(sawImporting, isTrue);
      expect(controller.isImporting, isFalse);
    });

    test('isImporting resets to false even on error', () async {
      fileService.pickBehavior = _PickBehavior.throwGeneric;
      await controller.pickFile();
      expect(controller.isImporting, isFalse);
    });
  });

  // ── openFile ──────────────────────────────────────────────────────────────

  group('openFile', () {
    test('returns true on success', () async {
      final ok = await controller.openFile(_file(1, 'a.pdf'));
      expect(ok, isTrue);
    });

    test('returns false when file service throws', () async {
      fileService.openShouldThrow = true;
      final ok = await controller.openFile(_file(1, 'a.pdf'));
      expect(ok, isFalse);
    });
  });

  // ── shareFile ─────────────────────────────────────────────────────────────

  group('shareFile', () {
    test('returns true on success', () async {
      final ok = await controller.shareFile(_file(1, 'a.pdf'));
      expect(ok, isTrue);
    });

    test('returns false when file service throws', () async {
      fileService.shareShouldThrow = true;
      final ok = await controller.shareFile(_file(1, 'a.pdf'));
      expect(ok, isFalse);
    });
  });

  // ── renameFile ────────────────────────────────────────────────────────────

  group('renameFile', () {
    setUp(() async {
      storage.files = [_file(1, 'old.pdf')];
      await controller.loadFiles();
    });

    test('success returns RenameResult.success and reloads', () async {
      final result = await controller.renameFile(_file(1, 'old.pdf'), 'new');
      expect(result.isSuccess, isTrue);
    });

    test('duplicate returns RenameResult.duplicate', () async {
      fileService.renameIsDuplicate = true;
      final result = await controller.renameFile(_file(1, 'old.pdf'), 'existing');
      expect(result.isDuplicate, isTrue);
    });

    test('generic error returns RenameResult.error', () async {
      fileService.renameShouldThrow = true;
      final result = await controller.renameFile(_file(1, 'old.pdf'), 'new');
      expect(result.isError, isTrue);
    });
  });

  // ── deleteFile ────────────────────────────────────────────────────────────

  group('deleteFile', () {
    setUp(() async {
      storage.files = [_file(1, 'a.pdf'), _file(2, 'b.pdf')];
      await controller.loadFiles();
    });

    test('success returns true and reloads files', () async {
      final ok = await controller.deleteFile(_file(1, 'a.pdf'));
      expect(ok, isTrue);
    });

    test('returns false when file service throws', () async {
      fileService.deleteShouldThrow = true;
      final ok = await controller.deleteFile(_file(1, 'a.pdf'));
      expect(ok, isFalse);
    });
  });
}
