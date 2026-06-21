import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

class PlanLimits {
  static const _whatsappNumber = '+919538923091';

  /// Shows an upgrade-required dialog with a WhatsApp contact option.
  static Future<bool> showLimitDialog(BuildContext context, String label, int current, int max) {
    final completer = Completer<bool>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plan Limit Reached'),
        content: Text(
          'You can add up to $max $label on your current plan.\n'
          'You already have $current $label.\n\n'
          'Upgrade to a paid plan for unlimited access.\n\n'
          'Contact us on WhatsApp to discuss plans.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              completer.complete(false);
            },
            child: const Text('Later'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.chat, size: 18),
            label: const Text('WhatsApp'),
            onPressed: () {
              Navigator.pop(ctx);
              _openWhatsApp();
              completer.complete(false);
            },
          ),
        ],
      ),
    );
    return completer.future;
  }

  static Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/$_whatsappNumber');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  static bool isLimitReached(int current, int max) => current >= max;
}
