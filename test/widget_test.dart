import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfiles/controllers/theme_controller.dart';
import 'package:pocketfiles/services/i_storage_service.dart';
import 'package:pocketfiles/utils/constants.dart';
import 'package:pocketfiles/widgets/color_palette_picker.dart';
import 'package:pocketfiles/widgets/dialogs/lockout_banner.dart';

class _NoopStorage implements IStorageService {
  @override dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
  @override Future<String?> getSetting(String key) async => null;
  @override Future<void> setSetting(String key, String value) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// ---------------------------------------------------------------------------
// ThemeController
// ---------------------------------------------------------------------------

void main() {
  group('ThemeController', () {
    test('starts in system mode', () {
      final ctrl = ThemeController(_NoopStorage());
      expect(ctrl.mode, ThemeMode.system);
    });

    test('system mode icon is brightness_auto', () {
      final ctrl = ThemeController(_NoopStorage());
      expect(ctrl.icon, Icons.brightness_auto_rounded);
    });

    test('system mode tooltip is correct', () {
      final ctrl = ThemeController(_NoopStorage());
      expect(ctrl.tooltip, 'Theme: System');
    });
  });

  // -------------------------------------------------------------------------
  // ColorPalettePicker
  // -------------------------------------------------------------------------

  group('ColorPalettePicker', () {
    testWidgets('renders all 16 palette swatches', (tester) async {
      await tester.pumpWidget(_wrap(
        ColorPalettePicker(
          selectedColor: kFolderPalette.first,
          onColorSelected: (_) {},
        ),
      ));
      // Each swatch is a GestureDetector wrapping an AnimatedContainer
      expect(find.byType(GestureDetector), findsNWidgets(kFolderPalette.length));
    });

    testWidgets('calls onColorSelected when swatch tapped', (tester) async {
      Color? picked;
      await tester.pumpWidget(_wrap(
        ColorPalettePicker(
          selectedColor: kFolderPalette.first,
          onColorSelected: (c) => picked = c,
        ),
      ));
      await tester.tap(find.byType(GestureDetector).last);
      expect(picked, equals(kFolderPalette.last));
    });

    testWidgets('selected swatch has white border', (tester) async {
      await tester.pumpWidget(_wrap(
        ColorPalettePicker(
          selectedColor: kFolderPalette[2],
          onColorSelected: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      // Find the AnimatedContainer for the selected swatch
      final containers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      ).toList();
      final selected = containers[2]; // index 2 matches kFolderPalette[2]
      final box = selected.decoration as BoxDecoration;
      final border = box.border as Border;
      // Border should be visible (not transparent) and 3 px wide for selected state.
      expect(border.top.color, isNot(Colors.transparent));
      expect(border.top.width, 3.0);
    });
  });

  // -------------------------------------------------------------------------
  // LockoutBanner
  // -------------------------------------------------------------------------

  group('LockoutBanner', () {
    testWidgets('displays remaining seconds', (tester) async {
      await tester.pumpWidget(_wrap(const LockoutBanner(seconds: 42)));
      expect(find.textContaining('42'), findsOneWidget);
    });

    testWidgets('displays 0 seconds gracefully', (tester) async {
      await tester.pumpWidget(_wrap(const LockoutBanner(seconds: 0)));
      expect(find.textContaining('0'), findsOneWidget);
    });

    testWidgets('shows timer icon', (tester) async {
      await tester.pumpWidget(_wrap(const LockoutBanner(seconds: 10)));
      expect(find.byIcon(Icons.timer_rounded), findsOneWidget);
    });
  });
}
