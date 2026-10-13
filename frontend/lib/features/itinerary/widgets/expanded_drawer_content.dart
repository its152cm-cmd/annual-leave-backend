import 'package:flutter/material.dart';

import '../../../../models/attraction.dart';
import '../../../../models/flight.dart';
import '../../../../models/food_option.dart';
import '../../../../models/hotel.dart';
import '../../../../models/itinerary.dart';
import 'attraction_list_view.dart';
import 'flight_comparison_view.dart';
import 'recommended_eats_view.dart';
import 'saved_places_view.dart';
import 'hotel_comparison_view.dart';
import 'panel_state.dart';

class ExpandedDrawerContent extends StatelessWidget {
  final String destinationCity;
  final String selectedCategory;
  final List<String> categories;
  final ValueChanged<PanelState> onPanelStateChanged;
  final ValueChanged<String> onCategorySelected;
  final String originCity;
  final String originCode;
  final String destinationCode;
  final Future<List<FlightOption>> flightsFuture;
  final Future<List<FlightDateChip>> dateChipsFuture;
  final Future<List<HotelOption>> hotelsFuture;
  final Future<List<FoodOption>> foodFuture; // Defined here
  final List<Attraction> attractions;
  final bool attractionsLoading;
  final ValueChanged<ItineraryDetailItem> onAddToTimeline;
  final List<String> cities; // trip stops, only shown when there are 2 or more
  final ValueChanged<String>? onCitySelected;

  const ExpandedDrawerContent({
    super.key,
    required this.destinationCity,
    required this.selectedCategory,
    required this.categories,
    required this.onPanelStateChanged,
    required this.onCategorySelected,
    required this.originCity,
    required this.originCode,
    required this.destinationCode,
    required this.flightsFuture,
    required this.dateChipsFuture,
    required this.hotelsFuture,
    required this.foodFuture, // Required in constructor
    required this.attractions,
    this.attractionsLoading = false,
    required this.onAddToTimeline,
    this.cities = const [],
    this.onCitySelected,
  });

  @override
  Widget build(BuildContext context) {
    final titleText = switch (selectedCategory) {
      'Flights' => 'Compare Flights',
      'Hotels' => 'Compare Hotels',
      'Food' => 'Recommended Eats',
      'Saved' => 'Your saved places',
      _ => '$destinationCity Sights',
    };

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  onPressed: () => onPanelStateChanged(PanelState.peek),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 36,
                  ),
                ),
                Expanded(
                  child: Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (cities.length > 1 && selectedCategory != 'Flights' && selectedCategory != 'Saved')
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final c in cities)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: c == destinationCity,
                        onSelected: (_) => onCitySelected?.call(c),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (selectedCategory) {
      case 'Flights':
        return FlightComparisonView(
          originCity: originCity,
          originCode: originCode,
          destinationCity: destinationCity,
          destinationCode: destinationCode,
          dateChipsFuture: dateChipsFuture,
          flightsFuture: flightsFuture,
          onAddToTimeline: onAddToTimeline,
        );
      case 'Hotels':
        return HotelComparisonView(
          destinationCity: destinationCity,
          hotelsFuture: hotelsFuture,
          onAddToTimeline: onAddToTimeline,
        );
      case 'Food':
        return RecommendedEatsScreen(
          destinationCity: destinationCity,
          foodFuture: foodFuture, // Passed down cleanly
          onAddToTimeline: onAddToTimeline,
        );
      case 'Saved':
        return SavedPlacesView(
          cities: cities.isNotEmpty ? cities : [destinationCity],
          onAddToTimeline: onAddToTimeline,
        );
      default:
        return AttractionListView(
          attractions: attractions,
          loading: attractionsLoading,
          destinationCity: destinationCity,
          onAddToTimeline: onAddToTimeline,
        );
    }
  }
}
