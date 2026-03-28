import 'package:flutter/material.dart';
import 'controllers/theme_controller.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'utils/app_colors.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await StorageService().pruneOldFailedAttempts();
  } catch (e, stack) {
    // Non-fatal — app still starts if DB prune fails, but log for diagnostics
    debugPrint('pruneOldFailedAttempts error: $e\n$stack');
  }
  runApp(const PocketFilesApp());
}

class PocketFilesApp extends StatefulWidget {
  const PocketFilesApp({super.key});

  @override
  State<PocketFilesApp> createState() => _PocketFilesAppState();
}

class _PocketFilesAppState extends State<PocketFilesApp> {
  final _themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    _themeController.addListener(_onThemeChanged);
    _themeController.init();
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketFiles',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        dialogTheme: AppTheme.dialogTheme,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        dialogTheme: AppTheme.dialogTheme,
      ),
      themeMode: _themeController.mode,
      home: HomeScreen(themeController: _themeController),
    );
  }
}
