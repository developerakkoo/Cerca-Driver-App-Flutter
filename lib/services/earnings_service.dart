import 'package:dio/dio.dart';
import 'package:driver_cerca/constants/api_constants.dart';
import 'package:driver_cerca/models/earnings_model.dart' as earnings_model;
import 'package:driver_cerca/services/storage_service.dart';

/// EarningsService handles all REST API calls related to earnings
class EarningsService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Get driver earnings
  /// GET /drivers/:id/earnings
  static Future<earnings_model.EarningsModel> getDriverEarnings({
    required String driverId,
    DateTime? startDate,
    DateTime? endDate,
    String? period,
  }) async {
    try {
      print('💰 Fetching earnings for driver: $driverId');
      if (period != null) print('   Period: $period');
      if (startDate != null) print('   Start date: $startDate');
      if (endDate != null) print('   End date: $endDate');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (period != null) {
        queryParams['period'] = period;
      }

      final response = await _dio.get(
        '/drivers/$driverId/earnings',
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Earnings fetched successfully: ${response.statusCode}');

      // API returns { success: true, data: { ... } }
      final earningsData = response.data is Map
          ? (response.data['data'] ?? response.data)
          : response.data;

      return earnings_model.EarningsModel.fromJson(earningsData);
    } on DioException catch (e) {
      print('❌ DioException fetching earnings: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      // Return empty earnings on error
      return earnings_model.EarningsModel(
        totalEarnings: 0,
        grossEarnings: 0,
        platformFees: 0,
        netEarnings: 0,
        totalRides: 0,
        averagePerRide: 0,
      );
    } catch (e) {
      print('❌ Error fetching earnings: $e');
      return earnings_model.EarningsModel(
        totalEarnings: 0,
        grossEarnings: 0,
        platformFees: 0,
        netEarnings: 0,
        totalRides: 0,
        averagePerRide: 0,
      );
    }
  }

  /// Get driver statistics
  /// GET /drivers/:id/stats
  static Future<earnings_model.DriverStats> getDriverStats(String driverId) async {
    try {
      print('📊 Fetching statistics for driver: $driverId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '/drivers/$driverId/stats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Stats fetched successfully: ${response.statusCode}');

      final statsData = response.data is Map
          ? (response.data['stats'] ?? response.data)
          : response.data;

      return earnings_model.DriverStats.fromJson(statsData);
    } on DioException catch (e) {
      print('❌ DioException fetching stats: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      // Return empty stats on error
      return earnings_model.DriverStats(
        totalRides: 0,
        completedRides: 0,
        cancelledRides: 0,
        completionRate: 0,
        averageRating: 0,
        totalRatings: 0,
        totalEarnings: 0,
        averageEarningPerRide: 0,
      );
    } catch (e) {
      print('❌ Error fetching stats: $e');
      return earnings_model.DriverStats(
        totalRides: 0,
        completedRides: 0,
        cancelledRides: 0,
        completionRate: 0,
        averageRating: 0,
        totalRatings: 0,
        totalEarnings: 0,
        averageEarningPerRide: 0,
      );
    }
  }

  /// Get driver payment history with optional status filter
  /// GET /drivers/:id/earnings/payments
  static Future<Map<String, dynamic>> getPaymentHistory({
    required String driverId,
    earnings_model.PaymentStatus? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      print('💰 Fetching payment history for driver: $driverId');
      if (status != null) print('   Status filter: ${status.value}');

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
        '/drivers/$driverId/earnings/payments',
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Payment history fetched successfully: ${response.statusCode}');

      final data = response.data is Map
          ? (response.data['data'] ?? response.data)
          : response.data;

      return {
        'payments': (data['payments'] as List?)
                ?.map((p) => {
                      'id': p['id'],
                      'rideId': p['rideId'],
                      'date': p['date'] != null ? DateTime.parse(p['date']) : null,
                      'grossFare': (p['grossFare'] ?? 0).toDouble(),
                      'driverEarning': (p['driverEarning'] ?? 0).toDouble(),
                      'platformFee': (p['platformFee'] ?? 0).toDouble(),
                      'tips': (p['tips'] ?? 0).toDouble(),
                      'netAmount': (p['netAmount'] ?? 0).toDouble(),
                      'paymentStatus': earnings_model.PaymentStatus.fromString(p['paymentStatus']),
                      'riderName': p['rider']?['name'],
                      'pickupAddress': p['pickupAddress'],
                      'dropoffAddress': p['dropoffAddress'],
                    })
                .toList() ??
            [],
        'pagination': data['pagination'] ?? {},
      };
    } on DioException catch (e) {
      print('❌ DioException fetching payment history: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      return {
        'payments': [],
        'pagination': {'currentPage': 1, 'totalPages': 0, 'totalPayments': 0},
      };
    } catch (e) {
      print('❌ Error fetching payment history: $e');
      return {
        'payments': [],
        'pagination': {'currentPage': 1, 'totalPages': 0, 'totalPayments': 0},
      };
    }
  }
}
