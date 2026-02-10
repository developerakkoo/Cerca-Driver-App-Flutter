/// Driver model matching Cerca API specification
class DriverModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? socketId;
  final LocationModel location;
  final bool isVerified;
  final bool isActive;
  final bool isBusy;
  final bool isOnline;
  final double rating;
  final int totalRatings;
  final double totalEarnings;
  final int completedRidesCount;
  final VehicleInfo? vehicleInfo;
  final DateTime? lastSeen;
  final List<String> documents;
  final List<RideReference> rides;
  final DateTime createdAt;
  final DateTime updatedAt;

  DriverModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.socketId,
    required this.location,
    this.isVerified = false,
    this.isActive = false,
    this.isBusy = false,
    this.isOnline = false,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.totalEarnings = 0.0,
    this.completedRidesCount = 0,
    this.vehicleInfo,
    this.lastSeen,
    this.documents = const [],
    this.rides = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      socketId: json['socketId'],
      location: json['location'] != null
          ? LocationModel.fromJson(json['location'])
          : LocationModel(coordinates: [0.0, 0.0]),
      isVerified: json['isVerified'] ?? false,
      isActive: json['isActive'] ?? false,
      isBusy: json['isBusy'] ?? false,
      isOnline: json['isOnline'] ?? false,
      rating: (json['rating'] ?? 0).toDouble(),
      totalRatings: json['totalRatings'] ?? 0,
      totalEarnings: (json['totalEarnings'] ?? 0).toDouble(),
      completedRidesCount: json['completedRidesCount'] ?? 0,
      vehicleInfo: json['vehicleInfo'] != null
          ? VehicleInfo.fromJson(json['vehicleInfo'])
          : null,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : null,
      documents: json['documents'] != null
          ? List<String>.from(json['documents'])
          : [],
      rides: json['rides'] != null
          ? (json['rides'] as List)
                .map((ride) => RideReference.fromJson(ride))
                .toList()
          : [],
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
      'name': name,
      'email': email,
      'phone': phone,
      'socketId': socketId,
      'location': location.toJson(),
      'isVerified': isVerified,
      'isActive': isActive,
      'isBusy': isBusy,
      'isOnline': isOnline,
      'rating': rating,
      'totalRatings': totalRatings,
      'totalEarnings': totalEarnings,
      'completedRidesCount': completedRidesCount,
      'vehicleInfo': vehicleInfo?.toJson(),
      'lastSeen': lastSeen?.toIso8601String(),
      'documents': documents,
      'rides': rides.map((ride) => ride.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  DriverModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? socketId,
    LocationModel? location,
    bool? isVerified,
    bool? isActive,
    bool? isBusy,
    bool? isOnline,
    double? rating,
    int? totalRatings,
    double? totalEarnings,
    int? completedRidesCount,
    VehicleInfo? vehicleInfo,
    DateTime? lastSeen,
    List<String>? documents,
    List<RideReference>? rides,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      socketId: socketId ?? this.socketId,
      location: location ?? this.location,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      isBusy: isBusy ?? this.isBusy,
      isOnline: isOnline ?? this.isOnline,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      completedRidesCount: completedRidesCount ?? this.completedRidesCount,
      vehicleInfo: vehicleInfo ?? this.vehicleInfo,
      lastSeen: lastSeen ?? this.lastSeen,
      documents: documents ?? this.documents,
      rides: rides ?? this.rides,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'DriverModel(id: $id, name: $name, email: $email, isOnline: $isOnline, rating: $rating)';
  }
}

/// Location model for GeoJSON Point
class LocationModel {
  final String type;
  final List<double> coordinates; // [longitude, latitude]

  LocationModel({this.type = 'Point', required this.coordinates});

  double get longitude => coordinates.isNotEmpty ? coordinates[0] : 0.0;
  double get latitude => coordinates.length > 1 ? coordinates[1] : 0.0;

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      type: json['type'] ?? 'Point',
      coordinates: json['coordinates'] != null
          ? List<double>.from(
              json['coordinates'].map((coord) => coord.toDouble()),
            )
          : [0.0, 0.0],
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'coordinates': coordinates};
  }

  @override
  String toString() => 'Location($latitude, $longitude)';
}

/// Vehicle information model
class VehicleInfo {
  final String? make;
  final String? model;
  final int? year;
  final String? color;
  final String? licensePlate;
  final VehicleType vehicleType;

  VehicleInfo({
    this.make,
    this.model,
    this.year,
    this.color,
    this.licensePlate,
    this.vehicleType = VehicleType.sedan,
  });

  factory VehicleInfo.fromJson(Map<String, dynamic> json) {
    return VehicleInfo(
      make: json['make'],
      model: json['model'],
      year: json['year'],
      color: json['color'],
      licensePlate: json['licensePlate'],
      vehicleType: VehicleType.fromString(json['vehicleType'] ?? 'sedan'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'licensePlate': licensePlate,
      'vehicleType': vehicleType.value,
    };
  }

  @override
  String toString() => '$make $model ($year) - $licensePlate';
}

/// Vehicle type enum
enum VehicleType {
  sedan('sedan'),
  suv('suv'),
  hatchback('hatchback'),
  auto('auto');

  final String value;
  const VehicleType(this.value);

  static VehicleType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'sedan':
        return VehicleType.sedan;
      case 'suv':
        return VehicleType.suv;
      case 'hatchback':
        return VehicleType.hatchback;
      case 'auto':
        return VehicleType.auto;
      default:
        return VehicleType.sedan;
    }
  }

  String get displayName {
    switch (this) {
      case VehicleType.sedan:
        return 'Sedan';
      case VehicleType.suv:
        return 'SUV';
      case VehicleType.hatchback:
        return 'Hatchback';
      case VehicleType.auto:
        return 'Auto';
    }
  }
}

/// Ride reference in driver's ride list
class RideReference {
  final String rideId;
  final RideStatus status;

  RideReference({required this.rideId, required this.status});

  factory RideReference.fromJson(Map<String, dynamic> json) {
    return RideReference(
      rideId: json['rideId'] ?? json['_id'] ?? '',
      status: RideStatus.fromString(json['status'] ?? 'requested'),
    );
  }

  Map<String, dynamic> toJson() {
    return {'rideId': rideId, 'status': status.value};
  }
}

/// Ride status enum
enum RideStatus {
  requested('requested'),
  pending('pending'),
  accepted('accepted'),
  arrived('arrived'),
  ongoing('ongoing'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  const RideStatus(this.value);

  static RideStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'requested':
        return RideStatus.requested;
      case 'pending':
        return RideStatus.pending;
      case 'accepted':
        return RideStatus.accepted;
      case 'arrived':
        return RideStatus.arrived;
      case 'ongoing':
        return RideStatus.ongoing;
      case 'in_progress':
        return RideStatus.inProgress;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
        return RideStatus.cancelled;
      default:
        return RideStatus.requested;
    }
  }

  String get displayName {
    switch (this) {
      case RideStatus.requested:
        return 'Requested';
      case RideStatus.pending:
        return 'Pending';
      case RideStatus.accepted:
        return 'Accepted';
      case RideStatus.arrived:
        return 'Arrived';
      case RideStatus.ongoing:
        return 'Ongoing';
      case RideStatus.inProgress:
        return 'In Progress';
      case RideStatus.completed:
        return 'Completed';
      case RideStatus.cancelled:
        return 'Cancelled';
    }
  }
}
