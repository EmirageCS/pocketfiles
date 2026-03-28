import 'dart:async';
import 'package:flutter/material.dart';
import 'package:reorderable_grid/reorderable_grid.dart';
import '../controllers/home_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/folder_model.dart';
import '../services/storage_service.dart';
import '../widgets/color_palette_picker.dart';
import '../widgets/folder_card.dart';
import '../widgets/pin_dialogs.dart';
import '../widgets/security_alert_dialog.dart';
import '../widgets/help_sheet.dart';
import '../widgets/dialogs/rename_folder_dialog.dart';
import '../widgets/dialogs/change_color_dialog.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'folder_detail_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  final ThemeController themeController;

  const HomeScreen({super.key, required this.themeController});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final HomeController _controller;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _controller = HomeController(StorageService())
      ..addListener(_onControllerUpdate)
      ..loadFolders(showLoading: true);
    _checkOnboarding();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _checkOnboarding() async {
    final shouldShow = await _controller.checkAndMarkOnboardingDone();
    if (shouldShow && mounted) HelpSheet.show(context);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _controller
      ..removeListener(_onControllerUpdate)
      ..dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _controller.lockAll();
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: kSearchDebounceMs), () {
      if (mounted) _controller.applySearch(_searchController.text);
    });
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _newFolder() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: AppTheme.sheetShape,
      builder: (_) => _NewFolderSheet(controller: _controller),
    );
  }

  void _handleFolderTap(FolderModel folder) {
    if (_controller.isEditMode) {
      _folderMenu(folder);
      return;
    }
    if (folder.isLocked && !_controller.isFolderUnlocked(folder.id!)) {
      PinDialogs.showUnlock(context, folder, () {
        _controller.markUnlocked(folder.id!);
        _openFolder(folder);
      });
    } else {
      _openFolder(folder);
    }
  }

  Future<void> _openFolder(FolderModel folder) async {
    final attempts = await _controller.prepareOpenFolder(folder);
    if (!context.mounted) return;

    if (attempts.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (_) => SecurityAlertDialog(attempts: attempts),
      );
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => FolderDetailScreen(folder: folder),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      _searchDebounce?.cancel();
      _controller.loadFolders();
    });
  }

  // ---------------------------------------------------------------------------
  // Folder action menu + dialogs
  // ---------------------------------------------------------------------------

  void _folderMenu(FolderModel folder) {
    showModalBottomSheet(
      context: context,
      shape: AppTheme.sheetShape,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppWidgets.sheetHandle(context),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                if (folder.isLocked &&
                    !_controller.isFolderUnlocked(folder.id!)) {
                  PinDialogs.showUnlock(
                      context, folder, () => _showRenameDialog(folder));
                } else {
                  _showRenameDialog(folder);
                }
              },
            ),
            ListTile(
              leading: Icon(folder.isLocked
                  ? Icons.lock_open_rounded
                  : Icons.lock_rounded),
              title: Text(folder.isLocked ? 'Remove Lock' : 'Set PIN Lock'),
              onTap: () {
                Navigator.pop(context);
                _handleLockToggle(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_rounded),
              title: const Text('Change Color'),
              onTap: () {
                Navigator.pop(context);
                _showChangeColorDialog(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                if (folder.isLocked &&
                    !_controller.isFolderUnlocked(folder.id!)) {
                  PinDialogs.showUnlock(
                      context, folder, () => _showDeleteDialog(folder));
                } else {
                  _showDeleteDialog(folder);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleLockToggle(FolderModel folder) {
    if (folder.isLocked && !_controller.isFolderUnlocked(folder.id!)) {
      PinDialogs.showUnlock(context, folder, () async {
        try {
          await _controller.removeFolderLock(folder.id!);
        } catch (e, stack) {
          debugPrint('removeFolderLock error: $e\n$stack');
          if (mounted) _showSnackBar('Failed to remove lock');
        }
      });
    } else if (folder.isLocked) {
      _controller.removeFolderLock(folder.id!).catchError((Object e, stack) {
        debugPrint('removeFolderLock error: $e\n$stack');
        if (mounted) _showSnackBar('Failed to remove lock');
      }).ignore();
    } else {
      PinDialogs.showSetPin(context, folder, () => _controller.loadFolders());
    }
  }

  void _showRenameDialog(FolderModel folder) {
    showDialog<String>(
      context: context,
      builder: (_) => RenameFolderDialog(initialName: folder.name),
    ).then((newName) async {
      if (newName == null || !mounted) return;
      try {
        await _controller.renameFolder(folder.id!, newName);
      } catch (e, stack) {
        debugPrint('renameFolder error: $e\n$stack');
        if (mounted) _showSnackBar('Failed to rename folder');
      }
    });
  }

  void _showChangeColorDialog(FolderModel folder) {
    showDialog<Color>(
      context: context,
      builder: (_) => ChangeColorDialog(initialColor: folder.toColor()),
    ).then((newColor) async {
      if (newColor == null || !mounted) return;
      try {
        await _controller.updateFolderColor(
            folder.id!, FolderModel.colorToHex(newColor));
      } catch (e, stack) {
        debugPrint('updateFolderColor error: $e\n$stack');
        if (mounted) _showSnackBar('Failed to update color');
      }
    });
  }

  void _showDeleteDialog(FolderModel folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
            'Are you sure you want to delete "${folder.name}"? All files inside will be deleted too.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _controller.deleteFolder(folder.id!);
                if (context.mounted) Navigator.pop(context);
              } catch (e, stack) {
                debugPrint('deleteFolder error: $e\n$stack');
                if (context.mounted) _showSnackBar('Failed to delete folder');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(message, Theme.of(context).colorScheme.error));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.background(context);
    final cardColor = AppColors.surface(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text('PocketFiles',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
        actions: [
          if (_controller.isEditMode)
            TextButton(
              onPressed: () {
                _controller.exitEditMode();
                _controller.applySearch(_searchController.text);
              },
              child: const Text('Done',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () {
                _searchDebounce?.cancel();
                _searchController.clear();
                _controller.enterEditMode();
              },
            ),
            IconButton(
              icon: const Icon(Icons.manage_search_rounded),
              tooltip: 'Search all files',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'sort_custom') { _controller.setSortMode(FolderSortMode.custom); }
                if (value == 'sort_name') { _controller.setSortMode(FolderSortMode.name); }
                if (value == 'sort_date') { _controller.setSortMode(FolderSortMode.date); }
                if (value == 'theme') { widget.themeController.cycle(); }
                if (value == 'help') { HelpSheet.show(context); }
                if (value == 'settings') { PinDialogs.showMasterPinSettings(context); }
              },
              itemBuilder: (_) {
                final c = _controller.sortMode;
                final color = Theme.of(context).colorScheme.primary;
                return [
                  PopupMenuItem(
                    value: 'sort_custom',
                    child: Row(children: [
                      Icon(Icons.drag_handle_rounded,
                          size: 18,
                          color: c == FolderSortMode.custom ? color : null),
                      const SizedBox(width: 8),
                      Text('Sort: Custom',
                          style: TextStyle(
                              color:
                                  c == FolderSortMode.custom ? color : null)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'sort_name',
                    child: Row(children: [
                      Icon(Icons.sort_by_alpha_rounded,
                          size: 18,
                          color: c == FolderSortMode.name ? color : null),
                      const SizedBox(width: 8),
                      Text('Sort: Name',
                          style: TextStyle(
                              color: c == FolderSortMode.name ? color : null)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'sort_date',
                    child: Row(children: [
                      Icon(Icons.access_time_rounded,
                          size: 18,
                          color: c == FolderSortMode.date ? color : null),
                      const SizedBox(width: 8),
                      Text('Sort: Date',
                          style: TextStyle(
                              color: c == FolderSortMode.date ? color : null)),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'theme',
                    child: Row(children: [
                      Icon(widget.themeController.icon, size: 18),
                      const SizedBox(width: 8),
                      Text(widget.themeController.tooltip),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'help',
                    child: Row(children: [
                      Icon(Icons.help_outline_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Help'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(children: [
                      Icon(Icons.settings_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Settings'),
                    ]),
                  ),
                ];
              },
            ),
          ],
        ],
      ),
      body: _controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_controller.isEditMode)
                  Builder(builder: (context) {
                    final tertiary = Theme.of(context).colorScheme.tertiary;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: tertiary.withAlpha(kEditModeBannerAlpha),
                      child: Row(
                        children: [
                          Icon(Icons.drag_handle_rounded,
                              size: 16, color: tertiary),
                          const SizedBox(width: 8),
                          Text('Hold and drag to reorder. Tap to edit.',
                              style: TextStyle(fontSize: 12, color: tertiary)),
                        ],
                      ),
                    );
                  }),
                if (!_controller.isEditMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search folders...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchDebounce?.cancel();
                                  _searchController.clear();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _controller.filteredFolders.isEmpty
                      ? (_controller.folders.isEmpty
                          ? _emptyState()
                          : _noResultsState())
                      : _folderGrid(),
                ),
              ],
            ),
      floatingActionButton: _controller.isEditMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _newFolder,
              icon: const Icon(Icons.create_new_folder_rounded),
              label: const Text('New Folder'),
            ),
    );
  }

  Widget _noResultsState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: scheme.outline),
          const SizedBox(height: 16),
          Text('No folders found',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Try a different search term',
              style: TextStyle(color: scheme.outline)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 80, color: scheme.outline),
          const SizedBox(height: 16),
          Text('No folders yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Tap the button below to create your first folder',
              style: TextStyle(color: scheme.outline)),
        ],
      ),
    );
  }

  Widget _folderGrid() {
    final crossAxisCount =
        MediaQuery.sizeOf(context).width >= kGridTabletBreakpoint
            ? kGridCrossAxisCountTablet
            : kGridCrossAxisCount;
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: kGridCrossAxisSpacing,
      mainAxisSpacing: kGridMainAxisSpacing,
      childAspectRatio: kGridChildAspectRatio,
    );

    if (_controller.isEditMode) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ReorderableGridView.builder(
          onReorder: _controller.reorder,
          gridDelegate: gridDelegate,
          itemCount: _controller.filteredFolders.length,
          itemBuilder: (context, index) =>
              _editCard(_controller.filteredFolders[index]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: gridDelegate,
        itemCount: _controller.filteredFolders.length,
        itemBuilder: (context, index) {
          final folder = _controller.filteredFolders[index];
          return FolderCard(
            key: ValueKey(folder.id),
            folder: folder,
            fileCount: _controller.fileCounts[folder.id] ?? 0,
            totalSize: _controller.fileSizes[folder.id] ?? 0,
            onTap: () => _handleFolderTap(folder),
            onLongPress: () => _folderMenu(folder),
          );
        },
      ),
    );
  }

  Widget _editCard(FolderModel folder) {
    final color = folder.toColor();
    return Stack(
      key: ValueKey(folder.id),
      children: [
        FolderCard(
          folder: folder,
          fileCount: _controller.fileCounts[folder.id] ?? 0,
          totalSize: _controller.fileSizes[folder.id] ?? 0,
          onTap: () => _handleFolderTap(folder),
        ),
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(Icons.drag_handle_rounded,
                size: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// New folder bottom sheet
// ---------------------------------------------------------------------------

class _NewFolderSheet extends StatefulWidget {
  final HomeController controller;
  const _NewFolderSheet({required this.controller});

  @override
  State<_NewFolderSheet> createState() => _NewFolderSheetState();
}

class _NewFolderSheetState extends State<_NewFolderSheet> {
  final _nameController = TextEditingController();
  Color _color = AppColors.primary;
  bool _nameError = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    setState(() => _isCreating = true);
    try {
      final folder = FolderModel(
        name: _nameController.text.trim(),
        color: FolderModel.colorToHex(_color),
        createdAt: DateTime.now(),
      );
      await widget.controller.addFolder(folder);
      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      debugPrint('addFolder error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(
            'Failed to create folder', Theme.of(context).colorScheme.error));
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppWidgets.sheetHandle(context),
          const SizedBox(height: 20),
          const Text('New Folder',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: 64,
            onChanged: (_) {
              if (_nameError) setState(() => _nameError = false);
            },
            decoration: AppTheme.inputDecoration('Folder name',
                error: _nameError ? 'Name cannot be empty' : null),
          ),
          const SizedBox(height: 20),
          const Text('Pick a color',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ColorPalettePicker(
            selectedColor: _color,
            onColorSelected: (color) => setState(() => _color = color),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isCreating ? null : _submit,
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Folder',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
