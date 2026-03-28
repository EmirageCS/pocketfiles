import 'package:flutter/material.dart';
import '../../models/file_model.dart';
import '../../services/file_service.dart';
import '../../utils/app_theme.dart';

/// Dialog that collects a new base name (without extension) for a file.
/// Pops with the trimmed base-name [String] on confirm, or [null] on cancel.
class RenameFileDialog extends StatefulWidget {
  final FileModel file;

  const RenameFileDialog({super.key, required this.file});

  @override
  State<RenameFileDialog> createState() => _RenameFileDialogState();
}

class _RenameFileDialogState extends State<RenameFileDialog> {
  late final TextEditingController _nameController;
  late final String _ext;
  bool _nameError = false;

  @override
  void initState() {
    super.initState();
    _ext = FileService.getFileExtension(widget.file.name);
    _nameController = TextEditingController(
      text: FileService.getFileBaseName(widget.file.name),
    );
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
    if (name == FileService.getFileBaseName(widget.file.name)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename File'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        maxLength: 64,
        onChanged: (_) {
          if (_nameError) setState(() => _nameError = false);
        },
        onSubmitted: (_) => _submit(),
        decoration: AppTheme.inputDecoration(
          _ext.isNotEmpty ? 'File name (without $_ext)' : 'File name',
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
