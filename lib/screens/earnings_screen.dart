import 'package:flutter/material.dart';
import 'package:driver_cerca/models/earnings_model.dart';
import 'package:driver_cerca/models/ride_model.dart';
import 'package:driver_cerca/providers/earnings_provider.dart';
import 'package:driver_cerca/services/ride_service.dart';
import 'package:driver_cerca/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

/// EarningsScreen displays driver earnings with filters and statistics
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  String? _driverId;
  List<RideModel> _completedRides = [];
  DateRangeFilter _selectedFilter = DateRangeFilter.month;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _loadDriverId();
  }

  Future<void> _loadDriverId() async {
    _driverId = await StorageService.getDriverId();
    if (_driverId != null) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_driverId == null) return;

    final earningsProvider =
        Provider.of<EarningsProvider>(context, listen: false);
    final dates = _getDateRange();

    try {
      await Future.wait([
        earningsProvider.fetchEarnings(
          driverId: _driverId!,
          startDate: dates['start'],
          endDate: dates['end'],
        ),
        earningsProvider.fetchStats(_driverId!),
        _loadCompletedRides(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error loading data: $e')));
      }
    }
  }

  Future<void> _loadCompletedRides() async {
    if (_driverId == null) return;
    try {
      final rides = await RideService.getCompletedRides(_driverId!);
      final dates = _getDateRange();

      setState(() {
        _completedRides = rides;

        // Filter rides by date range
        if (dates['start'] != null || dates['end'] != null) {
          _completedRides = _completedRides.where((ride) {
            final rideDate = ride.createdAt;
            if (dates['start'] != null && rideDate.isBefore(dates['start']!)) {
              return false;
            }
            if (dates['end'] != null && rideDate.isAfter(dates['end']!)) {
              return false;
            }
            return true;
          }).toList();
        }
      });
    } catch (e) {
      print('Error loading completed rides: $e');
    }
  }

  Map<String, DateTime?> _getDateRange() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case DateRangeFilter.today:
        return {
          'start': DateTime(now.year, now.month, now.day),
          'end': DateTime(now.year, now.month, now.day, 23, 59, 59),
        };
      case DateRangeFilter.week:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return {
          'start': DateTime(weekStart.year, weekStart.month, weekStart.day),
          'end': DateTime(now.year, now.month, now.day, 23, 59, 59),
        };
      case DateRangeFilter.month:
        return {
          'start': DateTime(now.year, now.month, 1),
          'end': DateTime(now.year, now.month, now.day, 23, 59, 59),
        };
      case DateRangeFilter.custom:
        return {'start': _customStartDate, 'end': _customEndDate};
    }
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedFilter = DateRangeFilter.custom;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Consumer<EarningsProvider>(
        builder: (context, earningsProvider, _) {
          final _earnings = earningsProvider.earnings;
          final _stats = earningsProvider.stats;
          final _isLoading = earningsProvider.isLoading;

          if (_isLoading && _earnings == null && _stats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date range filter
                  _buildDateRangeFilter(),

                  // Earnings summary card
                  if (_earnings != null) _buildEarningsSummaryCard(_earnings),

                  // Statistics cards
                  if (_stats != null) _buildStatsCards(_stats),

                  // Ride history
                  _buildRideHistory(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateRangeFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Time Period',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...DateRangeFilter.values.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (filter == DateRangeFilter.custom) {
                          _showDateRangePicker();
                        } else {
                          setState(() => _selectedFilter = filter);
                          _loadData();
                        }
                      },
                      selectedColor: Colors.indigo.shade100,
                      checkmarkColor: Colors.indigo.shade700,
                    ),
                  );
                }),
              ],
            ),
          ),
          if (_selectedFilter == DateRangeFilter.custom &&
              _customStartDate != null &&
              _customEndDate != null) ...[
            const SizedBox(height: 8),
            Text(
              '${DateFormat('MMM d, yyyy').format(_customStartDate!)} - ${DateFormat('MMM d, yyyy').format(_customEndDate!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEarningsSummaryCard(EarningsModel earnings) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Net Earnings',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${earnings.netEarnings.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildEarningDetail(
                  'Gross',
                  '₹${earnings.grossEarnings.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _buildEarningDetail(
                  'Platform Fee',
                  '₹${earnings.platformFees.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white30, height: 32),
          Row(
            children: [
              Expanded(
                child: _buildEarningDetail(
                  'Total Rides',
                  '${earnings.totalRides}',
                ),
              ),
              Expanded(
                child: _buildEarningDetail(
                  'Avg per Ride',
                  '₹${earnings.averagePerRide.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(DriverStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Stats',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle,
                  label: 'Completion Rate',
                  value: '${stats.completionRate.toStringAsFixed(1)}%',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.star,
                  label: 'Average Rating',
                  value: stats.averageRating.toStringAsFixed(1),
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.directions_car,
                  label: 'Total Rides',
                  value: '${stats.totalRides}',
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.cancel,
                  label: 'Cancelled',
                  value: '${stats.cancelledRides}',
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideHistory() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ride History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_completedRides.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No rides in selected period',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._completedRides.map((ride) => _buildRideCard(ride)),
        ],
      ),
    );
  }

  Widget _buildRideCard(RideModel ride) {
    final formattedDate = DateFormat('MMM d, h:mm a').format(ride.createdAt);
    final duration = ride.actualDuration ?? ride.estimatedDuration ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date and fare
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  '₹${ride.fare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Passenger
            if (ride.rider != null)
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    ride.rider!.fullName,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            const SizedBox(height: 8),

            // Route
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(Icons.my_location, size: 16, color: Colors.green[600]),
                    Container(width: 2, height: 20, color: Colors.grey[300]),
                    Icon(Icons.location_on, size: 16, color: Colors.red[600]),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride.pickupAddress,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        ride.dropoffAddress,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Details
            Row(
              children: [
                _buildRideDetailChip(
                  Icons.straighten,
                  '${ride.distanceInKm.toStringAsFixed(1)} km',
                ),
                const SizedBox(width: 8),
                _buildRideDetailChip(Icons.access_time, '$duration min'),
                const SizedBox(width: 8),
                _buildRideDetailChip(
                  Icons.payment,
                  ride.paymentMethod.displayName,
                ),
                if (ride.driverRating != null) ...[
                  const SizedBox(width: 8),
                  _buildRideDetailChip(
                    Icons.star,
                    ride.driverRating!.toStringAsFixed(1),
                    color: Colors.amber,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideDetailChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color ?? Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
