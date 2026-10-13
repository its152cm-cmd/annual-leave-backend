import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/flight.dart';
import '../../../../models/itinerary.dart';

class FlightCard extends StatelessWidget {
  final FlightOption flight;
  final bool isPrimary;
  final ValueChanged<ItineraryDetailItem> onAddToTimeline;

  const FlightCard({
    super.key,
    required this.flight,
    required this.isPrimary,
    required this.onAddToTimeline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flight_takeoff,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  flight.airlineName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                flight.priceFormatted,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? AppTheme.primaryColor : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${flight.departureTime} - ${flight.arrivalTime}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                flight.duration,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          if (flight.stops.isNotEmpty || flight.baggage.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              [flight.stops, flight.baggage]
                  .where((t) => t.isNotEmpty)
                  .join(' · '),
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                flight.flightType,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              Text(
                flight.terminal,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: isPrimary
                ? ElevatedButton.icon(
                    onPressed: () =>
                        onAddToTimeline(ItineraryScheduleOption.flight(flight)),
                    icon: const Icon(Icons.add, size: 16),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    label: const Text(
                      'Add to day',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () =>
                        onAddToTimeline(ItineraryScheduleOption.flight(flight)),
                    icon: const Icon(Icons.add, size: 16),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    label: const Text(
                      'Add to day',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
