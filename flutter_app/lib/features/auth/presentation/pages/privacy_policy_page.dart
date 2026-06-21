import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Privacy Policy',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Last updated: June 2026',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          SizedBox(height: 24),
          _Section(
            title: '1. Information We Collect',
            body:
                'We collect minimal information to provide our GST billing service:\n\n'
                '- Business information (name, address, GSTIN) you provide\n'
                '- Invoice, customer, purchase, and expense data you enter\n'
                '- Device advertising ID (for serving ads)\n'
                '- Crash and usage analytics data',
          ),
          _Section(
            title: '2. How We Use Your Information',
            body:
                'Your data is stored locally on your device by default. When you '
                'opt for cloud backup, data is transmitted securely to our servers.\n\n'
                'We use the advertising ID to serve relevant ads in the free version of the app. '
                'No personal or business data is shared with advertisers.',
          ),
          _Section(
            title: '3. Data Storage & Security',
            body:
                'All sensitive data is stored locally using encrypted Hive databases. '
                'Cloud backups use TLS encryption in transit. You can delete all '
                'local data at any time by clearing app storage.',
          ),
          _Section(
            title: '4. Third-Party Services',
            body:
                'This app uses Google Mobile Ads (AdMob) to display advertisements. '
                'AdMob may collect and process device identifiers and usage data '
                'in accordance with Google\'s Privacy Policy.\n\n'
                'We do not sell, trade, or transfer your personally identifiable '
                'information to outside parties.',
          ),
          _Section(
            title: '5. Your Rights',
            body:
                'You can request deletion of your cloud-stored data by contacting us on WhatsApp. '
                'You may also disable data collection by uninstalling the app.',
          ),
          _Section(
            title: '6. Contact Us',
            body:
                'For privacy-related inquiries, contact us on WhatsApp:\n'
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
