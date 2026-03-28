import 'package:flutter/material.dart';

/// Centralized color definitions for PocketFiles.
/// All hardcoded colors in the app should reference this class.
class AppColors {
  AppColors._();

  // Background colors
  static const Color backgroundDark = Color(0xFF1C1C1E);
  static const Color backgroundLight = Color(0xFFF5F5F7);

  // Card/surface colors
  static const Color surfaceDark = Color(0xFF2C2C2E);
  static const Color surfaceLight = Colors.white;

  // Brand color
  static const Color primary = Color(0xFF6C63FF);

  // Returns correct background color based on current brightness
  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? backgroundDark
        : backgroundLight;
  }

  // Returns correct surface/card color based on current brightness
  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? surfaceDark
        : surfaceLight;
  }
}