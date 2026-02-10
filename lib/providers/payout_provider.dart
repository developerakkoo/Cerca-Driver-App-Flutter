import 'package:flutter/foundation.dart';
import 'package:driver_cerca/models/payout_model.dart';
import 'package:driver_cerca/services/payout_service.dart';

/// PayoutProvider manages payout state
class PayoutProvider extends ChangeNotifier {
  AvailableBalanceModel? _availableBalance;
  BankAccountModel? _bankAccount;
  PayoutHistoryResponse? _payoutHistory;
  bool _isLoading = false;
  String? _error;

  // Getters
  AvailableBalanceModel? get availableBalance => _availableBalance;
  BankAccountModel? get bankAccount => _bankAccount;
  PayoutHistoryResponse? get payoutHistory => _payoutHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<PayoutModel> get payouts => _payoutHistory?.payouts ?? [];
  PaginationInfo? get pagination => _payoutHistory?.pagination;
  PayoutStatistics? get statistics => _payoutHistory?.statistics;

  /// Fetch available balance
  Future<void> fetchAvailableBalance(String driverId) async {
    _setLoading(true);
    _clearError();

    try {
      _availableBalance = await PayoutService.getAvailableBalance(driverId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch available balance: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch bank account
  Future<void> fetchBankAccount(String driverId) async {
    _setLoading(true);
    _clearError();

    try {
      _bankAccount = await PayoutService.getBankAccount(driverId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch bank account: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update bank account
  Future<void> updateBankAccount({
    required String driverId,
    required BankAccountModel bankAccount,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _bankAccount = await PayoutService.updateBankAccount(
        driverId: driverId,
        bankAccount: bankAccount,
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to update bank account: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Request payout
  Future<PayoutModel> requestPayout({
    required String driverId,
    required double amount,
    required BankAccountModel bankAccount,
    String? notes,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final payout = await PayoutService.requestPayout(
        driverId: driverId,
        amount: amount,
        bankAccount: bankAccount,
        notes: notes,
      );

      // Update bank account if saved
      _bankAccount = bankAccount;

      // Refresh available balance and payout history
      await Future.wait([
        fetchAvailableBalance(driverId),
        fetchPayoutHistory(driverId: driverId),
      ]);

      notifyListeners();
      return payout;
    } catch (e) {
      _setError('Failed to request payout: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch payout history
  Future<void> fetchPayoutHistory({
    required String driverId,
    int page = 1,
    int limit = 20,
    PayoutStatus? status,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _payoutHistory = await PayoutService.getPayoutHistory(
        driverId: driverId,
        page: page,
        limit: limit,
        status: status,
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch payout history: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load more payouts (pagination)
  Future<void> loadMorePayouts({
    required String driverId,
    PayoutStatus? status,
  }) async {
    if (_payoutHistory == null) {
      await fetchPayoutHistory(driverId: driverId, status: status);
      return;
    }

    final currentPage = _payoutHistory!.pagination.currentPage;
    final totalPages = _payoutHistory!.pagination.totalPages;

    if (currentPage >= totalPages) {
      return; // No more pages
    }

    try {
      final nextPage = currentPage + 1;
      final response = await PayoutService.getPayoutHistory(
        driverId: driverId,
        page: nextPage,
        limit: _payoutHistory!.pagination.limit,
        status: status,
      );

      // Append new payouts to existing list
      final updatedPayouts = [
        ..._payoutHistory!.payouts,
        ...response.payouts,
      ];

      _payoutHistory = PayoutHistoryResponse(
        payouts: updatedPayouts,
        pagination: response.pagination,
        statistics: response.statistics,
      );

      notifyListeners();
    } catch (e) {
      _setError('Failed to load more payouts: $e');
    }
  }

  /// Refresh all payout data
  Future<void> refreshAll(String driverId) async {
    await Future.wait([
      fetchAvailableBalance(driverId),
      fetchBankAccount(driverId),
      fetchPayoutHistory(driverId: driverId),
    ]);
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

