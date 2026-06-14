import 'dart:async';

import 'package:flutter/material.dart';

class PlanLimits {
  /// Shows an upgrade-required dialog. Returns true if the user tapped "Try anyway" (offline demo).
  static Future<bool> showLimitDialog(BuildContext context, String label, int current, int max) {
    final completer = Completer<bool>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plan Limit Reached'),
        content: Text(
          'You can add up to $max $label on your current plan.\n'
          'You already have $current $label.\n\n'
          'Upgrade to a paid plan for unlimited access.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              completer.complete(false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return completer.future;
  }

  static bool isLimitReached(int current, int max) => current >= max;
}
