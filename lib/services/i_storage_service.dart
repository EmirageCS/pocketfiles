import '../models/file_model.dart';
import '../models/folder_model.dart';

/// Contract for all persistence operations.
/// [StorageService] is the production implementation; implement this for mocks in tests.
abstract class IStorageService {
  Future<int> insertFolder(FolderModel folder);
  Future<List<FolderModel>> getFolders();
  Future<Map<int, int>> getFileCounts();
  Future<Map<int, int>> getFileSizes();

  /// Returns files matching [query] across all folders, with their folder name.
  Future<List<({FileModel file, String folderName})>> searchFiles(String query);
  Future<void> deleteFolder(int id);
  Future<void> renameFolder(int id, String newName);
  Future<void> updateFolderLock(
    int id,
    bool isLocked,
    String? pin, {
    String? pinHint,
    String? securityQuestion,
    String? securityAnswer,
  });
  Future<void> updateFolderOrder(List<FolderModel> folders);
  Future<void> updateFolderColor(int id, String color);

  Future<int> insertFile(FileModel file);
  Future<List<FileModel>> getFiles(int folderId);
  Future<void> deleteFile(int id);
  Future<bool> fileExists(int folderId, String fileName);
  Future<int> getFileCount(int folderId);
  Future<void> updateFileOrder(List<FileModel> files);
  Future<void> renameFile(int id, String newName, String newPath);

  Future<String?> getSetting(String key);
  Future<void> setSetting(String key, String value);
  Future<bool> isOnboardingDone();
  Future<void> setOnboardingDone();

  Future<void> setMasterPin(String pin);
  Future<({String hash, String? salt})?> getMasterPinInfo();
  Future<int> incrementMasterPinAttempts();
  Future<void> resetMasterPinAttempts();

  /// Atomically logs a failed attempt and returns the updated recent-attempt
  /// info in a single transaction — prevents concurrent requests from bypassing
  /// the brute-force lockout check.
  Future<({int count, DateTime? lastAttempt})> logFailedAttemptAndGet(int folderId);
  Future<List<DateTime>> getFailedAttempts(int folderId);
  Future<({int count, DateTime? lastAttempt})> getRecentAttemptInfo(int folderId);
  Future<void> clearFailedAttempts(int folderId);
  Future<void> pruneOldFailedAttempts();
  Future<void> recordSuccessfulUnlock(int folderId);

  Future<void> migratePinToBcrypt(int folderId, String bcryptHash);
  Future<void> migrateAnswerToBcrypt(int folderId, String bcryptHash);
}
