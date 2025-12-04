import 'package:dio/dio.dart';
import 'package:driver_cerca/constants/api_constants.dart';
import 'package:driver_cerca/models/ride_model.dart';
import 'package:driver_cerca/services/storage_service.dart';

/// RideService handles all REST API calls related to rides
class RideService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Get all rides for a specific driver
  /// GET /drivers/:driverId/rides
  static Future<List<RideModel>> getDriverRides(String driverId) async {
    try {
      print('🚗 Fetching rides for driver: $driverId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '/drivers/$driverId/rides',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Rides fetched successfully: ${response.statusCode}');

      if (response.data is List) {
        final rides = (response.data as List)
            .map((json) => RideModel.fromJson(json))
            .toList();
        print('📦 Total rides: ${rides.length}');
        return rides;
      } else if (response.data is Map && response.data['rides'] != null) {
        final rides = (response.data['rides'] as List)
            .map((json) => RideModel.fromJson(json))
            .toList();
        print('📦 Total rides: ${rides.length}');
        return rides;
      }

      return [];
    } on DioException catch (e) {
      print('❌ DioException fetching rides: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      throw Exception('Failed to fetch rides: ${e.message}');
    } catch (e) {
      print('❌ Error fetching rides: $e');
      throw Exception('Failed to fetch rides: $e');
    }
  }

  /// Get a specific ride by ID
  /// GET /rides/:rideId
  static Future<RideModel> getRideById(String rideId) async {
    try {
      print('🚗 Fetching ride details for: $rideId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '/rides/$rideId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Ride details fetched successfully: ${response.statusCode}');

      if (response.data is Map) {
        if (response.data['ride'] != null) {
          return RideModel.fromJson(response.data['ride']);
        }
        return RideModel.fromJson(response.data);
      }

      throw Exception('Invalid response format');
    } on DioException catch (e) {
      print('❌ DioException fetching ride: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      throw Exception('Failed to fetch ride: ${e.message}');
    } catch (e) {
      print('❌ Error fetching ride: $e');
      throw Exception('Failed to fetch ride: $e');
    }
  }

  /// Get rides filtered by status
  static Future<List<RideModel>> getRidesByStatus(
    String driverId,
    RideStatus status,
  ) async {
    try {
      final allRides = await getDriverRides(driverId);
      return allRides.where((ride) => ride.status == status).toList();
    } catch (e) {
      print('❌ Error filtering rides by status: $e');
      throw Exception('Failed to filter rides: $e');
    }
  }

  /// Get active ride (if any)
  static Future<RideModel?> getActiveRide(String driverId) async {
    try {
      final allRides = await getDriverRides(driverId);

      // Active ride can be in these statuses
      final activeStatuses = [
        RideStatus.pending,
        RideStatus.accepted,
        RideStatus.arrived,
        RideStatus.ongoing,
      ];

      for (var ride in allRides) {
        if (activeStatuses.contains(ride.status)) {
          return ride;
        }
      }

      return null;
    } catch (e) {
      print('❌ Error getting active ride: $e');
      return null;
    }
  }

  /// Get completed rides
  static Future<List<RideModel>> getCompletedRides(String driverId) async {
    return getRidesByStatus(driverId, RideStatus.completed);
  }

  /// Get cancelled rides
  static Future<List<RideModel>> getCancelledRides(String driverId) async {
    return getRidesByStatus(driverId, RideStatus.cancelled);
  }

  /// Get ride history with pagination
  static Future<Map<String, dynamic>> getRideHistory({
    required String driverId,
    int page = 1,
    int limit = 20,
    RideStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      print('📜 Fetching ride history - Page: $page, Limit: $limit');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final queryParams = <String, dynamic>{'page': page, 'limit': limit};

      if (status != null) {
        queryParams['status'] = status.name;
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final response = await _dio.get(
        '/drivers/$driverId/rides',
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Ride history fetched successfully');

      final data = response.data;
      if (data is Map) {
        final rides = (data['rides'] ?? data['data'] ?? []) as List;
        return {
          'rides': rides.map((json) => RideModel.fromJson(json)).toList(),
          'total': data['total'] ?? rides.length,
          'page': data['page'] ?? page,
          'totalPages': data['totalPages'] ?? 1,
        };
      }

      return {'rides': <RideModel>[], 'total': 0, 'page': 1, 'totalPages': 1};
    } on DioException catch (e) {
      print('❌ DioException fetching ride history: ${e.message}');
      throw Exception('Failed to fetch ride history: ${e.message}');
    } catch (e) {
      print('❌ Error fetching ride history: $e');
      throw Exception('Failed to fetch ride history: $e');
    }
  }
}
