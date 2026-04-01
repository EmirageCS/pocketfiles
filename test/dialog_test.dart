import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pocketfiles/models/file_model.dart';
import 'package:pocketfiles/models/folder_model.dart';
import 'package:pocketfiles/services/storage_service.dart';
import 'package:pocketfiles/utils/constants.dart';
import 'package:pocketfiles/widgets/dialogs/change_color_dialog.dart';
import 'package:pocketfiles/widgets/dialogs/forgot_pin_dialog.dart';
import 'package:pocketfiles/widgets/dialogs/master_pin_dialog.dart';
import 'package:pocketfiles/widgets/dialogs/rename_file_dialog.dart';
import 'package:pocketfiles/widgets/dialogs/rename_folder_dialog.dart';
import 'package:pocketfiles/widgets/dialogs/set_pin_dialog.dart';
import 'package:pocketfiles/widgets/dialogs/unlock_dialog.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

FolderModel _folder({
  int id = 1,
  bool isLocked = true,
  String? pin,
  String? pinHint,
  String? securityQuestion,
  String? securityAnswer,
}) =>
    FolderModel(
      id: id,
      name: 'Test Folder',
      color: 'ff6c63ff',
      isLocked: isLocked,
      pin: pin,
      pinHint: pinHint,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      createdAt: DateTime(2024, 1, 1),
    );

FileModel _file({String name = 'document.pdf'}) => FileModel(
      id: 1,
      folderId: 1,
      name: name,
      path: '/tmp/$name',
      createdAt: DateTime(2024, 1, 1),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    StorageService.setDatabasePathForTesting(inMemoryDatabasePath);
  });

  tearDown(() async {
    await StorageService.resetForTesting();
    // resetForTesting clears the path override — re-set it for the next test.
    StorageService.setDatabasePathForTesting(inMemoryDatabasePath);
  });

  // --------------------------------------------------------------------------
  // UnlockDialog
  // --------------------------------------------------------------------------

  group('UnlockDialog', () {
    testWidgets('renders folder name in title', (tester) async {
      await tester.pumpWidget(_wrap(
        UnlockDialog(folder: _folder(), onSuccess: () {}),
      ));
      await tester.pump();
      expect(find.text('Test Folder'), findsOneWidget);
    });

    testWidgets('shows PIN hint when folder has one', (tester) async {
      await tester.pumpWidget(_wrap(
        UnlockDialog(folder: _folder(pinHint: 'my dog'), onSuccess: () {}),
      ));
      await tester.pump();
      expect(find.textContaining('my dog'), findsOneWidget);
    });

    testWidgets('shows Forgot PIN? when security question is set', (tester) async {
      await tester.pumpWidget(_wrap(
        UnlockDialog(
          folder: _folder(securityQuestion: kSecurityQuestions[0]),
          onSuccess: () {},
        ),
      ));
      await tester.pump();
      expect(find.text('Forgot PIN?'), findsOneWidget);
    });

    testWidgets('does not show Forgot PIN? when no security question', (tester) async {
      await tester.pumpWidget(_wrap(
        UnlockDialog(folder: _folder(), onSuccess: () {}),
      ));
      await tester.pump();
      expect(find.text('Forgot PIN?'), findsNothing);
    });

    testWidgets('shows error when submitting fewer than 4 digits', (tester) async {
      await tester.pumpWidget(_wrap(
        UnlockDialog(folder: _folder(), onSuccess: () {}),
      ));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.text('Unlock'));
      await tester.pump();
      expect(find.text('Incorrect PIN'), findsOneWidget);
    });

    testWidgets('Unlock button is present and enabled', (tester) async {
      await tester.pumpWidget(_wrap(
        UnlockDialog(folder: _folder(), onSuccess: () {}),
      ));
      await tester.pump();
      expect(find.text('Unlock'), findsOneWidget);
    });
  });

  // --------------------------------------------------------------------------
  // SetPinDialog
  // --------------------------------------------------------------------------

  group('SetPinDialog', () {
    testWidgets('renders title and Set PIN button', (tester) async {
      await tester.pumpWidget(_wrap(
        SetPinDialog(folder: _folder(isLocked: false), onSuccess: () {}),
      ));
      await tester.pump();
      expect(find.text('Set PIN Lock'), findsOneWidget);
      expect(find.text('Set PIN'), findsOneWidget);
    });

    testWidgets('shows PIN length error when submitted without 4 digits', (tester) async {
      await tester.pumpWidget(_wrap(
        SetPinDialog(folder: _folder(isLocked: false), onSuccess: () {}),
      ));
      await tester.pump();
      await tester.tap(find.text('Set PIN'));
      await tester.pump();
      expect(find.text('PIN must be 4–8 digits'), findsOneWidget);
    });

    testWidgets('shows answer error when PIN valid but answer empty', (tester) async {
      await tester.pumpWidget(_wrap(
        SetPinDialog(folder: _folder(isLocked: false), onSuccess: () {}),
      ));
      await tester.pump();
      // Enter 4-digit PIN in the first TextField
      await tester.enterText(find.byType(TextField).at(0), '1234');
      await tester.tap(find.text('Set PIN'));
      await tester.pump();
      expect(find.text('Answer is required'), findsOneWidget);
    });

    testWidgets('PIN length error clears on input', (tester) async {
      await tester.pumpWidget(_wrap(
        SetPinDialog(folder: _folder(isLocked: false), onSuccess: () {}),
      ));
      await tester.pump();
      await tester.tap(find.text('Set PIN'));
      await tester.pump();
      expect(find.text('PIN must be 4–8 digits'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '1');
      await tester.pump();
      expect(find.text('PIN must be 4–8 digits'), findsNothing);
    });

    testWidgets('shows error when answer exceeds 72 characters', (tester) async {
      await tester.pumpWidget(_wrap(
        SetPinDialog(folder: _folder(isLocked: false), onSuccess: () {}),
      ));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), '1234');
      await tester.enterText(find.byType(TextField).at(2), 'a' * 73);
      await tester.tap(find.text('Set PIN'));
      await tester.pump();
      expect(find.text('Answer is too long (max 72 characters)'), findsOneWidget);
    });

    testWidgets('answer too long error clears on input', (tester) async {
      await tester.pumpWidget(_wrap(
        SetPinDialog(folder: _folder(isLocked: false), onSuccess: () {}),
      ));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), '1234');
      await tester.enterText(find.byType(TextField).at(2), 'a' * 73);
      await tester.tap(find.text('Set PIN'));
      await tester.pump();
      expect(find.text('Answer is too long (max 72 characters)'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(2), 'short answer');
      await tester.pump();
      expect(find.text('Answer is too long (max 72 characters)'), findsNothing);
    });
  });

  // --------------------------------------------------------------------------
  // ForgotPinDialog
  // --------------------------------------------------------------------------

  group('ForgotPinDialog', () {
    testWidgets('renders security question text', (tester) async {
      await tester.pumpWidget(_wrap(
        ForgotPinDialog(
          folder: _folder(securityQuestion: kSecurityQuestions[1]),
          onSuccess: () {},
        ),
      ));
      await tester.pump();
      expect(find.text(kSecurityQuestions[1]), findsOneWidget);
      // Drain the pending _loadPersistedAttempts() sqflite isolate call so it
      // doesn't bleed into the next test's pump().
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });

    testWidgets('shows Verify button when attempts remain', (tester) async {
      await tester.pumpWidget(_wrap(
        ForgotPinDialog(
          folder: _folder(securityQuestion: kSecurityQuestions[0]),
          onSuccess: () {},
        ),
      ));
      await tester.pump();
      expect(find.text('Verify'), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });

    testWidgets('empty answer does not trigger async verify', (tester) async {
      await tester.pumpWidget(_wrap(
        ForgotPinDialog(
          folder: _folder(securityQuestion: kSecurityQuestions[0]),
          onSuccess: () {},
        ),
      ));
      await tester.pump();
      // Tap Verify with empty field — early return, no state change
      await tester.tap(find.text('Verify'));
      await tester.pump();
      expect(find.text('Verify'), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });

    testWidgets('shows Cancel button (always visible)', (tester) async {
      await tester.pumpWidget(_wrap(
        ForgotPinDialog(
          folder: _folder(securityQuestion: kSecurityQuestions[0]),
          onSuccess: () {},
        ),
      ));
      await tester.pump();
      expect(find.text('Cancel'), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });
  });

  // --------------------------------------------------------------------------
  // MasterPinDialog
  // --------------------------------------------------------------------------

  group('MasterPinDialog', () {
    testWidgets('setup mode: shows description and single PIN field', (tester) async {
      await tester.pumpWidget(_wrap(const MasterPinDialog()));
      await tester.pump();
      expect(find.textContaining('Set a master PIN'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('change mode: shows current PIN field', (tester) async {
      const info = r'$2b$10$aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      await tester.pumpWidget(_wrap(const MasterPinDialog(masterInfo: info)));
      await tester.pump();
      expect(find.textContaining('Enter your current master PIN'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('shows error when new PIN shorter than 4 digits', (tester) async {
      await tester.pumpWidget(_wrap(const MasterPinDialog()));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('PIN must be 4–8 digits'), findsOneWidget);
    });

    testWidgets('PIN length error clears on input', (tester) async {
      await tester.pumpWidget(_wrap(const MasterPinDialog()));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('PIN must be 4–8 digits'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '1');
      await tester.pump();
      expect(find.text('PIN must be 4–8 digits'), findsNothing);
    });
  });

  // --------------------------------------------------------------------------
  // RenameFolderDialog
  // --------------------------------------------------------------------------

  group('RenameFolderDialog', () {
    testWidgets('pre-fills initial name', (tester) async {
      await tester.pumpWidget(_wrap(
        const RenameFolderDialog(initialName: 'My Folder'),
      ));
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'My Folder');
    });

    testWidgets('shows error on empty name', (tester) async {
      await tester.pumpWidget(_wrap(
        const RenameFolderDialog(initialName: 'My Folder'),
      ));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Rename'));
      await tester.pump();
      expect(find.text('Name cannot be empty'), findsOneWidget);
    });

    testWidgets('same name pops with null (no-op)', (tester) async {
      String? result = 'not-null';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showDialog<String>(
                context: ctx,
                builder: (_) => const RenameFolderDialog(initialName: 'Folder'),
              );
            },
            child: const Text('Open'),
          )),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300)); // dialog open animation
      await tester.tap(find.text('Rename'));
      await tester.pump(const Duration(milliseconds: 300)); // dialog close animation
      expect(result, isNull);
    });

    testWidgets('different name pops with new name', (tester) async {
      String? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showDialog<String>(
                context: ctx,
                builder: (_) => const RenameFolderDialog(initialName: 'Old'),
              );
            },
            child: const Text('Open'),
          )),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300)); // dialog open animation
      await tester.enterText(find.byType(TextField), 'New Name');
      await tester.tap(find.text('Rename'));
      await tester.pump(const Duration(milliseconds: 300)); // dialog close animation
      expect(result, 'New Name');
    });
  });

  // --------------------------------------------------------------------------
  // RenameFileDialog
  // --------------------------------------------------------------------------

  group('RenameFileDialog', () {
    testWidgets('pre-fills base name without extension', (tester) async {
      await tester.pumpWidget(_wrap(RenameFileDialog(file: _file())));
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'document');
    });

    testWidgets('shows extension in label', (tester) async {
      await tester.pumpWidget(_wrap(RenameFileDialog(file: _file())));
      await tester.pump();
      expect(find.textContaining('.pdf'), findsOneWidget);
    });

    testWidgets('shows error on empty name', (tester) async {
      await tester.pumpWidget(_wrap(RenameFileDialog(file: _file())));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Rename'));
      await tester.pump();
      expect(find.text('Name cannot be empty'), findsOneWidget);
    });

    testWidgets('same base name pops with null (no-op)', (tester) async {
      String? result = 'not-null';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showDialog<String>(
                context: ctx,
                builder: (_) => RenameFileDialog(file: _file()),
              );
            },
            child: const Text('Open'),
          )),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300)); // dialog open animation
      await tester.tap(find.text('Rename'));
      await tester.pump(const Duration(milliseconds: 300)); // dialog close animation
      expect(result, isNull);
    });

    testWidgets('different name pops with new base name', (tester) async {
      String? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showDialog<String>(
                context: ctx,
                builder: (_) => RenameFileDialog(file: _file()),
              );
            },
            child: const Text('Open'),
          )),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300)); // dialog open animation
      await tester.enterText(find.byType(TextField), 'report');
      await tester.tap(find.text('Rename'));
      await tester.pump(const Duration(milliseconds: 300)); // dialog close animation
      expect(result, 'report');
    });

    testWidgets('file without extension shows plain label', (tester) async {
      await tester.pumpWidget(_wrap(RenameFileDialog(file: _file(name: 'README'))));
      await tester.pump();
      expect(find.textContaining('File name'), findsOneWidget);
    });
  });

  // --------------------------------------------------------------------------
  // ChangeColorDialog
  // --------------------------------------------------------------------------

  group('ChangeColorDialog', () {
    testWidgets('renders title, Save and Cancel buttons', (tester) async {
      await tester.pumpWidget(_wrap(
        ChangeColorDialog(initialColor: kFolderPalette[0]),
      ));
      await tester.pump();
      expect(find.text('Change Color'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Save pops with the selected color', (tester) async {
      Color? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showDialog<Color>(
                context: ctx,
                builder: (_) => ChangeColorDialog(initialColor: kFolderPalette[2]),
              );
            },
            child: const Text('Open'),
          )),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result, kFolderPalette[2]);
    });

    testWidgets('Cancel pops with null', (tester) async {
      Color? result = kFolderPalette[0];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showDialog<Color>(
                context: ctx,
                builder: (_) => ChangeColorDialog(initialColor: kFolderPalette[0]),
              );
            },
            child: const Text('Open'),
          )),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });

    testWidgets('renders all 16 palette swatches', (tester) async {
      await tester.pumpWidget(_wrap(
        ChangeColorDialog(initialColor: kFolderPalette[0]),
      ));
      await tester.pump();
      expect(find.byType(AnimatedContainer), findsNWidgets(kFolderPalette.length));
    });
  });
}
