/// Earnings model for driver earnings data
class EarningsModel {
  final double totalEarnings;
  final double grossEarnings;
  final double platformFees;
  final double netEarnings;
  final int totalRides;
  final double averagePerRide;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<EarningBreakdown>? breakdown;
  final List<EarningBreakdown>? dailyBreakdown;
  final List<EarningBreakdown>? weeklyBreakdown;
  final List<EarningBreakdown>? monthlyBreakdown;
  // Payment status fields
  final double totalPendingEarnings;
  final double totalCompletedEarnings;
  final int pendingEarningsCount;
  final int completedEarningsCount;
  final List<RecentRideEarning>? recentRides;
  // Tips and bonuses
  final double totalTips;
  final double totalBonuses;

  EarningsModel({
    required this.totalEarnings,
    required this.grossEarnings,
    required this.platformFees,
    required this.netEarnings,
    required this.totalRides,
    required this.averagePerRide,
    this.startDate,
    this.endDate,
    this.breakdown,
    this.dailyBreakdown,
    this.weeklyBreakdown,
    this.monthlyBreakdown,
    this.totalPendingEarnings = 0,
    this.totalCompletedEarnings = 0,
    this.pendingEarningsCount = 0,
    this.completedEarningsCount = 0,
    this.recentRides,
    this.totalTips = 0,
    this.totalBonuses = 0,
  });

  factory EarningsModel.fromJson(Map<String, dynamic> json) {
    // Handle nested data structure from API
    final data = json['data'] ?? json;
    final summary = data['summary'] ?? {};

    return EarningsModel(
      totalEarnings:
          (summary['netEarnings'] ??
                  summary['totalEarnings'] ??
                  json['totalEarnings'] ??
                  0)
              .toDouble(),
      grossEarnings:
          (summary['totalGrossEarnings'] ??
                  summary['grossEarnings'] ??
                  json['grossEarnings'] ??
                  0)
              .toDouble(),
      platformFees:
          (summary['totalPlatformFees'] ??
                  summary['platformFees'] ??
                  json['platformFees'] ??
                  0)
              .toDouble(),
      netEarnings: (summary['netEarnings'] ?? json['netEarnings'] ?? 0)
          .toDouble(),
      totalRides: summary['totalRides'] ?? json['totalRides'] ?? 0,
      averagePerRide:
          (summary['averageNetPerRide'] ??
                  summary['averagePerRide'] ??
                  json['averagePerRide'] ??
                  0)
              .toDouble(),
      startDate: data['period']?['start'] != null
          ? DateTime.parse(data['period']['start'])
          : (json['startDate'] != null
                ? DateTime.parse(json['startDate'])
                : null),
      endDate: data['period']?['end'] != null
          ? DateTime.parse(data['period']['end'])
          : (json['endDate'] != null ? DateTime.parse(json['endDate']) : null),
      breakdown: data['breakdown'] != null
          ? (data['breakdown']['daily'] as List?)
                ?.map((e) => EarningBreakdown.fromJson(e))
                .toList()
          : (json['breakdown'] != null
                ? (json['breakdown'] as List)
                      .map((e) => EarningBreakdown.fromJson(e))
                      .toList()
                : null),
      totalPendingEarnings: (summary['totalPendingEarnings'] ?? 0).toDouble(),
      totalCompletedEarnings: (summary['totalCompletedEarnings'] ?? 0)
          .toDouble(),
      pendingEarningsCount: summary['pendingEarningsCount'] ?? 0,
      completedEarningsCount: summary['completedEarningsCount'] ?? 0,
      totalTips: (summary['totalTips'] ?? 0).toDouble(),
      totalBonuses: (summary['totalBonuses'] ?? 0).toDouble(),
      dailyBreakdown: data['breakdown']?['daily'] != null
          ? (data['breakdown']['daily'] as List)
                .map((e) => EarningBreakdown.fromJson(e))
                .toList()
          : null,
      weeklyBreakdown: data['breakdown']?['weekly'] != null
          ? (data['breakdown']['weekly'] as List)
                .map((e) => EarningBreakdown.fromJson(e))
                .toList()
          : null,
      monthlyBreakdown: data['breakdown']?['monthly'] != null
          ? (data['breakdown']['monthly'] as List)
                .map((e) => EarningBreakdown.fromJson(e))
                .toList()
          : null,
      recentRides: data['recentRides'] != null
          ? (data['recentRides'] as List)
                .map((e) => RecentRideEarning.fromJson(e))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalEarnings': totalEarnings,
      'grossEarnings': grossEarnings,
      'platformFees': platformFees,
      'netEarnings': netEarnings,
      'totalRides': totalRides,
      'averagePerRide': averagePerRide,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'breakdown': breakdown?.map((e) => e.toJson()).toList(),
      'totalPendingEarnings': totalPendingEarnings,
      'totalCompletedEarnings': totalCompletedEarnings,
      'pendingEarningsCount': pendingEarningsCount,
      'completedEarningsCount': completedEarningsCount,
      'recentRides': recentRides?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() =>
      'EarningsModel(net: ₹$netEarnings, rides: $totalRides, avg: ₹$averagePerRide)';
}

/// Daily/weekly/monthly earnings breakdown
class EarningBreakdown {
  final String date; // date, weekStart, or month
  final double earnings;
  final int ridesCount;
  final double grossEarnings;
  final double driverEarnings;
  final double tips;
  final double netEarnings;

  EarningBreakdown({
    required this.date,
    required this.earnings,
    required this.ridesCount,
    this.grossEarnings = 0,
    this.driverEarnings = 0,
    this.tips = 0,
    this.netEarnings = 0,
  });

  factory EarningBreakdown.fromJson(Map<String, dynamic> json) {
    return EarningBreakdown(
      date:
          json['date'] ??
          json['weekStart'] ??
          json['month'] ??
          json['_id'] ??
          '',
      earnings:
          (json['netEarnings'] ??
                  json['earnings'] ??
                  json['totalEarnings'] ??
                  0)
              .toDouble(),
      ridesCount: json['rides'] ?? json['ridesCount'] ?? json['count'] ?? 0,
      grossEarnings: (json['grossEarnings'] ?? 0).toDouble(),
      driverEarnings: (json['driverEarnings'] ?? 0).toDouble(),
      tips: (json['tips'] ?? 0).toDouble(),
      netEarnings: (json['netEarnings'] ?? json['earnings'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'earnings': earnings,
      'ridesCount': ridesCount,
      'grossEarnings': grossEarnings,
      'driverEarnings': driverEarnings,
      'tips': tips,
      'netEarnings': netEarnings,
    };
  }
}

/// Recent ride earning with payment status
class RecentRideEarning {
  final String? rideId;
  final DateTime date;
  final double grossFare;
  final double driverEarning;
  final double platformFee;
  final double tips;
  final PaymentStatus paymentStatus;
  final String? pickupAddress;
  final String? dropoffAddress;
  final String? riderName;

  RecentRideEarning({
    this.rideId,
    required this.date,
    required this.grossFare,
    required this.driverEarning,
    required this.platformFee,
    this.tips = 0,
    required this.paymentStatus,
    this.pickupAddress,
    this.dropoffAddress,
    this.riderName,
  });

  factory RecentRideEarning.fromJson(Map<String, dynamic> json) {
    return RecentRideEarning(
      rideId: json['rideId']?.toString(),
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      grossFare: (json['grossFare'] ?? 0).toDouble(),
      driverEarning: (json['driverEarning'] ?? 0).toDouble(),
      platformFee: (json['platformFee'] ?? 0).toDouble(),
      tips: (json['tips'] ?? 0).toDouble(),
      paymentStatus: PaymentStatus.fromString(json['paymentStatus']),
      pickupAddress: json['pickupAddress'],
      dropoffAddress: json['dropoffAddress'],
      riderName: json['rider']?['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rideId': rideId,
      'date': date.toIso8601String(),
      'grossFare': grossFare,
      'driverEarning': driverEarning,
      'platformFee': platformFee,
      'tips': tips,
      'paymentStatus': paymentStatus.value,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'riderName': riderName,
    };
  }
}

/// Driver statistics
class DriverStats {
  final int totalRides;
  final int completedRides;
  final int cancelledRides;
  final double completionRate;
  final double averageRating;
  final int totalRatings;
  final double totalEarnings;
  final double averageEarningPerRide;
  final int totalDistance; // in km
  final int totalDuration; // in minutes
  final DateTime? memberSince;

  DriverStats({
    required this.totalRides,
    required this.completedRides,
    required this.cancelledRides,
    required this.completionRate,
    required this.averageRating,
    required this.totalRatings,
    required this.totalEarnings,
    required this.averageEarningPerRide,
    this.totalDistance = 0,
    this.totalDuration = 0,
    this.memberSince,
  });

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    return DriverStats(
      totalRides: json['totalRides'] ?? 0,
      completedRides: json['completedRides'] ?? 0,
      cancelledRides: json['cancelledRides'] ?? 0,
      completionRate: (json['completionRate'] ?? 0).toDouble(),
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      totalRatings: json['totalRatings'] ?? 0,
      totalEarnings: (json['totalEarnings'] ?? 0).toDouble(),
      averageEarningPerRide: (json['averageEarningPerRide'] ?? 0).toDouble(),
      totalDistance: json['totalDistance'] ?? 0,
      totalDuration: json['totalDuration'] ?? 0,
      memberSince: json['memberSince'] != null
          ? DateTime.parse(json['memberSince'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRides': totalRides,
      'completedRides': completedRides,
      'cancelledRides': cancelledRides,
      'completionRate': completionRate,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'totalEarnings': totalEarnings,
      'averageEarningPerRide': averageEarningPerRide,
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'memberSince': memberSince?.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'DriverStats(rides: $totalRides, earnings: ₹$totalEarnings, rating: $averageRating⭐)';
}

/// Payment status enum
enum PaymentStatus {
  pending('pending'),
  completed('completed'),
  failed('failed'),
  refunded('refunded');

  final String value;
  const PaymentStatus(this.value);

  static PaymentStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
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
}

/// Date range filter enum
enum DateRangeFilter {
  today('Today'),
  week('This Week'),
  month('This Month'),
  custom('Custom Range');

  final String label;
  const DateRangeFilter(this.label);
}
