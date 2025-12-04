import 'package:dio/dio.dart';
import 'package:driver_cerca/constants/api_constants.dart';
import 'package:driver_cerca/models/rating_model.dart';
import 'package:driver_cerca/services/storage_service.dart';

/// RatingService handles all REST API calls related to ratings
class RatingService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Submit a rating for a ride
  /// POST /ratings
  static Future<RatingModel> submitRating({
    required String rideId,
    required String ratedToId,
    required String ratedToType, // 'Driver' or 'Rider'
    required double rating,
    String? review,
    List<String>? tags,
  }) async {
    try {
      print('⭐ Submitting rating for ride: $rideId');
      print('   Rating: $rating stars');
      print('   Review: ${review ?? "No review"}');
      print('   Tags: ${tags ?? []}');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.post(
        '/ratings',
        data: {
          'ride': rideId,
          'ratedTo': ratedToId,
          'ratedToType': ratedToType,
          'rating': rating,
          if (review != null && review.isNotEmpty) 'review': review,
          if (tags != null && tags.isNotEmpty) 'tags': tags,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Rating submitted successfully: ${response.statusCode}');

      final ratingData = response.data is Map
          ? (response.data['rating'] ?? response.data)
          : response.data;

      return RatingModel.fromJson(ratingData);
    } on DioException catch (e) {
      print('❌ DioException submitting rating: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      throw Exception('Failed to submit rating: ${e.message}');
    } catch (e) {
      print('❌ Error submitting rating: $e');
      throw Exception('Failed to submit rating: $e');
    }
  }

  /// Get all ratings received by a driver
  /// GET /ratings/Driver/:driverId
  static Future<List<RatingModel>> getDriverRatings(String driverId) async {
    try {
      print('⭐ Fetching ratings for driver: $driverId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '/ratings/Driver/$driverId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Ratings fetched successfully: ${response.statusCode}');

      if (response.data is List) {
        final ratings = (response.data as List)
            .map((json) => RatingModel.fromJson(json))
            .toList();
        print('📦 Total ratings: ${ratings.length}');
        return ratings;
      } else if (response.data is Map && response.data['ratings'] != null) {
        final ratings = (response.data['ratings'] as List)
            .map((json) => RatingModel.fromJson(json))
            .toList();
        print('📦 Total ratings: ${ratings.length}');
        return ratings;
      }

      return [];
    } on DioException catch (e) {
      print('❌ DioException fetching ratings: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      throw Exception('Failed to fetch ratings: ${e.message}');
    } catch (e) {
      print('❌ Error fetching ratings: $e');
      throw Exception('Failed to fetch ratings: $e');
    }
  }

  /// Get rating statistics for a driver
  /// GET /ratings/Driver/:driverId/stats
  static Future<RatingStats> getDriverRatingStats(String driverId) async {
    try {
      print('📊 Fetching rating statistics for driver: $driverId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '/ratings/Driver/$driverId/stats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Rating stats fetched successfully: ${response.statusCode}');

      final statsData = response.data is Map
          ? (response.data['stats'] ?? response.data)
          : response.data;

      return RatingStats.fromJson(statsData);
    } on DioException catch (e) {
      print('❌ DioException fetching rating stats: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      // Return empty stats on error
      return RatingStats(
        averageRating: 0.0,
        totalRatings: 0,
        ratingDistribution: {},
      );
    } catch (e) {
      print('❌ Error fetching rating stats: $e');
      return RatingStats(
        averageRating: 0.0,
        totalRatings: 0,
        ratingDistribution: {},
      );
    }
  }

  /// Get ratings for a specific ride
  /// GET /ratings/ride/:rideId
  static Future<List<RatingModel>> getRideRatings(String rideId) async {
    try {
      print('⭐ Fetching ratings for ride: $rideId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '/ratings/ride/$rideId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Ride ratings fetched successfully: ${response.statusCode}');

      if (response.data is List) {
        return (response.data as List)
            .map((json) => RatingModel.fromJson(json))
            .toList();
      } else if (response.data is Map && response.data['ratings'] != null) {
        return (response.data['ratings'] as List)
            .map((json) => RatingModel.fromJson(json))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      print('❌ DioException fetching ride ratings: ${e.message}');
      throw Exception('Failed to fetch ride ratings: ${e.message}');
    } catch (e) {
      print('❌ Error fetching ride ratings: $e');
      throw Exception('Failed to fetch ride ratings: $e');
    }
  }
}
