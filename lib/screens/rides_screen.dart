import 'package:flutter/material.dart';
import 'package:driver_cerca/models/ride_model.dart';
import 'package:driver_cerca/services/ride_service.dart';
import 'package:driver_cerca/services/storage_service.dart';
import 'package:driver_cerca/services/message_service.dart';
import 'package:driver_cerca/services/socket_service.dart';
import 'package:driver_cerca/screens/active_ride_screen.dart';
import 'package:driver_cerca/constants/constants.dart';

/// RidesScreen displays all rides for the driver
/// Shows active and completed rides with filters
class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RideModel> _activeRides = [];
  List<RideModel> _completedRides = [];
  bool _isLoading = false;
  String? _driverId;
  Map<String, int> _unreadCounts = {}; // Map of rideId -> unread count

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDriverId();
    _setupUnreadCountListener();
  }

  void _setupUnreadCountListener() {
    SocketService.onUnreadCountUpdated = (data) {
      final rideId = data['rideId'] as String?;
      final unreadCount = data['unreadCount'] as int? ?? 0;
      
      if (rideId != null && mounted) {
        setState(() {
          _unreadCounts[rideId] = unreadCount;
        });
      }
    };
  }

  Future<void> _loadDriverId() async {
    _driverId = await StorageService.getDriverId();
    if (_driverId != null) {
      _loadRides();
    }
  }

  Future<void> _loadRides() async {
    if (_driverId == null) return;

    setState(() => _isLoading = true);
    try {
      final rides = await RideService.getDriverRides(_driverId!);

      setState(() {
        // Filter active rides (requested, pending, accepted, arrived, ongoing)
        _activeRides = rides.where((ride) {
          return ride.status == RideStatus.requested ||
              ride.status == RideStatus.pending ||
              ride.status == RideStatus.accepted ||
              ride.status == RideStatus.arrived ||
              ride.status == RideStatus.ongoing ||
              ride.status == RideStatus.inProgress;
        }).toList();

        // Filter completed rides (including cancelled)
        _completedRides = rides
            .where(
              (ride) =>
                  ride.status == RideStatus.completed ||
                  ride.status == RideStatus.cancelled,
            )
            .toList();
      });

      // Load unread counts for all rides
      _loadUnreadCounts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error loading rides: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUnreadCounts() async {
    if (_driverId == null) return;
    
    final allRides = [..._activeRides, ..._completedRides];
    for (var ride in allRides) {
      try {
        final count = await MessageService.getUnreadCountForRide(ride.id, _driverId!);
        if (mounted) {
          setState(() {
            _unreadCounts[ride.id] = count;
          });
        }
      } catch (e) {
        print('❌ Error loading unread count for ride ${ride.id}: $e');
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    SocketService.onUnreadCountUpdated = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rides'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRides),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.drive_eta),
              text: 'Active (${_activeRides.length})',
            ),
            Tab(
              icon: const Icon(Icons.check_circle),
              text: 'Completed (${_completedRides.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRidesList(_activeRides, 'active'),
                _buildRidesList(_completedRides, 'completed'),
              ],
            ),
    );
  }

  Widget _buildRidesList(List<RideModel> rides, String type) {
    if (rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'active'
                  ? Icons.drive_eta_outlined
                  : Icons.check_circle_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${type} rides',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRides,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rides.length,
        itemBuilder: (context, index) {
          return _buildRideCard(rides[index]);
        },
      ),
    );
  }

  Widget _buildRideCard(RideModel ride) {
    final statusColor = _getStatusColor(ride.status);
    final isActive =
        ride.status != RideStatus.completed &&
        ride.status != RideStatus.cancelled;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewRideDetails(ride),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status and fare
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status badge with unread count badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(ride.status),
                              size: 16,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ride.status.displayName,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Unread message badge
                      if (_unreadCounts[ride.id] != null && _unreadCounts[ride.id]! > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${_unreadCounts[ride.id]}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Fare
                  Text(
                    '₹${ride.fare.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Passenger info
              if (ride.rider != null)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        ride.rider!.fullName[0].toUpperCase(),
                        style: TextStyle(
                          color: AppColors.primary,
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
                            ride.rider!.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (ride.rider!.phone != null &&
                              ride.rider!.phone!.isNotEmpty)
                            Text(
                              ride.rider!.phone!,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),

              // Locations
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const Icon(
                        Icons.my_location,
                        color: Colors.green,
                        size: 20,
                      ),
                      Container(
                        width: 2,
                        height: 30,
                        color: Colors.grey.shade300,
                      ),
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.pickupAddress,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 30),
                        Text(
                          ride.dropoffAddress,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Ride details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailChip(
                    Icons.straighten,
                    '${ride.distanceInKm.toStringAsFixed(1)} km',
                  ),
                  _buildDetailChip(
                    Icons.access_time,
                    '${ride.estimatedDuration ?? 0} min',
                  ),
                  _buildDetailChip(
                    Icons.payment,
                    ride.paymentMethod.displayName,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _viewRideDetails(ride),
                  icon: Icon(isActive ? Icons.visibility : Icons.info),
                  label: Text(isActive ? 'View Active Ride' : 'View Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.1),
                    foregroundColor: isActive ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _viewRideDetails(RideModel ride) {
    // Check if ride is active
    final isActive =
        ride.status != RideStatus.completed &&
        ride.status != RideStatus.cancelled;

    if (isActive) {
      // Navigate to ActiveRideScreen for active rides
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ActiveRideScreen(ride: ride)),
      );
    } else {
      // Show ride details dialog for completed/cancelled rides
      _showRideDetailsDialog(ride);
    }
  }

  void _showRideDetailsDialog(RideModel ride) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getStatusIcon(ride.status),
              color: _getStatusColor(ride.status),
            ),
            const SizedBox(width: 8),
            const Text('Ride Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Ride ID', ride.id),
              const Divider(),
              if (ride.rider != null) ...[
                _buildDetailRow('Passenger', ride.rider!.fullName),
                if (ride.rider!.phone != null)
                  _buildDetailRow('Phone', ride.rider!.phone!),
                const Divider(),
              ],
              _buildDetailRow('Pickup', ride.pickupAddress),
              _buildDetailRow('Dropoff', ride.dropoffAddress),
              const Divider(),
              _buildDetailRow('Fare', '₹${ride.fare.toStringAsFixed(2)}'),
              _buildDetailRow(
                'Distance',
                '${ride.distanceInKm.toStringAsFixed(2)} km',
              ),
              _buildDetailRow('Payment', ride.paymentMethod.displayName),
              _buildDetailRow('Status', ride.status.displayName),
              const Divider(),
              if (ride.actualStartTime != null)
                _buildDetailRow(
                  'Started At',
                  _formatDateTime(ride.actualStartTime!),
                ),
              if (ride.actualEndTime != null)
                _buildDetailRow(
                  'Completed At',
                  _formatDateTime(ride.actualEndTime!),
                ),
              if (ride.actualDuration != null)
                _buildDetailRow('Duration', '${ride.actualDuration} minutes'),
              if (ride.driverRating != null)
                _buildDetailRow(
                  'My Rating',
                  '⭐ ${ride.driverRating!.toStringAsFixed(1)}',
                ),
              if (ride.riderRating != null)
                _buildDetailRow(
                  'Passenger Rating',
                  '⭐ ${ride.riderRating!.toStringAsFixed(1)}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
      case RideStatus.pending:
        return AppColors.primary;
      case RideStatus.accepted:
        return Colors.orange;
      case RideStatus.arrived:
        return Colors.green;
      case RideStatus.ongoing:
      case RideStatus.inProgress:
        return Colors.purple;
      case RideStatus.completed:
        return Colors.green.shade700;
      case RideStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
      case RideStatus.pending:
        return Icons.pending;
      case RideStatus.accepted:
        return Icons.check_circle;
      case RideStatus.arrived:
        return Icons.location_on;
      case RideStatus.ongoing:
      case RideStatus.inProgress:
        return Icons.drive_eta;
      case RideStatus.completed:
        return Icons.done_all;
      case RideStatus.cancelled:
        return Icons.cancel;
    }
  }
}
