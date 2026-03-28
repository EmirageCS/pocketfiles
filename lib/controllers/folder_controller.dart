import 'package:flutter/foundation.dart';
import '../models/file_model.dart';
import '../models/folder_model.dart';
import '../services/file_service.dart' show FileAlreadyExistsException, StorageFullException;
import '../services/i_file_service.dart';
import '../services/i_storage_service.dart';
import '../utils/constants.dart';

/// Sort mode for files within a folder.
enum SortMode { custom, name, size, date }

// ---------------------------------------------------------------------------
// Typed result objects — avoids string-based error checking in the UI layer
// ---------------------------------------------------------------------------

enum _PickStatus { success, cancelled, duplicate, storageFull, error }

/// Result of a [FolderController.pickFile] call.
///
/// | Status | Meaning |
/// |--------|---------|
/// | `success` | File imported; [fileName] holds the stored name. |
/// | `cancelled` | User dismissed the picker without selecting a file. |
/// | `duplicate` | A file with the same name already exists in this folder. |
/// | `storageFull` | Device has insufficient free space (ENOSPC). |
/// | `error` | Any other I/O or DB error. |
class PickResult {
  final _PickStatus _status;
  final String? fileName;

  const PickResult._(_PickStatus status, {this.fileName}) : _status = status;

  const PickResult.success(String name) : this._(_PickStatus.success, fileName: name);
  const PickResult.cancelled()         : this._(_PickStatus.cancelled);
  const PickResult.duplicate()         : this._(_PickStatus.duplicate);
  const PickResult.storageFull()       : this._(_PickStatus.storageFull);
  const PickResult.error()             : this._(_PickStatus.error);

  bool get isSuccess     => _status == _PickStatus.success;
  bool get isCancelled   => _status == _PickStatus.cancelled;
  bool get isDuplicate   => _status == _PickStatus.duplicate;
  bool get isStorageFull => _status == _PickStatus.storageFull;
  bool get isError       => _status == _PickStatus.error;
}

/// Result of a [FolderController.pickFiles] (multi-select) call.
class MultiPickResult {
  final int success;
  final int duplicates;
  final int errors;
  final bool cancelled;

  const MultiPickResult._({
    this.success = 0,
    this.duplicates = 0,
    this.errors = 0,
    this.cancelled = false,
  });

  const MultiPickResult.cancelled() : this._(cancelled: true);
  const MultiPickResult.done({
    required int success,
    required int duplicates,
    required int errors,
  }) : this._(success: success, duplicates: duplicates, errors: errors);

  bool get isCancelled => cancelled;
}

enum _RenameStatus { success, duplicate, error }

/// Result of a [FolderController.renameFile] call.
///
/// | Status | Meaning |
/// |--------|---------|
/// | `success` | File renamed on disk and in DB. |
/// | `duplicate` | A file with the new name already exists in this folder. |
/// | `error` | Any other I/O or DB error. |
class RenameResult {
  final _RenameStatus _status;

  const RenameResult._(_RenameStatus status) : _status = status;

  const RenameResult.success()   : this._(_RenameStatus.success);
  const RenameResult.duplicate() : this._(_RenameStatus.duplicate);
  const RenameResult.error()     : this._(_RenameStatus.error);

  bool get isSuccess   => _status == _RenameStatus.success;
  bool get isDuplicate => _status == _RenameStatus.duplicate;
  bool get isError     => _status == _RenameStatus.error;
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Manages all state and business logic for the folder detail screen.
/// The screen observes this controller and handles only UI (dialogs, snackbars,
/// navigation) — it never calls storage or file services directly.
class FolderController extends ChangeNotifier {
  final FolderModel folder;
  final IStorageService _storage;
  final IFileService _fileService;

  List<FileModel> _files       = [];
  List<FileModel> _displayFiles = [];
  String   _searchQuery = '';
  bool     _isLoading   = true;
  bool     _isImporting = false;
  SortMode _sortBy      = SortMode.custom;

  FolderController(this.folder, this._storage, this._fileService);

  List<FileModel> get files        => List.unmodifiable(_files);
  List<FileModel> get displayFiles => List.unmodifiable(_displayFiles);
  String   get searchQuery => _searchQuery;
  bool     get isLoading   => _isLoading;
  bool     get isImporting => _isImporting;
  SortMode get sortBy      => _sortBy;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Load sort preference then files. Call once from [initState].
  Future<void> init() async {
    await _loadSortMode();
    await loadFiles();
  }

  Future<void> _loadSortMode() async {
    final saved = await _storage.getSetting(StorageKeys.sortMode(folder.id!));
    _sortBy = SortMode.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => SortMode.custom,
    );
  }

  // ---------------------------------------------------------------------------
  // File list state
  // ---------------------------------------------------------------------------

  /// Fetches files for this folder from storage and re-applies the current sort.
  Future<void> loadFiles() async {
    _isLoading = true;
    notifyListeners();
    try {
      _files = await _storage.getFiles(folder.id!);
      _applySort();
    } catch (e, stack) {
      debugPrint('loadFiles error: $e\n$stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filters [displayFiles] to those whose names contain [query].
  void applySearch(String query) {
    _searchQuery = query.toLowerCase();
    _applySort();
    notifyListeners();
  }

  /// Changes the sort mode, re-sorts [displayFiles], and persists the choice.
  void setSortMode(SortMode mode) {
    _sortBy = mode;
    _applySort();
    notifyListeners();
    _storage.setSetting(StorageKeys.sortMode(folder.id!), mode.name)
        .catchError((e) => debugPrint('setSortMode persist failed: $e'));
  }

  void _applySort() {
    final filtered = _searchQuery.isEmpty
        ? [..._files]
        : _files.where((f) => f.name.toLowerCase().contains(_searchQuery)).toList();

    if (_sortBy == SortMode.custom) {
      _displayFiles = filtered;
      return;
    }
    final sorted = [...filtered];
    switch (_sortBy) {
      case SortMode.name:
        sorted.sort((a, b) => a.name.compareTo(b.name));
      case SortMode.size:
        sorted.sort((a, b) => b.size.compareTo(a.size));
      case SortMode.date:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SortMode.custom:
        break;
    }
    _displayFiles = sorted;
  }

  // ---------------------------------------------------------------------------
  // Reordering
  // ---------------------------------------------------------------------------

  /// Moves a file from [oldIndex] to [newIndex] and persists the new order.
  Future<void> reorder(int oldIndex, int newIndex) async {
    // Reordering only makes sense in custom mode — other modes derive their
    // order from file properties, so allowing drag-reorder would silently
    // corrupt the stored custom order.
    if (_sortBy != SortMode.custom) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final previous = List<FileModel>.from(_files); // keep for rollback
    final mutable  = List<FileModel>.from(_files);
    final file     = mutable.removeAt(oldIndex);
    mutable.insert(newIndex, file);
    _files = mutable;
    _applySort(); // re-applies search filter so displayFiles stays consistent
    notifyListeners();
    try {
      await _storage.updateFileOrder(_files);
    } catch (e, stack) {
      debugPrint('reorder persist failed — rolling back: $e\n$stack');
      _files = previous;
      _applySort();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // File operations — return typed results so the screen can react without
  // catching exceptions or inspecting error strings
  // ---------------------------------------------------------------------------

  /// Opens the system file picker, imports the selected file, and reloads.
  /// Pass [deleteOriginal] = true to remove the source after a successful import.
  Future<PickResult> pickFile({bool deleteOriginal = false}) async {
    _isImporting = true;
    notifyListeners();
    try {
      final file = await _fileService.pickAndSaveFile(
        folder.id!,
        deleteOriginal: deleteOriginal,
      );
      if (file == null) return const PickResult.cancelled();
      await loadFiles();
      return PickResult.success(file.name);
    } on FileAlreadyExistsException {
      return const PickResult.duplicate();
    } on StorageFullException {
      return const PickResult.storageFull();
    } catch (e, stack) {
      debugPrint('pickFile error: $e\n$stack');
      return const PickResult.error();
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  /// Opens the system file picker in multi-select mode, imports all selected
  /// files, and reloads. Pass [deleteOriginal] = true to remove sources after
  /// a successful import.
  Future<MultiPickResult> pickFiles({bool deleteOriginal = false}) async {
    _isImporting = true;
    notifyListeners();
    try {
      final result = await _fileService.pickAndSaveFiles(
        folder.id!,
        deleteOriginal: deleteOriginal,
      );
      if (result == null) return const MultiPickResult.cancelled();
      if (result.saved.isNotEmpty) await loadFiles();
      return MultiPickResult.done(
        success: result.saved.length,
        duplicates: result.duplicates,
        errors: result.errors,
      );
    } catch (e, stack) {
      debugPrint('pickFiles error: $e\n$stack');
      return const MultiPickResult.done(success: 0, duplicates: 0, errors: 1);
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  /// Opens [file] with the device's default app. Returns false on failure.
  Future<bool> openFile(FileModel file) async {
    try {
      await _fileService.openFile(file);
      return true;
    } catch (e, stack) {
      debugPrint('openFile error: $e\n$stack');
      return false;
    }
  }

  /// Shares [file] via the system share sheet. Returns false on failure.
  Future<bool> shareFile(FileModel file) async {
    try {
      await _fileService.shareFile(file);
      return true;
    } catch (e, stack) {
      debugPrint('shareFile error: $e\n$stack');
      return false;
    }
  }

  /// Renames [file] to [newBaseName] (without extension) and reloads.
  Future<RenameResult> renameFile(FileModel file, String newBaseName) async {
    try {
      await _fileService.renameFile(file, newBaseName);
      await loadFiles();
      return const RenameResult.success();
    } on FileAlreadyExistsException {
      return const RenameResult.duplicate();
    } catch (e, stack) {
      debugPrint('renameFile error: $e\n$stack');
      return const RenameResult.error();
    }
  }

  /// Deletes [file] from disk and storage, then reloads. Returns false on failure.
  Future<bool> deleteFile(FileModel file) async {
    try {
      await _fileService.deleteFile(file);
      await loadFiles();
      return true;
    } catch (e, stack) {
      debugPrint('deleteFile error: $e\n$stack');
      return false;
    }
  }
}
