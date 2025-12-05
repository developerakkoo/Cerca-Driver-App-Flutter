import 'package:flutter/foundation.dart';
import 'package:driver_cerca/services/socket_service.dart';
import 'package:driver_cerca/models/ride_model.dart';
import 'package:driver_cerca/models/message_model.dart';

/// Connection state enum
enum ConnectionState { disconnected, connecting, connected, error }

/// SocketProvider manages socket connection state reactively
/// Uses singleton pattern - single instance managed by Provider
class SocketProvider extends ChangeNotifier {
  ConnectionState _connectionState = ConnectionState.disconnected;
  String? _socketId;
  String? _error;
  List<RideModel> _pendingRides = [];
  bool _isDriverOnline = false;

  // Getters
  ConnectionState get connectionState => _connectionState;
  String? get socketId => _socketId;
  bool get isConnected => _connectionState == ConnectionState.connected;
  List<RideModel> get pendingRides => List.unmodifiable(_pendingRides);
  bool get isDriverOnline => _isDriverOnline;
  String? get error => _error;

  /// Initialize SocketProvider and SocketService
  Future<void> initialize() async {
    print('🚀 [SocketProvider] initialize() called');
    try {
      await SocketService.initialize();
      print('✅ [SocketProvider] SocketService initialized');
      
      // Register callbacks to sync state
      _registerCallbacks();
      
      // Check if already connected
      if (SocketService.isConnected) {
        _connectionState = ConnectionState.connected;
        _socketId = SocketService.currentSocketId;
        print('✅ [SocketProvider] Socket already connected');
        print('   Socket ID: $_socketId');
        notifyListeners();
      }
    } catch (e) {
      print('❌ [SocketProvider] Error initializing: $e');
      _connectionState = ConnectionState.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Register callbacks with SocketService to sync state
  void _registerCallbacks() {
    print('📝 [SocketProvider] Registering callbacks with SocketService');
    
    SocketService.onConnectionStatusChanged = (bool connected) {
      print('📢 [SocketProvider] Connection status changed callback received');
      print('   Connected: $connected');
      print('   Current socket ID: ${SocketService.currentSocketId}');
      
      if (connected) {
        _connectionState = ConnectionState.connected;
        _socketId = SocketService.currentSocketId;
        _error = null;
        print('✅ [SocketProvider] State updated: connected');
        print('   Socket ID: $_socketId');
      } else {
        _connectionState = ConnectionState.disconnected;
        _socketId = null;
        print('❌ [SocketProvider] State updated: disconnected');
      }
      notifyListeners();
    };

    SocketService.onRidesUpdated = (List<RideModel> rides) {
      print('📢 [SocketProvider] Rides updated callback received');
      print('   Pending rides count: ${rides.length}');
      print('   Socket ID: $_socketId');
      _pendingRides = rides;
      notifyListeners();
    };

    SocketService.onRideAccepted = (RideModel ride) {
      print('📢 [SocketProvider] Ride accepted callback received');
      print('   Ride ID: ${ride.id}');
      print('   Socket ID: $_socketId');
      // Remove from pending if exists
      _pendingRides.removeWhere((r) => r.id == ride.id);
      notifyListeners();
    };

    SocketService.onRideStatusUpdated = (RideModel ride) {
      print('📢 [SocketProvider] Ride status updated callback received');
      print('   Ride ID: ${ride.id}');
      print('   Status: ${ride.status.displayName}');
      print('   Socket ID: $_socketId');
      // Update ride in pending list if exists
      final index = _pendingRides.indexWhere((r) => r.id == ride.id);
      if (index >= 0) {
        _pendingRides[index] = ride;
        notifyListeners();
      }
    };

    SocketService.onMessageReceived = (MessageModel message) {
      print('📢 [SocketProvider] Message received callback');
      print('   Message ID: ${message.id}');
      print('   Socket ID: $_socketId');
      // Handle message if needed
    };

    print('✅ [SocketProvider] All callbacks registered');
  }

  /// Connect to socket server
  Future<void> connect() async {
    print('🔌 [SocketProvider] connect() called');
    print('   Current state: $_connectionState');
    print('   Current socket ID: $_socketId');
    print('   Is connecting: ${SocketService.isConnecting}');

    if (_connectionState == ConnectionState.connected) {
      print('ℹ️ [SocketProvider] Already connected, skipping');
      return;
    }

    _connectionState = ConnectionState.connecting;
    _error = null;
    notifyListeners();
    print('📊 [SocketProvider] State updated: connecting');

    try {
      final success = await SocketService.connect();
      print('📊 [SocketProvider] SocketService.connect() completed');
      print('   Success: $success');
      print('   Socket ID: ${SocketService.currentSocketId}');

      if (success) {
        _connectionState = ConnectionState.connected;
        _socketId = SocketService.currentSocketId;
        _error = null;
        print('✅ [SocketProvider] Connection successful');
        print('   Socket ID: $_socketId');
        print('   Expected backend to store: $_socketId');
      } else {
        _connectionState = ConnectionState.error;
        _error = 'Connection failed';
        print('❌ [SocketProvider] Connection failed');
      }
    } catch (e) {
      _connectionState = ConnectionState.error;
      _error = e.toString();
      print('❌ [SocketProvider] Connection error: $e');
      print('   Socket ID: $_socketId');
    }

    notifyListeners();
    print('📢 [SocketProvider] State change notified to listeners');
  }

  /// Disconnect from socket server
  Future<void> disconnect() async {
    print('🔌 [SocketProvider] disconnect() called');
    print('   Current state: $_connectionState');
    print('   Current socket ID: $_socketId');

    _connectionState = ConnectionState.disconnected;
    _error = null;

    try {
      await SocketService.disconnect();
      _socketId = null;
      print('✅ [SocketProvider] Disconnected successfully');
    } catch (e) {
      _error = e.toString();
      print('❌ [SocketProvider] Disconnect error: $e');
    }

    notifyListeners();
  }

  /// Reconnect to socket server
  Future<void> reconnect() async {
    print('🔄 [SocketProvider] reconnect() called');
    print('   Current state: $_connectionState');
    print('   Current socket ID: $_socketId');

    await disconnect();
    await Future.delayed(const Duration(seconds: 1));
    await connect();
  }

  /// Set driver online status
  /// Connects socket when toggling to Online, disconnects when toggling to Offline
  void setDriverOnline(bool online) async {
    print('🚗 [SocketProvider] setDriverOnline() called');
    print('   New status: ${online ? "ONLINE" : "OFFLINE"}');
    print('   Current status: ${_isDriverOnline ? "ONLINE" : "OFFLINE"}');
    print('   Socket ID: $_socketId');
    print('   Connection state: $_connectionState');

    _isDriverOnline = online;
    
    if (online) {
      // Toggling to Online - connect socket if not already connected
      print('🔄 [SocketProvider] Toggling to ONLINE - connecting socket...');
      if (!isConnected) {
        print('🔌 [SocketProvider] Socket not connected, initiating connection...');
        await connect();
      } else {
        print('✅ [SocketProvider] Socket already connected');
        print('   Socket ID: $_socketId');
      }
      // Set driver online status in SocketService (emits driverToggleStatus)
      SocketService.setDriverOnline(online);
    } else {
      // Toggling to Offline - disconnect socket
      print('🔄 [SocketProvider] Toggling to OFFLINE - disconnecting socket...');
      // Set driver offline status in SocketService first (emits driverToggleStatus)
      SocketService.setDriverOnline(online);
      // Then disconnect socket
      if (isConnected) {
        print('🔌 [SocketProvider] Disconnecting socket...');
        await disconnect();
      } else {
        print('ℹ️ [SocketProvider] Socket already disconnected');
      }
    }
    
    notifyListeners();
    print('✅ [SocketProvider] Driver online status updated');
    print('   Final status: ${_isDriverOnline ? "ONLINE" : "OFFLINE"}');
    print('   Final connection state: $_connectionState');
    print('   Final socket ID: $_socketId');
  }

  /// Accept a ride
  void acceptRide(String rideId) {
    print('✅ [SocketProvider] acceptRide() called');
    print('   Ride ID: $rideId');
    print('   Socket ID: $_socketId');
    print('   Connection state: $_connectionState');

    if (!isConnected) {
      print('❌ [SocketProvider] Cannot accept ride: not connected');
      _error = 'Not connected to server';
      notifyListeners();
      return;
    }

    SocketService.acceptRide(rideId);
    // Remove from pending rides
    _pendingRides.removeWhere((r) => r.id == rideId);
    notifyListeners();
    print('✅ [SocketProvider] Ride accepted and removed from pending list');
  }

  /// Reject a ride
  void rejectRide(String rideId) {
    print('❌ [SocketProvider] rejectRide() called');
    print('   Ride ID: $rideId');
    print('   Socket ID: $_socketId');
    print('   Connection state: $_connectionState');

    if (!isConnected) {
      print('❌ [SocketProvider] Cannot reject ride: not connected');
      _error = 'Not connected to server';
      notifyListeners();
      return;
    }

    SocketService.rejectRide(rideId);
    // Remove from pending rides
    _pendingRides.removeWhere((r) => r.id == rideId);
    notifyListeners();
    print('✅ [SocketProvider] Ride rejected and removed from pending list');
  }

  /// Get pending rides
  List<RideModel> getPendingRides() {
    print('📋 [SocketProvider] getPendingRides() called');
    print('   Pending rides count: ${_pendingRides.length}');
    return List.unmodifiable(_pendingRides);
  }

  /// Clear error state
  void clearError() {
    print('🧹 [SocketProvider] clearError() called');
    _error = null;
    notifyListeners();
  }

  /// Print current state for debugging
  void printState() {
    print('🔍 [SocketProvider] Current State:');
    print('   Connection state: $_connectionState');
    print('   Socket ID: $_socketId');
    print('   Is connected: $isConnected');
    print('   Is driver online: $_isDriverOnline');
    print('   Pending rides: ${_pendingRides.length}');
    print('   Error: $_error');
    SocketService.printSocketState();
  }
}

