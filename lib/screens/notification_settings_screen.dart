import 'package:flutter/material.dart';
import 'package:driver_cerca/constants/constants.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _rideUpdates = true;
  bool _earningsUpdates = true;
  bool _promotions = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive push notifications'),
              value: _pushNotifications,
              onChanged: (value) {
                setState(() {
                  _pushNotifications = value;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Ride Updates'),
              subtitle: const Text('Notifications about ride requests and status'),
              value: _rideUpdates,
              onChanged: (value) {
                setState(() {
                  _rideUpdates = value;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Earnings Updates'),
              subtitle: const Text('Notifications about earnings and payouts'),
              value: _earningsUpdates,
              onChanged: (value) {
                setState(() {
                  _earningsUpdates = value;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Promotions'),
              subtitle: const Text('Special offers and promotions'),
              value: _promotions,
              onChanged: (value) {
                setState(() {
                  _promotions = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
