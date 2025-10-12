import 'package:dio/dio.dart';
import 'package:driver_cerca/models/earnings_model.dart';
import 'package:driver_cerca/services/storage_service.dart';

/// EarningsService handles all REST API calls related to earnings
class EarningsService {
  static const String baseUrl = 'http://192.168.1.18:3000';
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Get driver earnings
  /// GET /drivers/:id/earnings
  static Future<EarningsModel> getDriverEarnings({
    required String driverId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      print('💰 Fetching earnings for driver: $driverId');
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

      final response = await _dio.get(
        '/drivers/$driverId/earnings',
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Earnings fetched successfully: ${response.statusCode}');

      final earningsData = response.data is Map
          ? (response.data['earnings'] ?? response.data)
          : response.data;

      return EarningsModel.fromJson(earningsData);
    } on DioException catch (e) {
      print('❌ DioException fetching earnings: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      // Return empty earnings on error
      return EarningsModel(
        totalEarnings: 0,
        grossEarnings: 0,
        platformFees: 0,
        netEarnings: 0,
        totalRides: 0,
        averagePerRide: 0,
      );
    } catch (e) {
      print('❌ Error fetching earnings: $e');
      return EarningsModel(
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
  static Future<DriverStats> getDriverStats(String driverId) async {
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

      return DriverStats.fromJson(statsData);
    } on DioException catch (e) {
      print('❌ DioException fetching stats: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      // Return empty stats on error
      return DriverStats(
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
      return DriverStats(
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
}
