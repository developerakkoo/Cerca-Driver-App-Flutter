import 'package:dio/dio.dart';
import 'package:driver_cerca/constants/api_constants.dart';
import 'package:driver_cerca/models/ride_model.dart';
import 'package:driver_cerca/services/storage_service.dart';

/// BookingService handles all REST API calls related to scheduled bookings
class BookingService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Get upcoming scheduled bookings for a driver
  /// GET /drivers/:driverId/upcoming-bookings
  static Future<List<RideModel>> getUpcomingBookings(String driverId) async {
    try {
      print('📅 Fetching upcoming bookings for driver: $driverId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '/drivers/$driverId/upcoming-bookings',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Upcoming bookings fetched successfully: ${response.statusCode}');

      if (response.data is Map && response.data['bookings'] != null) {
        final bookings = (response.data['bookings'] as List)
            .map((json) => RideModel.fromJson(json))
            .toList();
        print('📦 Total upcoming bookings: ${bookings.length}');
        return bookings;
      }

      return [];
    } on DioException catch (e) {
      print('❌ Error fetching upcoming bookings: ${e.message}');
      if (e.response != null) {
        print('   Status: ${e.response!.statusCode}');
        print('   Data: ${e.response!.data}');
      }
      rethrow;
    } catch (e) {
      print('❌ Unexpected error fetching upcoming bookings: $e');
      rethrow;
    }
  }

  /// Get bookings for a specific date
  /// Filters the upcoming bookings list by date
  static Future<List<RideModel>> getBookingsForDate(
    String driverId,
    DateTime date,
  ) async {
    try {
      final allBookings = await getUpcomingBookings(driverId);
      
      // Filter bookings for the specific date
      final dateBookings = allBookings.where((booking) {
        if (booking.bookingMeta?.startTime == null) return false;
        
        final bookingDate = booking.bookingMeta!.startTime!;
        return bookingDate.year == date.year &&
            bookingDate.month == date.month &&
            bookingDate.day == date.day;
      }).toList();

      print('📅 Found ${dateBookings.length} bookings for ${date.toString().split(' ')[0]}');
      return dateBookings;
    } catch (e) {
      print('❌ Error fetching bookings for date: $e');
      rethrow;
    }
  }
}

