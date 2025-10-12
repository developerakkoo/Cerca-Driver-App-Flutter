import 'dart:ui';

import 'package:driver_cerca/screens/home_screen.dart';
import 'package:driver_cerca/screens/login_screen.dart';
import 'package:driver_cerca/screens/main_navigation_screen.dart';
import 'package:driver_cerca/screens/active_ride_screen.dart';
import 'package:driver_cerca/screens/rides_screen.dart';
import 'package:driver_cerca/screens/register_screen.dart';
import 'package:driver_cerca/screens/document_upload_screen.dart';
import 'package:driver_cerca/screens/profile_screen.dart';
import 'package:driver_cerca/screens/earnings_screen.dart';
import 'package:driver_cerca/screens/edit_profile_screen.dart';
import 'package:driver_cerca/screens/vehicle_details_screen.dart';
import 'package:driver_cerca/screens/documents_screen.dart';
import 'package:driver_cerca/models/ride_model.dart';
import 'package:driver_cerca/models/driver_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:driver_cerca/utils/notification_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:driver_cerca/services/auth_service.dart';
import 'package:driver_cerca/services/socket_service.dart';

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

// Global navigator key for navigation from background
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Overlay entry point
@pragma("vm:entry-point")
void overlayMain() {
  runApp(const OverlayApp());
}

class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  Map<String, dynamic>? _rideData;

  @override
  void initState() {
    super.initState();

    // Listen for ride data from main isolate
    FlutterOverlayWindow.overlayListener.listen((data) {
      print('🎧 Overlay received data: $data');
      if (data is Map && mounted) {
        setState(() {
          _rideData = Map<String, dynamic>.from(data);
        });
        print('🎨 Overlay updated with ride data:');
        print('   Passenger: ${_rideData?['passengerName']}');
        print('   Pickup: ${_rideData?['pickupLocation']}');
        print('   Dropoff: ${_rideData?['dropoffLocation']}');
        print('   Fare: ${_rideData?['estimatedFare']}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rideData =
        _rideData ??
        currentRideDetails ??
        {
          'rideId': 'RIDE_${DateTime.now().millisecondsSinceEpoch}',
          'passengerName': 'Unknown Rider',
          'passengerRating': 0.0,
          'pickupLocation': 'Pickup location not available',
          'dropoffLocation': 'Dropoff location not available',
          'distance': '0 km',
          'estimatedFare': '₹0',
          'estimatedTime': '0 minutes',
          'rideType': 'Normal',
        };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        child: RideRequestOverlay(
          rideDetails: rideData,
          onAccept: () {
            print('📱 User clicked to open app from overlay');
            print('   Ride ID: ${rideData['rideId']}');

            // Just close overlay - ride is already in the pending list
            // User will see it in the app and can accept/reject from there
            FlutterOverlayWindow.closeOverlay();
          },
          onReject: null, // No reject callback needed
        ),
      ),
    );
  }
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

  // ✅ Initialize socket service ONCE globally
  print('🔌 Initializing global socket service...');
  await SocketService.initialize();

  // ✅ Connect socket immediately (don't wait for MyApp)
  print('🔌 Connecting socket from main()...');
  final connected = await SocketService.connect();
  if (connected) {
    print('✅ Socket connected successfully in main()');
  } else {
    print('⚠️ Socket connection failed in main()');
  }

  // Background service will now be controlled by the home page toggle
  // No automatic initialization here

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectSocket();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SocketService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconnect if disconnected when app comes to foreground
      if (!SocketService.isConnected) {
        print('📱 App resumed, reconnecting socket...');
        SocketService.connect();
      }
    }
  }

  Future<void> _connectSocket() async {
    // Check if already connected (from main())
    if (SocketService.isConnected) {
      print('✅ Socket already connected from main()');
      return;
    }

    print('🔌 Connecting to socket from MyApp...');
    final connected = await SocketService.connect();
    if (connected) {
      print('✅ Global socket connected in MyApp');
    } else {
      print('⚠️ Socket connection failed in MyApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cerca Driver',
      navigatorKey:
          navigatorKey, // Global navigator key for background navigation
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/main': (context) => const MainNavigationScreen(),
        '/register': (context) => const RegisterScreen(),
        '/rides': (context) => const RidesScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/earnings': (context) => const EarningsScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle routes with arguments
        if (settings.name == '/active-ride') {
          final ride = settings.arguments as RideModel;
          return MaterialPageRoute(
            builder: (context) => ActiveRideScreen(ride: ride),
          );
        } else if (settings.name == '/document-upload') {
          final driverId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => DocumentUploadScreen(driverId: driverId),
          );
        } else if (settings.name == '/edit-profile') {
          final driver = settings.arguments as DriverModel;
          return MaterialPageRoute(
            builder: (context) => EditProfileScreen(driver: driver),
          );
        } else if (settings.name == '/vehicle-details') {
          final driver = settings.arguments as DriverModel;
          return MaterialPageRoute(
            builder: (context) => VehicleDetailsScreen(driver: driver),
          );
        } else if (settings.name == '/documents') {
          final driver = settings.arguments as DriverModel;
          return MaterialPageRoute(
            builder: (context) => DocumentsScreen(driver: driver),
          );
        }
        return null;
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
  void _handleOpenApp() {
    print('📱 User clicked to open app from overlay');
    print('   Ride ID: ${widget.rideDetails['rideId']}');

    // Call the onAccept callback (which just closes overlay now)
    widget.onAccept?.call();
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

            // Action Button - Open App
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleOpenApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.open_in_new, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Open App to Accept/Reject',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
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
