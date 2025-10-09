import 'dart:ui';

import 'package:driver_cerca/screens/home_screen.dart';
import 'package:driver_cerca/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:io';
import 'package:driver_cerca/utils/notification_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:driver_cerca/services/overlay_service.dart';
import 'package:driver_cerca/services/auth_service.dart';

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  print('Service started');
  DartPluginRegistrant.ensureInitialized();

  for (var i = 0; i < 10; i++) {
    print('Service running $i');
    NotificationHelper.showNotification(
      'Service running',
      'Service running $i',
      'service_running_$i',
    );
    await Future.delayed(const Duration(seconds: 2));
  }

  service.stopSelf();
}

// Global variables to store overlay data
Map<String, dynamic>? currentRideDetails;
Function()? currentOnAccept;
Function()? currentOnReject;

// Overlay entry point
@pragma("vm:entry-point")
void overlayMain() {
  // Dummy ride data for testing
  final Map<String, dynamic> dummyRideData = {
    'rideId': 'RIDE_${DateTime.now().millisecondsSinceEpoch}',
    'passengerName': 'John Doe',
    'passengerRating': 4.8,
    'pickupLocation': '123 Main Street, Downtown',
    'dropoffLocation': '456 Oak Avenue, Uptown',
    'distance': '2.5 km',
    'estimatedFare': '\$12.50',
    'estimatedTime': '8 minutes',
    'rideType': 'Standard',
  };

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        child: RideRequestOverlay(
          rideDetails: dummyRideData,
          onAccept: () {
            print('✅ Ride accepted from overlay');
            FlutterOverlayWindow.closeOverlay();
          },
          onReject: () {
            print('❌ Ride rejected from overlay');
            FlutterOverlayWindow.closeOverlay();
          },
        ),
      ),
    ),
  );
}

@pragma("vm:entry-point")
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AuthService
  await AuthService.initialize();

  // Create notification channels
  final androidPlugin = FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  // Create channel for regular notifications
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'notification_channel',
      'Notification Channel',
      description: 'Channel for regular notifications',
      importance: Importance.high,
    ),
  );

  // Create channel for foreground service
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'foreground_service_channel',
      'Foreground Service Channel',
      description: 'Channel for foreground service notifications',
      importance: Importance.low,
    ),
  );

  // Initialize notification helper
  await NotificationHelper.initialize();

  // Background service will now be controlled by the home page toggle
  // No automatic initialization here

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Removed automatic overlay initialization
    // Overlay will now only be controlled by the home page toggle
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cerca Driver',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Overlay Widget - Ride Request Interface
class RideRequestOverlay extends StatefulWidget {
  final Map<String, dynamic> rideDetails;
  final Function()? onAccept;
  final Function()? onReject;

  const RideRequestOverlay({
    super.key,
    required this.rideDetails,
    this.onAccept,
    this.onReject,
  });

  @override
  State<RideRequestOverlay> createState() => _RideRequestOverlayState();
}

class _RideRequestOverlayState extends State<RideRequestOverlay> {
  void _handleAcceptRide() {
    print('=== RIDE ACCEPTED ===');
    print('Ride ID: ${widget.rideDetails['rideId']}');
    print('Passenger: ${widget.rideDetails['passengerName']}');
    print('Pickup: ${widget.rideDetails['pickupLocation']}');
    print('Dropoff: ${widget.rideDetails['dropoffLocation']}');
    print('Fare: ${widget.rideDetails['estimatedFare']}');
    print('Time: ${widget.rideDetails['estimatedTime']}');
    print('====================');

    // Call custom onAccept callback if provided
    widget.onAccept?.call();

    // Close overlay after accepting
    FlutterOverlayWindow.closeOverlay();
  }

  void _handleRejectRide() {
    print('=== RIDE REJECTED ===');
    print('Ride ID: ${widget.rideDetails['rideId']}');
    print('Passenger: ${widget.rideDetails['passengerName']}');
    print('Pickup: ${widget.rideDetails['pickupLocation']}');
    print('Dropoff: ${widget.rideDetails['dropoffLocation']}');
    print('Fare: ${widget.rideDetails['estimatedFare']}');
    print('Time: ${widget.rideDetails['estimatedTime']}');
    print('====================');

    // Call custom onReject callback if provided
    widget.onReject?.call();

    // Close overlay after rejecting
    FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 800,
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 57, 171, 120),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'New Ride Request',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to accept or reject',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Ride Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Passenger Info
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.indigo[100],
                        child: Text(
                          widget.rideDetails['passengerName'][0],
                          style: TextStyle(
                            color: Colors.indigo[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.rideDetails['passengerName'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.rideDetails['passengerRating']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Location Details
                  _buildLocationRow(
                    Icons.my_location,
                    'Pickup',
                    widget.rideDetails['pickupLocation'],
                    Colors.green,
                  ),

                  const SizedBox(height: 10),

                  _buildLocationRow(
                    Icons.location_on,
                    'Dropoff',
                    widget.rideDetails['dropoffLocation'],
                    Colors.red,
                  ),

                  const SizedBox(height: 16),

                  // Ride Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoColumn(
                          Icons.straighten,
                          'Distance',
                          widget.rideDetails['distance'],
                        ),
                        _buildInfoColumn(
                          Icons.attach_money,
                          'Fare',
                          widget.rideDetails['estimatedFare'],
                        ),
                        _buildInfoColumn(
                          Icons.access_time,
                          'Time',
                          widget.rideDetails['estimatedTime'],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  // Reject Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleRejectRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Reject',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Accept Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleAcceptRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Accept',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(
    IconData icon,
    String label,
    String address,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoColumn(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.indigo[600], size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.indigo[700],
          ),
        ),
      ],
    );
  }
}
