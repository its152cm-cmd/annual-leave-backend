import 'package:flutter/material.dart';

import 'itinerary_overview_screen.dart';

class ItineraryDayDetailScreen extends StatelessWidget {
  final String itineraryId;
  final int dayIndex;

  const ItineraryDayDetailScreen({
    super.key,
    this.itineraryId = 'ITIN_KYOTO_2026',
    this.dayIndex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return ItineraryOverviewScreen(
      itineraryId: itineraryId,
      initialDayIndex: dayIndex,
    );
  }
}