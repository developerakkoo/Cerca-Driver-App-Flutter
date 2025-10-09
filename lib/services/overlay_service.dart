import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:driver_cerca/main.dart';
import 'dart:ui' as ui;
import 'dart:convert';

class OverlayService {
  static const String _overlayTitle = "Cerca Driver - Ride Request";
  static const String _overlayContent = "New ride request available";

  /// Shows a ride request overlay with the provided ride details
  static Future<void> showRideRequestOverlay({
    required Map<String, dynamic> rideDetails,
    Function()? onAccept,
    Function()? onReject,
  }) async {
    try {
      // Check if overlay permission is granted
      final bool isPermissionGranted =
          await FlutterOverlayWindow.isPermissionGranted();

      if (!isPermissionGranted) {
        print('Overlay permission not granted');
        return;
      }

      // Store the data globally for the overlay to access
      currentRideDetails = rideDetails;
      currentOnAccept = onAccept;
      currentOnReject = onReject;

      // Close existing overlay if active
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        await FlutterOverlayWindow.closeOverlay();
      }

      // Show new overlay - full screen
      await FlutterOverlayWindow.showOverlay(
        alignment: OverlayAlignment.center,
        enableDrag: false, // disable drag to allow full-screen
        width: WindowSize.matchParent, // match device width
        height: WindowSize.matchParent, // match device height
        flag: OverlayFlag.focusPointer,
        startPosition: OverlayPosition(0, 0),
      );
      print('Created new full-screen overlay');

      print('Ride request overlay displayed successfully');
    } catch (e) {
      print('Error showing ride request overlay: $e');
    }
  }

  /// Closes the current overlay
  static Future<void> closeOverlay() async {
    try {
      // Add timeout to prevent hanging
      await FlutterOverlayWindow.closeOverlay().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Overlay close timed out');
        },
      );
      print('Overlay closed successfully');
    } catch (e) {
      print('Error closing overlay: $e');
    }
  }

  /// Checks if overlay permission is granted
  static Future<bool> isPermissionGranted() async {
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e) {
      print('Error checking overlay permission: $e');
      return false;
    }
  }

  /// Requests overlay permission
  static Future<bool> requestPermission() async {
    try {
      final bool? granted = await FlutterOverlayWindow.requestPermission();
      return granted ?? false;
    } catch (e) {
      print('Error requesting overlay permission: $e');
      return false;
    }
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
    OverlayService.closeOverlay();
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
    OverlayService.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 600,
          minWidth: 600,
          minHeight: 400,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.indigo[600],
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
                padding: const EdgeInsets.all(20),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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

                    const SizedBox(height: 20),

                    // Location Details
                    _buildLocationRow(
                      Icons.my_location,
                      'Pickup',
                      widget.rideDetails['pickupLocation'],
                      Colors.green,
                    ),

                    const SizedBox(height: 12),

                    _buildLocationRow(
                      Icons.location_on,
                      'Dropoff',
                      widget.rideDetails['dropoffLocation'],
                      Colors.red,
                    ),

                    const SizedBox(height: 20),

                    // Ride Info
                    Container(
                      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    // Reject Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleRejectRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
