import 'package:dio/dio.dart';
import 'package:driver_cerca/models/message_model.dart';
import 'package:driver_cerca/services/storage_service.dart';

/// MessageService handles all REST API calls related to messaging
class MessageService {
  static const String baseUrl = 'http://192.168.1.18:3000';
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Send a message via REST API
  /// POST /messages
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
      print('💬 Sending message for ride: $rideId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final data = {
        'rideId': rideId,
        'sender': {'id': senderId, 'role': senderRole.name},
        'receiver': {'id': receiverId, 'role': receiverRole.name},
        'message': message,
        'messageType': messageType.name,
      };

      print('📤 Message data: $data');

      final response = await _dio.post(
        '/messages',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('✅ Message sent successfully: ${response.statusCode}');

      if (response.data is Map) {
        if (response.data['message'] != null) {
          return MessageModel.fromJson(response.data['message']);
        }
        return MessageModel.fromJson(response.data);
      }

      throw Exception('Invalid response format');
    } on DioException catch (e) {
      print('❌ DioException sending message: ${e.message}');
      if (e.response != null) {
        print('📦 Status Code: ${e.response?.statusCode}');
        print('📦 Response Data: ${e.response?.data}');
      }
      throw Exception('Failed to send message: ${e.message}');
    } catch (e) {
      print('❌ Error sending message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  /// Get all messages for a specific ride
  /// GET /messages/ride/:rideId
  static Future<List<MessageModel>> getRideMessages(String rideId) async {
    try {
      print('💬 Fetching messages for ride: $rideId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.get(
        '/messages/ride/$rideId',
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
  /// PATCH /messages/:messageId/read
  static Future<MessageModel> markMessageAsRead(String messageId) async {
    try {
      print('✅ Marking message as read: $messageId');

      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _dio.patch(
        '/messages/$messageId/read',
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

  /// Mark all messages as read for a ride
  static Future<void> markAllMessagesAsRead(
    String rideId,
    String driverId,
  ) async {
    try {
      final messages = await getRideMessages(rideId);
      final unreadMessages = messages
          .where((msg) => !msg.isRead && msg.receiver.id == driverId)
          .toList();

      for (var message in unreadMessages) {
        await markMessageAsRead(message.id);
      }

      print('✅ All messages marked as read for ride: $rideId');
    } catch (e) {
      print('❌ Error marking all messages as read: $e');
    }
  }
}
