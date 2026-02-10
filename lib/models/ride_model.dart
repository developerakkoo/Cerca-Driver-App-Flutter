import 'package:driver_cerca/models/driver_model.dart';

// Export RideStatus for convenience
export 'package:driver_cerca/models/driver_model.dart' show RideStatus;

/// Complete Ride model matching Cerca API specification
class RideModel {
  final String id;
  final RiderInfo? rider;
  final DriverInfo? driver;
  final String pickupAddress;
  final String dropoffAddress;
  final LocationModel pickupLocation;
  final LocationModel dropoffLocation;
  final double fare;
  final double distanceInKm;
  final RideStatus status;
  final RideType rideType;
  final String? cancelledBy;
  final String startOtp;
  final String stopOtp;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? driverSocketId;
  final String? userSocketId;
  final DateTime? actualStartTime;
  final DateTime? actualEndTime;
  final int? estimatedDuration;
  final int? actualDuration;
  final DateTime? estimatedArrivalTime;
  final DateTime? driverArrivedAt;
  final double? riderRating;
  final double? driverRating;
  final double tips;
  final double discount;
  final String? promoCode;
  final String? cancellationReason;
  final double cancellationFee;
  final String? transactionId;
  final CustomSchedule? customSchedule;
  final BookingType? bookingType;
  final BookingMeta? bookingMeta;
  final RideFor? rideFor;
  final PassengerInfo? passenger;
  final DateTime createdAt;
  final DateTime updatedAt;

  RideModel({
    required this.id,
    this.rider,
    this.driver,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.fare,
    required this.distanceInKm,
    required this.status,
    this.rideType = RideType.normal,
    this.cancelledBy,
    required this.startOtp,
    required this.stopOtp,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentStatus = PaymentStatus.pending,
    this.driverSocketId,
    this.userSocketId,
    this.actualStartTime,
    this.actualEndTime,
    this.estimatedDuration,
    this.actualDuration,
    this.estimatedArrivalTime,
    this.driverArrivedAt,
    this.riderRating,
    this.driverRating,
    this.tips = 0.0,
    this.discount = 0.0,
    this.promoCode,
    this.cancellationReason,
    this.cancellationFee = 0.0,
    this.transactionId,
    this.customSchedule,
    this.bookingType,
    this.bookingMeta,
    this.rideFor,
    this.passenger,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['_id'] ?? json['id'] ?? '',
      rider: json['rider'] != null && json['rider'] is Map
          ? RiderInfo.fromJson(json['rider'])
          : null,
      driver: json['driver'] != null && json['driver'] is Map
          ? DriverInfo.fromJson(json['driver'])
          : null,
      pickupAddress: json['pickupAddress'] ?? '',
      dropoffAddress: json['dropoffAddress'] ?? '',
      pickupLocation: json['pickupLocation'] != null
          ? LocationModel.fromJson(json['pickupLocation'])
          : LocationModel(coordinates: [0.0, 0.0]),
      dropoffLocation: json['dropoffLocation'] != null
          ? LocationModel.fromJson(json['dropoffLocation'])
          : LocationModel(coordinates: [0.0, 0.0]),
      fare: (json['fare'] ?? 0).toDouble(),
      distanceInKm: (json['distanceInKm'] ?? 0).toDouble(),
      status: RideStatus.fromString(json['status'] ?? 'requested'),
      rideType: RideType.fromString(json['rideType'] ?? 'normal'),
      cancelledBy: json['cancelledBy'],
      startOtp: json['startOtp'] ?? '',
      stopOtp: json['stopOtp'] ?? '',
      paymentMethod: PaymentMethod.fromString(json['paymentMethod'] ?? 'CASH'),
      paymentStatus: PaymentStatus.fromString(
        json['paymentStatus'] ?? 'pending',
      ),
      driverSocketId: json['driverSocketId'],
      userSocketId: json['userSocketId'],
      actualStartTime: json['actualStartTime'] != null
          ? DateTime.parse(json['actualStartTime'])
          : null,
      actualEndTime: json['actualEndTime'] != null
          ? DateTime.parse(json['actualEndTime'])
          : null,
      estimatedDuration: json['estimatedDuration'],
      actualDuration: json['actualDuration'],
      estimatedArrivalTime: json['estimatedArrivalTime'] != null
          ? DateTime.parse(json['estimatedArrivalTime'])
          : null,
      driverArrivedAt: json['driverArrivedAt'] != null
          ? DateTime.parse(json['driverArrivedAt'])
          : null,
      riderRating: json['riderRating']?.toDouble(),
      driverRating: json['driverRating']?.toDouble(),
      tips: (json['tips'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      promoCode: json['promoCode'],
      cancellationReason: json['cancellationReason'],
      cancellationFee: (json['cancellationFee'] ?? 0).toDouble(),
      transactionId: json['transactionId'],
      customSchedule: json['customSchedule'] != null
          ? CustomSchedule.fromJson(json['customSchedule'])
          : null,
      bookingType: json['bookingType'] != null
          ? BookingType.fromString(json['bookingType'])
          : null,
      bookingMeta: json['bookingMeta'] != null
          ? BookingMeta.fromJson(json['bookingMeta'])
          : null,
      rideFor: json['rideFor'] != null
          ? RideFor.fromString(json['rideFor'])
          : null,
      passenger: json['passenger'] != null
          ? PassengerInfo.fromJson(json['passenger'])
          : null,
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
      'rider': rider?.toJson(),
      'driver': driver?.toJson(),
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'pickupLocation': pickupLocation.toJson(),
      'dropoffLocation': dropoffLocation.toJson(),
      'fare': fare,
      'distanceInKm': distanceInKm,
      'status': status.value,
      'rideType': rideType.value,
      'cancelledBy': cancelledBy,
      'startOtp': startOtp,
      'stopOtp': stopOtp,
      'paymentMethod': paymentMethod.value,
      'paymentStatus': paymentStatus.value,
      'driverSocketId': driverSocketId,
      'userSocketId': userSocketId,
      'actualStartTime': actualStartTime?.toIso8601String(),
      'actualEndTime': actualEndTime?.toIso8601String(),
      'estimatedDuration': estimatedDuration,
      'actualDuration': actualDuration,
      'estimatedArrivalTime': estimatedArrivalTime?.toIso8601String(),
      'driverArrivedAt': driverArrivedAt?.toIso8601String(),
      'riderRating': riderRating,
      'driverRating': driverRating,
      'tips': tips,
      'discount': discount,
      'promoCode': promoCode,
      'cancellationReason': cancellationReason,
      'cancellationFee': cancellationFee,
      'transactionId': transactionId,
      'customSchedule': customSchedule?.toJson(),
      'bookingType': bookingType?.value,
      'bookingMeta': bookingMeta?.toJson(),
      'rideFor': rideFor?.value,
      'passenger': passenger?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Check if this is a scheduled booking (not instant)
  bool isScheduledBooking() {
    return bookingType != null && bookingType != BookingType.instant;
  }

  /// Check if this is a Full Day booking
  bool isFullDayBooking() {
    return bookingType == BookingType.fullDay;
  }

  /// Check if ride is active (for Full Day bookings, check if scheduled time has arrived)
  bool isRideActive() {
    if (bookingType == BookingType.fullDay && bookingMeta?.startTime != null) {
      final startTime = bookingMeta!.startTime!;
      final now = DateTime.now();
      return now.isAfter(startTime) || now.isAtSameMomentAs(startTime);
    }
    // For instant rides or other booking types, consider active if status allows
    return status == RideStatus.accepted || 
           status == RideStatus.inProgress || 
           status == RideStatus.arrived ||
           status == RideStatus.ongoing;
  }

  /// Get booking start time if available
  DateTime? getBookingStartTime() {
    return bookingMeta?.startTime;
  }

  /// Get booking end time if available
  DateTime? getBookingEndTime() {
    return bookingMeta?.endTime;
  }

  @override
  String toString() =>
      'RideModel(id: $id, status: ${status.displayName}, fare: ₹$fare)';
}

/// Rider information
class RiderInfo {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;

  RiderInfo({required this.id, required this.fullName, this.phone, this.email});

  factory RiderInfo.fromJson(Map<String, dynamic> json) {
    return RiderInfo(
      id: json['_id'] ?? json['id'] ?? '',
      fullName: json['fullName'] ?? json['name'] ?? 'Unknown Rider',
      phone: json['phone'] ?? json['phoneNumber'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'_id': id, 'fullName': fullName, 'phone': phone, 'email': email};
  }
}

/// Driver information in ride
class DriverInfo {
  final String id;
  final String name;
  final String phone;
  final double? rating;

  DriverInfo({
    required this.id,
    required this.name,
    required this.phone,
    this.rating,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      rating: json['rating']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'_id': id, 'name': name, 'phone': phone, 'rating': rating};
  }
}

/// Ride type enum
enum RideType {
  normal('normal'),
  wholeDay('whole_day'),
  custom('custom');

  final String value;
  const RideType(this.value);

  static RideType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'normal':
        return RideType.normal;
      case 'whole_day':
        return RideType.wholeDay;
      case 'custom':
        return RideType.custom;
      default:
        return RideType.normal;
    }
  }

  String get displayName {
    switch (this) {
      case RideType.normal:
        return 'Normal';
      case RideType.wholeDay:
        return 'Whole Day';
      case RideType.custom:
        return 'Custom';
    }
  }
}

/// Payment method enum
enum PaymentMethod {
  cash('CASH'),
  razorpay('RAZORPAY'),
  wallet('WALLET');

  final String value;
  const PaymentMethod(this.value);

  static PaymentMethod fromString(String value) {
    switch (value.toUpperCase()) {
      case 'CASH':
        return PaymentMethod.cash;
      case 'RAZORPAY':
        return PaymentMethod.razorpay;
      case 'WALLET':
        return PaymentMethod.wallet;
      default:
        return PaymentMethod.cash;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.razorpay:
        return 'Razorpay';
      case PaymentMethod.wallet:
        return 'Wallet';
    }
  }
}

/// Payment status enum
enum PaymentStatus {
  pending('pending'),
  completed('completed'),
  failed('failed'),
  refunded('refunded');

  final String value;
  const PaymentStatus(this.value);

  static PaymentStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'completed':
        return PaymentStatus.completed;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }
}

/// Booking type enum
enum BookingType {
  instant('INSTANT'),
  fullDay('FULL_DAY'),
  rental('RENTAL'),
  dateWise('DATE_WISE');

  final String value;
  const BookingType(this.value);

  static BookingType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'INSTANT':
        return BookingType.instant;
      case 'FULL_DAY':
        return BookingType.fullDay;
      case 'RENTAL':
        return BookingType.rental;
      case 'DATE_WISE':
        return BookingType.dateWise;
      default:
        return BookingType.instant;
    }
  }

  String get displayName {
    switch (this) {
      case BookingType.instant:
        return 'Instant';
      case BookingType.fullDay:
        return 'Full Day';
      case BookingType.rental:
        return 'Rental';
      case BookingType.dateWise:
        return 'Date Wise';
    }
  }
}

/// Booking metadata for scheduled bookings
class BookingMeta {
  final DateTime? startTime;
  final DateTime? endTime;
  final int? days;
  final List<DateTime>? dates;

  BookingMeta({
    this.startTime,
    this.endTime,
    this.days,
    this.dates,
  });

  factory BookingMeta.fromJson(Map<String, dynamic> json) {
    return BookingMeta(
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : null,
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'])
          : null,
      days: json['days'],
      dates: json['dates'] != null
          ? (json['dates'] as List)
              .map((d) => DateTime.parse(d))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'days': days,
      'dates': dates?.map((d) => d.toIso8601String()).toList(),
    };
  }
}

/// Ride for enum (SELF or OTHER)
enum RideFor {
  self('SELF'),
  other('OTHER');

  final String value;
  const RideFor(this.value);

  static RideFor fromString(String value) {
    switch (value.toUpperCase()) {
      case 'SELF':
        return RideFor.self;
      case 'OTHER':
        return RideFor.other;
      default:
        return RideFor.self;
    }
  }
}

/// Passenger information for rides booked for other person
class PassengerInfo {
  final String? name;
  final String? phone;
  final String? relation;
  final String? notes;

  PassengerInfo({this.name, this.phone, this.relation, this.notes});

  factory PassengerInfo.fromJson(Map<String, dynamic> json) {
    return PassengerInfo(
      name: json['name'],
      phone: json['phone'],
      relation: json['relation'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'relation': relation,
      'notes': notes,
    };
  }
}

/// Custom schedule for custom rides
class CustomSchedule {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? startTime;
  final String? endTime;

  CustomSchedule({this.startDate, this.endDate, this.startTime, this.endTime});

  factory CustomSchedule.fromJson(Map<String, dynamic> json) {
    return CustomSchedule(
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      startTime: json['startTime'],
      endTime: json['endTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}
