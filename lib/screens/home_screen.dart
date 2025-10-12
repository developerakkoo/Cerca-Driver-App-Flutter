import 'package:flutter/material.dart';
import 'package:driver_cerca/services/permission_service.dart';
import 'package:driver_cerca/services/overlay_service.dart';
import 'package:driver_cerca/services/socket_service.dart';
import 'package:driver_cerca/models/ride_model.dart';
import 'package:driver_cerca/screens/active_ride_screen.dart';
import 'package:driver_cerca/widgets/connection_status_indicator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Top-level function for background service
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  print('📱 Background service started');

  // Listen for stop command
  service.on('stop').listen((event) {
    print('🛑 Stop command received in background service');
    SocketService.stopTestEvents();
    SocketService.stopLocationUpdates();
    service.stopSelf();
  });

  // ✅ DON'T initialize socket here - it's already initialized in main app!
  // The socket is a singleton and shared across the entire app including background service

  print('✅ Background service ready (using existing socket connection)');

  // Socket is already connected from main app, just verify
  if (SocketService.isConnected) {
    print('✅ Socket already connected from main app');
    SocketService.startTestEvents();
  } else {
    print('⏳ Waiting for socket connection from main app...');
    // Wait a bit and check again
    await Future.delayed(const Duration(seconds: 2));
    if (SocketService.isConnected) {
      print('✅ Socket connected');
      SocketService.startTestEvents();
    } else {
      print('⚠️ Socket not connected yet');
    }
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
  List<RideModel> _pendingRides = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDriverStatus(); // Load saved driver status
    _checkPendingRideRequest();
    _registerCallback();
  }

  /// Load driver online/offline status from storage
  Future<void> _loadDriverStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isOnline = prefs.getBool('driver_is_online') ?? false;

    if (mounted) {
      setState(() {
        isSelected = [isOnline, !isOnline];
      });

      print('📱 Loaded driver status: ${isOnline ? "ONLINE" : "OFFLINE"}');

      // If driver was online, ensure services are running
      if (isOnline && SocketService.isConnected) {
        print('✅ Driver was online, services should be running');
      }
    }
  }

  /// Save driver online/offline status to storage
  Future<void> _saveDriverStatus(bool isOnline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('driver_is_online', isOnline);
    print('💾 Saved driver status: ${isOnline ? "ONLINE" : "OFFLINE"}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // ❌ DON'T clear callback in dispose - it prevents rides from showing
    // when user navigates between tabs. Callback is only cleared when
    // app goes to background (in didChangeAppLifecycleState)
    super.dispose();
  }

  /// Register the callback for ride updates
  void _registerCallback() {
    print('📝 Registering ride updates callback');
    SocketService.onRidesUpdated = (rides) {
      if (mounted) {
        setState(() {
          _pendingRides = rides;
        });
      }
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // ✅ Re-register callback when app comes to foreground
      print('📱 App resumed - registering ride updates callback');
      _registerCallback();

      // ✅ Sync with current pending rides from SocketService
      setState(() {
        _pendingRides = SocketService.getPendingRides();
        print('✅ Synced pending rides. Count: ${_pendingRides.length}');
      });

      // ✅ Check for overlay actions from SharedPreferences FIRST (must await!)
      _checkOverlayAction().then((_) {
        // ✅ IMPORTANT: Check accepted ride FIRST, then pending requests
        // This prevents showing stale overlay for already-accepted ride
        _checkPendingAcceptedRide();
        _checkPendingRideRequest();
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // ✅ Clear callback when app goes to background so overlay can be shown
      print('🌙 App backgrounded - clearing ride updates callback');
      SocketService.onRidesUpdated = null;
    }
  }

  /// Check for pending accepted ride and navigate if found
  void _checkPendingAcceptedRide() {
    final acceptedRide = SocketService.getAcceptedRideForNavigation();
    if (acceptedRide != null) {
      print('📱 [HomeScreen] Found pending accepted ride from background!');
      print('   Ride ID: ${acceptedRide.id}');

      // Clear it
      SocketService.clearAcceptedRideForNavigation();

      // Navigate
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveRideScreen(ride: acceptedRide),
        ),
      );
    }
  }

  /// Check for overlay actions from SharedPreferences (backup method)
  Future<void> _checkOverlayAction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final action = prefs.getString('overlay_action');
      final rideId = prefs.getString('overlay_rideId');
      final timestamp = prefs.getInt('overlay_timestamp');

      if (action != null && rideId != null && timestamp != null) {
        // Check if action is recent (within last 60 seconds)
        final now = DateTime.now().millisecondsSinceEpoch;
        final ageInSeconds = (now - timestamp) / 1000;
        print('📱 Found overlay action in SharedPreferences:');
        print('   Action: $action');
        print('   Ride ID: $rideId');
        print('   Age: ${ageInSeconds.toStringAsFixed(1)} seconds');

        if (now - timestamp < 60000) {
          if (action == 'acceptRide') {
            print('✅ Processing accept from SharedPreferences');
            SocketService.acceptRide(rideId);
          } else if (action == 'rejectRide') {
            print('❌ Processing reject from SharedPreferences');
            // Just remove from list
            setState(() {
              _pendingRides = _pendingRides
                  .where((r) => r.id != rideId)
                  .toList();
            });
          }
        } else {
          print(
            '⏰ Overlay action too old (${ageInSeconds.toStringAsFixed(1)}s), ignoring',
          );
        }

        // Clear the stored action
        await prefs.remove('overlay_action');
        await prefs.remove('overlay_rideId');
        await prefs.remove('overlay_timestamp');
      }
    } catch (e) {
      print('❌ Error checking overlay action: $e');
    }
  }

  /// Check for pending ride requests when app comes to foreground
  ///
  /// IMPORTANT: Overlays are ONLY triggered by socket events in background.
  /// This prevents stale/duplicate overlays from stored data on app resume.
  Future<void> _checkPendingRideRequest() async {
    print(
      '⏭️ Skipping overlay check on resume - overlays only from socket events',
    );
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

      // ✅ Save driver status as ONLINE
      await _saveDriverStatus(true);

      _showSuccessSnackBar(
        'Driver mode enabled! You will now receive ride requests.',
      );

      // Start background service or overlay service here
      await _startDriverServices();

      // Start test events
      SocketService.startTestEvents();

      // Start location updates
      SocketService.startLocationUpdates();
    } else {
      // Some permissions denied, keep toggle off
      setState(() {
        isSelected = [false, true];
      });

      // ✅ Save driver status as OFFLINE
      await _saveDriverStatus(false);

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

      // ✅ Save driver status as OFFLINE
      await _saveDriverStatus(false);

      // Stop test events first
      SocketService.stopTestEvents();

      // Stop location updates
      SocketService.stopLocationUpdates();

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
      // Socket is already initialized in main(), just ensure it's connected
      if (!SocketService.isConnected) {
        print('🔌 Socket not connected, connecting now...');
        await SocketService.connect();
      } else {
        print('✅ Socket already connected');
      }

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
      print('✅ Background service started successfully');
    } catch (e) {
      print('❌ Error starting driver services: $e');
    }
  }

  Future<void> _stopDriverServices() async {
    try {
      // ✅ DON'T disconnect socket - keep it connected for app functionality
      // Just stop location updates and test events
      print('🛑 Stopping driver services (keeping socket connected)...');

      // Stop background service
      final service = FlutterBackgroundService();
      var isRunning = await service.isRunning();
      if (isRunning) {
        service.invoke("stop");
        print('✅ Background service stopped');
      }

      // Close overlay with timeout
      await OverlayService.closeOverlay().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('⏱️ Stop services timed out');
        },
      );
      print('✅ Driver services stopped successfully');
    } catch (e) {
      print('❌ Error stopping driver services: $e');
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
          const Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: ConnectionStatusIndicator(),
          ),
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

            // Pending Rides List (only show when driver is online)
            if (isSelected[0] && _pendingRides.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Pending Ride Requests (${_pendingRides.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _pendingRides.length,
                  itemBuilder: (context, index) {
                    final ride = _pendingRides[index];
                    return _buildRideCard(ride);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRideCard(RideModel ride) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.indigo[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride.rider?.fullName ?? 'Unknown Rider',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '4.5', // TODO: Get actual rating
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₹${ride.fare.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLocationRow(
              Icons.my_location,
              'Pickup',
              ride.pickupAddress,
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildLocationRow(
              Icons.location_on,
              'Dropoff',
              ride.dropoffAddress,
              Colors.red,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  Icons.route,
                  '${ride.distanceInKm.toStringAsFixed(1)} km',
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.access_time,
                  '${ride.estimatedDuration ?? 0} min',
                ),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.payment, ride.paymentMethod.displayName),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Remove from local list - create new list to avoid unmodifiable error
                      setState(() {
                        _pendingRides = _pendingRides
                            .where((r) => r.id != ride.id)
                            .toList();
                      });
                      _showInfoSnackBar('Ride rejected');
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[600],
                      side: BorderSide(color: Colors.red[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Remove from local list immediately - create new list to avoid unmodifiable error
                      setState(() {
                        _pendingRides = _pendingRides
                            .where((r) => r.id != ride.id)
                            .toList();
                      });

                      // Emit accept socket event
                      SocketService.acceptRide(ride.id);

                      _showSuccessSnackBar('Ride accepted! Navigating...');

                      // Navigate to ActiveRideScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActiveRideScreen(ride: ride),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Accept Ride'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
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
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                address,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
