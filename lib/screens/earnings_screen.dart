import 'package:flutter/material.dart';
import 'package:driver_cerca/models/earnings_model.dart' as earnings_model;
import 'package:driver_cerca/models/payout_model.dart';
import 'package:driver_cerca/providers/earnings_provider.dart' as earnings_provider;
import 'package:driver_cerca/providers/payout_provider.dart';
import 'package:driver_cerca/screens/payment_history_screen.dart';
import 'package:driver_cerca/screens/payout_request_screen.dart';
import 'package:driver_cerca/screens/bank_account_screen.dart';
import 'package:driver_cerca/services/storage_service.dart';
import 'package:driver_cerca/services/socket_service.dart';
import 'package:driver_cerca/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

/// EarningsScreen displays driver earnings with filters and statistics
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _driverId;
  earnings_model.DateRangeFilter _selectedFilter = earnings_model.DateRangeFilter.month;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _selectedBreakdownType = 'daily'; // 'daily', 'weekly', 'monthly'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDriverId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    SocketService.onDriverEarningAdded = null;
    super.dispose();
  }

  Future<void> _loadDriverId() async {
    _driverId = await StorageService.getDriverId();
    if (_driverId != null) {
      _registerEarningsListener();
      _loadData();
    }
  }

  void _registerEarningsListener() {
    final earningsProvider =
        Provider.of<earnings_provider.EarningsProvider>(context, listen: false);
    earningsProvider.registerEarningsSocketListener(
      driverId: _driverId!,
      onRefresh: () async {
        final dates = _getDateRange();
        final period = _getPeriodParam();
        await earningsProvider.fetchEarnings(
          driverId: _driverId!,
          startDate: period == null ? dates['start'] : null,
          endDate: period == null ? dates['end'] : null,
          period: period,
        );
      },
      onNotify: (amount) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New earning added: INR ${amount.toStringAsFixed(2)}'),
          ),
        );
      },
    );
  }

  Future<void> _loadData() async {
    if (_driverId == null) return;

    final earningsProvider =
        Provider.of<earnings_provider.EarningsProvider>(context, listen: false);
    final payoutProvider = Provider.of<PayoutProvider>(context, listen: false);
    final dates = _getDateRange();
    final period = _getPeriodParam();

    try {
      await Future.wait([
        earningsProvider.fetchEarnings(
          driverId: _driverId!,
          startDate: period == null ? dates['start'] : null,
          endDate: period == null ? dates['end'] : null,
          period: period,
        ),
        if (_tabController.index == 2) // Load payout data if on payouts tab
          payoutProvider.refreshAll(_driverId!),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error loading data: $e')));
      }
    }
  }


  Map<String, DateTime?> _getDateRange() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case earnings_model.DateRangeFilter.today:
        return {
          'start': DateTime(now.year, now.month, now.day),
          'end': DateTime(now.year, now.month, now.day, 23, 59, 59),
        };
      case earnings_model.DateRangeFilter.week:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return {
          'start': DateTime(weekStart.year, weekStart.month, weekStart.day),
          'end': DateTime(now.year, now.month, now.day, 23, 59, 59),
        };
      case earnings_model.DateRangeFilter.month:
        return {
          'start': DateTime(now.year, now.month, 1),
          'end': DateTime(now.year, now.month, now.day, 23, 59, 59),
        };
      case earnings_model.DateRangeFilter.custom:
        return {'start': _customStartDate, 'end': _customEndDate};
    }
  }

  String? _getPeriodParam() {
    switch (_selectedFilter) {
      case earnings_model.DateRangeFilter.today:
        return 'today';
      case earnings_model.DateRangeFilter.week:
        return 'week';
      case earnings_model.DateRangeFilter.month:
        return 'month';
      case earnings_model.DateRangeFilter.custom:
        return null;
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
        _selectedFilter = earnings_model.DateRangeFilter.custom;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            if (index == 2 && _driverId != null) {
              // Load payout data when switching to payouts tab
              final payoutProvider = Provider.of<PayoutProvider>(context, listen: false);
              payoutProvider.refreshAll(_driverId!);
            }
          },
          tabs: const [
            Tab(text: 'Earnings', icon: Icon(Icons.account_balance_wallet)),
            Tab(text: 'Payments', icon: Icon(Icons.payment)),
            Tab(text: 'Payouts', icon: Icon(Icons.account_balance)),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEarningsTab(),
          _buildPaymentHistoryTab(),
          _buildPayoutsTab(),
        ],
      ),
    );
  }

  Widget _buildEarningsTab() {
    return Consumer<earnings_provider.EarningsProvider>(
      builder: (context, earningsProvider, _) {
        final _earnings = earningsProvider.earnings;
        final _isLoading = earningsProvider.isLoading;

        if (_isLoading && _earnings == null) {
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

                // Breakdown section
                if (_earnings != null && (_earnings.dailyBreakdown != null ||
                    _earnings.weeklyBreakdown != null ||
                    _earnings.monthlyBreakdown != null))
                  _buildBreakdownSection(_earnings),

                // Recent rides
                if (_earnings != null && _earnings.recentRides != null && _earnings.recentRides!.isNotEmpty)
                  _buildRecentRidesSection(_earnings),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentHistoryTab() {
    return const PaymentHistoryScreen();
  }

  Widget _buildPayoutsTab() {
    return Consumer<PayoutProvider>(
      builder: (context, payoutProvider, _) {
        return RefreshIndicator(
          onRefresh: () => _loadData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Available balance card
                if (payoutProvider.availableBalance != null)
                  _buildAvailableBalanceCard(payoutProvider.availableBalance!),

                // Bank account section
                _buildBankAccountSection(payoutProvider),

                // Payout history
                _buildPayoutHistorySection(payoutProvider),
              ],
            ),
          ),
        );
      },
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
                ...earnings_model.DateRangeFilter.values.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (filter == earnings_model.DateRangeFilter.custom) {
                          _showDateRangePicker();
                        } else {
                          setState(() => _selectedFilter = filter);
                          _loadData();
                        }
                      },
                      selectedColor: AppColors.primary.withOpacity(0.1),
                      checkmarkColor: AppColors.primary,
                    ),
                  );
                }),
              ],
            ),
          ),
          if (_selectedFilter == earnings_model.DateRangeFilter.custom &&
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

  Widget _buildEarningsSummaryCard(earnings_model.EarningsModel earnings) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
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
            'Total Earnings',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '₹${earnings.netEarnings.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 32),
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
          if (earnings.totalTips > 0 || earnings.totalBonuses > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (earnings.totalTips > 0)
                  Expanded(
                    child: _buildEarningDetail(
                      'Tips',
                      '₹${earnings.totalTips.toStringAsFixed(2)}',
                    ),
                  ),
                if (earnings.totalBonuses > 0)
                  Expanded(
                    child: _buildEarningDetail(
                      'Bonuses',
                      '₹${earnings.totalBonuses.toStringAsFixed(2)}',
                    ),
                  ),
              ],
            ),
          ],
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

  Widget _buildBreakdownSection(earnings_model.EarningsModel earnings) {
    List<earnings_model.EarningBreakdown>? breakdown;
    String title;
    
    switch (_selectedBreakdownType) {
      case 'daily':
        breakdown = earnings.dailyBreakdown;
        title = 'Daily Breakdown';
        break;
      case 'weekly':
        breakdown = earnings.weeklyBreakdown;
        title = 'Weekly Breakdown';
        break;
      case 'monthly':
        breakdown = earnings.monthlyBreakdown;
        title = 'Monthly Breakdown';
        break;
      default:
        breakdown = earnings.dailyBreakdown;
        title = 'Daily Breakdown';
    }

    if (breakdown == null || breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Breakdown type selector - wrap in Expanded + scroll to prevent overflow
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBreakdownTypeChip('Daily', 'daily'),
                      const SizedBox(width: 8),
                      _buildBreakdownTypeChip('Weekly', 'weekly'),
                      const SizedBox(width: 8),
                      _buildBreakdownTypeChip('Monthly', 'monthly'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...breakdown.map((item) => _buildBreakdownCard(item)),
        ],
      ),
    );
  }

  Widget _buildBreakdownTypeChip(String label, String type) {
    final isSelected = _selectedBreakdownType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedBreakdownType = type);
        }
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? AppColors.primary : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildBreakdownCard(earnings_model.EarningBreakdown breakdown) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  breakdown.date,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${breakdown.ridesCount} rides',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            Text(
              '₹${breakdown.netEarnings.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRidesSection(earnings_model.EarningsModel earnings) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Rides',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...earnings.recentRides!.map((ride) => _buildRecentRideCard(ride)),
        ],
      ),
    );
  }

  Widget _buildRecentRideCard(earnings_model.RecentRideEarning ride) {
    final formattedDate = DateFormat('MMM d, h:mm a').format(ride.date);
    final statusColor = ride.paymentStatus == earnings_model.PaymentStatus.completed
        ? Colors.green
        : ride.paymentStatus == earnings_model.PaymentStatus.pending
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        ride.paymentStatus.value.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${ride.driverEarning.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (ride.pickupAddress != null || ride.dropoffAddress != null) ...[
              const SizedBox(height: 12),
              if (ride.pickupAddress != null)
                Row(
                  children: [
                    Icon(Icons.my_location, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ride.pickupAddress!,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (ride.pickupAddress != null && ride.dropoffAddress != null)
                const SizedBox(height: 8),
              if (ride.dropoffAddress != null)
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.red[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ride.dropoffAddress!,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
            if (ride.tips > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.thumb_up, size: 16, color: Colors.amber[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Tip: ₹${ride.tips.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.amber[700]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableBalanceCard(AvailableBalanceModel balance) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '₹${balance.totalAvailable.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          if (balance.totalTips > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Including ₹${balance.totalTips.toStringAsFixed(2)} in tips',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: balance.canRequestPayout
                  ? () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PayoutRequestScreen(),
                        ),
                      );
                      if (result == true && _driverId != null) {
                        final payoutProvider = Provider.of<PayoutProvider>(context, listen: false);
                        await payoutProvider.refreshAll(_driverId!);
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Request Payout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (!balance.canRequestPayout) ...[
            const SizedBox(height: 8),
            Text(
              'Minimum payout: ₹${balance.minPayoutThreshold.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBankAccountSection(PayoutProvider payoutProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.account_balance, color: AppColors.primary),
          title: const Text('Bank Account'),
          subtitle: payoutProvider.bankAccount != null
              ? Text(
                  '${payoutProvider.bankAccount!.accountHolderName}\n${payoutProvider.bankAccount!.accountNumber}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : const Text('Not set'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BankAccountScreen(),
              ),
            );
            if (_driverId != null) {
              await payoutProvider.fetchBankAccount(_driverId!);
            }
          },
        ),
      ),
    );
  }

  Widget _buildPayoutHistorySection(PayoutProvider payoutProvider) {
    if (payoutProvider.payouts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.account_balance_wallet, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No payout history',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payout History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...payoutProvider.payouts.map((payout) => _buildPayoutCard(payout)),
          if (payoutProvider.pagination != null &&
              payoutProvider.pagination!.currentPage < payoutProvider.pagination!.totalPages)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (_driverId != null) {
                      payoutProvider.loadMorePayouts(driverId: _driverId!);
                    }
                  },
                  child: const Text('Load More'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPayoutCard(PayoutModel payout) {
    final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(payout.requestedAt);
    final statusColor = payout.status == PayoutStatus.completed
        ? Colors.green
        : payout.status == PayoutStatus.pending || payout.status == PayoutStatus.processing
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (payout.transactionReference != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        payout.transactionReference!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${payout.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        payout.status.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (payout.processedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Processed: ${DateFormat('MMM d, yyyy').format(payout.processedAt!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (payout.transactionId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Transaction ID: ${payout.transactionId}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


