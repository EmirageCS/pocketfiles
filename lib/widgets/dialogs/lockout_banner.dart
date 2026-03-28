import 'package:flutter/material.dart';

/// Red warning banner shown during brute-force lockout.
/// Displays [seconds] remaining until the user may try again.
class LockoutBanner extends StatelessWidget {
  final int seconds;

  const LockoutBanner({super.key, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: errorColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: errorColor.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_rounded, color: errorColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Too many attempts. Try again in $seconds seconds.',
              style: TextStyle(color: errorColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
