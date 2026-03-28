import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../services/storage_service.dart';
import 'dialogs/forgot_pin_dialog.dart';
import 'dialogs/master_pin_dialog.dart';
import 'dialogs/set_pin_dialog.dart';
import 'dialogs/unlock_dialog.dart';

/// Entry point for all PIN-related dialogs.
/// Each method delegates to a dedicated [StatefulWidget] that owns
/// its own state, timers, and controllers.
abstract final class PinDialogs {
  static void showSetPin(
    BuildContext context,
    FolderModel folder,
    VoidCallback onSuccess,
  ) =>
      showDialog(
        context: context,
        builder: (_) => SetPinDialog(folder: folder, onSuccess: onSuccess),
      );

  static void showUnlock(
    BuildContext context,
    FolderModel folder,
    VoidCallback onSuccess,
  ) =>
      showDialog(
        context: context,
        builder: (_) => UnlockDialog(folder: folder, onSuccess: onSuccess),
      );

  static void showForgotPin(
    BuildContext context,
    FolderModel folder,
    VoidCallback onSuccess,
  ) =>
      showDialog(
        context: context,
        builder: (_) => ForgotPinDialog(folder: folder, onSuccess: onSuccess),
      );

  static Future<void> showMasterPinSettings(BuildContext context) async {
    final masterInfo = await StorageService().getMasterPinInfo();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => MasterPinDialog(masterInfo: masterInfo),
    );
  }
}
