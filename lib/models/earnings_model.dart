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
  });

  factory EarningsModel.fromJson(Map<String, dynamic> json) {
    return EarningsModel(
      totalEarnings: (json['totalEarnings'] ?? 0).toDouble(),
      grossEarnings: (json['grossEarnings'] ?? 0).toDouble(),
      platformFees: (json['platformFees'] ?? 0).toDouble(),
      netEarnings: (json['netEarnings'] ?? 0).toDouble(),
      totalRides: json['totalRides'] ?? 0,
      averagePerRide: (json['averagePerRide'] ?? 0).toDouble(),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      breakdown: json['breakdown'] != null
          ? (json['breakdown'] as List)
                .map((e) => EarningBreakdown.fromJson(e))
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
    };
  }

  @override
  String toString() =>
      'EarningsModel(net: ₹$netEarnings, rides: $totalRides, avg: ₹$averagePerRide)';
}

/// Daily/weekly earnings breakdown
class EarningBreakdown {
  final String date;
  final double earnings;
  final int ridesCount;

  EarningBreakdown({
    required this.date,
    required this.earnings,
    required this.ridesCount,
  });

  factory EarningBreakdown.fromJson(Map<String, dynamic> json) {
    return EarningBreakdown(
      date: json['date'] ?? json['_id'] ?? '',
      earnings: (json['earnings'] ?? json['totalEarnings'] ?? 0).toDouble(),
      ridesCount: json['ridesCount'] ?? json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'date': date, 'earnings': earnings, 'ridesCount': ridesCount};
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

/// Date range filter enum
enum DateRangeFilter {
  today('Today'),
  week('This Week'),
  month('This Month'),
  custom('Custom Range');

  final String label;
  const DateRangeFilter(this.label);
}
