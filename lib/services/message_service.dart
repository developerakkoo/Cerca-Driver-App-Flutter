import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:driver_cerca/constants/api_constants.dart';
import 'package:driver_cerca/models/message_model.dart';
import 'package:driver_cerca/services/storage_service.dart';

/// MessageService handles all REST API calls related to messaging
class MessageService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Send a message via REST API
  /// POST /drivers (driver message routes are mounted under /drivers)
  static Future<MessageModel> sendMessage({
    required String rideId,
    required String senderId,
    required SenderRole senderRole,
    required String receiverId,
    required ReceiverRole receiverRole,
    required String message,
    MessageType messageType = MessageType.text,
  }) async {
    try {
      print('💬 ========================================');
      print('💬 [MessageService] sendMessage() called');
      print('💬 ========================================');
      print('⏰ Timestamp: ${DateTime.now().toIso8601String()}');
      print('🆔 Ride ID: $rideId');
      print('👤 Sender ID: $senderId');
      print('👤 Sender Role: ${senderRole.name}');
      print('👤 Receiver ID: $receiverId');
      print('👤 Receiver Role: ${receiverRole.name}');
      print('💬 Message: ${message.substring(0, message.length > 50 ? 50 : message.length)}${message.length > 50 ? "..." : ""}');
      print('📝 Message Type: ${messageType.name}');

      final token = await StorageService.getToken();
      print('🔑 Token exists: ${token != null}');
      
      if (token == null) {
        print('❌ [MessageService] No authentication token found');
        throw Exception('No authentication token found');
      }

      final data = {
        'rideId': rideId,
        'senderId': senderId,
        'senderModel': senderRole.name == 'driver' ? 'Driver' : 'User',
        'receiverId': receiverId,
        'receiverModel': receiverRole.name == 'rider' ? 'User' : 'Driver',
        'message': message,
        'messageType': messageType.name,
      };

      print('📦 [MessageService] Request data: $data');
      print('🌐 [MessageService] API URL: ${ApiConstants.baseUrl}/drivers');

      final response = await _dio.post(
        '/drivers',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ [MessageService] Message sent successfully');
      print('   Status code: ${response.statusCode}');
      print('   Response data type: ${response.data.runtimeType}');
      print('   Response data: ${response.data}');

      print('🔄 [MessageService] Parsing response...');
      if (response.data is Map) {
        final responseMap = response.data as Map<String, dynamic>;
        print('✅ [MessageService] Response is Map');
        print('   Response keys: ${responseMap.keys.toList()}');
        
        // Backend returns {message: "Message sent successfully", data: {...}}
        if (responseMap['data'] != null && responseMap['data'] is Map) {
          print('✅ [MessageService] Found data field in response');
          final messageModel = MessageModel.fromJson(
            Map<String, dynamic>.from(responseMap['data'] as Map),
          );
          print('✅ [MessageService] Message parsed successfully - ID: ${messageModel.id}');
          print('========================================');
          return messageModel;
        }
        // Fallback: if no 'data' field, try parsing the whole response
        print('⚠️ [MessageService] No data field, parsing whole response');
        final messageModel = MessageModel.fromJson(responseMap);
        print('✅ [MessageService] Message parsed from whole response - ID: ${messageModel.id}');
        print('========================================');
        return messageModel;
      } else if (response.data is String) {
        // Backend might return a string response
        print('⚠️ [MessageService] Backend returned string response instead of object');
        // Try to parse as JSON
        try {
          final jsonData = json.decode(response.data);
          print('✅ [MessageService] String parsed as JSON');
          
          if (jsonData is Map) {
            print('   JSON keys: ${jsonData.keys.toList()}');
            // Backend returns {message: "Message sent successfully", data: {...}}
            if (jsonData['data'] != null && jsonData['data'] is Map) {
              print('✅ [MessageService] Found data field in JSON');
              final messageModel = MessageModel.fromJson(
                Map<String, dynamic>.from(jsonData['data'] as Map),
              );
              print('✅ [MessageService] Message parsed successfully - ID: ${messageModel.id}');
              print('========================================');
              return messageModel;
            }
            print('⚠️ [MessageService] No data field, parsing whole JSON');
            final messageModel = MessageModel.fromJson(Map<String, dynamic>.from(jsonData));
            print('✅ [MessageService] Message parsed from whole JSON - ID: ${messageModel.id}');
            print('========================================');
            return messageModel;
          }
        } catch (e) {
          print('❌ [MessageService] Failed to parse string response: $e');
        }
      }

      print('❌ [MessageService] Invalid response format');
      print('========================================');
      throw Exception('Invalid response format');
    } on DioException catch (e) {
      print('❌ [MessageService] DioException sending message: ${e.message}');
      print('   Error type: ${e.type}');
      if (e.response != null) {
        print('   Status Code: ${e.response?.statusCode}');
        print('   Response Data: ${e.response?.data}');
      }
      print('========================================');
      throw Exception('Failed to send message: ${e.message}');
    } catch (e, stackTrace) {
      print('❌ [MessageService] Error sending message: $e');
      print('   Error type: ${e.runtimeType}');
      print('   Stack trace: $stackTrace');
      print('========================================');
      throw Exception('Failed to send message: $e');
    }
  }

  /// Get all messages for a specific ride
  /// GET /drivers/ride/:rideId
  static Future<List<MessageModel>> getRideMessages(String rideId) async {
    try {
      print('💬 Fetching messages for ride: $rideId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '/drivers/ride/$rideId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Messages fetched successfully: ${response.statusCode}');

      if (response.data is List) {
        final messages = (response.data as List)
            .map((json) => MessageModel.fromJson(json))
            .toList();
        print('📦 Total messages: ${messages.length}');
        return messages;
      } else if (response.data is Map && response.data['messages'] != null) {
        final messages = (response.data['messages'] as List)
            .map((json) => MessageModel.fromJson(json))
            .toList();
        print('📦 Total messages: ${messages.length}');
        return messages;
      }

      return [];
    } on DioException catch (e) {
      print('❌ DioException fetching messages: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      throw Exception('Failed to fetch messages: ${e.message}');
    } catch (e) {
      print('❌ Error fetching messages: $e');
      throw Exception('Failed to fetch messages: $e');
    }
  }

  /// Mark a message as read
  /// PATCH /drivers/:messageId/read
  static Future<MessageModel> markMessageAsRead(String messageId) async {
    try {
      print('✅ Marking message as read: $messageId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.patch(
        '/drivers/$messageId/read',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Message marked as read: ${response.statusCode}');

      if (response.data is Map) {
        if (response.data['message'] != null) {
          return MessageModel.fromJson(response.data['message']);
        }
        return MessageModel.fromJson(response.data);
      }

      throw Exception('Invalid response format');
    } on DioException catch (e) {
      print('❌ DioException marking message as read: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      throw Exception('Failed to mark message as read: ${e.message}');
    } catch (e) {
      print('❌ Error marking message as read: $e');
      throw Exception('Failed to mark message as read: $e');
    }
  }

  /// Get unread message count for a ride
  static Future<int> getUnreadMessageCount(
    String rideId,
    String driverId,
  ) async {
    try {
      final messages = await getRideMessages(rideId);
      return messages
          .where((msg) => !msg.isRead && msg.receiver.id == driverId)
          .length;
    } catch (e) {
      print('❌ Error getting unread message count: $e');
      return 0;
    }
  }

  /// Get unread message count for a ride from backend endpoint
  static Future<int> getUnreadCountForRide(
    String rideId,
    String driverId,
  ) async {
    try {
      print('💬 Fetching unread count for ride: $rideId, driver: $driverId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '/drivers/ride/$rideId/unread-count',
        queryParameters: {
          'receiverId': driverId,
          'receiverModel': 'Driver',
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Unread count fetched successfully: ${response.statusCode}');

      if (response.data is Map) {
        final unreadCount = response.data['unreadCount'] as int? ?? 0;
        print('📦 Unread count: $unreadCount');
        return unreadCount;
      }

      return 0;
    } on DioException catch (e) {
      print('❌ DioException fetching unread count: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      return 0;
    } catch (e) {
      print('❌ Error fetching unread count: $e');
      return 0;
    }
  }

  /// Mark all messages as read for a ride
  static Future<void> markAllMessagesAsRead(
    String rideId,
    String driverId,
  ) async {
    try {
      print('✅ Marking all messages as read for ride: $rideId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.patch(
        '/drivers/ride/$rideId/read-all',
        data: {'receiverId': driverId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ All messages marked as read: ${response.statusCode}');
      print('📦 Modified count: ${response.data['modifiedCount'] ?? 0}');
    } on DioException catch (e) {
      print('❌ DioException marking all messages as read: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      // Fallback to individual marking if batch fails
      try {
        final messages = await getRideMessages(rideId);
        final unreadMessages = messages
            .where((msg) => !msg.isRead && msg.receiver.id == driverId)
            .toList();

        for (var message in unreadMessages) {
          await markMessageAsRead(message.id);
        }
        print('✅ All messages marked as read (fallback method)');
      } catch (fallbackError) {
        print('❌ Error in fallback method: $fallbackError');
      }
    } catch (e) {
      print('❌ Error marking all messages as read: $e');
    }
  }
}
