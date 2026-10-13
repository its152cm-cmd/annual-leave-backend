import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../models/group_trip_summary.dart';

class ChatSummaryCard extends StatelessWidget {
  final GroupTripSummary tripSummary;
  final bool isExpanded;
  final VoidCallback onTapCard;
  final VoidCallback onToggleSummary;

  const ChatSummaryCard({
    super.key,
    required this.tripSummary,
    required this.isExpanded,
    required this.onTapCard,
    required this.onToggleSummary,
  });

  @override
  Widget build(BuildContext context) {
    if (tripSummary.isTripComplete) {
      return GestureDetector(
        onTap: onTapCard,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Expanded(
                child: Text(
                  'Itinerary',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
      );
    }

    final dates = tripSummary.confirmedDetails['Dates'] ?? tripSummary.dates;
    final destination =
        tripSummary.confirmedDetails['Destination'] ?? tripSummary.destination;

    final int completedItems = tripSummary.completedItems;
    final int totalItems = tripSummary.totalItems;
    final double progressValue = totalItems > 0 ? tripSummary.progress : 0.0;
    final bool isReady = tripSummary.isReadyToPlan;

    return GestureDetector(
      onTap: onTapCard,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row: Title + Green Toggle Button Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trip Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppTheme.textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isReady
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isReady ? Icons.check : Icons.hourglass_empty,
                            size: 16,
                            color: isReady
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFF9800),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isReady ? 'Ready to plan' : 'In progress',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isReady
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Green Icon Button moved inside the summary box
                    InkWell(
                      onTap: onToggleSummary,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isExpanded
                              ? Icons.summarize
                              : Icons.summarize_outlined,
                          color: AppTheme.primaryGreen,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (isExpanded) ...[
              const SizedBox(height: 10),

              // Key Details Grid (DATES, DESTINATION)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DATES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF788896),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dates,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DESTINATION',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF788896),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destination,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE8F5E9),
                  color: const Color(0xFF66BB6A),
                ),
              ),
              const SizedBox(height: 8),

              // Completion Subtitle
              Text(
                '$completedItems of $totalItems planning items are complete',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF788896),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
