import 'package:flutter/material.dart';
import '../../models/folder_model.dart';
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/pin_hasher.dart';

/// Dialog for recovering folder access via the security question
/// when the user has forgotten their PIN.
class ForgotPinDialog extends StatefulWidget {
  final FolderModel folder;
  final VoidCallback onSuccess;

  const ForgotPinDialog({
    super.key,
    required this.folder,
    required this.onSuccess,
  });

  @override
  State<ForgotPinDialog> createState() => _ForgotPinDialogState();
}

class _ForgotPinDialogState extends State<ForgotPinDialog> {
  final _answerController = TextEditingController();
  bool _hasError    = false;
  bool _isChecking  = false;
  int  _attemptsLeft = kMaxPinAttempts;

  @override
  void initState() {
    super.initState();
    _loadPersistedAttempts();
  }

  Future<void> _loadPersistedAttempts() async {
    try {
      final saved = await StorageService()
          .getSetting(StorageKeys.questionAttempts(widget.folder.id!));
      if (!mounted) return;
      final used = int.tryParse(saved ?? '0') ?? 0;
      if (used > 0) setState(() => _attemptsLeft = kMaxPinAttempts - used);
    } catch (e) {
      debugPrint('_loadPersistedAttempts failed: $e');
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final answer = _answerController.text.trim().toLowerCase();
    if (answer.isEmpty) return;

    setState(() => _isChecking = true);
    var success = false;
    try {
      final matches = widget.folder.securityAnswer != null &&
          await PinHasher.verify(answer, widget.folder.securityAnswer!);
      if (!mounted) return;

      if (matches) {
        success = true;
        _answerController.clear(); // zero answer from memory before dialog closes
        // Await reset so the next dialog open doesn't see stale attempt count.
        await StorageService()
            .setSetting(StorageKeys.questionAttempts(widget.folder.id!), '0');
        if (!mounted) return;
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        setState(() {
          _hasError = true;
          _attemptsLeft--;
        });
        final used = kMaxPinAttempts - _attemptsLeft;
        // Persist attempt count before re-enabling the button (finally block)
        // so a rapid second tap cannot read a stale counter from the DB.
        await StorageService()
            .setSetting(StorageKeys.questionAttempts(widget.folder.id!), used.toString());
      }
    } catch (e, stack) {
      debugPrint('ForgotPinDialog verify error: $e\n$stack');
      _answerController.clear(); // zero answer from memory on unexpected error
    } finally {
      // Skip reset on success — the dialog is closing anyway.
      if (!success && mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Security Question'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.folder.securityQuestion ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_attemptsLeft <= 0)
            Builder(builder: (context) {
              final errorColor = Theme.of(context).colorScheme.error;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: errorColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: errorColor.withAlpha(50)),
                ),
                child: Text(
                  'Too many incorrect answers. Please use your PIN.',
                  style: TextStyle(color: errorColor, fontSize: 12),
                ),
              );
            })
          else
            TextField(
              controller: _answerController,
              autofocus: true,
              decoration: AppTheme.inputDecoration(
                'Your answer',
                error: _hasError
                    ? 'Incorrect answer ($_attemptsLeft '
                        '${_attemptsLeft == 1 ? "attempt" : "attempts"} left)'
                    : null,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _answerController.clear(); // zero answer from memory on cancel
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        if (_attemptsLeft > 0)
          TextButton(
            onPressed: _isChecking ? null : _verify,
            child: const Text('Verify'),
          ),
      ],
    );
  }
}
