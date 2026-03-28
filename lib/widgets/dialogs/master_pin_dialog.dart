import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/pin_hasher.dart';
import 'lockout_banner.dart';

const _snackColor = Color(0xFF43A047); // green — same tone as kFolderPalette

/// Dialog for setting or changing the master PIN.
/// The master PIN can unlock any locked folder and is protected
/// by its own brute-force lockout (5-minute cooldown).
class MasterPinDialog extends StatefulWidget {
  /// Pass [masterInfo] when a master PIN already exists (change flow).
  /// Pass null to enter the initial setup flow.
  final ({String hash, String? salt})? masterInfo;

  const MasterPinDialog({super.key, this.masterInfo});

  @override
  State<MasterPinDialog> createState() => _MasterPinDialogState();
}

class _MasterPinDialogState extends State<MasterPinDialog> {
  final _currentPinController = TextEditingController();
  final _newPinController     = TextEditingController();

  bool _hasError          = false;
  bool _newPinLengthError = false;
  bool _isBruteForceLocked = false;
  bool _isChecking        = false;
  int  _remainingSeconds  = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _currentPinController.dispose();
    _newPinController.dispose();
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
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        // Reset attempt counter outside setState — it's async and must not
        // be called inside a synchronous build-phase callback.
        StorageService().resetMasterPinAttempts()
            .catchError((e) => debugPrint('resetMasterPinAttempts failed: $e'))
            .ignore();
        if (mounted) setState(() => _isBruteForceLocked = false);
      }
    });
  }

  Future<void> _save() async {
    if (_newPinController.text.length < kPinMinLength) {
      setState(() => _newPinLengthError = true);
      return;
    }

    setState(() => _isChecking = true);
    var lockoutTriggered = false;
    try {
      if (widget.masterInfo != null) {
        final matches = await PinHasher.verify(
          _currentPinController.text,
          widget.masterInfo!.hash,
          legacySalt: widget.masterInfo!.salt,
        );
        if (!mounted) return;
        if (!matches) {
          final attempts = await StorageService().incrementMasterPinAttempts();
          if (!mounted) return;
          if (attempts >= kMaxPinAttempts) {
            lockoutTriggered = true;
            _startLockout(kMasterLockoutSeconds);
          } else {
            setState(() => _hasError = true);
          }
          return;
        }
      }
      await StorageService().resetMasterPinAttempts();
      await StorageService().setMasterPin(_newPinController.text);
      if (mounted) {
        // Zero sensitive values from memory before the dialog closes
        _currentPinController.clear();
        _newPinController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar('Master PIN saved', _snackColor),
        );
        Navigator.pop(context);
      }
    } catch (e, stack) {
      debugPrint('MasterPinDialog save error: $e\n$stack');
      _currentPinController.clear(); // zero PINs from memory on unexpected error
      _newPinController.clear();
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (!lockoutTriggered && mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Master PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isBruteForceLocked)
            LockoutBanner(seconds: _remainingSeconds)
          else ...[
            Text(
              widget.masterInfo == null
                  ? 'Set a master PIN to unlock any locked folder.'
                  : 'Enter your current master PIN to change it.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (widget.masterInfo != null) ...[
              TextField(
                controller: _currentPinController,
                obscureText: true,
                maxLength: kPinMaxLength,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                decoration: AppTheme.inputDecoration(
                  'Current master PIN',
                  error: _hasError ? 'Incorrect PIN' : null,
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _newPinController,
              obscureText: true,
              maxLength: kPinMaxLength,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: widget.masterInfo == null,
              onChanged: (_) {
                if (_newPinLengthError) setState(() => _newPinLengthError = false);
              },
              decoration: AppTheme.inputDecoration(
                widget.masterInfo == null ? 'Master PIN (4–8 digits)' : 'New master PIN (4–8 digits)',
                error: _newPinLengthError ? 'PIN must be 4–8 digits' : null,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _currentPinController.clear(); // zero PINs from memory on cancel
            _newPinController.clear();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        if (!_isBruteForceLocked)
          TextButton(
            onPressed: _isChecking ? null : _save,
            child: const Text('Save'),
          ),
      ],
    );
  }
}
