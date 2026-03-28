import 'package:flutter/material.dart';
import '../color_palette_picker.dart';

/// Dialog for changing a folder's accent color using the curated palette.
/// Pops with the chosen [Color] on confirm, or [null] on cancel.
class ChangeColorDialog extends StatefulWidget {
  final Color initialColor;

  const ChangeColorDialog({super.key, required this.initialColor});

  @override
  State<ChangeColorDialog> createState() => _ChangeColorDialogState();
}

class _ChangeColorDialogState extends State<ChangeColorDialog> {
  late Color _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Color'),
      content: ColorPalettePicker(
        selectedColor: _selected,
        onColorSelected: (color) => setState(() => _selected = color),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
