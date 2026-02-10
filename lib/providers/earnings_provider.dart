import 'package:flutter/foundation.dart';
import 'package:driver_cerca/models/earnings_model.dart' as earnings_model;
import 'package:driver_cerca/services/earnings_service.dart';
import 'package:driver_cerca/services/socket_service.dart';

/// EarningsProvider manages earnings and statistics state
class EarningsProvider extends ChangeNotifier {
  earnings_model.EarningsModel? _earnings;
  earnings_model.DriverStats? _stats;
  bool _isLoading = false;
  String? _error;

  // Getters
  earnings_model.EarningsModel? get earnings => _earnings;
  earnings_model.DriverStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Payment status getters
  double get totalPendingEarnings => _earnings?.totalPendingEarnings ?? 0;
  double get totalCompletedEarnings => _earnings?.totalCompletedEarnings ?? 0;
  int get pendingEarningsCount => _earnings?.pendingEarningsCount ?? 0;
  int get completedEarningsCount => _earnings?.completedEarningsCount ?? 0;
  
  // Filter recent rides by payment status
  List<earnings_model.RecentRideEarning> getRecentRidesByStatus(earnings_model.PaymentStatus? status) {
    if (_earnings?.recentRides == null) return [];
    if (status == null) return _earnings!.recentRides!;
    return _earnings!.recentRides!
        .where((ride) => ride.paymentStatus == status)
        .toList();
  }

  /// Fetch driver earnings with optional date range
  Future<void> fetchEarnings({
    required String driverId,
    DateTime? startDate,
    DateTime? endDate,
    String? period,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final earningsData = await EarningsService.getDriverEarnings(
        driverId: driverId,
        startDate: startDate,
        endDate: endDate,
        period: period,
      );

      _earnings = earningsData;
      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch earnings: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch driver statistics
  Future<void> fetchStats(String driverId) async {
    _setLoading(true);
    _clearError();

    try {
      final statsData = await EarningsService.getDriverStats(driverId);
      _stats = statsData;
      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch statistics: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh earnings data (fetch both earnings and stats)
  Future<void> refreshEarnings({
    required String driverId,
    DateTime? startDate,
    DateTime? endDate,
    String? period,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await Future.wait([
        fetchEarnings(
          driverId: driverId,
          startDate: startDate,
          endDate: endDate,
          period: period,
        ),
        fetchStats(driverId),
      ]);
    } catch (e) {
      _setError('Failed to refresh earnings: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Clear error state
  void clearError() {
    _clearError();
  }

  /// Register socket listener for real-time earnings updates
  void registerEarningsSocketListener({
    required String driverId,
    required Future<void> Function() onRefresh,
    Function(double)? onNotify,
  }) {
    SocketService.onDriverEarningAdded = (data) {
      final eventDriverId = data['driverId']?.toString();
      if (eventDriverId != null && eventDriverId != driverId) return;

      final earningAmount = (data['driverEarning'] is num)
          ? (data['driverEarning'] as num).toDouble()
          : 0.0;

      onRefresh();
      if (onNotify != null) {
        onNotify(earningAmount);
      }
    };
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}

