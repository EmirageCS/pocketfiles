import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Dialog that collects a new name for a folder.
/// Pops with the trimmed [String] on confirm, or [null] on cancel.
class RenameFolderDialog extends StatefulWidget {
  final String initialName;

  const RenameFolderDialog({super.key, required this.initialName});

  @override
  State<RenameFolderDialog> createState() => _RenameFolderDialogState();
}

class _RenameFolderDialogState extends State<RenameFolderDialog> {
  late final TextEditingController _nameController;
  bool _nameError = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    if (name == widget.initialName) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Folder'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        maxLength: 64,
        onChanged: (_) {
          if (_nameError) setState(() => _nameError = false);
        },
        onSubmitted: (_) => _submit(),
        decoration: AppTheme.inputDecoration(
          'Folder name',
          error: _nameError ? 'Name cannot be empty' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Rename'),
        ),
      ],
    );
  }
}
