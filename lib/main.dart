import 'dart:ui';
import 'dart:async';

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
import 'package:driver_cerca/services/audio_service.dart';
import 'package:driver_cerca/services/storage_service.dart';
import 'package:driver_cerca/providers/auth_provider.dart';
import 'package:driver_cerca/providers/earnings_provider.dart';
import 'package:driver_cerca/providers/socket_provider.dart';
import 'package:driver_cerca/providers/payout_provider.dart';
import 'package:driver_cerca/constants/constants.dart';
import 'package:provider/provider.dart';

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

    // Initialize StorageService for overlay isolate
    StorageService.initialize().catchError((e) {
      print('⚠️ Error initializing StorageService in overlay: $e');
    });

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

  // ✅ Defer socket initialization to after app starts
  // This ensures UI can render first without blocking
  runApp(const MyApp());

  // Initialize socket after app is running (non-blocking)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeSocketAfterAppStart();
  });
}

// Helper function to initialize socket after app starts
// Note: SocketProvider now handles socket initialization and connection
Future<void> _initializeSocketAfterAppStart() async {
  print('🔌 [main] Initializing socket via SocketProvider...');
  // SocketProvider will handle initialization and connection
  // Connection will happen automatically when provider is created
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
    // ✅ Don't connect socket here - it's already handled in main()
    // If connection failed in main(), it will retry on app resume
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
      print('📱 [main] App resumed, checking socket connection...');
      // ✅ Use SocketService directly instead of Provider to avoid context issues
      // The context in didChangeAppLifecycleState is outside the Provider tree
      if (!SocketService.isConnected) {
        print(
          '📱 [main] Socket disconnected, will reconnect via SocketProvider in HomeScreen...',
        );
        // SocketProvider will handle reconnection when HomeScreen resumes
      } else {
        print('✅ [main] Socket already connected');
        print('   Socket ID: ${SocketService.currentSocketId}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => EarningsProvider()),
        ChangeNotifierProvider(create: (_) => PayoutProvider()),
        ChangeNotifierProvider(create: (_) => SocketProvider()..initialize()),
      ],
      child: MaterialApp(
        title: 'Cerca Driver',
        navigatorKey:
            navigatorKey, // Global navigator key for background navigation
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          primaryColor: AppColors.primary,
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
      ),
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
  Timer? _timeoutTimer;
  int _remainingSeconds = 15;

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
    _playNotificationSound();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    // Stop any playing sound when overlay is disposed
    _stopSound();
    super.dispose();
  }

  /// Play notification sound when overlay appears
  /// Since overlay runs in separate isolate, AudioService needs to be initialized here
  /// Only plays sound if driver is authenticated AND overlay has valid ride data
  Future<void> _playNotificationSound() async {
    try {
      // Check 1: Verify driver is actually authenticated (has valid token)
      final token = await StorageService.getToken();
      if (token == null || token.isEmpty) {
        print('⛔ Cannot play sound: Driver not authenticated (no token found)');
        return;
      }

      // Check 2: Verify driver ID exists
      final driverId = await StorageService.getDriverId();
      if (driverId == null) {
        print('⛔ Cannot play sound: Driver not logged in (no driver ID found)');
        return;
      }

      // Check 3: Verify overlay has valid ride data (not default/stale data)
      // Default ride data has 'Unknown Rider' or 'RIDE_' prefix in rideId
      final rideId = widget.rideDetails['rideId']?.toString() ?? '';
      if (rideId.isEmpty || 
          rideId.startsWith('RIDE_') || 
          widget.rideDetails['passengerName'] == 'Unknown Rider') {
        print('⛔ Cannot play sound: Overlay showing stale/default ride data');
        return;
      }

      print('🔊 Driver is authenticated, initializing AudioService in overlay isolate...');
      // Initialize AudioService in overlay isolate context
      await AudioService.instance.initialize();
      print('✅ AudioService initialized in overlay');
      
      print('🔊 Playing notification sound in overlay...');
      await AudioService.instance.playRideRequestSound();
      print('✅ Notification sound playback started');
    } catch (e) {
      print('⚠️ Error playing notification sound in overlay (non-critical): $e');
      // Don't throw - gracefully degrade if sound cannot play
    }
  }

  /// Stop sound playback
  Future<void> _stopSound() async {
    try {
      await AudioService.instance.stop();
      print('🛑 Sound stopped in overlay');
    } catch (e) {
      print('⚠️ Error stopping sound: $e');
    }
  }

  void _startTimeoutTimer() {
    // Start a 15-second countdown timer
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      print('🕒 Timer running: $_remainingSeconds seconds remaining');
      if (_remainingSeconds <= 1) {
        print('🕒 Timer expired: $_remainingSeconds seconds remaining');
        timer.cancel();
        _handleTimeout();
      } else {
        print('🕒 Timer running: $_remainingSeconds seconds remaining');
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  void _handleTimeout() {
    print('⏰ Overlay timeout after 15 seconds - auto-closing');
    // Close the overlay
    FlutterOverlayWindow.closeOverlay();
    // Clear pending ride data
    if (widget.onReject != null) {
      widget.onReject?.call();
    }
  }

  void _handleOpenApp() {
    print('📱 User clicked to open app from overlay');
    print('   Ride ID: ${widget.rideDetails['rideId']}');

    // Cancel the timeout timer since user took action
    _timeoutTimer?.cancel();

    // Call the onAccept callback (which just closes overlay now)
    widget.onAccept?.call();
  }

  /// Calculate estimated time in minutes based on distance
  /// Assumes average speed of 35 km/h for city driving
  String _calculateEstimatedTime(String distanceStr) {
    try {
      // Parse distance string (e.g., "2.5 km" -> 2.5)
      final distanceMatch = RegExp(r'([\d.]+)\s*km').firstMatch(distanceStr);
      if (distanceMatch == null) {
        // If parsing fails, return the original estimatedTime or a default
        return widget.rideDetails['estimatedTime'] ?? 'N/A';
      }

      final distanceKm = double.tryParse(distanceMatch.group(1) ?? '0');
      if (distanceKm == null || distanceKm <= 0) {
        return widget.rideDetails['estimatedTime'] ?? 'N/A';
      }

      // Calculate time: distance (km) / speed (km/h) * 60 = minutes
      // Using average city speed of 35 km/h
      const averageSpeedKmh = 35.0;
      final timeInMinutes = (distanceKm / averageSpeedKmh * 60).round();

      // Format as "X minutes" or "X min"
      if (timeInMinutes == 1) {
        return '1 minute';
      } else if (timeInMinutes < 60) {
        return '$timeInMinutes minutes';
      } else {
        final hours = timeInMinutes ~/ 60;
        final minutes = timeInMinutes % 60;
        if (minutes == 0) {
          return hours == 1 ? '1 hour' : '$hours hours';
        } else {
          return '$hours h ${minutes} min';
        }
      }
    } catch (e) {
      print('❌ Error calculating estimated time: $e');
      return widget.rideDetails['estimatedTime'] ?? 'N/A';
    }
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tap to accept or reject',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_remainingSeconds',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          widget.rideDetails['passengerName'][0],
                          style: TextStyle(
                            color: AppColors.primary,
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
                          _calculateEstimatedTime(
                            widget.rideDetails['distance'],
                          ),
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
                    backgroundColor: AppColors.primary,
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
                        'Open App to Accept or Reject Ride!',
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
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
