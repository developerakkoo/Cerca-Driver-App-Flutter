import 'package:dio/dio.dart';
import 'package:driver_cerca/constants/api_constants.dart';
import 'package:driver_cerca/models/payout_model.dart';
import 'package:driver_cerca/services/storage_service.dart';

/// PayoutService handles all REST API calls related to payouts
class PayoutService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Get available balance for payout
  /// GET /drivers/:driverId/payout/available-balance
  static Future<AvailableBalanceModel> getAvailableBalance(
    String driverId,
  ) async {
    try {
      print('💰 Fetching available balance for driver: $driverId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '/drivers/$driverId/payout/available-balance',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Available balance fetched successfully: ${response.statusCode}');

      return AvailableBalanceModel.fromJson(response.data);
    } on DioException catch (e) {
      print('❌ DioException fetching available balance: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      rethrow;
    } catch (e) {
      print('❌ Error fetching available balance: $e');
      rethrow;
    }
  }

  /// Request payout
  /// POST /drivers/:driverId/payout/request
  static Future<PayoutModel> requestPayout({
    required String driverId,
    required double amount,
    required BankAccountModel bankAccount,
    String? notes,
  }) async {
    try {
      print('💰 Requesting payout for driver: $driverId, amount: ₹$amount');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.post(
        '/drivers/$driverId/payout/request',
        data: {
          'amount': amount,
          'bankAccount': bankAccount.toJson(),
          if (notes != null) 'notes': notes,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Payout requested successfully: ${response.statusCode}');

      final data = response.data['data'] ?? response.data;
      final payoutData = data['payout'] ?? data;
      return PayoutModel.fromJson(payoutData);
    } on DioException catch (e) {
      print('❌ DioException requesting payout: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
        final errorMessage = e.response?.data['message'] ?? 'Failed to request payout';
        throw Exception(errorMessage);
      }
      rethrow;
    } catch (e) {
      print('❌ Error requesting payout: $e');
      rethrow;
    }
  }

  /// Get payout history
  /// GET /drivers/:driverId/payout/history
  static Future<PayoutHistoryResponse> getPayoutHistory({
    required String driverId,
    int page = 1,
    int limit = 20,
    PayoutStatus? status,
  }) async {
    try {
      print('💰 Fetching payout history for driver: $driverId, page: $page');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (status != null) {
        queryParams['status'] = status.value;
      }

      final response = await _dio.get(
        '/drivers/$driverId/payout/history',
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Payout history fetched successfully: ${response.statusCode}');

      return PayoutHistoryResponse.fromJson(response.data);
    } on DioException catch (e) {
      print('❌ DioException fetching payout history: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      rethrow;
    } catch (e) {
      print('❌ Error fetching payout history: $e');
      rethrow;
    }
  }

  /// Get payout by ID
  /// GET /drivers/:driverId/payout/:payoutId
  static Future<PayoutModel> getPayoutById(
    String driverId,
    String payoutId,
  ) async {
    try {
      print('💰 Fetching payout: $payoutId for driver: $driverId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '/drivers/$driverId/payout/$payoutId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Payout fetched successfully: ${response.statusCode}');

      final data = response.data['data'] ?? response.data;
      return PayoutModel.fromJson(data['payout'] ?? data);
    } on DioException catch (e) {
      print('❌ DioException fetching payout: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      rethrow;
    } catch (e) {
      print('❌ Error fetching payout: $e');
      rethrow;
    }
  }

  /// Get bank account
  /// GET /drivers/:driverId/payout/bank-account
  static Future<BankAccountModel?> getBankAccount(String driverId) async {
    try {
      print('💰 Fetching bank account for driver: $driverId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '/drivers/$driverId/payout/bank-account',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Bank account fetched successfully: ${response.statusCode}');

      final data = response.data['data'] ?? response.data;
      final bankAccountData = data['bankAccount'];
      if (bankAccountData == null) {
        return null;
      }
      return BankAccountModel.fromJson(bankAccountData);
    } on DioException catch (e) {
      print('❌ DioException fetching bank account: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      rethrow;
    } catch (e) {
      print('❌ Error fetching bank account: $e');
      rethrow;
    }
  }

  /// Update bank account
  /// PUT /drivers/:driverId/payout/bank-account
  static Future<BankAccountModel> updateBankAccount({
    required String driverId,
    required BankAccountModel bankAccount,
  }) async {
    try {
      print('💰 Updating bank account for driver: $driverId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.put(
        '/drivers/$driverId/payout/bank-account',
        data: {'bankAccount': bankAccount.toJson()},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Bank account updated successfully: ${response.statusCode}');

      final data = response.data['data'] ?? response.data;
      return BankAccountModel.fromJson(data['bankAccount'] ?? data);
    } on DioException catch (e) {
      print('❌ DioException updating bank account: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
        final errorMessage = e.response?.data['message'] ?? 'Failed to update bank account';
        throw Exception(errorMessage);
      }
      rethrow;
    } catch (e) {
      print('❌ Error updating bank account: $e');
      rethrow;
    }
  }
}

