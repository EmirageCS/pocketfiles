import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import '../../models/folder_model.dart';
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

/// Dialog for setting a 4-digit PIN lock on a folder,
/// including an optional hint and a mandatory security question.
class SetPinDialog extends StatefulWidget {
  final FolderModel folder;
  final VoidCallback onSuccess;

  const SetPinDialog({
    super.key,
    required this.folder,
    required this.onSuccess,
  });

  @override
  State<SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<SetPinDialog> {
  final _pinController    = TextEditingController();
  final _hintController   = TextEditingController();
  final _answerController = TextEditingController();

  String _selectedQuestion = kSecurityQuestions[0];
  bool _isSubmitting     = false;
  bool _pinLengthError   = false;
  bool _answerEmptyError = false;
  bool _answerTooLong    = false;

  @override
  void dispose() {
    _pinController.dispose();
    _hintController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pinController.text.length < kPinMinLength) {
      setState(() => _pinLengthError = true);
      return;
    }
    if (_answerController.text.trim().isEmpty) {
      setState(() => _answerEmptyError = true);
      return;
    }
    // BCrypt silently truncates inputs > 72 bytes — reject before hashing.
    if (_answerController.text.trim().length > 72) {
      setState(() => _answerTooLong = true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await StorageService().updateFolderLock(
        widget.folder.id!, true, _pinController.text,
        pinHint: _hintController.text.trim().isEmpty
            ? null
            : _hintController.text.trim(),
        securityQuestion: _selectedQuestion,
        securityAnswer: _answerController.text.trim().toLowerCase(),
      );
      if (mounted) {
        // Zero sensitive values from memory before the dialog closes
        _pinController.clear();
        _answerController.clear();
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e, stack) {
      debugPrint('SetPinDialog submit error: $e\n$stack');
      _pinController.clear(); // zero sensitive values from memory on unexpected error
      _hintController.clear();
      _answerController.clear();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set PIN Lock'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _pinController,
              obscureText: true,
              maxLength: kPinMaxLength,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                if (_pinLengthError) setState(() => _pinLengthError = false);
              },
              decoration: AppTheme.inputDecoration(
                'PIN (4–8 digits)',
                error: _pinLengthError ? 'PIN must be 4–8 digits' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hintController,
              maxLength: 64,
              decoration: AppTheme.inputDecoration('PIN hint (optional)'),
            ),
            const SizedBox(height: 16),
            const Text('Security Question',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: _selectedQuestion,
                isExpanded: true,
                underline: const SizedBox(),
                items: kSecurityQuestions
                    .map((q) => DropdownMenuItem(
                          value: q,
                          child: Text(q, style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedQuestion = val);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              onChanged: (_) {
                if (_answerEmptyError || _answerTooLong) {
                  setState(() {
                    _answerEmptyError = false;
                    _answerTooLong    = false;
                  });
                }
              },
              decoration: AppTheme.inputDecoration(
                'Your answer',
                error: _answerEmptyError
                    ? 'Answer is required'
                    : _answerTooLong
                        ? 'Answer is too long (max 72 characters)'
                        : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _pinController.clear(); // zero sensitive values from memory on cancel
            _hintController.clear();
            _answerController.clear();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : _submit,
          child: const Text('Set PIN'),
        ),
      ],
    );
  }
}
