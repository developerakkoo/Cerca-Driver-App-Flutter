/// Message Model for in-ride communication
/// Represents messages exchanged between driver and rider during a ride
class MessageModel {
  final String id;
  final String rideId;
  final SenderInfo sender;
  final ReceiverInfo receiver;
  final String message;
  final MessageType messageType;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  MessageModel({
    required this.id,
    required this.rideId,
    required this.sender,
    required this.receiver,
    required this.message,
    required this.messageType,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // Handle ride ID - backend sends 'ride' as ObjectId or populated object
    String rideId = '';
    if (json['ride'] != null) {
      if (json['ride'] is String) {
        rideId = json['ride'];
      } else if (json['ride'] is Map && json['ride']['_id'] != null) {
        rideId = json['ride']['_id'].toString();
      }
    }
    rideId = rideId.isEmpty ? (json['rideId'] ?? '') : rideId;

    // Handle sender - backend sends populated object with _id, name, fullName and senderModel
    final senderModelStr = json['senderModel'] ?? '';
    final senderRole = senderModelStr == 'Driver' ? SenderRole.driver : SenderRole.rider;
    final senderId = json['sender'] is Map 
        ? (json['sender']['_id'] ?? json['sender']['id'] ?? '').toString()
        : json['sender']?.toString() ?? '';

    // Handle receiver - backend sends populated object with _id, name, fullName and receiverModel
    final receiverModelStr = json['receiverModel'] ?? '';
    final receiverRole = receiverModelStr == 'Driver' ? ReceiverRole.driver : ReceiverRole.rider;
    final receiverId = json['receiver'] is Map
        ? (json['receiver']['_id'] ?? json['receiver']['id'] ?? '').toString()
        : json['receiver']?.toString() ?? '';

    return MessageModel(
      id: json['_id'] ?? json['id'] ?? '',
      rideId: rideId,
      sender: SenderInfo(id: senderId, role: senderRole),
      receiver: ReceiverInfo(id: receiverId, role: receiverRole),
      message: json['message'] ?? '',
      messageType: _parseMessageType(json['messageType']),
      isRead: json['isRead'] ?? false,
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'rideId': rideId,
      'sender': sender.toJson(),
      'receiver': receiver.toJson(),
      'message': message,
      'messageType': messageType.name,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static MessageType _parseMessageType(dynamic type) {
    if (type == null) return MessageType.text;
    final typeStr = type.toString().toLowerCase();
    switch (typeStr) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'location':
        return MessageType.location;
      default:
        return MessageType.text;
    }
  }

  MessageModel copyWith({
    String? id,
    String? rideId,
    SenderInfo? sender,
    ReceiverInfo? receiver,
    String? message,
    MessageType? messageType,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      rideId: rideId ?? this.rideId,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
      message: message ?? this.message,
      messageType: messageType ?? this.messageType,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Sender Information
class SenderInfo {
  final String id;
  final SenderRole role;

  SenderInfo({required this.id, required this.role});

  factory SenderInfo.fromJson(Map<String, dynamic> json) {
    return SenderInfo(
      id: json['id'] ?? '',
      role: _parseSenderRole(json['role']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'role': role.name};
  }

  static SenderRole _parseSenderRole(dynamic role) {
    if (role == null) return SenderRole.rider;
    final roleStr = role.toString().toLowerCase();
    switch (roleStr) {
      case 'driver':
        return SenderRole.driver;
      case 'rider':
        return SenderRole.rider;
      default:
        return SenderRole.rider;
    }
  }
}

/// Receiver Information
class ReceiverInfo {
  final String id;
  final ReceiverRole role;

  ReceiverInfo({required this.id, required this.role});

  factory ReceiverInfo.fromJson(Map<String, dynamic> json) {
    return ReceiverInfo(
      id: json['id'] ?? '',
      role: _parseReceiverRole(json['role']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'role': role.name};
  }

  static ReceiverRole _parseReceiverRole(dynamic role) {
    if (role == null) return ReceiverRole.rider;
    final roleStr = role.toString().toLowerCase();
    switch (roleStr) {
      case 'driver':
        return ReceiverRole.driver;
      case 'rider':
        return ReceiverRole.rider;
      default:
        return ReceiverRole.rider;
    }
  }
}

/// Message Type Enum
enum MessageType { text, image, location }

/// Sender Role Enum
enum SenderRole { driver, rider }

/// Receiver Role Enum
enum ReceiverRole { driver, rider }
