import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// A grid of [kFolderPalette] color swatches for picking a folder accent color.
/// Replaces the free-form color wheel to guarantee that every selectable color
/// is legible on the tinted card background in both light and dark mode.
class ColorPalettePicker extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  const ColorPalettePicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: kFolderPalette.map((color) {
        final isSelected = color.toARGB32() == selectedColor.toARGB32();
        final surfaceColor = Theme.of(context).colorScheme.surface;
        return Semantics(
          label: 'Color option',
          selected: isSelected,
          button: true,
          child: GestureDetector(
            onTap: () => onColorSelected(color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: surfaceColor, width: 3)
                    : Border.all(color: Colors.transparent, width: 3),
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withAlpha(120), blurRadius: 8, spreadRadius: 2)]
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
