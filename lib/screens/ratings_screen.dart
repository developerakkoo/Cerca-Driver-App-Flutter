import 'package:flutter/material.dart';
import 'package:driver_cerca/models/rating_model.dart';
import 'package:driver_cerca/services/rating_service.dart';
import 'package:driver_cerca/services/storage_service.dart';
import 'package:driver_cerca/constants/constants.dart';
import 'package:intl/intl.dart';

/// RatingsScreen displays all ratings received by the driver
class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  List<RatingModel> _ratings = [];
  RatingStats? _stats;
  bool _isLoading = false;
  String? _driverId;

  @override
  void initState() {
    super.initState();
    _loadDriverId();
  }

  Future<void> _loadDriverId() async {
    _driverId = await StorageService.getDriverId();
    if (_driverId != null) {
      _loadRatings();
    }
  }

  Future<void> _loadRatings() async {
    if (_driverId == null) return;

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        RatingService.getDriverRatings(_driverId!),
        RatingService.getDriverRatingStats(_driverId!),
      ]);

      setState(() {
        _ratings = results[0] as List<RatingModel>;
        _stats = results[1] as RatingStats;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error loading ratings: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Ratings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRatings),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRatings,
              child: _stats == null
                  ? const Center(child: Text('No rating data available'))
                  : Column(
                      children: [
                        // Rating summary card
                        _buildRatingSummaryCard(),
                        const Divider(height: 1),

                        // Ratings list
                        Expanded(
                          child: _ratings.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.star_outline,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No ratings yet',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Complete rides to receive ratings',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _ratings.length,
                                  itemBuilder: (context, index) {
                                    return _buildRatingCard(_ratings[index]);
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildRatingSummaryCard() {
    if (_stats == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Average rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _stats!.averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Icon(Icons.star, color: Colors.amber, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Based on ${_stats!.totalRatings} ${_stats!.totalRatings == 1 ? 'rating' : 'ratings'}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 20),

          // Rating distribution
          _buildRatingBars(),

          // Top tags
          if (_stats!.topTags.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _stats!.topTags.take(5).map((tag) {
                return Chip(
                  label: Text(tag),
                  backgroundColor: Colors.white.withOpacity(0.2),
                  labelStyle: const TextStyle(color: Colors.white),
                  avatar: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 16,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingBars() {
    if (_stats == null || _stats!.totalRatings == 0) {
      return const SizedBox();
    }

    return Column(
      children: List.generate(5, (index) {
        final star = 5 - index;
        final count = _stats!.ratingDistribution[star] ?? 0;
        final percentage = _stats!.totalRatings > 0
            ? (count / _stats!.totalRatings)
            : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text(
                '$star',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.star, color: Colors.amber, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.amber,
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildRatingCard(RatingModel rating) {
    final raterName = rating.ratedBy?.name ?? 'Anonymous';
    final formattedDate = DateFormat('MMM d, yyyy').format(rating.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name, date, and stars
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    raterName[0].toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        raterName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating.rating ? Icons.star : Icons.star_border,
                      color: index < rating.rating ? Colors.amber : Colors.grey,
                      size: 18,
                    );
                  }),
                ),
              ],
            ),

            // Review text
            if (rating.review != null && rating.review!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                rating.review!,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],

            // Tags
            if (rating.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: rating.tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    backgroundColor: Colors.green.shade50,
                    labelStyle: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
