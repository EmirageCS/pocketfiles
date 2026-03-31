import 'package:flutter/material.dart';
import '../services/file_service.dart';
import '../utils/constants.dart';

/// Dialog shown after a successful unlock if there were failed attempts
/// since the last visit. Displays timestamps of each failed attempt.
class SecurityAlertDialog extends StatelessWidget {
  final List<DateTime> attempts;

  const SecurityAlertDialog({super.key, required this.attempts});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // shape comes from global DialogThemeData in main.dart
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          const Text('Security Alert'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${attempts.length} failed unlock attempt${attempts.length > 1 ? 's' : ''} since your last visit:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...attempts.take(kMaxSecurityAlertItems).map((time) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      FileService.formatDateTime(time),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              )),
          if (attempts.length > kMaxSecurityAlertItems)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '...and ${attempts.length - kMaxSecurityAlertItems} more',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
