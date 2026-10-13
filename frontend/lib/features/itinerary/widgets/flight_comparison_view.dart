import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/flight.dart';
import '../../../../models/itinerary.dart';
import 'flight_card.dart';
import 'flight_date_chips_bar.dart';

class FlightComparisonView extends StatelessWidget {
  final String originCity;
  final String originCode;
  final String destinationCity;
  final String destinationCode;
  final Future<List<FlightDateChip>> dateChipsFuture;
  final Future<List<FlightOption>> flightsFuture;
  final ValueChanged<ItineraryDetailItem> onAddToTimeline;

  const FlightComparisonView({
    super.key,
    required this.originCity,
    required this.originCode,
    required this.destinationCity,
    required this.destinationCode,
    required this.dateChipsFuture,
    required this.flightsFuture,
    required this.onAddToTimeline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$originCity ($originCode)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              Expanded(
                child: Text(
                  '$destinationCity ($destinationCode)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        FlightDateChipsBar(dateChipsFuture: dateChipsFuture),
        const SizedBox(height: 6),
        Expanded(
          child: FutureBuilder<List<FlightOption>>(
            future: flightsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                );
              }

              final flights = snapshot.data ?? [];
              if (flights.isEmpty) {
                return const Center(child: Text('No flights found.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: flights.length,
                itemBuilder: (context, index) {
                  final flight = flights[index];
                  final scheduleItem = ItineraryScheduleOption.flight(flight);
                  return Draggable<ItineraryDetailItem>(
                    data: scheduleItem,
                    feedback: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 280,
                        child: FlightCard(
                          flight: flight,
                          isPrimary: index == 0,
                          onAddToTimeline: onAddToTimeline,
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: FlightCard(
                        flight: flight,
                        isPrimary: index == 0,
                        onAddToTimeline: onAddToTimeline,
                      ),
                    ),
                    child: FlightCard(
                      flight: flight,
                      isPrimary: index == 0,
                      onAddToTimeline: onAddToTimeline,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
