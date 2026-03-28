import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ShapeBorder get sheetShape =>
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      );

  static DialogThemeData get dialogTheme => const DialogThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20))),
      );

  static InputDecoration inputDecoration(String label, {String? error}) =>
      InputDecoration(
        labelText: label,
        errorText: error,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  static InputDecoration hintDecoration(String hint, {String? error}) =>
      InputDecoration(
        hintText: hint,
        errorText: error,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  static SnackBar snackBar(String content, Color color) => SnackBar(
        content: Text(content),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: color,
      );
}

abstract final class AppWidgets {
  // context required for dark-mode-aware color
  static Widget sheetHandle(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  static Widget iconBox(Color color, IconData icon) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      );
}
