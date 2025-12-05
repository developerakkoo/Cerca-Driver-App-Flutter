import 'package:flutter/foundation.dart';
import 'package:driver_cerca/models/earnings_model.dart';
import 'package:driver_cerca/services/earnings_service.dart';

/// EarningsProvider manages earnings and statistics state
class EarningsProvider extends ChangeNotifier {
  EarningsModel? _earnings;
  DriverStats? _stats;
  bool _isLoading = false;
  String? _error;

  // Getters
  EarningsModel? get earnings => _earnings;
  DriverStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch driver earnings with optional date range
  Future<void> fetchEarnings({
    required String driverId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final earningsData = await EarningsService.getDriverEarnings(
        driverId: driverId,
        startDate: startDate,
        endDate: endDate,
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
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await Future.wait([
        fetchEarnings(
          driverId: driverId,
          startDate: startDate,
          endDate: endDate,
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

