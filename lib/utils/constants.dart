// App-wide constant values
import 'package:flutter/material.dart';

// Home screen folder grid layout
const int    kGridCrossAxisCount       = 2;   // phones (< 600 dp wide)
const int    kGridCrossAxisCountTablet = 3;   // tablets / landscape (≥ 600 dp)
const double kGridCrossAxisSpacing     = 16;
const double kGridMainAxisSpacing      = 16;
const double kGridChildAspectRatio     = 1.1;
const double kGridTabletBreakpoint     = 600; // dp width above which 3 columns are used

// Folder card appearance
const double kFolderCardBorderRadius = 20; // shared by card + palette swatch container

// Folder card color overlay opacities (as 0–255 alpha values)
const int kFolderCardBackgroundAlpha = 38;  // ~15 % — tinted fill
const int kFolderCardBorderAlpha     = 77;  // ~30 % — tinted border
const int kFolderCardBadgeAlpha      = 51;  // ~20 % — file-count badge
const int kEditModeBannerAlpha       = 30;  // ~12 % — orange edit-mode bar
const int kCardShadowAlpha           = 13;  //  ~5 % — tile drop shadow

/// 16 curated folder accent colors.
/// Every color is from Material Design's 600–400 range, ensuring sufficient
/// saturation to be legible when applied as a 15 % tinted fill on both
/// light and dark backgrounds.
const List<Color> kFolderPalette = [
  Color(0xFF6C63FF), // Indigo-purple  (app primary)
  Color(0xFF3F6EE8), // Blue
  Color(0xFF00ACC1), // Cyan
  Color(0xFF00897B), // Teal
  Color(0xFF43A047), // Green
  Color(0xFF7CB342), // Light green
  Color(0xFFFFB300), // Amber
  Color(0xFFFF7043), // Deep orange
  Color(0xFFE53935), // Red
  Color(0xFFEC407A), // Pink
  Color(0xFFAB47BC), // Purple
  Color(0xFF7E57C2), // Deep purple
  Color(0xFF5C6BC0), // Indigo
  Color(0xFF26C6DA), // Light cyan
  Color(0xFF8D6E63), // Brown
  Color(0xFF78909C), // Blue-grey
];

const List<String> kSecurityQuestions = [
  "What is your pet's name?",
  "What city were you born in?",
  "What is your mother's maiden name?",
  "What was the name of your first school?",
  "What is your favorite movie?",
];

// Folder sort modes
enum FolderSortMode { custom, name, date }

// Search
const int kSearchDebounceMs = 300; // ms to wait after last keystroke before applying search

// PIN length constraints
const int kPinMinLength = 4;
const int kPinMaxLength = 8;

// Brute force settings
const int kMaxPinAttempts = 3;
const int kLockoutSeconds = 60;        // Folder PIN lockout
const int kMasterLockoutSeconds = 300; // Master PIN lockout (5 minutes)

// Max failed attempts to display before "…and X more" truncation in security alert
const int kMaxSecurityAlertItems = 5;

/// Keys used to read/write rows in the `settings` table.
/// Centralised here to prevent typos and aid future renaming.
abstract final class StorageKeys {
  static const String onboardingDone    = 'onboardingDone';
  static const String masterPin         = 'masterPin';
  static const String masterPinSalt     = 'masterPinSalt';
  static const String masterPinAttempts = 'masterPinAttempts';
  static const String themeMode         = 'themeMode';

  /// Per-folder sort-mode preference key.
  static String sortMode(int folderId) => 'sortMode_$folderId';

  /// Per-folder security-question failed-attempt counter (persists across dialog opens).
  static String questionAttempts(int folderId) => 'questionAttempts_$folderId';
}
