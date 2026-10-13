import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/recommendation.dart';

/// Individual Recommendation Card Component
class RecommendationCard extends StatelessWidget {
  final String destination;
  final String flightTime;
  final String cost;
  final String imageUrl;
  final String matchPercentage;
  final List<String> tags;
  final VoidCallback onTap;

  const RecommendationCard({
    super.key,
    required this.destination,
    required this.flightTime,
    required this.cost,
    required this.imageUrl,
    required this.matchPercentage,
    required this.tags,
    required this.onTap,
  });

  /// Factory constructor to easily create a card directly from a Recommendation model
  factory RecommendationCard.fromModel({
    Key? key,
    required Recommendation recommendation,
    required VoidCallback onTap,
  }) {
    return RecommendationCard(
      key: key,
      destination: recommendation.destination,
      flightTime: recommendation.flightTime,
      cost: recommendation.cost,
      imageUrl: recommendation.imageUrl,
      matchPercentage: recommendation.matchPercentage,
      tags: recommendation.tags,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.75),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        destination,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.flight_takeoff, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            flightTime,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'EST. COST',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        cost,
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}