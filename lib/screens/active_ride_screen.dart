import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driver_cerca/models/ride_model.dart';
import 'package:driver_cerca/models/driver_model.dart';
import 'package:driver_cerca/services/socket_service.dart';
import 'package:driver_cerca/widgets/rating_dialog.dart';
import 'package:driver_cerca/screens/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

/// ActiveRideScreen shows the current active ride with Google Maps
/// Features: Live driver tracking, route display, navigation controls
class ActiveRideScreen extends StatefulWidget {
  final RideModel ride;

  const ActiveRideScreen({super.key, required this.ride});

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  late RideModel _ride;
  bool _isLoading = false;
  int _unreadMessageCount = 0;

  // Google Maps
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentDriverLocation;
  StreamSubscription<Position>? _locationSubscription;
  PolylinePoints polylinePoints = PolylinePoints();

  // Map UI state
  bool _isMapExpanded = true;
  final double _expandedMapHeight = 400;
  final double _collapsedMapHeight = 200;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    _loadUnreadMessageCount();
    _initializeMap();
    _startLocationTracking();
    _setupRideStatusListener();
  }

  void _setupRideStatusListener() {
    print('🎧 [ActiveRideScreen] Setting up ride status listener for ride: ${_ride.id}');
    print('   Current status: ${_ride.status.displayName}');

    // Listen for rideAssigned event (sent when ride is first accepted)
    SocketService.onRideAssigned = (assignedRide) {
      print('🔔 [ActiveRideScreen] rideAssigned event received');
      print('   Assigned Ride ID: ${assignedRide.id}');
      print('   Current Ride ID: ${_ride.id}');
      print('   Assigned Status: ${assignedRide.status.displayName}');
      print('   Mounted: $mounted');

      if (assignedRide.id == _ride.id && mounted) {
        print('   ✅ Updating ride from rideAssigned event...');
        setState(() {
          _ride = assignedRide;
        });
        print(
          '   ✅ Ride updated in UI: ${assignedRide.status.displayName}',
        );
      } else {
        print('   ⚠️ Skipping update - ID mismatch or not mounted');
      }
    };

    // Listen for ride status updates from socket
    SocketService.onRideStatusUpdated = (updatedRide) {
      print('🔔 [ActiveRideScreen] Ride status update received');
      print('   Updated Ride ID: ${updatedRide.id}');
      print('   Current Ride ID: ${_ride.id}');
      print('   Match: ${updatedRide.id == _ride.id}');
      print('   Mounted: $mounted');
      print('   New Status: ${updatedRide.status.displayName}');
      print('   Current Status: ${_ride.status.displayName}');

      if (updatedRide.id == _ride.id && mounted) {
        print('   ✅ Updating ride state...');
        setState(() {
          _ride = updatedRide;
        });
        print(
          '   ✅ Ride status updated in UI: ${updatedRide.status.displayName}',
        );

        // If ride just completed, show rating dialog
        if (updatedRide.status == RideStatus.completed) {
          _handleRideCompletion();
        }
      } else {
        print('   ⚠️ Skipping update - ID mismatch or not mounted');
      }
    };

    // Listen for stop OTP verification success
    SocketService.onOtpVerifiedForCompletion = (rideId, otp) async {
      print('🔑 Stop OTP verified, emitting rideCompleted...');
      if (rideId == _ride.id && mounted) {
        // Emit rideCompleted with fare
        SocketService.emitRideCompleted(_ride.id, _ride.fare, otp);
      }
    };

    // Listen for OTP verification failures
    SocketService.onOtpVerificationFailed = (message) {
      print('❌ OTP verification failed: $message');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $message'), backgroundColor: Colors.red),
        );
      }
    };
  }

  Future<void> _handleRideCompletion() async {
    print('🏁 Handling ride completion...');
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Ride completed')));

      // Show rating dialog for the rider
      if (_ride.rider != null) {
        await showRatingDialog(
          context: context,
          rideId: _ride.id,
          riderId: _ride.rider!.id,
          riderName: _ride.rider!.fullName,
        );
      }

      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    SocketService.onRideAssigned = null; // Clear callback
    SocketService.onRideStatusUpdated = null; // Clear callback
    SocketService.onOtpVerifiedForCompletion = null; // Clear callback
    SocketService.onOtpVerificationFailed = null; // Clear callback
    super.dispose();
  }

  void _loadUnreadMessageCount() {
    // TODO: Implement actual unread message count from MessageService
    setState(() {
      _unreadMessageCount = 0;
    });
  }

  Future<void> _initializeMap() async {
    // Get current location
    try {
      final position = await Geolocator.getCurrentPosition();
      _currentDriverLocation = LatLng(position.latitude, position.longitude);
      _updateMarkers();
      _drawRoute();
    } catch (e) {
      print('❌ Error getting location: $e');
    }
  }

  void _startLocationTracking() {
    // Listen to location changes
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            setState(() {
              _currentDriverLocation = LatLng(
                position.latitude,
                position.longitude,
              );
              _updateMarkers();
              _updateCameraPosition();
            });

            // Emit location update via socket
            SocketService.emitLocationUpdate(
              position.latitude,
              position.longitude,
            );
          },
        );
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    // Driver marker (current location)
    if (_currentDriverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _currentDriverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'You'),
          rotation: 0, // TODO: Add heading/bearing
        ),
      );
    }

    // Pickup marker
    final pickupCoords = _ride.pickupLocation.coordinates;
    if (pickupCoords.length >= 2) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pickupCoords[1], pickupCoords[0]),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: 'Pickup', snippet: _ride.pickupAddress),
        ),
      );
    }

    // Dropoff marker
    final dropoffCoords = _ride.dropoffLocation.coordinates;
    if (dropoffCoords.length >= 2) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(dropoffCoords[1], dropoffCoords[0]),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Dropoff',
            snippet: _ride.dropoffAddress,
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _drawRoute() async {
    if (_currentDriverLocation == null) return;

    final pickupCoords = _ride.pickupLocation.coordinates;
    if (pickupCoords.length < 2) return;

    final pickup = LatLng(pickupCoords[1], pickupCoords[0]);
    final dropoffCoords = _ride.dropoffLocation.coordinates;
    final dropoff = LatLng(dropoffCoords[1], dropoffCoords[0]);

    // For now, create a simple straight line polyline
    // TODO: Use Google Directions API for actual route
    final polylineCoordinates = <LatLng>[];

    // Add route: Driver -> Pickup -> Dropoff
    polylineCoordinates.add(_currentDriverLocation!);
    polylineCoordinates.add(pickup);
    polylineCoordinates.add(dropoff);

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.indigo,
          width: 5,
          points: polylineCoordinates,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    });
  }

  void _updateCameraPosition() {
    if (_mapController == null || _currentDriverLocation == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newLatLng(_currentDriverLocation!),
    );
  }

  void _fitMarkersInView() {
    if (_mapController == null || _markers.isEmpty) return;

    LatLngBounds bounds;
    final positions = _markers.map((m) => m.position).toList();

    if (positions.length == 1) {
      bounds = LatLngBounds(southwest: positions[0], northeast: positions[0]);
    } else {
      double minLat = positions[0].latitude;
      double maxLat = positions[0].latitude;
      double minLng = positions[0].longitude;
      double maxLng = positions[0].longitude;

      for (var pos in positions) {
        if (pos.latitude < minLat) minLat = pos.latitude;
        if (pos.latitude > maxLat) maxLat = pos.latitude;
        if (pos.longitude < minLng) minLng = pos.longitude;
        if (pos.longitude > maxLng) maxLng = pos.longitude;
      }

      bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
    }

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  // Ride control methods
  Future<void> _handleDriverArrived() async {
    HapticFeedback.mediumImpact(); // Haptic feedback
    setState(() => _isLoading = true);
    try {
      SocketService.emitDriverArrived(_ride.id);

      // Backend doesn't send confirmation event, so we need to update status locally
      // Create a new ride object with updated status
      final updatedRide = RideModel(
        id: _ride.id,
        rider: _ride.rider,
        driver: _ride.driver,
        pickupAddress: _ride.pickupAddress,
        dropoffAddress: _ride.dropoffAddress,
        pickupLocation: _ride.pickupLocation,
        dropoffLocation: _ride.dropoffLocation,
        fare: _ride.fare,
        distanceInKm: _ride.distanceInKm,
        status: RideStatus.arrived, // Update status
        rideType: _ride.rideType,
        cancelledBy: _ride.cancelledBy,
        startOtp: _ride.startOtp,
        stopOtp: _ride.stopOtp,
        paymentMethod: _ride.paymentMethod,
        paymentStatus: _ride.paymentStatus,
        driverSocketId: _ride.driverSocketId,
        userSocketId: _ride.userSocketId,
        actualStartTime: _ride.actualStartTime,
        actualEndTime: _ride.actualEndTime,
        estimatedDuration: _ride.estimatedDuration,
        actualDuration: _ride.actualDuration,
        estimatedArrivalTime: _ride.estimatedArrivalTime,
        driverArrivedAt: DateTime.now(), // Set arrived time
        riderRating: _ride.riderRating,
        driverRating: _ride.driverRating,
        tips: _ride.tips,
        discount: _ride.discount,
        promoCode: _ride.promoCode,
        cancellationReason: _ride.cancellationReason,
        cancellationFee: _ride.cancellationFee,
        transactionId: _ride.transactionId,
        customSchedule: _ride.customSchedule,
        createdAt: _ride.createdAt,
        updatedAt: DateTime.now(),
      );

      print('✅ [ActiveRideScreen] Updating ride status...');
      print('   Old status: ${_ride.status.displayName}');
      print('   New status: ${updatedRide.status.displayName}');
      
      setState(() {
        _ride = updatedRide;
        _isLoading = false; // Stop loading immediately
      });

      print('✅ [ActiveRideScreen] Status updated successfully');
      print('   Current ride status: ${_ride.status.displayName}');
      print('   UI should rebuild and show appropriate button');
      
      // Verify the state change
      if (_ride.status == RideStatus.arrived) {
        print('   ✅ Status is now "arrived" - "Start Ride" button should be visible');
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Marked as arrived')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStartRide() async {
    final otp = await _showOTPDialog(context, 'Enter Start OTP');
    if (otp == null || otp.isEmpty) return;

    HapticFeedback.heavyImpact(); // Strong haptic feedback for ride start
    setState(() => _isLoading = true);
    try {
      SocketService.verifyStartOtp(_ride.id, otp);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Ride started')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Invalid OTP or error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStopRide() async {
    final otp = await _showOTPDialog(context, 'Enter Stop OTP');
    if (otp == null || otp.isEmpty) return;

    HapticFeedback.heavyImpact(); // Strong haptic feedback for ride completion
    setState(() => _isLoading = true);
    try {
      // Just verify the OTP
      // The callback chain will handle: otpVerified -> emitRideCompleted -> rideCompleted event -> show rating
      SocketService.verifyStopOtp(_ride.id, otp);
      print('🔐 Verifying stop OTP...');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Invalid OTP or error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCancelRide() async {
    final reason = await _showCancelDialog(context);
    if (reason == null || reason.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      SocketService.cancelRide(_ride.id, reason);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Ride cancelled')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmergency() async {
    HapticFeedback.vibrate(); // Heavy vibration for emergency
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Emergency Alert'),
        content: const Text(
          'This will notify authorities and emergency contacts. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final position = await Geolocator.getCurrentPosition();
      SocketService.triggerEmergencyAlert(
        rideId: _ride.id,
        latitude: position.latitude,
        longitude: position.longitude,
        notes: 'Emergency alert from driver',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚨 Emergency alert sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    }
  }

  Future<void> _navigateToPickup() async {
    final pickupCoords = _ride.pickupLocation.coordinates;
    if (pickupCoords.length < 2) return;

    final lat = pickupCoords[1];
    final lng = pickupCoords[0];
    final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch navigation';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ Could not open maps')));
      }
    }
  }

  Future<void> _navigateToDropoff() async {
    final dropoffCoords = _ride.dropoffLocation.coordinates;
    if (dropoffCoords.length < 2) return;

    final lat = dropoffCoords[1];
    final lng = dropoffCoords[0];
    final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch navigation';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ Could not open maps')));
      }
    }
  }

  Future<void> _callPassenger() async {
    if (_ride.rider == null || _ride.rider!.phone == null) return;
    final uri = Uri.parse('tel:${_ride.rider!.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(ride: _ride)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Ride'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Fit markers button
          IconButton(
            icon: const Icon(Icons.fit_screen),
            onPressed: _fitMarkersInView,
            tooltip: 'Fit all markers',
          ),
          // Emergency button
          IconButton(
            icon: const Icon(Icons.warning, color: Colors.red),
            onPressed: _handleEmergency,
            tooltip: 'Emergency',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Google Maps
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _isMapExpanded
                    ? _expandedMapHeight
                    : _collapsedMapHeight,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target:
                            _currentDriverLocation ??
                            const LatLng(12.9716, 77.5946),
                        zoom: 14,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: false,
                      mapType: MapType.normal,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        Future.delayed(const Duration(milliseconds: 500), () {
                          _fitMarkersInView();
                        });
                      },
                    ),
                    // Expand/Collapse button
                    Positioned(
                      top: 10,
                      right: 10,
                      child: FloatingActionButton.small(
                        backgroundColor: Colors.white,
                        onPressed: () {
                          setState(() {
                            _isMapExpanded = !_isMapExpanded;
                          });
                        },
                        child: Icon(
                          _isMapExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Ride details (scrollable)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Passenger info card
                      _buildPassengerCard(),
                      const SizedBox(height: 16),

                      // Route info card
                      _buildRouteCard(),
                      const SizedBox(height: 16),

                      // Ride details card
                      _buildRideDetailsCard(),
                      const SizedBox(height: 16),

                      // Action buttons
                      _buildActionButtons(),
                      const SizedBox(height: 100), // Space for bottom sheet
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPassengerCard() {
    if (_ride.rider == null) return const SizedBox();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.indigo.shade100,
              child: Text(
                _ride.rider!.fullName[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ride.rider!.fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_ride.rider!.phone != null)
                    Text(
                      _ride.rider!.phone!,
                      style: const TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: _callPassenger,
            ),
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.chat, color: Colors.indigo),
                  onPressed: _openChat,
                ),
                if (_unreadMessageCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_unreadMessageCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildRouteCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Pickup
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.my_location, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pickup',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _ride.pickupAddress,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.navigation, color: Colors.indigo),
                  onPressed: _navigateToPickup,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Row(
                children: [
                  Container(width: 2, height: 30, color: Colors.grey.shade300),
                ],
              ),
            ),
            // Dropoff
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dropoff',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _ride.dropoffAddress,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.navigation, color: Colors.indigo),
                  onPressed: _navigateToDropoff,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideDetailsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow('Status', _ride.status.displayName),
            const Divider(),
            _buildDetailRow('Fare', '₹${_ride.fare.toStringAsFixed(2)}'),
            const Divider(),
            _buildDetailRow(
              'Distance',
              '${_ride.distanceInKm.toStringAsFixed(2)} km',
            ),
            const Divider(),
            _buildDetailRow('Payment', _ride.paymentMethod.displayName),
            const Divider(),
            _buildDetailRow('Ride Type', _ride.rideType.displayName),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Primary action based on status
        if (_ride.status == RideStatus.accepted)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _handleDriverArrived,
              icon: const Icon(Icons.where_to_vote),
              label: const Text(
                'Mark as Arrived',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        if (_ride.status == RideStatus.arrived)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _handleStartRide,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Ride', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        if (_ride.status == RideStatus.ongoing ||
            _ride.status == RideStatus.inProgress)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _handleStopRide,
              icon: const Icon(Icons.stop),
              label: const Text(
                'Complete Ride',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        const SizedBox(height: 12),

        // Cancel button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _handleCancelRide,
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel Ride', style: TextStyle(fontSize: 16)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Future<String?> _showOTPDialog(BuildContext context, String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(
            hintText: 'Enter 4-digit OTP',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showCancelDialog(BuildContext context) {
    String selectedReason = 'Passenger not responding';
    final reasons = [
      'Passenger not responding',
      'Passenger cancelled',
      'Vehicle issue',
      'Emergency',
      'Other',
    ];

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Cancel Ride'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select cancellation reason:'),
              const SizedBox(height: 16),
              ...reasons.map(
                (reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) {
                    setState(() => selectedReason = value!);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedReason),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancel Ride'),
            ),
          ],
        ),
      ),
    );
  }
}
