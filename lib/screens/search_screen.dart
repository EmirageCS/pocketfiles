import 'dart:async';
import 'package:flutter/material.dart';
import '../models/file_model.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<({FileModel file, String folderName})> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _results = []; _hasSearched = false; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: kSearchDebounceMs), () async {
      final results = await StorageService().searchFiles(query.trim());
      if (mounted) setState(() { _results = results; _isSearching = false; _hasSearched = true; });
    });
  }

  Future<void> _openFile(FileModel file) async {
    try {
      await FileService().openFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar('Could not open file', Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor   = AppColors.background(context);
    final cardColor = AppColors.surface(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Search all files...',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      _onChanged('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _buildBody(cardColor),
    );
  }

  Widget _buildBody(Color cardColor) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasSearched) {
      return _buildHint();
    }
    if (_results.isEmpty) {
      return _buildNoResults();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final (:file, :folderName) = _results[index];
        return Container(
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
            leading: AppWidgets.iconBox(
              Theme.of(context).colorScheme.primary,
              FileService.getFileIcon(file.name),
            ),
            title: Text(file.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '$folderName · ${FileService.formatSize(file.size)}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline, fontSize: 12),
            ),
            onTap: () => _openFile(file),
          ),
        );
      },
    );
  }

  Widget _buildHint() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 64, color: scheme.outline),
          const SizedBox(height: 16),
          Text('Search across all folders',
              style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
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
}
