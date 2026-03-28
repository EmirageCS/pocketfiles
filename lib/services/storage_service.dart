import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/folder_model.dart';
import '../models/file_model.dart';
import '../utils/constants.dart';
import '../utils/pin_hasher.dart';
import 'i_storage_service.dart';

/// SQLite-backed singleton that owns all read/write access to the app database.
///
/// Responsibilities are split by domain:
/// - **Folders**: CRUD, color, PIN lock, ordering
/// - **Files**: CRUD, ordering, duplicate detection
/// - **Settings**: key/value store for preferences and master PIN
/// - **Security**: failed-attempt logging, lockout queries, bcrypt migration
///
/// All destructive folder operations run inside transactions so partial
/// failures leave no orphaned rows.  Disk deletion (which cannot be rolled
/// back) is performed after the transaction commits.
class StorageService implements IStorageService {
  static Database? _database;
  static Future<Database>? _openFuture;
  static final StorageService _instance = StorageService._internal();
  // ignore: prefer_final_fields
  static String? _databasePathOverride; // test-only: override DB path

  factory StorageService() => _instance;
  StorageService._internal();

  /// Overrides the database path used by [_initDatabase].
  /// Call with [inMemoryDatabasePath] in tests to use an in-memory database.
  // ignore: invalid_use_of_visible_for_testing_member
  static void setDatabasePathForTesting(String path) {
    _databasePathOverride = path;
  }

  /// Closes and discards the current database so the next [database] access
  /// opens a fresh connection. Must be called between tests.
  static Future<void> resetForTesting() async {
    await _database?.close();
    _database = null;
    _openFuture = null;
    _databasePathOverride = null;
  }

  /// Returns the singleton database, initialising it on the first call.
  /// Concurrent callers share the same init future so [_initDatabase] is
  /// never invoked more than once even if multiple awaits race at startup.
  Future<Database> get database {
    if (_database != null) return Future.value(_database!);
    return _openFuture ??= _initDatabase().then((db) => _database = db);
  }

  Future<Database> _initDatabase() async {
    final path = _databasePathOverride ?? join(await getDatabasesPath(), 'pocketfiles.db');

    return await openDatabase(
      path,
      version: 8,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE folders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            color TEXT NOT NULL,
            isLocked INTEGER NOT NULL DEFAULT 0,
            pin TEXT,
            pinSalt TEXT,
            pinHint TEXT,
            securityQuestion TEXT,
            securityAnswer TEXT,
            answerSalt TEXT,
            orderIndex INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL,
            lastUnlockedAt TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            folderId INTEGER NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            path TEXT NOT NULL,
            size INTEGER NOT NULL DEFAULT 0,
            orderIndex INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE failed_attempts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            folderId INTEGER NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
            attemptedAt TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_files_folder ON files(folderId)');
        await db.execute(
            'CREATE INDEX idx_attempts_folder_time ON failed_attempts(folderId, attemptedAt)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE folders ADD COLUMN isLocked INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE folders ADD COLUMN pin TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE folders ADD COLUMN pinHint TEXT');
          await db.execute(
              'ALTER TABLE folders ADD COLUMN securityQuestion TEXT');
          await db.execute(
              'ALTER TABLE folders ADD COLUMN securityAnswer TEXT');
        }
        if (oldVersion < 4) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS failed_attempts (id INTEGER PRIMARY KEY AUTOINCREMENT, folderId INTEGER NOT NULL, attemptedAt TEXT NOT NULL)');
          await db.execute(
              'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)');
        }
        if (oldVersion < 5) {
          await db.execute(
              'ALTER TABLE files ADD COLUMN orderIndex INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 6) {
          await db.execute(
              'ALTER TABLE folders ADD COLUMN orderIndex INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 7) {
          await db.execute('ALTER TABLE folders ADD COLUMN pinSalt TEXT');
          await db.execute('ALTER TABLE folders ADD COLUMN answerSalt TEXT');
          await db.execute('ALTER TABLE folders ADD COLUMN lastUnlockedAt TEXT');
        }
        if (oldVersion < 8) {
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_files_folder ON files(folderId)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_attempts_folder_time ON failed_attempts(folderId, attemptedAt)');
        }
      },
    );
  }

  /// Inserts [folder] and assigns it the next available [orderIndex].
  @override
  Future<int> insertFolder(FolderModel folder) async {
    final db = await database;
    final count = await _getFolderCount();
    final folderWithOrder = FolderModel(
      name: folder.name,
      color: folder.color,
      createdAt: folder.createdAt,
      orderIndex: count,
    );
    return await db.insert('folders', folderWithOrder.toMap());
  }

  Future<int> _getFolderCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM folders');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<List<FolderModel>> getFolders() async {
    final db = await database;
    final maps = await db.query('folders', orderBy: 'orderIndex ASC');
    return maps.map((map) => FolderModel.fromMap(map)).toList();
  }

  /// Returns a map of `folderId → fileCount` in a single aggregation query,
  /// avoiding the N+1 problem that would arise from fetching counts per folder.
  @override
  Future<Map<int, int>> getFileCounts() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT folderId, COUNT(*) as count FROM files GROUP BY folderId');
    return {
      for (final row in result) row['folderId'] as int: row['count'] as int,
    };
  }

  /// Deletes the folder, its files, and its failed-attempt records atomically,
  /// then removes the folder's directory from disk.
  /// Searches file names across all folders, joining with folder names.
  @override
  Future<List<({FileModel file, String folderName})>> searchFiles(
      String query) async {
    final db = await database;
    final q = '%${query.toLowerCase()}%';
    final rows = await db.rawQuery('''
      SELECT f.*, folders.name AS folderName
      FROM files f
      JOIN folders ON folders.id = f.folderId
      WHERE LOWER(f.name) LIKE ?
      ORDER BY f.name ASC
    ''', [q]);
    return rows.map((r) {
      final folderName = r['folderName'] as String;
      final fileMap = Map<String, Object?>.from(r)..remove('folderName');
      return (file: FileModel.fromMap(fileMap), folderName: folderName);
    }).toList();
  }

  /// Returns a map of `folderId → totalSize` (bytes) in a single aggregation query.
  @override
  Future<Map<int, int>> getFileSizes() async {
    final db = await database;
    final result = await db
        .rawQuery('SELECT folderId, SUM(size) as total FROM files GROUP BY folderId');
    return {
      for (final row in result) row['folderId'] as int: (row['total'] as int? ?? 0),
    };
  }

  @override
  Future<void> deleteFolder(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('failed_attempts',
          where: 'folderId = ?', whereArgs: [id]);
      await txn.delete('files', where: 'folderId = ?', whereArgs: [id]);
      await txn.delete('folders', where: 'id = ?', whereArgs: [id]);
    });
    // Disk deletion is outside the transaction — it can't be rolled back
    final appDir = await getApplicationDocumentsDirectory();
    final folderDir = Directory(join(appDir.path, 'folders', id.toString()));
    if (await folderDir.exists()) {
      await folderDir.delete(recursive: true);
    }
  }

  @override
  Future<void> renameFolder(int id, String newName) async {
    final db = await database;
    await db.update('folders', {'name': newName},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Enables or disables the PIN lock on a folder, hashing [pin] and
  /// [securityAnswer] with bcrypt before storing.  Pass `null` for both to
  /// clear security fields when removing the lock.
  @override
  Future<void> updateFolderLock(
    int id,
    bool isLocked,
    String? pin, {
    String? pinHint,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    final db = await database;
    String? hashedPin, hashedAnswer;

    if (pin != null) {
      hashedPin = await PinHasher.hash(pin);
    }
    if (securityAnswer != null) {
      hashedAnswer = await PinHasher.hash(securityAnswer);
    }

    await db.update(
      'folders',
      {
        'isLocked': isLocked ? 1 : 0,
        'pin': hashedPin,
        'pinSalt': null, // bcrypt embeds salt
        'pinHint': pinHint,
        'securityQuestion': securityQuestion,
        'securityAnswer': hashedAnswer,
        'answerSalt': null, // bcrypt embeds salt
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateFolderOrder(List<FolderModel> folders) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < folders.length; i++) {
      batch.update('folders', {'orderIndex': i},
          where: 'id = ?', whereArgs: [folders[i].id]);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> updateFolderColor(int id, String color) async {
    final db = await database;
    await db.update('folders', {'color': color},
        where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> insertFile(FileModel file) async {
    final db = await database;
    final count = await getFileCount(file.folderId);
    final fileWithOrder = FileModel(
      folderId: file.folderId,
      name: file.name,
      path: file.path,
      size: file.size,
      orderIndex: count,
      createdAt: file.createdAt,
    );
    return await db.insert('files', fileWithOrder.toMap());
  }

  @override
  Future<List<FileModel>> getFiles(int folderId) async {
    final db = await database;
    final maps = await db.query('files',
        where: 'folderId = ?',
        whereArgs: [folderId],
        orderBy: 'orderIndex ASC');
    return maps.map((map) => FileModel.fromMap(map)).toList();
  }

  @override
  Future<void> deleteFile(int id) async {
    final db = await database;
    await db.delete('files', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<bool> fileExists(int folderId, String fileName) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT 1 FROM files WHERE folderId = ? AND name = ? LIMIT 1',
      [folderId, fileName],
    );
    return result.isNotEmpty;
  }

  @override
  Future<int> getFileCount(int folderId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM files WHERE folderId = ?', [folderId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<void> updateFileOrder(List<FileModel> files) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < files.length; i++) {
      batch.update('files', {'orderIndex': i},
          where: 'id = ?', whereArgs: [files[i].id]);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> renameFile(int id, String newName, String newPath) async {
    final db = await database;
    await db.update('files', {'name': newName, 'path': newPath},
        where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> isOnboardingDone() async {
    final db = await database;
    final result = await db.query('settings',
        where: 'key = ?', whereArgs: [StorageKeys.onboardingDone]);
    return result.isNotEmpty;
  }

  @override
  Future<void> setOnboardingDone() async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': StorageKeys.onboardingDone, 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Stores the bcrypt hash of [pin] as the master PIN and removes any
  /// legacy salt row.  Written atomically via a batch operation.
  @override
  Future<void> setMasterPin(String pin) async {
    final db = await database;
    final hash = await PinHasher.hash(pin);
    final batch = db.batch();
    batch.insert(
      'settings',
      {'key': StorageKeys.masterPin, 'value': hash},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Remove legacy salt — bcrypt no longer needs a separate column
    batch.delete('settings',
        where: 'key = ?', whereArgs: [StorageKeys.masterPinSalt]);
    await batch.commit(noResult: true);
  }

  @override
  Future<({String hash, String? salt})?> getMasterPinInfo() async {
    final db = await database;
    final result = await db.query('settings',
        where: 'key = ? OR key = ?',
        whereArgs: [StorageKeys.masterPin, StorageKeys.masterPinSalt]);
    if (result.isEmpty) return null;
    String? hash, salt;
    for (final row in result) {
      if (row['key'] == StorageKeys.masterPin) hash = row['value'] as String?;
      if (row['key'] == StorageKeys.masterPinSalt) salt = row['value'] as String?;
    }
    if (hash == null) return null;
    return (hash: hash, salt: salt);
  }

  @override
  Future<int> incrementMasterPinAttempts() async {
    final db = await database;
    // Wrapped in a transaction so that concurrent wrong-PIN submissions
    // cannot both read the same counter value and undercount attempts.
    return db.transaction<int>((txn) async {
      final result = await txn.query('settings',
          where: 'key = ?', whereArgs: [StorageKeys.masterPinAttempts]);
      final current = result.isEmpty
          ? 0
          : int.tryParse(result.first['value'] as String? ?? '') ?? 0;
      final newCount = current + 1;
      await txn.insert(
        'settings',
        {'key': StorageKeys.masterPinAttempts, 'value': newCount.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return newCount;
    });
  }

  @override
  Future<void> resetMasterPinAttempts() async {
    final db = await database;
    await db.delete('settings',
        where: 'key = ?', whereArgs: [StorageKeys.masterPinAttempts]);
  }

  /// Inserts a failed attempt and returns the updated recent-attempt count
  /// inside a single transaction — prevents two simultaneous wrong-PIN
  /// submissions from racing past the lockout threshold.
  @override
  Future<({int count, DateTime? lastAttempt})> logFailedAttemptAndGet(
      int folderId) async {
    final db = await database;
    return db.transaction<({int count, DateTime? lastAttempt})>((txn) async {
      await txn.insert('failed_attempts', {
        'folderId': folderId,
        'attemptedAt': DateTime.now().toIso8601String(),
      });
      final cutoff = DateTime.now()
          .subtract(const Duration(seconds: kLockoutSeconds))
          .toIso8601String();
      final result = await txn.rawQuery(
        'SELECT COUNT(*) as count, MAX(attemptedAt) as last '
        'FROM failed_attempts WHERE folderId = ? AND attemptedAt > ?',
        [folderId, cutoff],
      );
      final count    = Sqflite.firstIntValue(result) ?? 0;
      final lastStr  = result.isNotEmpty ? result.first['last'] as String? : null;
      DateTime? lastAttempt;
      if (lastStr != null) {
        try {
          lastAttempt = DateTime.parse(lastStr);
        } catch (_) {
          // Malformed timestamp in DB — treat as no recent attempt so the
          // lockout window is not enforced on corrupt data.
        }
      }
      return (count: count, lastAttempt: lastAttempt);
    });
  }

  /// Returns all failed attempts for [folderId] that occurred *after* the
  /// last successful unlock.  A single JOIN avoids a separate round-trip to
  /// fetch the last-unlock timestamp.
  @override
  Future<List<DateTime>> getFailedAttempts(int folderId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT fa.attemptedAt FROM failed_attempts fa
      LEFT JOIN folders f ON f.id = fa.folderId
      WHERE fa.folderId = ?
        AND (f.lastUnlockedAt IS NULL OR fa.attemptedAt > f.lastUnlockedAt)
      ORDER BY fa.attemptedAt DESC
    ''', [folderId]);
    final dates = <DateTime>[];
    for (final r in result) {
      try {
        dates.add(DateTime.parse(r['attemptedAt'] as String));
      } catch (_) {
        // Skip malformed timestamps — don't crash the security alert screen.
      }
    }
    return dates;
  }

  /// Returns the number of failed attempts within the lockout window and the
  /// timestamp of the most recent one — both in a single aggregation query.
  @override
  Future<({int count, DateTime? lastAttempt})> getRecentAttemptInfo(
      int folderId) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(const Duration(seconds: kLockoutSeconds))
        .toIso8601String();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count, MAX(attemptedAt) as last FROM failed_attempts WHERE folderId = ? AND attemptedAt > ?',
      [folderId, cutoff],
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    final lastStr = result.isNotEmpty ? result.first['last'] as String? : null;
    DateTime? lastAttempt;
    if (lastStr != null) {
      try {
        lastAttempt = DateTime.parse(lastStr);
      } catch (_) {
        // Malformed timestamp in DB — treat as no recent attempt.
      }
    }
    return (count: count, lastAttempt: lastAttempt);
  }

  @override
  Future<void> clearFailedAttempts(int folderId) async {
    final db = await database;
    await db.delete('failed_attempts',
        where: 'folderId = ?', whereArgs: [folderId]);
  }

  @override
  Future<void> pruneOldFailedAttempts() async {
    final db = await database;
    final cutoff =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    await db.delete('failed_attempts',
        where: 'attemptedAt < ?', whereArgs: [cutoff]);
  }

  @override
  Future<void> recordSuccessfulUnlock(int folderId) async {
    final db = await database;
    await db.update(
      'folders',
      {'lastUnlockedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }

  // Transparent migration: rehash legacy SHA-256 PIN to bcrypt in-place
  @override
  Future<void> migratePinToBcrypt(int folderId, String bcryptHash) async {
    final db = await database;
    await db.update(
      'folders',
      {'pin': bcryptHash, 'pinSalt': null},
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }

  // Transparent migration: rehash legacy SHA-256 answer to bcrypt in-place
  @override
  Future<void> migrateAnswerToBcrypt(int folderId, String bcryptHash) async {
    final db = await database;
    await db.update(
      'folders',
      {'securityAnswer': bcryptHash, 'answerSalt': null},
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }
}
