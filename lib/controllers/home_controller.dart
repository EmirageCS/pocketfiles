import 'package:flutter/foundation.dart';
import '../models/folder_model.dart';
import '../services/i_storage_service.dart';
import '../utils/constants.dart';

/// Manages all state and business logic for the home (folder list) screen.
/// The screen observes this controller via [ChangeNotifier] and rebuilds
/// only when [notifyListeners] is called — it never calls storage directly.
class HomeController extends ChangeNotifier {
  final IStorageService _storage;

  List<FolderModel> _folders = [];
  List<FolderModel> _filteredFolders = [];
  Map<int, int> _fileCounts = {};
  Map<int, int> _fileSizes  = {};
  bool _isLoading = true;
  bool _isEditMode = false;
  final Set<int> _unlockedFolders = {};
  String _searchQuery = '';
  FolderSortMode _sortMode = FolderSortMode.custom;

  HomeController(this._storage);

  List<FolderModel> get folders          => List.unmodifiable(_folders);
  List<FolderModel> get filteredFolders  => List.unmodifiable(_filteredFolders);
  Map<int, int>     get fileCounts       => Map.unmodifiable(_fileCounts);
  Map<int, int>     get fileSizes        => Map.unmodifiable(_fileSizes);
  bool              get isLoading        => _isLoading;
  bool              get isEditMode       => _isEditMode;
  FolderSortMode    get sortMode         => _sortMode;

  /// Returns true if the folder with [id] has been unlocked this session.
  bool isFolderUnlocked(int id) => _unlockedFolders.contains(id);

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Returns true if onboarding should be shown (i.e. first launch).
  Future<bool> checkAndMarkOnboardingDone() async {
    final done = await _storage.isOnboardingDone();
    if (!done) await _storage.setOnboardingDone();
    return !done;
  }

  // ---------------------------------------------------------------------------
  // Folder list state
  // ---------------------------------------------------------------------------

  /// Loads the persisted folder sort mode from storage.
  Future<void> loadSortMode() async {
    final saved = await _storage.getSetting(StorageKeys.folderSortMode);
    _sortMode = FolderSortMode.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => FolderSortMode.custom,
    );
  }

  /// Fetches folders and file counts from storage.
  /// Pass [showLoading] = true on first load to show the spinner.
  Future<void> loadFolders({bool showLoading = false}) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _folders    = await _storage.getFolders();
      _fileCounts = await _storage.getFileCounts();
      _fileSizes  = await _storage.getFileSizes();
      _applySearch(_searchQuery);
    } catch (e, stack) {
      debugPrint('loadFolders error: $e\n$stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filters [filteredFolders] to those whose names contain [query].
  void applySearch(String query) {
    _searchQuery = query.toLowerCase();
    _applySearch(_searchQuery);
    notifyListeners();
  }

  void _applySearch(String query) {
    var list = query.isEmpty
        ? List<FolderModel>.from(_folders)
        : _folders.where((f) => f.name.toLowerCase().contains(query)).toList();
    if (_sortMode == FolderSortMode.name) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortMode == FolderSortMode.date) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    _filteredFolders = list;
  }

  /// Changes folder sort mode, re-applies filter, and persists the choice.
  void setSortMode(FolderSortMode mode) {
    _sortMode = mode;
    _applySearch(_searchQuery);
    notifyListeners();
    _storage.setSetting(StorageKeys.folderSortMode, mode.name)
        .catchError((e) => debugPrint('setSortMode persist failed: $e'));
  }

  // ---------------------------------------------------------------------------
  // Edit mode
  // ---------------------------------------------------------------------------

  /// Enters edit mode, clears the active search, and shows all folders.
  void enterEditMode() {
    _isEditMode  = true;
    _searchQuery = '';
    _filteredFolders = List<FolderModel>.from(_folders);
    notifyListeners();
  }

  /// Exits edit mode without clearing the folder list.
  void exitEditMode() {
    _isEditMode = false;
    notifyListeners();
  }

  /// Locks all folders and exits edit mode — called when app goes to background.
  void lockAll() {
    _unlockedFolders.clear();
    _isEditMode = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Reordering
  // ---------------------------------------------------------------------------

  /// Moves a folder from [oldIndex] to [newIndex] and persists the new order.
  Future<void> reorder(int oldIndex, int newIndex) async {
    // ReorderableListView reports newIndex after removing the dragged item,
    // so when moving an item forward we must subtract 1 to get the true target.
    if (newIndex > oldIndex) newIndex -= 1;
    final previous = List<FolderModel>.from(_folders); // keep for rollback
    final mutable  = List<FolderModel>.from(_filteredFolders);
    final folder   = mutable.removeAt(oldIndex);
    mutable.insert(newIndex, folder);
    _folders = mutable;
    // Re-apply search so _filteredFolders stays consistent with _folders.
    // enterEditMode() always clears the query, so this is effectively a copy,
    // but calling _applySearch makes the contract explicit and future-safe.
    _applySearch(_searchQuery);
    notifyListeners();
    try {
      await _storage.updateFolderOrder(_folders);
    } catch (e, stack) {
      debugPrint('reorder persist failed — rolling back: $e\n$stack');
      _folders = previous;
      _applySearch(_searchQuery);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Unlock tracking
  // ---------------------------------------------------------------------------

  /// Marks [folderId] as unlocked for the current session.
  void markUnlocked(int folderId) {
    _unlockedFolders.add(folderId);
  }

  // ---------------------------------------------------------------------------
  // Opening a folder (returns failed attempts to show in SecurityAlertDialog)
  // ---------------------------------------------------------------------------

  /// Retrieves failed-attempt timestamps for a locked folder, then clears them.
  /// Returns an empty list if the folder is not locked.
  Future<List<DateTime>> prepareOpenFolder(FolderModel folder) async {
    if (!folder.isLocked) return const [];
    final attempts = await _storage.getFailedAttempts(folder.id!);
    await _storage.recordSuccessfulUnlock(folder.id!);
    await _storage.clearFailedAttempts(folder.id!);
    return attempts;
  }

  // ---------------------------------------------------------------------------
  // CRUD — called by dialogs in the screen
  // ---------------------------------------------------------------------------

  /// Inserts [folder] into storage and reloads the folder list.
  Future<void> addFolder(FolderModel folder) async {
    await _storage.insertFolder(folder);
    await loadFolders();
  }

  /// Renames the folder with [id] to [name] and reloads.
  Future<void> renameFolder(int id, String name) async {
    await _storage.renameFolder(id, name);
    await loadFolders();
  }

  /// Deletes the folder with [id] and reloads.
  Future<void> deleteFolder(int id) async {
    await _storage.deleteFolder(id);
    await loadFolders();
  }

  /// Updates the accent color of folder [id] and reloads.
  Future<void> updateFolderColor(int id, String color) async {
    await _storage.updateFolderColor(id, color);
    await loadFolders();
  }

  /// Removes the PIN lock from folder [id], clears its unlocked state, and reloads.
  Future<void> removeFolderLock(int id) async {
    await _storage.updateFolderLock(id, false, null);
    _unlockedFolders.remove(id);
    await loadFolders();
  }
}
