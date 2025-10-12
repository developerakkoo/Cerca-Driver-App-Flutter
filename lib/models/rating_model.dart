/// Rating model for driver and rider ratings
class RatingModel {
  final String id;
  final String rideId;
  final RaterInfo? ratedBy; // Who gave the rating
  final RaterInfo? ratedTo; // Who received the rating
  final double rating; // 1-5 stars
  final String? review; // Optional text review
  final List<String> tags; // e.g., ['Punctual', 'Clean Vehicle', 'Polite']
  final DateTime createdAt;
  final DateTime updatedAt;

  RatingModel({
    required this.id,
    required this.rideId,
    this.ratedBy,
    this.ratedTo,
    required this.rating,
    this.review,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: json['_id'] ?? json['id'] ?? '',
      rideId: json['ride'] ?? json['rideId'] ?? '',
      ratedBy: json['ratedBy'] != null && json['ratedBy'] is Map
          ? RaterInfo.fromJson(json['ratedBy'])
          : null,
      ratedTo: json['ratedTo'] != null && json['ratedTo'] is Map
          ? RaterInfo.fromJson(json['ratedTo'])
          : null,
      rating: (json['rating'] ?? 0).toDouble(),
      review: json['review'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
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
      'ride': rideId,
      'ratedBy': ratedBy?.toJson(),
      'ratedTo': ratedTo?.toJson(),
      'rating': rating,
      'review': review,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'RatingModel(id: $id, rating: $rating⭐, ride: $rideId)';
}

/// Rater information (can be rider or driver)
class RaterInfo {
  final String id;
  final String name;
  final String? email;
  final String type; // 'Rider' or 'Driver'

  RaterInfo({
    required this.id,
    required this.name,
    this.email,
    this.type = 'Rider',
  });

  factory RaterInfo.fromJson(Map<String, dynamic> json) {
    return RaterInfo(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? json['fullName'] ?? 'Unknown',
      email: json['email'],
      type: json['type'] ?? 'Rider',
    );
  }

  Map<String, dynamic> toJson() {
    return {'_id': id, 'name': name, 'email': email, 'type': type};
  }
}

/// Rating statistics for a driver
class RatingStats {
  final double averageRating;
  final int totalRatings;
  final Map<int, int>
  ratingDistribution; // e.g., {5: 120, 4: 45, 3: 10, 2: 2, 1: 1}
  final List<String> topTags; // Most common positive tags
  final int fiveStarCount;
  final int fourStarCount;
  final int threeStarCount;
  final int twoStarCount;
  final int oneStarCount;

  RatingStats({
    required this.averageRating,
    required this.totalRatings,
    required this.ratingDistribution,
    this.topTags = const [],
    this.fiveStarCount = 0,
    this.fourStarCount = 0,
    this.threeStarCount = 0,
    this.twoStarCount = 0,
    this.oneStarCount = 0,
  });

  factory RatingStats.fromJson(Map<String, dynamic> json) {
    final distribution = <int, int>{};
    if (json['ratingDistribution'] != null) {
      final dist = json['ratingDistribution'] as Map<String, dynamic>;
      dist.forEach((key, value) {
        distribution[int.parse(key)] = value as int;
      });
    }

    return RatingStats(
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      totalRatings: json['totalRatings'] ?? 0,
      ratingDistribution: distribution,
      topTags: json['topTags'] != null
          ? List<String>.from(json['topTags'])
          : [],
      fiveStarCount: json['fiveStarCount'] ?? distribution[5] ?? 0,
      fourStarCount: json['fourStarCount'] ?? distribution[4] ?? 0,
      threeStarCount: json['threeStarCount'] ?? distribution[3] ?? 0,
      twoStarCount: json['twoStarCount'] ?? distribution[2] ?? 0,
      oneStarCount: json['oneStarCount'] ?? distribution[1] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'ratingDistribution': ratingDistribution.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'topTags': topTags,
      'fiveStarCount': fiveStarCount,
      'fourStarCount': fourStarCount,
      'threeStarCount': threeStarCount,
      'twoStarCount': twoStarCount,
      'oneStarCount': oneStarCount,
    };
  }

  double get percentage => totalRatings > 0 ? (averageRating / 5.0) * 100 : 0;

  @override
  String toString() =>
      'RatingStats(avg: $averageRating⭐, total: $totalRatings)';
}

/// Common rating tags
class RatingTags {
  static const List<String> positiveDriverTags = [
    'Punctual',
    'Clean Vehicle',
    'Safe Driving',
    'Polite',
    'Helpful',
    'Professional',
    'Good Communication',
    'Smooth Ride',
  ];

  static const List<String> negativeDriverTags = [
    'Late',
    'Rude Behavior',
    'Unsafe Driving',
    'Dirty Vehicle',
    'Wrong Route',
    'Unprofessional',
    'Poor Communication',
  ];
}
