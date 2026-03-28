import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/folder_controller.dart';
import '../models/file_model.dart';
import '../models/folder_model.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/dialogs/rename_file_dialog.dart';

PopupMenuItem<SortMode> _sortItem(
  SortMode value,
  String label,
  IconData icon, {
  required SortMode current,
  required Color selectedColor,
}) {
  final selected = value == current;
  return PopupMenuItem(
    value: value,
    child: Row(children: [
      Icon(icon, size: 18, color: selected ? selectedColor : null),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: selected ? selectedColor : null)),
    ]),
  );
}

class FolderDetailScreen extends StatefulWidget {
  final FolderModel folder;

  const FolderDetailScreen({super.key, required this.folder});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  late final FolderController _controller;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _controller = FolderController(
      widget.folder,
      StorageService(),
      FileService(),
    )
      ..addListener(_onControllerUpdate)
      ..init();
    _searchController.addListener(_onSearchChanged);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _controller
      ..removeListener(_onControllerUpdate)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: kSearchDebounceMs), () {
      if (mounted) _controller.applySearch(_searchController.text);
    });
  }

  // ---------------------------------------------------------------------------
  // File actions
  // ---------------------------------------------------------------------------

  Future<void> _pickFile() async {
    bool deleteOriginal = false;

    if (widget.folder.isLocked) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Move to PocketFiles?'),
          content: const Text(
            'The original files will be deleted from your gallery. Move them for privacy, or keep copies.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Originals'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Move'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      deleteOriginal = choice;
    }

    final result = await _controller.pickFiles(deleteOriginal: deleteOriginal);
    if (!mounted) return;

    if (result.isCancelled) return;

    if (result.success > 0 && result.duplicates == 0 && result.errors == 0) {
      final n = result.success;
      _showSnackBar('$n ${n == 1 ? "file" : "files"} added', Colors.green);
    } else if (result.success > 0) {
      final parts = <String>['${result.success} added'];
      if (result.duplicates > 0) parts.add('${result.duplicates} duplicate');
      if (result.errors > 0) parts.add('${result.errors} failed');
      _showSnackBar(parts.join(', '), Colors.orange);
    } else if (result.duplicates > 0 && result.errors == 0) {
      _showSnackBar('File already exists in this folder', Colors.orange);
    } else {
      _showSnackBar('Failed to add files', Theme.of(context).colorScheme.error);
    }
  }

  Future<void> _openFile(FileModel file) async {
    final ok = await _controller.openFile(file);
    if (!ok && mounted) _showSnackBar('Could not open file', Theme.of(context).colorScheme.error);
  }

  Future<void> _shareFile(FileModel file) async {
    final ok = await _controller.shareFile(file);
    if (!ok && mounted) _showSnackBar('Could not share file', Theme.of(context).colorScheme.error);
  }

  Future<void> _renameFile(FileModel file) async {
    final newBaseName = await showDialog<String>(
      context: context,
      builder: (_) => RenameFileDialog(file: file),
    );
    if (newBaseName == null || !mounted) return;
    final result = await _controller.renameFile(file, newBaseName);
    if (!mounted) return;
    if (result.isSuccess) {
      _showSnackBar('File renamed', Colors.green);
    } else if (result.isDuplicate) {
      _showSnackBar('A file with that name already exists', Colors.orange);
    } else if (result.isError) {
      _showSnackBar('Failed to rename file', Theme.of(context).colorScheme.error);
    }
  }

  Future<void> _deleteFile(FileModel file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await _controller.deleteFile(file);
    if (!mounted) return;
    if (ok) {
      _showSnackBar('${file.name} deleted', Theme.of(context).colorScheme.error);
    } else {
      _showSnackBar('Failed to delete file', Theme.of(context).colorScheme.error);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(message, color));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final color     = widget.folder.toColor();
    final bgColor   = AppColors.background(context);
    final cardColor = AppColors.surface(context);

    final fileCount   = _controller.files.length;
    final displayCount = _controller.displayFiles.length;
    final subtitle = _controller.searchQuery.isNotEmpty
        ? '$displayCount of $fileCount ${fileCount == 1 ? "file" : "files"}'
        : '$fileCount ${fileCount == 1 ? "file" : "files"}';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.folder.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              subtitle,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: _controller.setSortMode,
            itemBuilder: (_) => [
              _sortItem(SortMode.custom, 'Custom', Icons.drag_handle_rounded,
                  current: _controller.sortBy, selectedColor: color),
              _sortItem(SortMode.date, 'Date', Icons.access_time_rounded,
                  current: _controller.sortBy, selectedColor: color),
              _sortItem(SortMode.name, 'Name', Icons.sort_by_alpha_rounded,
                  current: _controller.sortBy, selectedColor: color),
              _sortItem(SortMode.size, 'Size', Icons.data_usage_rounded,
                  current: _controller.sortBy, selectedColor: color),
            ],
          ),
        ],
      ),
      body: _controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _controller.files.isEmpty
              ? _buildEmptyState(color)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search files...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _controller.searchQuery.isNotEmpty
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
                      child: _controller.displayFiles.isEmpty
                          ? _buildNoResultsState()
                          : _buildFileList(color, cardColor),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: color,
        foregroundColor: Colors.white,
        onPressed: _controller.isImporting ? null : _pickFile,
        icon: _controller.isImporting
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add_rounded),
        label: Text(_controller.isImporting ? 'Adding...' : 'Add Files'),
      ),
    );
  }

  Widget _buildEmptyState(Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 80, color: color.withAlpha(100)),
          const SizedBox(height: 16),
          Text('No files yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Tap the button below to add files',
              style: TextStyle(color: scheme.outline)),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: scheme.outline),
          const SizedBox(height: 16),
          Text('No files found',
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

  Widget _buildFileList(Color color, Color cardColor) {
    if (_controller.sortBy == SortMode.custom && _controller.searchQuery.isEmpty) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        onReorder: _controller.reorder,
        itemCount: _controller.displayFiles.length,
        itemBuilder: (context, index) => _buildFileTile(
          _controller.displayFiles[index],
          color,
          cardColor,
          key: ValueKey(_controller.displayFiles[index].id),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _controller.displayFiles.length,
      itemBuilder: (context, index) => _buildFileTile(
        _controller.displayFiles[index],
        color,
        cardColor,
        key: ValueKey(_controller.displayFiles[index].id),
      ),
    );
  }

  Widget _buildFileTile(FileModel file, Color color, Color cardColor,
      {required Key key}) {
    return Dismissible(
      key: key,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.share_rounded, color: Colors.white),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _shareFile(file);
          return false; // don't remove from list — share doesn't delete
        } else {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete File'),
              content: Text('Are you sure you want to delete "${file.name}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Delete',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              ],
            ),
          );
          return confirmed == true;
        }
      },
      onDismissed: (_) async {
        final ok = await _controller.deleteFile(file);
        if (mounted && ok) {
          _showSnackBar('${file.name} deleted', Theme.of(context).colorScheme.error);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withAlpha(kCardShadowAlpha),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: AppWidgets.iconBox(color, FileService.getFileIcon(file.name)),
        title: Text(file.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${FileService.formatDate(file.createdAt)} · ${FileService.formatSize(file.size)}',
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'open',
              child: Row(children: [
                Icon(Icons.open_in_new_rounded, size: 18),
                SizedBox(width: 8),
                Text('Open'),
              ]),
            ),
            PopupMenuItem(
              value: 'share',
              child: Row(children: [
                Icon(Icons.share_rounded, size: 18),
                SizedBox(width: 8),
                Text('Share'),
              ]),
            ),
            PopupMenuItem(
              value: 'rename',
              child: Row(children: [
                Icon(Icons.drive_file_rename_outline_rounded, size: 18),
                SizedBox(width: 8),
                Text('Rename'),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ]),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'open':   _openFile(file);
              case 'share':  _shareFile(file);
              case 'rename': _renameFile(file);
              case 'delete': _deleteFile(file);
            }
          },
        ),
        onTap: () => _openFile(file),
      ),
    ),
    );
  }
}
