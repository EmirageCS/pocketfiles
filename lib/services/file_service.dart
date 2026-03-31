import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../models/file_model.dart';
import '../utils/backup_excluder.dart';
import 'i_file_service.dart';
import 'storage_service.dart';

class FileAlreadyExistsException implements Exception {
  const FileAlreadyExistsException();
}

/// Thrown when the device does not have enough free space to import a file.
class StorageFullException implements Exception {
  const StorageFullException();
}

class FileService implements IFileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  final StorageService _storageService = StorageService();

  static const Map<String, IconData> _fileIcons = {
    // Documents
    '.pdf':  Icons.picture_as_pdf_rounded,
    '.doc':  Icons.description_rounded,
    '.docx': Icons.description_rounded,
    '.txt':  Icons.article_rounded,
    '.xlsx': Icons.table_chart_rounded,
    '.xls':  Icons.table_chart_rounded,
    '.pptx': Icons.slideshow_rounded,
    '.ppt':  Icons.slideshow_rounded,
    // Images
    '.jpg':  Icons.image_rounded,
    '.jpeg': Icons.image_rounded,
    '.png':  Icons.image_rounded,
    '.gif':  Icons.gif_box_rounded,
    '.webp': Icons.image_rounded,
    '.svg':  Icons.image_rounded,
    '.heic': Icons.image_rounded,
    '.heif': Icons.image_rounded,
    // Video
    '.mp4':  Icons.video_file_rounded,
    '.mov':  Icons.video_file_rounded,
    '.avi':  Icons.video_file_rounded,
    '.mkv':  Icons.video_file_rounded,
    '.wmv':  Icons.video_file_rounded,
    // Audio
    '.mp3':  Icons.audio_file_rounded,
    '.wav':  Icons.audio_file_rounded,
    '.aac':  Icons.audio_file_rounded,
    '.flac': Icons.audio_file_rounded,
    '.m4a':  Icons.audio_file_rounded,
    // Archives
    '.zip':  Icons.folder_zip_rounded,
    '.rar':  Icons.folder_zip_rounded,
    '.7z':   Icons.folder_zip_rounded,
    '.tar':  Icons.folder_zip_rounded,
  };

  @override
  Future<FileModel?> pickAndSaveFile(int folderId, {bool deleteOriginal = false}) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return null;

    final pickedFile = result.files.single;
    final sourcePath = pickedFile.path;
    if (sourcePath == null) return null; // picker returned bytes-only result (e.g. web)

    final exists = await _storageService.fileExists(folderId, pickedFile.name);
    if (exists) throw const FileAlreadyExistsException();

    final appDir = await getApplicationDocumentsDirectory();
    final foldersRoot = p.join(appDir.path, 'folders');
    final folderDir = Directory(p.join(foldersRoot, folderId.toString()));
    if (!await folderDir.exists()) {
      await folderDir.create(recursive: true);
    }
    // Exclude from iCloud/iTunes backup on iOS (idempotent; no-op on Android).
    // NSURLIsExcludedFromBackupKey on a directory is recursive — marking the
    // root 'folders/' once is enough to cover all current and future subdirs.
    await BackupExcluder.exclude(foldersRoot);

    final fileName = pickedFile.name;
    final destPath = p.join(folderDir.path, fileName);
    try {
      await File(sourcePath).copy(destPath);
    } on FileSystemException catch (e) {
      // errno 28 = ENOSPC (No space left on device)
      if (e.osError?.errorCode == 28 || e.message.contains('No space')) {
        throw const StorageFullException();
      }
      rethrow;
    }

    final fileSize = await File(destPath).length();

    final file = FileModel(
      folderId: folderId,
      name: fileName,
      path: destPath,
      size: fileSize,
      createdAt: DateTime.now(),
    );
    try {
      await _storageService.insertFile(file);
    } catch (_) {
      // DB insert failed — remove the copied file so it doesn't become an
      // orphan that wastes space and is invisible to the user.
      try { await File(destPath).delete(); } catch (_) {}
      rethrow;
    }

    // Delete original only after DB insert succeeds — prevents data loss if insert throws
    if (deleteOriginal) {
      final source = File(sourcePath);
      if (await source.exists()) await source.delete();
    }

    return file;
  }

  @override
  Future<({List<FileModel> saved, int duplicates, int errors})?> pickAndSaveFiles(
    int folderId, {
    bool deleteOriginal = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final foldersRoot = p.join(appDir.path, 'folders');
    final folderDir = Directory(p.join(foldersRoot, folderId.toString()));
    if (!await folderDir.exists()) {
      await folderDir.create(recursive: true);
    }
    await BackupExcluder.exclude(foldersRoot);

    final saved = <FileModel>[];
    int duplicates = 0;
    int errors = 0;

    for (final picked in result.files) {
      final sourcePath = picked.path;
      if (sourcePath == null) { errors++; continue; }
      try {
        final exists = await _storageService.fileExists(folderId, picked.name);
        if (exists) { duplicates++; continue; }

        final destPath = p.join(folderDir.path, picked.name);
        try {
          await File(sourcePath).copy(destPath);
        } on FileSystemException catch (e) {
          if (e.osError?.errorCode == 28 || e.message.contains('No space')) {
            errors++;
            break; // device is full — stop processing further files
          }
          rethrow;
        }

        final fileSize = await File(destPath).length();
        final file = FileModel(
          folderId: folderId,
          name: picked.name,
          path: destPath,
          size: fileSize,
          createdAt: DateTime.now(),
        );
        try {
          await _storageService.insertFile(file);
        } catch (_) {
          try { await File(destPath).delete(); } catch (_) {}
          errors++;
          continue;
        }

        if (deleteOriginal) {
          final source = File(sourcePath);
          if (await source.exists()) await source.delete();
        }

        saved.add(file);
      } catch (_) {
        errors++;
      }
    }

    return (saved: saved, duplicates: duplicates, errors: errors);
  }

  @override
  Future<void> openFile(FileModel file) async {
    await OpenFilex.open(file.path);
  }

  @override
  Future<void> shareFile(FileModel file) async {
    await Share.shareXFiles([XFile(file.path)], text: file.name);
  }

  @override
  Future<FileModel> renameFile(FileModel file, String newBaseName) async {
    final ext = p.extension(file.name);
    final fullName = newBaseName.trim() + ext;
    if (fullName == file.name) return file;

    final exists = await _storageService.fileExists(file.folderId, fullName);
    if (exists) throw const FileAlreadyExistsException();

    final newPath = p.join(p.dirname(file.path), fullName);
    await File(file.path).rename(newPath);
    try {
      await _storageService.renameFile(file.id!, fullName, newPath);
    } catch (e) {
      // DB update failed — roll back the disk rename to keep state consistent.
      try {
        await File(newPath).rename(file.path);
      } catch (rollbackError) {
        // Rollback also failed: disk has new name, DB has old name.
        // Log so the inconsistency is visible in crash reports.
        debugPrint('renameFile rollback failed: $rollbackError '
            '(disk="$fullName", db="${file.name}") — state inconsistent');
      }
      rethrow;
    }

    return file.copyWith(name: fullName, path: newPath);
  }

  @override
  Future<void> deleteFile(FileModel file) async {
    // Delete from disk first: if this fails the user still sees the file
    // and can retry. Deleting DB first would leave an invisible orphan on disk.
    final fileOnDisk = File(file.path);
    if (await fileOnDisk.exists()) {
      await fileOnDisk.delete();
    }
    await _storageService.deleteFile(file.id!);
  }

  static IconData getFileIcon(String fileName) {
    final ext = getFileExtension(fileName);
    return _fileIcons[ext] ?? Icons.insert_drive_file_rounded;
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String formatDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  static String formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${formatDate(dt)} $h:$min';
  }

  static String getFileExtension(String fileName) {
    return p.extension(fileName).toLowerCase();
  }

  static String getFileBaseName(String fileName) {
    return p.basenameWithoutExtension(fileName);
  }
}
