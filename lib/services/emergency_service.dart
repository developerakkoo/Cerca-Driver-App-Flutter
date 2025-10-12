import 'package:dio/dio.dart';
import 'package:driver_cerca/services/storage_service.dart';

/// EmergencyService handles emergency alert API calls
class EmergencyService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://192.168.1.18:3000',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Get all emergency alerts for a driver
  static Future<List<Map<String, dynamic>>> getDriverEmergencyAlerts(
    String driverId,
  ) async {
    try {
      final token = await StorageService.getToken();
      final response = await _dio.get(
        '/emergency-alerts/driver/$driverId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['alerts'] ?? []);
      }
      throw Exception('Failed to fetch emergency alerts');
    } catch (e) {
      print('❌ Error fetching emergency alerts: $e');
      rethrow;
    }
  }

  /// Create an emergency alert (REST API backup to socket)
  static Future<Map<String, dynamic>> createEmergencyAlert({
    required String rideId,
    required String reportedBy,
    required String reporterType,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    try {
      final token = await StorageService.getToken();
      final response = await _dio.post(
        '/emergency-alerts',
        data: {
          'rideId': rideId,
          'reportedBy': reportedBy,
          'reporterType': reporterType,
          'location': {'latitude': latitude, 'longitude': longitude},
          'notes': notes,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 201) {
        return response.data['alert'];
      }
      throw Exception('Failed to create emergency alert');
    } catch (e) {
      print('❌ Error creating emergency alert: $e');
      rethrow;
    }
  }

  /// Update emergency alert status
  static Future<void> updateEmergencyAlertStatus(
    String alertId,
    String status,
  ) async {
    try {
      final token = await StorageService.getToken();
      await _dio.patch(
        '/emergency-alerts/$alertId',
        data: {'status': status},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      print('❌ Error updating emergency alert status: $e');
      rethrow;
    }
  }
}
