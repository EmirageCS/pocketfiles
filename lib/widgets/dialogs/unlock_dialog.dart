import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/folder_model.dart';
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/pin_hasher.dart';
import 'forgot_pin_dialog.dart';
import 'lockout_banner.dart';

/// Dialog for unlocking a PIN-protected folder.
/// Handles brute-force protection, countdown lockout, PIN hint display,
/// master PIN verification, and transparent SHA-256→bcrypt migration.
class UnlockDialog extends StatefulWidget {
  final FolderModel folder;
  final VoidCallback onSuccess;

  const UnlockDialog({
    super.key,
    required this.folder,
    required this.onSuccess,
  });

  @override
  State<UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<UnlockDialog> {
  final _pinController = TextEditingController();
  bool _hasError          = false;
  bool _isBruteForceLocked = false;
  bool _isChecking        = false;
  int  _remainingSeconds  = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _startLockout(int seconds) {
    _countdownTimer?.cancel();
    setState(() {
      _isBruteForceLocked = true;
      _remainingSeconds   = seconds;
      _isChecking         = false; // always exit checking state when entering lockout
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _isBruteForceLocked = false;
        }
      });
    });
  }

  Future<void> _submit() async {
    if (_pinController.text.length < kPinMinLength) {
      setState(() => _hasError = true);
      return;
    }

    // Disable the button immediately — prevents double-submission while the
    // async lockout check is in flight (double-tap window before first await).
    setState(() => _isChecking = true);
    var lockoutTriggered = false;
    try {
      // Check if already locked out before verifying
      final info = await StorageService().getRecentAttemptInfo(widget.folder.id!);
      if (!mounted) return;

      if (info.count >= kMaxPinAttempts && info.lastAttempt != null) {
        final elapsed = DateTime.now().difference(info.lastAttempt!).inSeconds;
        if (elapsed < kLockoutSeconds) {
          lockoutTriggered = true;
          _startLockout(kLockoutSeconds - elapsed);
          return;
        }
      }

      final masterInfo = await StorageService().getMasterPinInfo();
      if (!mounted) return;

      final pinMatches = widget.folder.pin != null &&
          await PinHasher.verify(
            _pinController.text,
            widget.folder.pin!,
            legacySalt: widget.folder.pinSalt,
          );
      // Skip master PIN verify when folder PIN already matched — saves ~100ms.
      final masterMatches = !pinMatches &&
          masterInfo != null &&
          await PinHasher.verify(
            _pinController.text,
            masterInfo.hash,
            legacySalt: masterInfo.salt,
          );
      if (!mounted) return;

      if (pinMatches || masterMatches) {
        // Transparent migration from SHA-256 to bcrypt
        if (pinMatches &&
            widget.folder.pin != null &&
            !PinHasher.isBcrypt(widget.folder.pin!)) {
          PinHasher.hash(_pinController.text)
              .then((h) => StorageService().migratePinToBcrypt(widget.folder.id!, h))
              .catchError((e) => debugPrint('PIN bcrypt migration failed: $e'))
              .ignore();
        }
        // Reset security-question attempt counter so recovery is usable again
        // after a successful PIN entry (fire-and-forget — non-critical).
        StorageService()
            .setSetting(StorageKeys.questionAttempts(widget.folder.id!), '0')
            .catchError((e) => debugPrint('reset questionAttempts failed: $e'))
            .ignore();
        _pinController.clear(); // zero PIN from memory before dialog closes
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        final updated =
            await StorageService().logFailedAttemptAndGet(widget.folder.id!);
        if (!mounted) return;
        if (updated.count >= kMaxPinAttempts) {
          lockoutTriggered = true;
          _startLockout(kLockoutSeconds);
        } else {
          setState(() => _hasError = true);
        }
      }
    } catch (e, stack) {
      debugPrint('UnlockDialog submit error: $e\n$stack');
      _pinController.clear(); // zero PIN from memory on unexpected error
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (!lockoutTriggered && mounted) setState(() => _isChecking = false);
    }
  }

  void _showForgotPin() {
    _countdownTimer?.cancel();
    // Use the navigator's own context — valid even after the dialog is popped
    final navigator = Navigator.of(context);
    navigator.pop();
    showDialog(
      context: navigator.context,
      builder: (_) => ForgotPinDialog(
        folder: widget.folder,
        onSuccess: widget.onSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.lock_rounded, size: 20),
        const SizedBox(width: 8),
        Text(widget.folder.name),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isBruteForceLocked)
            LockoutBanner(seconds: _remainingSeconds)
          else
            TextField(
              controller: _pinController,
              autofocus: true,
              obscureText: true,
              maxLength: kPinMaxLength,
              keyboardType: TextInputType.number,
              onChanged: (_) {
                if (_hasError) setState(() => _hasError = false);
              },
              decoration: AppTheme.hintDecoration(
                'Enter PIN',
                error: _hasError ? 'Incorrect PIN' : null,
              ),
            ),
          if (widget.folder.pinHint != null && !_isBruteForceLocked)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.tertiary),
                const SizedBox(width: 4),
                Text(
                  'Hint: ${widget.folder.pinHint}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.tertiary),
                ),
              ]),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _pinController.clear(); // zero PIN from memory on cancel
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        if (widget.folder.securityQuestion != null && !_isBruteForceLocked)
          TextButton(
            onPressed: _showForgotPin,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            child: const Text('Forgot PIN?'),
          ),
        if (!_isBruteForceLocked)
          TextButton(
            onPressed: _isChecking ? null : _submit,
            child: const Text('Unlock'),
          ),
      ],
    );
  }
}
