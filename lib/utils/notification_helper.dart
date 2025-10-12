import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:driver_cerca/services/overlay_service.dart';
import 'package:driver_cerca/services/socket_service.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize notification plugin
  static Future<void> initialize() async {
    try {
      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      // Combined initialization settings
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      // Initialize the plugin
      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      print('📱 Notification helper initialized');
    } catch (e) {
      print('❌ Error initializing notification helper: $e');
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    try {
      print('🔔 Notification tapped: ${response.payload}');

      // Check if it's a ride request notification
      if (response.payload?.startsWith('ride_request_') == true) {
        print('🚗 Ride request notification tapped - showing overlay');

        // Show overlay when notification is tapped
        _showRideRequestOverlay();
      }
    } catch (e) {
      print('❌ Error handling notification tap: $e');
    }
  }

  /// Show ride request overlay when notification is tapped
  static void _showRideRequestOverlay() {
    try {
      // Check if there's pending ride data
      if (SocketService.hasPendingRideRequest()) {
        final rideDetails = SocketService.getPendingRideRequest();
        final onAccept = SocketService.getPendingOnAccept();
        final onReject = SocketService.getPendingOnReject();

        if (rideDetails != null) {
          // Show the overlay
          OverlayService.showRideRequestOverlay(
            rideDetails: rideDetails,
            onAccept: onAccept,
            onReject: onReject,
          
          );

          print('📱 Overlay shown from notification tap');
          print('📱 Ride ID: ${rideDetails['rideId']}');
          print('📱 Passenger: ${rideDetails['passengerName']}');
        }
      } else {
        print('❌ No pending ride request data found');
      }
    } catch (e) {
      print('❌ Error showing ride request overlay: $e');
    }
  }

  /// Show a notification
  static Future<void> showNotification(
    String title,
    String body,
    String payload,
  ) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'ride_requests',
            'Ride Requests',
            channelDescription: 'Notifications for incoming ride requests',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      print('📱 Notification shown: $title');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    try {
      await _notifications.cancelAll();
      print('📱 All notifications cancelled');
    } catch (e) {
      print('❌ Error cancelling notifications: $e');
    }
  }
}
