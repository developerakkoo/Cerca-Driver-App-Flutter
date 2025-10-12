/// Notification model for driver notifications
class NotificationModel {
  final String id;
  final String userId;
  final String userType; // 'Driver' or 'Rider'
  final String title;
  final String message;
  final String type; // 'ride', 'payment', 'emergency', 'system', etc.
  final bool isRead;
  final Map<String, dynamic>? data; // Additional data (rideId, etc.)
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    this.userType = 'Driver',
    required this.title,
    required this.message,
    this.type = 'system',
    this.isRead = false,
    this.data,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['user'] ?? json['userId'] ?? '',
      userType: json['userType'] ?? 'Driver',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'system',
      isRead: json['isRead'] ?? false,
      data: json['data'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'user': userId,
      'userType': userType,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'NotificationModel(id: $id, title: $title, read: $isRead)';
}
