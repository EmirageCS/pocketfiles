import '../models/file_model.dart';

/// Contract for file I/O operations.
/// [FileService] is the production implementation; implement this for mocks in tests.
abstract class IFileService {
  Future<FileModel?> pickAndSaveFile(int folderId, {bool deleteOriginal = false});

  /// Pick multiple files and save them to [folderId].
  /// Returns null if the user cancelled without selecting any file.
  Future<({List<FileModel> saved, int duplicates, int errors})?> pickAndSaveFiles(
    int folderId, {
    bool deleteOriginal = false,
  });

  Future<void> openFile(FileModel file);
  Future<void> shareFile(FileModel file);
  Future<FileModel> renameFile(FileModel file, String newBaseName);
  Future<void> deleteFile(FileModel file);
}
