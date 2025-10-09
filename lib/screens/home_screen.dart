import 'package:flutter/material.dart';
import 'package:driver_cerca/services/permission_service.dart';
import 'package:driver_cerca/services/overlay_service.dart';
import 'package:driver_cerca/services/socket_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

// Top-level function for background service
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  print('Background service started');
  // Initialize and connect socket in background service
  await SocketService.initialize();
  final connected = await SocketService.connect();
  if (connected) {
    print('✅ Socket connected in background service');
    // Start test events in background
    SocketService.startTestEvents();
  } else {
    print('❌ Failed to connect socket in background service');
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<bool> isSelected = [
    false,
    true,
  ]; // [On, Off] - Off is selected by default
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPendingRideRequest();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkPendingRideRequest();
    }
  }

  /// Check for pending ride requests when app comes to foreground
  Future<void> _checkPendingRideRequest() async {
    if (SocketService.hasPendingRideRequest()) {
      print('🎯 Found pending ride request, showing overlay...');

      final rideDetails = SocketService.getPendingRideRequest();
      final onAccept = SocketService.getPendingOnAccept();
      final onReject = SocketService.getPendingOnReject();

      if (rideDetails != null) {
        await OverlayService.showRideRequestOverlay(
          rideDetails: rideDetails,
          onAccept: onAccept,
          onReject: onReject,
        );

        // Clear the pending request after showing
        SocketService.clearPendingRideRequest();
      }
    }
  }

  Future<void> _handleToggle(int index) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      if (index == 0) {
        // Toggle ON - Request permissions
        await _handleToggleOn();
      } else {
        // Toggle OFF - Stop services
        await _handleToggleOff();
      }
    } catch (e) {
      print('Error handling toggle: $e');
      _showErrorSnackBar('An error occurred. Please try again.');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleToggleOn() async {
    // Show permission dialog first
    final bool userAccepted = await PermissionService.showPermissionDialog(
      context,
    );

    if (!userAccepted) {
      // User cancelled, keep toggle off
      setState(() {
        isSelected = [false, true];
      });
      return;
    }

    // Show loading indicator
    _showLoadingSnackBar('Requesting permissions...');

    // Request all permissions
    final Map<String, bool> results =
        await PermissionService.requestAllPermissions();

    // Show permission status
    await PermissionService.showPermissionStatus(context, results);

    // Check if all permissions were granted
    final bool allGranted = results.values.every((isGranted) => isGranted);

    if (allGranted) {
      // All permissions granted, enable toggle
      setState(() {
        isSelected = [true, false];
      });
      _showSuccessSnackBar(
        'Driver mode enabled! You will now receive ride requests.',
      );

      // Start background service or overlay service here
      await _startDriverServices();

      // Start test events
      SocketService.startTestEvents();
    } else {
      // Some permissions denied, keep toggle off
      setState(() {
        isSelected = [false, true];
      });
      _showWarningSnackBar(
        'Some permissions were denied. Driver mode cannot be enabled.',
      );
    }
  }

  Future<void> _handleToggleOff() async {
    try {
      setState(() {
        isSelected = [false, true];
      });

      // Stop test events first
      SocketService.stopTestEvents();

      // Stop background services and disconnect socket
      await _stopDriverServices();

      _showInfoSnackBar(
        'Driver mode disabled. You will no longer receive ride requests.',
      );
    } catch (e) {
      print('Error handling toggle off: $e');
      _showErrorSnackBar('An error occurred while disabling driver mode.');
    }
  }

  Future<void> _startDriverServices() async {
    try {
      // Initialize socket service
      await SocketService.initialize();

      // Start background service
      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          isForegroundMode: false,
          autoStart: false,
          autoStartOnBoot: false,
          initialNotificationContent: "Cerca Service Activated. Don't Stop It.",
          initialNotificationTitle: "Cerca Service",
          notificationChannelId: 'foreground_service_channel',
          foregroundServiceNotificationId: 1,
        ),
        iosConfiguration: IosConfiguration(onForeground: onStart),
      );

      await service.startService();
      print('Background service started successfully');

      // Test overlay service after a delay
      await Future.delayed(const Duration(seconds: 2));

      final Map<String, dynamic> testRideDetails = {
        'rideId': 'TEST_001',
        'passengerName': 'Test Passenger',
        'passengerRating': 4.5,
        'pickupLocation': 'Test Pickup Location',
        'dropoffLocation': 'Test Dropoff Location',
        'distance': '1.0 km',
        'estimatedFare': '\$5.00',
        'estimatedTime': '5 minutes',
        'rideType': 'Test',
      };

      await OverlayService.showRideRequestOverlay(
        rideDetails: testRideDetails,
        onAccept: () {
          print('Test ride accepted');
          // Emit ride response to socket
          SocketService.emitRideResponse('TEST_001', 'accept');
        },
        onReject: () {
          print('Test ride rejected');
          // Emit ride response to socket
          SocketService.emitRideResponse('TEST_001', 'reject');
        },
      );
    } catch (e) {
      print('Error starting driver services: $e');
    }
  }

  Future<void> _stopDriverServices() async {
    try {
      // Disconnect socket first
      await SocketService.disconnect();
      print('Socket disconnected');

      // Stop background service
      final service = FlutterBackgroundService();
      var isRunning = await service.isRunning();
      if (isRunning) {
        service.invoke("stop");
        print('Background service stopped');
      }

      // Close overlay with timeout
      await OverlayService.closeOverlay().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('Stop services timed out');
        },
      );
      print('Driver services stopped successfully');
    } catch (e) {
      print('Error stopping driver services: $e');
      // Don't rethrow the error, just log it
    }
  }

  void _showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Dashboard"),
        backgroundColor: Colors.indigo[600],
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ToggleButtons(
              children: const <Widget>[
                Text("ON", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("OFF", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
              isSelected: isSelected,
              onPressed: _isProcessing ? null : _handleToggle,
              direction: Axis.horizontal,
              selectedColor: Colors.white,
              fillColor: Colors.green,
              color: Colors.grey[600],
              constraints: const BoxConstraints(minHeight: 40, minWidth: 60),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSelected[0]
                              ? Icons.directions_car
                              : Icons.directions_car_outlined,
                          color: isSelected[0] ? Colors.green : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Driver Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSelected[0]
                          ? 'You are online and ready to receive ride requests'
                          : 'You are offline and will not receive ride requests',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Instructions Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How to use:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Toggle ON to enable driver mode\n'
                      '2. Grant all required permissions\n'
                      '3. You will receive ride requests via overlay\n'
                      '4. Accept or reject rides as they come',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            if (_isProcessing) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
