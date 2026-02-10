import 'package:flutter/material.dart';
import 'package:driver_cerca/models/earnings_model.dart' as earnings_model;
import 'package:driver_cerca/services/earnings_service.dart';
import 'package:driver_cerca/services/storage_service.dart';
import 'package:driver_cerca/constants/constants.dart';
import 'package:intl/intl.dart';

/// PaymentHistoryScreen displays paginated payment history
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  String? _driverId;
  List<Map<String, dynamic>> _payments = [];
  earnings_model.PaymentStatus? _selectedStatus;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDriverId();
  }

  Future<void> _loadDriverId() async {
    _driverId = await StorageService.getDriverId();
    if (_driverId != null) {
      _loadPayments();
    }
  }

  Future<void> _loadPayments({bool loadMore = false}) async {
    if (_driverId == null) return;

    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _error = null;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final result = await EarningsService.getPaymentHistory(
        driverId: _driverId!,
        status: _selectedStatus,
        page: _currentPage,
        limit: 20,
      );

      setState(() {
        if (loadMore) {
          _payments.addAll(
            List<Map<String, dynamic>>.from(result['payments'] ?? []),
          );
        } else {
          _payments = List<Map<String, dynamic>>.from(result['payments'] ?? []);
        }
        _totalPages = result['pagination']?['totalPages'] ?? 1;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_currentPage < _totalPages && !_isLoadingMore) {
      setState(() {
        _currentPage++;
      });
      await _loadPayments(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Status filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[100],
          child: Row(
            children: [
              _buildStatusChip('All', null),
              const SizedBox(width: 8),
              _buildStatusChip('Pending', earnings_model.PaymentStatus.pending),
              const SizedBox(width: 8),
              _buildStatusChip('Completed', earnings_model.PaymentStatus.completed),
            ],
          ),
        ),

        // Payments list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading payments',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadPayments,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _payments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No payments found',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadPayments(),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _payments.length + (_currentPage < _totalPages ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _payments.length) {
                                return _buildLoadMoreButton();
                              }
                              return _buildPaymentCard(_payments[index]);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, earnings_model.PaymentStatus? status) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? status : null;
        });
        _loadPayments();
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final date = payment['date'] as DateTime?;
    final formattedDate = date != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(date)
        : 'N/A';
    final status = payment['paymentStatus'] as earnings_model.PaymentStatus;
    final statusColor = status == earnings_model.PaymentStatus.completed
        ? Colors.green
        : status == earnings_model.PaymentStatus.pending
            ? Colors.orange
            : Colors.red;
    final driverEarning = (payment['driverEarning'] ?? 0) as num;
    final grossFare = (payment['grossFare'] ?? 0) as num;
    final platformFee = (payment['platformFee'] ?? 0) as num;
    final netAmount = (payment['netAmount'] ?? 0) as num;
    final tips = (payment['tips'] ?? 0) as num;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    status.value.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver Earning',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${driverEarning.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Gross Fare',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${grossFare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Fee',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${platformFee.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Net Amount',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${netAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (tips > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.thumb_up, size: 16, color: Colors.amber[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Tip: ₹${tips.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.amber[700]),
                  ),
                ],
              ),
            ],
            if (payment['pickupAddress'] != null || payment['dropoffAddress'] != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              if (payment['pickupAddress'] != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.my_location, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        payment['pickupAddress'],
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (payment['pickupAddress'] != null && payment['dropoffAddress'] != null)
                const SizedBox(height: 8),
              if (payment['dropoffAddress'] != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.red[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        payment['dropoffAddress'],
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _isLoadingMore
          ? const Center(child: CircularProgressIndicator())
          : ElevatedButton(
              onPressed: _loadMore,
              child: const Text('Load More'),
            ),
    );
  }
}

