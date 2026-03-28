import 'package:flutter/material.dart';

abstract final class HelpSheet {
  static void show(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _HelpScreen()),
    );
  }

  static const List<(IconData, String, String)> _items = [
    (
      Icons.create_new_folder_rounded,
      'Create folders',
      'Tap "New Folder", choose a name and pick a color from the curated palette.',
    ),
    (
      Icons.lock_rounded,
      'PIN lock',
      'Long-press a folder to open its menu and set a 4–8 digit PIN. '
          "You'll also set a security question to recover access if you forget the PIN.",
    ),
    (
      Icons.vpn_key_rounded,
      'Master PIN',
      'Tap ⋮ → Settings to set a master PIN — one code that unlocks any locked folder.',
    ),
    (
      Icons.drag_handle_rounded,
      'Reorder',
      'Tap ✏️ to enter edit mode and drag folders or files into your preferred order.',
    ),
    (
      Icons.sort_rounded,
      'Sort',
      'Sort folders by name or date from the ⋮ menu. Inside a folder, use the sort icon to order files by name, size, date, or custom order.',
    ),
    (
      Icons.manage_search_rounded,
      'Global search',
      'Tap the search icon in the top bar to find files across all folders at once.',
    ),
    (
      Icons.search_rounded,
      'Folder search',
      'Search files by name inside any open folder using the search bar at the top.',
    ),
    (
      Icons.swipe_rounded,
      'Swipe actions',
      'Swipe a file right to share it, or left to delete it.',
    ),
    (
      Icons.file_copy_rounded,
      'Add files',
      'Open a folder and tap "Add Files" to pick one or more files at once. For locked folders you can choose to move the originals for extra privacy.',
    ),
    (
      Icons.brightness_auto_rounded,
      'Theme',
      'Tap ⋮ → Theme to switch between system, light, and dark mode.',
    ),
    (
      Icons.warning_amber_rounded,
      'Security alerts',
      'Failed unlock attempts are recorded and shown the next time you open that folder.',
    ),
  ];
}

class _HelpScreen extends StatelessWidget {
  const _HelpScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How to use PocketFiles',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: HelpSheet._items
              .map((item) => _HelpItem(
                    icon: item.$1,
                    title: item.$2,
                    description: item.$3,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _HelpItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(description,
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
