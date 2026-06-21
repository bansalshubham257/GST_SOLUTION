import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Terms of Service',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Last updated: June 2026',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          SizedBox(height: 24),
          _Section(
            title: '1. Acceptance of Terms',
            body:
                'By using Business Solution ("the App"), you agree to these Terms of Service. '
                'If you do not agree, do not use the App.',
          ),
          _Section(
            title: '2. Description of Service',
            body:
                'The App provides GST billing, invoice management, stock tracking, '
                'and related business tools. The free version is ad-supported. '
                'Paid versions remove advertisements.',
          ),
          _Section(
            title: '3. User Responsibilities',
            body:
                'You are responsible for:\n\n'
                '- Accuracy of data entered into the App\n'
                '- Compliance with GST laws and regulations in India\n'
                '- Maintaining backup copies of your data\n'
                '- Not using the App for illegal purposes',
          ),
          _Section(
            title: '4. Data Backup & Loss',
            body:
                'The App provides local and cloud backup features. However, we '
                'are not responsible for data loss due to device failure, '
                'uninstallation, or user error. We recommend regular backups.',
          ),
          _Section(
            title: '5. Limitation of Liability',
            body:
                'The App is provided "as is" without warranty. We are not liable '
                'for any damages arising from the use or inability to use the App, '
                'including but not limited to financial losses from incorrect '
                'GST calculations or data entry errors.',
          ),
          _Section(
            title: '6. Changes to Terms',
            body:
                'We reserve the right to modify these terms at any time. '
                'Continued use of the App after changes constitutes acceptance.',
          ),
          _Section(
            title: '7. Contact',
            body:
                'For questions about these terms, contact us on WhatsApp:\n'
                '+91 9538923091',
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
