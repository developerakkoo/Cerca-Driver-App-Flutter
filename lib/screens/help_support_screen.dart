import 'package:flutter/material.dart';
import 'package:driver_cerca/constants/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone, color: AppColors.primary),
              title: const Text('Call Support'),
              subtitle: const Text('+91 1234567890'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _launchPhone('+911234567890'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email, color: AppColors.primary),
              title: const Text('Email Support'),
              subtitle: const Text('support@cerca.com'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _launchEmail('support@cerca.com'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
              title: const Text('Live Chat'),
              subtitle: const Text('Chat with our support team'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Live chat coming soon')),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ExpansionTile(
              title: const Text('How do I update my bank details?'),
              children: const [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Go to Profile > Payment Methods to update your bank account details.'),
                ),
              ],
            ),
          ),
          Card(
            child: ExpansionTile(
              title: const Text('How are my earnings calculated?'),
              children: const [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Your earnings are calculated as a percentage of the ride fare. Check your Earnings screen for detailed breakdown.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
