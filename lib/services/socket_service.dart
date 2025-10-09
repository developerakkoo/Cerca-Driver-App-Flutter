import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:driver_cerca/services/storage_service.dart';
import 'package:driver_cerca/services/overlay_service.dart';
import 'package:driver_cerca/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

// Global variables to store ride request data
Map<String, dynamic>? _currentRideDetails;
Function()? _currentOnAccept;
Function()? _currentOnReject;

class SocketService {
  static IO.Socket? _socket;
  static bool _isConnected = false;
  static String? _driverId;
  static String? _token;
  static Timer? _testEventTimer;

  /// Initialize socket connection
  static Future<void> initialize() async {
    try {
      // Get stored driver credentials
      _driverId = await StorageService.getDriverId();
      _token = await StorageService.getToken();

      if (_driverId == null || _token == null) {
        print('❌ Socket initialization failed: Missing driver credentials');
        return;
      }

      print('🔌 Initializing socket connection...');
      print('📦 Driver ID: $_driverId');
      print('🔑 Token: ${_token!.substring(0, 20)}...');
    } catch (e) {
      print('❌ Error initializing socket service: $e');
    }
  }

  /// Connect to socket server
  static Future<bool> connect() async {
    try {
      if (_isConnected) {
        print('🔌 Socket already connected');
        return true;
      }

      if (_driverId == null || _token == null) {
        print('❌ Cannot connect: Missing driver credentials');
        return false;
      }

      print('🔌 Connecting to socket server...');

      _socket = IO.io('http://192.168.1.14:3000', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      // Set up event listeners
      _setupEventListeners();

      // Connect to server
      _socket!.connect();

      // Wait for connection with timeout
      await _waitForConnection();

      return _isConnected;
    } catch (e) {
      print('❌ Error connecting to socket: $e');
      return false;
    }
  }

  /// Set up socket event listeners
  static void _setupEventListeners() {
    if (_socket == null) return;

    // Connection events
    _socket!.onConnect((_) {
      print('✅ Socket connected successfully');
      _isConnected = true;
      _emitDriverConnect();
    });

    _socket!.onDisconnect((_) {
      print('❌ Socket disconnected');
      _isConnected = false;
    });

    _socket!.onConnectError((error) {
      print('❌ Socket connection error: $error');
      _isConnected = false;
    });

    _socket!.onError((error) {
      print('❌ Socket error: $error');
    });

    // Custom events
    _socket!.on('rideRequest', (data) {
      print('🚗 Received ride request: $data');
      _handleRideRequest(data);
    });

    _socket!.on('newRideRequest', (data) {
      print('🚗 Received new ride request: $data');
      _handleNewRideRequest(data);
    });

    _socket!.on('rideCancelled', (data) {
      print('❌ Ride cancelled: $data');
      _handleRideCancelled(data);
    });

    _socket!.on('driverStatusUpdate', (data) {
      print('📊 Driver status update: $data');
      _handleDriverStatusUpdate(data);
    });

    _socket!.on('serverMessage', (data) {
      print('📨 Server message: $data');
      _handleServerMessage(data);
    });
  }

  /// Wait for socket connection with timeout
  static Future<void> _waitForConnection() async {
    int attempts = 0;
    const maxAttempts = 30; // 30 seconds timeout

    while (!_isConnected && attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 1));
      attempts++;
    }

    if (!_isConnected) {
      print('❌ Socket connection timeout');
    }
  }

  /// Emit driver connect event
  static void _emitDriverConnect() {
    if (_socket == null || !_isConnected || _driverId == null) return;

    try {
      _socket!.emit('driverConnect', {'driverId': _driverId});
      print('📤 Emitted driverConnect event');
    } catch (e) {
      print('❌ Error emitting driverConnect: $e');
    }
  }

  /// Emit driver disconnect event
  static void emitDriverDisconnect() {
    if (_socket == null || !_isConnected || _driverId == null) return;

    try {
      _socket!.emit('driverDisconnect', {
        'driverId': _driverId,
        'status': 'offline',
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('📤 Emitted driverDisconnect event');
    } catch (e) {
      print('❌ Error emitting driverDisconnect: $e');
    }
  }

  /// Start emitting test events
  static void startTestEvents() {
    try {
      print('🧪 Starting test events...');

      // Emit initial test event
      _emitTestEvent();

      // Start timer for continuous test events every 5 seconds
      _testEventTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _emitTestEvent();
      });
    } catch (e) {
      print('❌ Error starting test events: $e');
    }
  }

  /// Stop emitting test events
  static void stopTestEvents() {
    try {
      _testEventTimer?.cancel();
      _testEventTimer = null;
      print('🧪 Test events stopped');
    } catch (e) {
      print('❌ Error stopping test events: $e');
    }
  }

  /// Emit test event
  static void _emitTestEvent() {
    if (_socket == null || !_isConnected || _driverId == null) return;

    try {
      _socket!.emit('test', {
        'driverId': _driverId,
        'message': 'Test event from driver app',
        'timestamp': DateTime.now().toIso8601String(),
        'data': 'This is a test string for background socket testing',
      });
      print('📤 Emitted test event');
    } catch (e) {
      print('❌ Error emitting test event: $e');
    }
  }

  /// Emit ride response (accept/reject)
  static void emitRideResponse(
    String rideId,
    String response, {
    Map<String, dynamic>? data,
  }) {
    if (_socket == null || !_isConnected || _driverId == null) return;

    try {
      _socket!.emit('rideResponse', {
        'rideId': rideId,
        'driverId': _driverId,
        'response': response, // 'accept' or 'reject'
        'timestamp': DateTime.now().toIso8601String(),
        ...?data,
      });
      print('📤 Emitted rideResponse: $response for ride $rideId');
    } catch (e) {
      print('❌ Error emitting rideResponse: $e');
    }
  }

  /// Emit location update
  static void emitLocationUpdate(double lat, double lng) {
    if (_socket == null || !_isConnected || _driverId == null) return;

    try {
      _socket!.emit('locationUpdate', {
        'driverId': _driverId,
        'location': {'longitude': lng, 'latitude': lat},
      });
      print('📤 Emitted location update: $lat, $lng');
    } catch (e) {
      print('❌ Error emitting location update: $e');
    }
  }

  /// Emit driver status update
  static void emitDriverStatus(String status) {
    if (_socket == null || !_isConnected || _driverId == null) return;

    try {
      _socket!.emit('driverStatus', {
        'driverId': _driverId,
        'status': status, // 'online', 'offline', 'busy', 'available'
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('📤 Emitted driver status: $status');
    } catch (e) {
      print('❌ Error emitting driver status: $e');
    }
  }

  /// Disconnect from socket
  static Future<void> disconnect() async {
    try {
      if (_socket != null && _isConnected) {
        emitDriverDisconnect();
        stopTestEvents();
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
        _isConnected = false;
        print('🔌 Socket disconnected');
      }
    } catch (e) {
      print('❌ Error disconnecting socket: $e');
    }
  }

  /// Check if socket is connected
  static bool get isConnected => _isConnected;

  /// Get socket instance
  static IO.Socket? get socket => _socket;

  // Event handlers
  static void _handleRideRequest(dynamic data) {
    // This will be handled by the overlay service
    print('🚗 Ride request received: $data');
  }

  static void _handleNewRideRequest(dynamic data) {
    print('🚗 New ride request received: $data');

    // Show overlay with dummy data for now
    _showRideRequestOverlay();
  }

  static void _handleRideCancelled(dynamic data) {
    print('❌ Ride cancelled: $data');
  }

  static void _handleDriverStatusUpdate(dynamic data) {
    print('📊 Driver status updated: $data');
  }

  static void _handleServerMessage(dynamic data) {
    print('📨 Server message: $data');
  }

  /// Show ride request overlay with dummy data
  static void _showRideRequestOverlay() {
    try {
      print(
        '🎯 Received ride request in background - showing overlay immediately',
      );

      // Store ride data for when overlay is shown
      _storeRideRequestData();

      // Show overlay directly from background service
      _showOverlayFromBackground();
    } catch (e) {
      print('❌ Error handling ride request: $e');
    }
  }

  /// Show overlay directly from background service
  static void _showOverlayFromBackground() {
    try {
      print('📱 Showing overlay directly from background service...');

      if (_currentRideDetails != null) {
        // Use the same overlay service as the login screen test button
        OverlayService.showRideRequestOverlay(
          rideDetails: _currentRideDetails!,
          onAccept: _currentOnAccept,
          onReject: _currentOnReject,
        );

        print('📱 Overlay shown from background service using OverlayService');
        print('📱 Ride ID: ${_currentRideDetails?['rideId']}');
        print('📱 Passenger: ${_currentRideDetails?['passengerName']}');
        print('📱 Pickup: ${_currentRideDetails?['pickupLocation']}');
        print('📱 Dropoff: ${_currentRideDetails?['dropoffLocation']}');
      } else {
        print('❌ No ride data available for overlay');
      }
    } catch (e) {
      print('❌ Error showing overlay from background: $e');
    }
  }

  /// Store ride request data for later display
  static void _storeRideRequestData() async {
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

    // Store the data globally for the overlay service
    _currentRideDetails = dummyRideData;
    _currentOnAccept = () => _handleRideAccept();
    _currentOnReject = () => _handleRideReject();

    // Also store in main.dart global variables
    currentRideDetails = dummyRideData;
    currentOnAccept = () => _handleRideAccept();
    currentOnReject = () => _handleRideReject();

    // Store in SharedPreferences for overlay access
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_ride_details', jsonEncode(dummyRideData));
      print('💾 Ride request data stored in SharedPreferences');
    } catch (e) {
      print('❌ Error storing ride data in SharedPreferences: $e');
    }

    print('💾 Ride request data stored for overlay display');
  }

  /// Handle ride acceptance
  static void _handleRideAccept() {
    print('✅ Ride accepted');
    emitRideResponse('RIDE_${DateTime.now().millisecondsSinceEpoch}', 'accept');
  }

  /// Handle ride rejection
  static void _handleRideReject() {
    print('❌ Ride rejected');
    emitRideResponse('RIDE_${DateTime.now().millisecondsSinceEpoch}', 'reject');
  }

  /// Update driver credentials
  static Future<void> updateCredentials() async {
    _driverId = await StorageService.getDriverId();
    _token = await StorageService.getToken();
    print('🔄 Updated socket credentials');
  }

  /// Check if there's a pending ride request to show
  static bool hasPendingRideRequest() {
    return _currentRideDetails != null;
  }

  /// Get pending ride request data
  static Map<String, dynamic>? getPendingRideRequest() {
    return _currentRideDetails;
  }

  /// Get pending ride request callbacks
  static Function()? getPendingOnAccept() {
    return _currentOnAccept;
  }

  static Function()? getPendingOnReject() {
    return _currentOnReject;
  }

  /// Clear pending ride request data
  static void clearPendingRideRequest() {
    _currentRideDetails = null;
    _currentOnAccept = null;
    _currentOnReject = null;
    print('🧹 Cleared pending ride request data');
  }
}
