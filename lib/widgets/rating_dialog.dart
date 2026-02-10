import 'package:flutter/material.dart';
import 'package:driver_cerca/services/rating_service.dart';
import 'package:driver_cerca/constants/constants.dart';

/// Show rating dialog for rating a rider after ride completion
Future<bool?> showRatingDialog({
  required BuildContext context,
  required String rideId,
  required String riderId,
  required String riderName,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) =>
        RatingDialog(rideId: rideId, riderId: riderId, riderName: riderName),
  );
}

class RatingDialog extends StatefulWidget {
  final String rideId;
  final String riderId;
  final String riderName;

  const RatingDialog({
    super.key,
    required this.rideId,
    required this.riderId,
    required this.riderName,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 5.0;
  final TextEditingController _reviewController = TextEditingController();
  final Set<String> _selectedTags = {}; // Stores backend enum values
  bool _isSubmitting = false;
  bool _popped = false;

  // Mapping: Display name -> Backend enum value
  static const Map<String, String> _tagMapping = {
    'Polite': 'polite',
    'Professional': 'professional',
    'Clean Vehicle': 'clean_vehicle',
    'Safe Driving': 'safe_driving',
  };

  // Available tags for display (only positive tags for driver rating rider)
  final List<String> _availableTags = [
    'Polite',
    'Professional',
    'Clean Vehicle',
    'Safe Driving',
  ];

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);

    try {
      // _selectedTags already contains backend enum values, just convert to list
      final backendTags = _selectedTags.toList();

      await RatingService.submitRating(
        rideId: widget.rideId,
        ratedToId: widget.riderId,
        ratedToType: 'Rider',
        rating: _rating,
        review: _reviewController.text.trim().isEmpty
            ? null
            : _reviewController.text.trim(),
        tags: backendTags.isNotEmpty ? backendTags : null,
      );

      if (mounted && !_popped) {
        _popped = true;
        Navigator.of(context, rootNavigator: true).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⭐ Rating submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to submit rating: ${e.toString().replaceAll('Exception: ', '')}'),
            duration: const Duration(seconds: 4),
          ),
        );
        // Don't prevent dismissal on error - user can still skip
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rate ${widget.riderName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating stars
            const Text(
              'How was your experience?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = star.toDouble();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        star <= _rating ? Icons.star : Icons.star_border,
                        color: star <= _rating ? Colors.amber : Colors.grey,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _getRatingText(_rating),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Review text
            const Text(
              'Share your thoughts (optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Tell us about your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),

            // Tags
            if (_rating >= 4) ...[
              const Text(
                'What did you like?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags.map((displayTag) {
                  final backendTag = _tagMapping[displayTag] ?? displayTag;
                  final isSelected = _selectedTags.contains(backendTag);
                  return FilterChip(
                    label: Text(displayTag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(backendTag);
                        } else {
                          _selectedTags.remove(backendTag);
                        }
                      });
                    },
                    selectedColor: Colors.green.shade100,
                    checkmarkColor: Colors.green.shade700,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  if (_popped) return;
                  _popped = true;
                  Navigator.of(context, rootNavigator: true).pop(false);
                },
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitRating,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit Rating'),
        ),
      ],
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'Excellent! 🌟';
    if (rating >= 4) return 'Great! 😊';
    if (rating >= 3) return 'Good 👍';
    if (rating >= 2) return 'Fair 😐';
    return 'Needs Improvement 😞';
  }
}
