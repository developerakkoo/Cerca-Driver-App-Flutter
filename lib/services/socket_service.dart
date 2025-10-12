import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:driver_cerca/services/storage_service.dart';
import 'package:driver_cerca/services/overlay_service.dart';
import 'package:driver_cerca/services/app_launcher_service.dart';
import 'package:driver_cerca/main.dart';
import 'package:driver_cerca/models/ride_model.dart';
import 'package:driver_cerca/models/message_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:async';

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
  static Timer? _locationTimer;
  static String? _currentRideId;
  static final List<RideModel> _pendingRides = [];
  static RideModel?
  _acceptedRideForNavigation; // Store accepted ride for navigation

  // Callbacks for UI updates
  static Function(List<RideModel>)? onRidesUpdated;
  static Function(RideModel)? onRideAccepted;
  static Function(MessageModel)? onMessageReceived;
  static Function(bool)? onConnectionStatusChanged;

  // Reconnection variables
  static int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static Timer? _reconnectTimer;

  // Initialization guard
  static bool _isInitialized = false;

  // Overlay listener subscription (keep it alive)
  static StreamSubscription? _overlayListenerSubscription;

  /// Get connection status
  static bool get isConnected => _isConnected;

  /// Get initialization status
  static bool get isInitialized => _isInitialized;

  /// Initialize socket connection
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ Socket already initialized, skipping...');
      return;
    }
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

      // Listen for messages from overlay (accept/reject actions)
      print('👂 Setting up overlay listener...');

      // Test if the stream is working
      try {
        print('🧪 Testing overlay listener stream...');
        print('   Stream: ${FlutterOverlayWindow.overlayListener}');
        print(
          '   Stream type: ${FlutterOverlayWindow.overlayListener.runtimeType}',
        );
      } catch (e) {
        print('❌ Error accessing overlay listener: $e');
      }

      _overlayListenerSubscription = FlutterOverlayWindow.overlayListener.listen(
        (data) {
          print('📨 !!!!! RECEIVED MESSAGE FROM OVERLAY !!!!!: $data');
          print('📨 Data type: ${data.runtimeType}');
          if (data is Map) {
            print('✅ Data is a Map, processing...');
            final action = data['action'];
            final rideId = data['rideId'];
            print('   Action: $action');
            print('   Ride ID: $rideId');

            if (action == 'acceptRide' && rideId != null) {
              print('✅ Processing ride acceptance from overlay: $rideId');

              // Find the ride in pending list
              final ride = _pendingRides.firstWhere(
                (r) => r.id == rideId,
                orElse: () => _pendingRides.first,
              );

              // ✅ Remove ride from pending list FIRST (before socket emit)
              _pendingRides.removeWhere((r) => r.id == rideId);
              print(
                '✅ Removed ride from pending list. Remaining: ${_pendingRides.length}',
              );

              // ✅ Notify UI to update pending rides list (if callback exists)
              if (onRidesUpdated != null) {
                print('✅ Notifying UI of list update');
                onRidesUpdated!(_pendingRides);
              } else {
                print(
                  'ℹ️ UI callback null (app in background), list still updated',
                );
              }

              // Emit socket event
              acceptRide(rideId);

              // ✅ Clear pending ride request data so it doesn't show again
              clearPendingRideRequest();

              // Store ride for navigation when app comes to foreground
              _acceptedRideForNavigation = ride;
              print('💾 Stored ride for navigation when app resumes');
              print(
                '🧹 Cleared pending ride data to prevent re-showing overlay',
              );

              // Close the overlay first
              FlutterOverlayWindow.closeOverlay()
                  .then((_) async {
                    print('✅ Overlay closed successfully');

                    // Try immediate navigation if app is in foreground
                    if (navigatorKey.currentState != null) {
                      print('🔑 App in foreground, navigating immediately');
                      try {
                        // Navigate to main navigation screen first, then to rides tab with active ride
                        navigatorKey.currentState
                            ?.pushNamedAndRemoveUntil('/main', (route) => false)
                            .then((_) {
                              // After navigating to main, push active ride screen
                              Future.delayed(
                                const Duration(milliseconds: 300),
                                () {
                                  navigatorKey.currentState?.pushNamed(
                                    '/active-ride',
                                    arguments: ride,
                                  );
                                },
                              );
                            });
                        print('✅ Direct navigation initiated');
                        _acceptedRideForNavigation =
                            null; // Clear after navigation
                      } catch (e) {
                        print('❌ Direct navigation failed: $e');
                      }
                    } else {
                      print(
                        '⏳ App in background, bringing app to foreground...',
                      );
                      // Bring app to foreground automatically
                      AppLauncherService.bringAppToForeground()
                          .then((success) {
                            print('✅ App foreground result: $success');
                          })
                          .catchError((error) {
                            print('❌ Error launching app: $error');
                          });
                    }

                    // Also try callback
                    if (onRideAccepted != null) {
                      try {
                        onRideAccepted!(ride);
                      } catch (e) {
                        print('❌ Callback execution failed: $e');
                      }
                    }
                  })
                  .catchError((error) {
                    print('❌ Error closing overlay: $error');
                  });
            } else if (action == 'rejectRide' && rideId != null) {
              print('❌ Processing ride rejection from overlay: $rideId');

              // ✅ Remove ride from pending list
              _pendingRides.removeWhere((r) => r.id == rideId);
              print(
                '✅ Removed ride from pending list. Remaining: ${_pendingRides.length}',
              );

              // ✅ Notify UI to update pending rides list (if callback exists)
              if (onRidesUpdated != null) {
                print('✅ Notifying UI of list update');
                onRidesUpdated!(_pendingRides);
              } else {
                print(
                  'ℹ️ UI callback null (app in background), list still updated',
                );
              }

              // ✅ Clear pending ride data when rejected
              clearPendingRideRequest();
              print('🧹 Cleared pending ride data after rejection');
            }
          }
        },
        onError: (error) {
          print('❌ Overlay listener error: $error');
        },
        onDone: () {
          print('✅ Overlay listener closed');
        },
      );
      print('✅ Overlay listener subscription created successfully');

      _isInitialized = true;
      print('✅ Socket service initialized successfully');
    } catch (e) {
      print('❌ Error initializing socket service: $e');
      _isInitialized = false;
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

      _socket = IO.io('http://192.168.1.18:3000', <String, dynamic>{
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
      _reconnectAttempts =
          0; // Reset reconnect attempts on successful connection
      _reconnectTimer?.cancel();
      _emitDriverConnect();
      if (onConnectionStatusChanged != null) {
        onConnectionStatusChanged!(true);
      }
    });

    _socket!.onDisconnect((_) {
      print('❌ Socket disconnected');
      _isConnected = false;
      if (onConnectionStatusChanged != null) {
        onConnectionStatusChanged!(false);
      }
      // Attempt to reconnect
      _attemptReconnect();
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

    // Ride assignment confirmation
    _socket!.on('rideAssigned', (data) {
      print('✅ Ride assigned successfully: $data');
      _handleRideAssigned(data);
    });

    // Ride error handling
    _socket!.on('rideError', (data) {
      print('❌ Ride error: $data');
      _handleRideError(data);
    });

    // OTP verification events
    _socket!.on('otpVerified', (data) {
      print('✅ OTP verified: $data');
      _handleOtpVerified(data);
    });

    _socket!.on('otpVerificationFailed', (data) {
      print('❌ OTP verification failed: $data');
      _handleOtpVerificationFailed(data);
    });

    // Ride lifecycle events
    // Driver arrived confirmation
    _socket!.on('driverArrived', (data) {
      print('✅ Driver arrived confirmation: $data');
      _handleDriverArrived(data);
    });

    _socket!.on('rideStarted', (data) {
      print('🚀 Ride started: $data');
      _handleRideStarted(data);
    });

    _socket!.on('rideCompleted', (data) {
      print('🏁 Ride completed: $data');
      _handleRideCompleted(data);
    });

    // Messaging events
    _socket!.on('receiveMessage', (data) {
      print('💬 Message received: $data');
      _handleReceiveMessage(data);
    });

    _socket!.on('messageSent', (data) {
      print('📤 Message sent confirmation: $data');
      _handleMessageSent(data);
    });

    _socket!.on('messageError', (data) {
      print('❌ Message error: $data');
      _handleMessageError(data);
    });

    // Rating events
    _socket!.on('ratingReceived', (data) {
      print('⭐ Rating received: $data');
      _handleRatingReceived(data);
    });

    _socket!.on('ratingSubmitted', (data) {
      print('⭐ Rating submitted confirmation: $data');
      _handleRatingSubmitted(data);
    });

    // Emergency events
    _socket!.on('emergencyAlert', (data) {
      print('🚨 EMERGENCY ALERT: $data');
      _handleEmergencyAlert(data);
    });

    _socket!.on('emergencyAlertCreated', (data) {
      print('🚨 Emergency alert created: $data');
      _handleEmergencyAlertCreated(data);
    });

    // Notification events
    _socket!.on('notifications', (data) {
      print('🔔 Notifications received: $data');
      _handleNotifications(data);
    });

    _socket!.on('notificationMarkedRead', (data) {
      print('✅ Notification marked as read: $data');
      _handleNotificationMarkedRead(data);
    });

    // Generic error event
    _socket!.on('errorEvent', (data) {
      print('❌ Error event: $data');
      _handleErrorEvent(data);
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

  /// Start location updates (every 5-10 seconds when online)
  static void startLocationUpdates({String? rideId}) {
    // Stop any existing timer first
    if (_locationTimer != null && _locationTimer!.isActive) {
      print('⚠️ Location updates already running, stopping old timer first');
      _locationTimer!.cancel();
      _locationTimer = null;
    }

    _currentRideId = rideId;
    final interval = rideId != null
        ? const Duration(seconds: 5) // 5 seconds during ride
        : const Duration(seconds: 10); // 10 seconds when idle

    print(
      '📍 Starting location updates (interval: ${interval.inSeconds}s, rideId: $rideId)',
    );

    _locationTimer = Timer.periodic(interval, (timer) async {
      await _emitLocationUpdate();
    });

    // Emit immediately
    _emitLocationUpdate();
  }

  /// Stop location updates
  static void stopLocationUpdates() {
    try {
      if (_locationTimer != null) {
        _locationTimer!.cancel();
        _locationTimer = null;
      }
      _currentRideId = null;
      print('🛑 Location updates stopped');
    } catch (e) {
      print('❌ Error stopping location updates: $e');
      // Force reset
      _locationTimer = null;
      _currentRideId = null;
    }
  }

  /// Emit driver location update
  static Future<void> _emitLocationUpdate() async {
    if (_socket == null || !_isConnected || _driverId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      final locationData = {
        'driverId': _driverId,
        'location': {
          'coordinates': [position.longitude, position.latitude],
        },
      };

      // Add rideId if driver is on a ride
      if (_currentRideId != null) {
        locationData['rideId'] = _currentRideId;
      }

      _socket!.emit('driverLocationUpdate', locationData);
      print('📍 Location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('❌ Error updating location: $e');
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

  /// Accept a ride
  static void acceptRide(String rideId) {
    if (_socket == null || !_isConnected || _driverId == null) {
      print('❌ Cannot accept ride: Socket not connected');
      print('   Socket: $_socket');
      print('   Connected: $_isConnected');
      print('   Driver ID: $_driverId');
      return;
    }

    try {
      final eventData = {'rideId': rideId, 'driverId': _driverId};
      print('📤 Emitting rideAccepted event:');
      print('   Event name: rideAccepted');
      print('   Ride ID: $rideId');
      print('   Driver ID: $_driverId');
      print('   Socket connected: $_isConnected');
      print('   Full data: $eventData');

      _socket!.emit('rideAccepted', eventData);
      print('✅ Emitted rideAccepted event for ride: $rideId');

      // Remove from pending rides
      _pendingRides.removeWhere((r) => r.id == rideId);
      if (onRidesUpdated != null) {
        onRidesUpdated!(_pendingRides);
      }
    } catch (e) {
      print('❌ Error accepting ride: $e');
      print('   Error details: ${e.toString()}');
    }
  }

  /// Emit driver arrived at pickup
  static void emitDriverArrived(String rideId) {
    print('🚗 emitDriverArrived called for ride: $rideId');
    print('   Socket: ${_socket != null ? "Connected" : "NULL"}');
    print('   Is Connected: $_isConnected');

    if (_socket == null || !_isConnected) {
      print('❌ Cannot emit driverArrived - socket not connected');
      return;
    }

    try {
      _socket!.emit('driverArrived', {'rideId': rideId});
      print('✅ Emitted driverArrived event');
      print('   Ride ID: $rideId');
    } catch (e) {
      print('❌ Error emitting driverArrived: $e');
    }
  }

  /// Verify start OTP
  static void verifyStartOtp(String rideId, String otp) {
    if (_socket == null || !_isConnected) return;

    try {
      _socket!.emit('verifyStartOtp', {'rideId': rideId, 'otp': otp});
      print('🔐 Verifying start OTP for ride: $rideId');
    } catch (e) {
      print('❌ Error verifying start OTP: $e');
    }
  }

  /// Start ride after OTP verification
  static void emitRideStarted(String rideId, String otp) {
    if (_socket == null || !_isConnected) return;

    try {
      _socket!.emit('rideStarted', {'rideId': rideId, 'otp': otp});
      print('🚀 Emitted rideStarted for ride: $rideId');
    } catch (e) {
      print('❌ Error emitting rideStarted: $e');
    }
  }

  /// Verify stop OTP
  static void verifyStopOtp(String rideId, String otp) {
    if (_socket == null || !_isConnected) return;

    try {
      _socket!.emit('verifyStopOtp', {'rideId': rideId, 'otp': otp});
      print('🔐 Verifying stop OTP for ride: $rideId');
    } catch (e) {
      print('❌ Error verifying stop OTP: $e');
    }
  }

  /// Complete ride after OTP verification
  static void emitRideCompleted(String rideId, double fare, String otp) {
    if (_socket == null || !_isConnected) return;

    try {
      _socket!.emit('rideCompleted', {
        'rideId': rideId,
        'fare': fare,
        'otp': otp,
      });
      print('🏁 Emitted rideCompleted for ride: $rideId with fare: ₹$fare');
    } catch (e) {
      print('❌ Error emitting rideCompleted: $e');
    }
  }

  /// Cancel ride
  static void cancelRide(String rideId, String reason) {
    if (_socket == null || !_isConnected) return;

    try {
      _socket!.emit('rideCancelled', {
        'rideId': rideId,
        'cancelledBy': 'driver',
        'reason': reason,
      });
      print('❌ Emitted rideCancelled for ride: $rideId');
    } catch (e) {
      print('❌ Error cancelling ride: $e');
    }
  }

  /// Send message to rider
  static void sendMessage({
    required String rideId,
    required String receiverId,
    required String message,
    String messageType = 'text',
  }) {
    if (_socket == null || !_isConnected || _driverId == null) return;

    try {
      _socket!.emit('sendMessage', {
        'rideId': rideId,
        'senderId': _driverId,
        'senderModel': 'Driver',
        'receiverId': receiverId,
        'receiverModel': 'User',
        'message': message,
        'messageType': messageType,
      });
      print('💬 Sent message to rider');
    } catch (e) {
      print('❌ Error sending message: $e');
    }
  }

  /// Submit rating for rider
  static void submitRating({
    required String rideId,
    required String riderId,
    required int rating,
    String? review,
    List<String>? tags,
  }) {
    if (_socket == null || !_isConnected || _driverId == null) return;

    try {
      _socket!.emit('submitRating', {
        'rideId': rideId,
        'ratedBy': _driverId,
        'ratedByModel': 'Driver',
        'ratedTo': riderId,
        'ratedToModel': 'User',
        'rating': rating,
        'review': review,
        'tags': tags ?? [],
      });
      print('⭐ Submitted rating: $rating stars');
    } catch (e) {
      print('❌ Error submitting rating: $e');
    }
  }

  /// Trigger emergency alert
  static void triggerEmergencyAlert({
    required String rideId,
    required double latitude,
    required double longitude,
    String? notes,
  }) {
    if (_socket == null || !_isConnected || _driverId == null) return;

    try {
      _socket!.emit('emergencyAlert', {
        'rideId': rideId,
        'triggeredBy': _driverId,
        'triggeredByModel': 'Driver',
        'location': {
          'coordinates': [longitude, latitude],
        },
        'notes': notes ?? 'Emergency triggered by driver',
      });
      print('🚨 Emergency alert triggered for ride: $rideId');
    } catch (e) {
      print('❌ Error triggering emergency alert: $e');
    }
  }

  /// Get notifications
  static void getNotifications() {
    if (_socket == null || !_isConnected || _driverId == null) return;

    try {
      _socket!.emit('getNotifications', {
        'userId': _driverId,
        'userModel': 'Driver',
      });
      print('🔔 Requested notifications');
    } catch (e) {
      print('❌ Error getting notifications: $e');
    }
  }

  /// Mark notification as read
  static void markNotificationRead(String notificationId) {
    if (_socket == null || !_isConnected) return;

    try {
      _socket!.emit('markNotificationRead', {'notificationId': notificationId});
      print('✅ Marked notification as read: $notificationId');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  /// Get pending rides list
  static List<RideModel> getPendingRides() => List.unmodifiable(_pendingRides);

  /// Clear all pending rides
  static void clearPendingRides() {
    _pendingRides.clear();
    if (onRidesUpdated != null) {
      onRidesUpdated!(_pendingRides);
    }
  }

  /// Disconnect from socket
  static Future<void> disconnect() async {
    try {
      if (_socket != null && _isConnected) {
        emitDriverDisconnect();
        stopTestEvents();
        stopLocationUpdates();
        clearPendingRides();
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

  /// Get socket instance
  static IO.Socket? get socket => _socket;

  // Event handlers
  static void _handleRideRequest(dynamic data) {
    // This will be handled by the overlay service
    print('🚗 Ride request received: $data');
  }

  static void _handleNewRideRequest(dynamic data) {
    print('🚗 New ride request received: $data');

    try {
      // Parse the complete ride object
      final ride = RideModel.fromJson(data);

      // Add to pending rides list
      _pendingRides.add(ride);
      print(
        '📋 Added ride to pending list. Total pending: ${_pendingRides.length}',
      );

      // ✅ Check if app is in foreground or background
      final isAppInForeground = onRidesUpdated != null;

      if (isAppInForeground) {
        // App is in FOREGROUND (HomeScreen visible)
        print('📱 App in foreground - showing ride in list only');
        onRidesUpdated!(_pendingRides); // Update UI list
        // DON'T show overlay - user can see the list
      } else {
        // App is in BACKGROUND
        print('🌙 App in background - showing overlay');
        _showRideRequestOverlay(ride); // Show overlay
      }
    } catch (e) {
      print('❌ Error handling new ride request: $e');
    }
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

  static void _handleRideAssigned(dynamic data) {
    print('✅ Ride successfully assigned to driver');
    try {
      final ride = RideModel.fromJson(data);
      print('🚗 Ride ID: ${ride.id}');
      print('🎯 Pickup: ${ride.pickupAddress}');
      print('📍 Dropoff: ${ride.dropoffAddress}');

      // TODO: Navigate to ActiveRideScreen
      // TODO: Start location updates with rideId
      startLocationUpdates(rideId: ride.id);
    } catch (e) {
      print('❌ Error parsing assigned ride: $e');
    }
  }

  static void _handleRideError(dynamic data) {
    print('❌ Ride assignment error: ${data['message']}');
    // TODO: Show error notification to driver
    // Common errors: "Ride already assigned to another driver"
  }

  static void _handleOtpVerified(dynamic data) {
    print('✅ OTP verified successfully: ${data['success']}');
    // UI will handle the next action based on which OTP was verified
  }

  static void _handleOtpVerificationFailed(dynamic data) {
    print('❌ OTP verification failed: ${data['message']}');
    // TODO: Show error to driver
  }

  static void _handleDriverArrived(dynamic data) {
    print('✅ Driver arrived at pickup confirmed');
    try {
      if (data is Map && data['ride'] != null) {
        final ride = RideModel.fromJson(data['ride']);
        print('🚗 Ride ID: ${ride.id}');
        print('📍 Status: ${ride.status.displayName}');
        print('⏰ Arrived at: ${ride.driverArrivedAt}');
        // TODO: Update UI to show arrived status
      }
    } catch (e) {
      print('❌ Error parsing driver arrived confirmation: $e');
    }
  }

  static void _handleRideStarted(dynamic data) {
    print('🚀 Ride started successfully');
    try {
      final ride = RideModel.fromJson(data);
      print('📍 Ride ID: ${ride.id}');
      print('⏱️ Started at: ${ride.actualStartTime}');
      // TODO: Update UI to show ride in progress
      // TODO: Start navigation to dropoff
      // TODO: Update location frequency to 5 seconds
      startLocationUpdates(rideId: ride.id);
    } catch (e) {
      print('❌ Error parsing started ride: $e');
    }
  }

  static void _handleRideCompleted(dynamic data) {
    print('🏁 Ride completed successfully');
    try {
      final ride = RideModel.fromJson(data);
      print('💰 Fare: ₹${ride.fare}');
      print('⏱️ Duration: ${ride.actualDuration} minutes');
      // Stop location updates
      stopLocationUpdates();
      // TODO: Show ride summary screen
      // TODO: Request rating from driver
    } catch (e) {
      print('❌ Error parsing completed ride: $e');
    }
  }

  static void _handleReceiveMessage(dynamic data) {
    print('💬 New message from rider: ${data['message']}');
    try {
      final message = MessageModel.fromJson(data);
      print('📨 Message ID: ${message.id}');
      print('   From: ${message.sender.role.name}');
      print('   Text: ${message.message}');

      // Notify UI via callback
      if (onMessageReceived != null) {
        onMessageReceived!(message);
      }

      // TODO: Show notification if app is in background
    } catch (e) {
      print('❌ Error parsing received message: $e');
    }
  }

  static void _handleMessageSent(dynamic data) {
    if (data['success'] == true) {
      print('✅ Message sent successfully');
      // TODO: Update chat UI with sent message
    }
  }

  static void _handleMessageError(dynamic data) {
    print('❌ Message error: ${data['message']}');
    // TODO: Show error in chat UI
  }

  static void _handleRatingReceived(dynamic data) {
    print('⭐ New rating received from rider');
    print('   Rating: ${data['rating']} stars');
    print('   Review: ${data['review']}');
    // TODO: Show notification
    // TODO: Update driver profile
  }

  static void _handleRatingSubmitted(dynamic data) {
    if (data['success'] == true) {
      print('✅ Rating submitted successfully');
      // TODO: Close rating dialog
    }
  }

  static void _handleEmergencyAlert(dynamic data) {
    print('🚨🚨🚨 EMERGENCY ALERT FROM RIDER 🚨🚨🚨');
    print('   Ride ID: ${data['rideId']}');
    print('   Location: ${data['location']}');
    print('   Notes: ${data['notes']}');
    // TODO: Show urgent emergency alert dialog
    // TODO: Consider auto-calling emergency services
  }

  static void _handleEmergencyAlertCreated(dynamic data) {
    if (data['success'] == true) {
      print('✅ Emergency alert sent to authorities');
      // TODO: Show confirmation to driver
    }
  }

  static void _handleNotifications(dynamic data) {
    print('🔔 Received notifications list');
    // TODO: Update notifications UI
    // TODO: Show badge count
  }

  static void _handleNotificationMarkedRead(dynamic data) {
    if (data['success'] == true) {
      print('✅ Notification marked as read');
      // TODO: Update notifications UI
    }
  }

  static void _handleErrorEvent(dynamic data) {
    print('❌ Generic error event: ${data['message']}');
    // TODO: Show error to driver
  }

  /// Show ride request overlay with ride data
  static void _showRideRequestOverlay(RideModel? ride) {
    try {
      print(
        '🎯 Received ride request in background - showing overlay immediately',
      );

      // Store ride data for overlay display
      _storeRideRequestData(ride);

      // Show overlay directly from background service
      _showOverlayFromBackground();

      // ✅ DON'T auto-clear here!
      // Data will be cleared when:
      // - Driver accepts ride (in overlay listener)
      // - Driver rejects ride (in overlay listener)
      // This prevents premature clearing while overlay is still shown
    } catch (e) {
      print('❌ Error handling ride request: $e');
    }
  }

  /// Show overlay directly from background service
  static void _showOverlayFromBackground() async {
    try {
      print('📱 Showing overlay directly from background service...');

      if (_currentRideDetails != null) {
        // Step 1: Show the overlay FIRST
        await OverlayService.showRideRequestOverlay(
          rideDetails: _currentRideDetails!,
          onAccept: _currentOnAccept,
          onReject: _currentOnReject,
        );

        print('📱 Overlay window created');

        // Step 2: Wait a moment for overlay to initialize
        await Future.delayed(const Duration(milliseconds: 500));

        // Step 3: THEN share ride data with overlay isolate
        // The overlay runs in a separate isolate and can't access Dart global variables
        await FlutterOverlayWindow.shareData(_currentRideDetails!);

        print('📤 Shared ride data with overlay isolate:');
        print('   Ride ID: ${_currentRideDetails?['rideId']}');
        print('   Passenger: ${_currentRideDetails?['passengerName']}');
        print('   Pickup: ${_currentRideDetails?['pickupLocation']}');
        print('   Dropoff: ${_currentRideDetails?['dropoffLocation']}');
        print('   Fare: ${_currentRideDetails?['estimatedFare']}');
      } else {
        print('❌ No ride data available for overlay');
      }
    } catch (e) {
      print('❌ Error showing overlay from background: $e');
    }
  }

  /// Store ride request data for later display
  static void _storeRideRequestData(RideModel? ride) {
    if (ride != null) {
      // Store the real ride data
      final Map<String, dynamic> rideData = {
        'rideId': ride.id,
        'passengerName': ride.rider?.fullName ?? 'Unknown Rider',
        'passengerRating': 4.5, // TODO: Get actual rider rating from API
        'passengerPhone': ride.rider?.phone ?? '',
        'pickupLocation': ride.pickupAddress,
        'dropoffLocation': ride.dropoffAddress,
        'distance': '${ride.distanceInKm.toStringAsFixed(1)} km',
        'estimatedFare': '₹${ride.fare.toStringAsFixed(0)}',
        'estimatedTime': '${ride.estimatedDuration ?? 0} minutes',
        'rideType': ride.rideType.displayName,
        'paymentMethod': ride.paymentMethod.displayName,
        'startOtp': ride.startOtp,
      };

      // Store the data globally for the overlay service
      _currentRideDetails = rideData;

      // Update global variables in main.dart for overlay
      currentRideDetails = rideData;

      currentOnAccept = () {
        print('✅ Ride ${ride.id} accepted from overlay');
        acceptRide(ride.id);
      };

      currentOnReject = () {
        print('❌ Ride ${ride.id} rejected from overlay');
        _pendingRides.removeWhere((r) => r.id == ride.id);
        if (onRidesUpdated != null) {
          onRidesUpdated!(_pendingRides);
        }
      };
    } else {
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

      _currentRideDetails = dummyRideData;

      // Also store in main.dart global variables
      currentRideDetails = dummyRideData;
      currentOnAccept = () => print('Dummy ride accepted');
      currentOnReject = () => print('Dummy ride rejected');

      print('💾 Ride request data stored for overlay display');
    }
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

  /// Get accepted ride waiting for navigation (when app was in background)
  static RideModel? getAcceptedRideForNavigation() {
    return _acceptedRideForNavigation;
  }

  /// Clear the accepted ride for navigation (after navigation is done)
  static void clearAcceptedRideForNavigation() {
    _acceptedRideForNavigation = null;
    print('🗑️ Cleared accepted ride for navigation');
  }

  /// Attempt to reconnect with exponential backoff
  static void _attemptReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('❌ Max reconnect attempts reached. Please restart the app.');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(
      seconds: 2 * _reconnectAttempts,
    ); // Exponential backoff

    print(
      '🔄 Attempting to reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      print('🔌 Reconnecting to socket...');
      await connect();
    });
  }

  /// Cleanup on app termination
  static void cleanup() {
    print('🧹 Cleaning up socket resources...');
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
  }

  /// Complete disposal of socket service
  static Future<void> dispose() async {
    print('🧹 Disposing socket service completely...');

    // Stop all timers
    _reconnectTimer?.cancel();
    _locationTimer?.cancel();
    stopLocationUpdates();
    stopTestEvents();

    // Cancel overlay listener subscription
    await _overlayListenerSubscription?.cancel();
    _overlayListenerSubscription = null;

    // Disconnect socket
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    // Clear all state
    _isConnected = false;
    _isInitialized = false;
    _reconnectAttempts = 0;
    _currentRideId = null;
    _pendingRides.clear();
    _acceptedRideForNavigation = null;

    // Clear callbacks
    onRidesUpdated = null;
    onRideAccepted = null;
    onMessageReceived = null;
    onConnectionStatusChanged = null;

    print('✅ Socket service disposed');
  }
}
