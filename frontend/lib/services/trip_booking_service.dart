import '../models/attraction.dart';
import '../models/flight.dart';
import '../models/food_option.dart';
import '../models/hotel.dart';
import '../models/trip.dart';
import '../models/trip_booking.dart';
import 'flight_service.dart';
import 'food_service.dart';
import 'hotel_service.dart';
import 'recommendation_service.dart';

class TripBookingService {
  final FlightService _flightService = FlightService();
  final HotelService _hotelService = HotelService();
  final RecommendationService _recommendationService = RecommendationService();
  final FoodService _foodService = FoodService();

  Future<TripBookingOptions> getOptions(Trip trip) async {
    final futures = await Future.wait<Object>([
      _flightService.getFlights(),
      _hotelService.searchHotels(trip.destination),
      _recommendationService.getRecommendedAttractions(),
      _foodService.getRecommendedEats(trip.destination),
    ]);
    return TripBookingOptions(
      flights: futures[0] as List<FlightOption>,
      hotels: futures[1] as List<HotelOption>,
      attractions: futures[2] as List<Attraction>,
      food: futures[3] as List<FoodOption>,
    );
  }

  TripBookingQuote estimate(
    Trip trip,
    TripBookingOptions options,
    TripBookingSelection selection,
  ) {
    final travellers = trip.travellerCount < 1 ? 1 : trip.travellerCount;
    final days = int.tryParse(trip.duration.split(' ').first) ?? 1;
    final selectedFlight = _findById(
      options.flights,
      selection.flightId,
      (flight) => flight.id,
    );
    final selectedHotel = _findById(
      options.hotels,
      selection.hotelId,
      (hotel) => hotel.id,
    );
    final selectedAttractions = options.attractions
        .where((attraction) => selection.attractionIds.contains(attraction.id))
        .toList();

    final flightCost = selectedFlight == null
        ? 600.0 * travellers
        : _price(selectedFlight.priceFormatted) * travellers;
    final accommodationCost = selectedHotel == null
        ? 120.0 * days
        : _price(selectedHotel.pricePerNightFormatted) * days;
    final activitiesCost = selectedAttractions.isEmpty
        ? 17.0 * days * travellers
        : selectedAttractions.fold<double>(
            0,
            (sum, attraction) => sum + _price(attraction.price) * travellers,
          );
    final foodCost = selection.foodIds.isEmpty
        ? 25.0 * days * travellers
        : 35.0 * selection.foodIds.length * travellers;
    final transportCost = (20.0 + days * 15.0) * travellers;

    return TripBookingQuote(
      plannedBudget: trip.plannedBudget,
      travellerCount: travellers,
      lines: [
        TripBookingBudgetLine(
          category: 'Flights',
          amount: flightCost,
          isSelected: selectedFlight != null,
        ),
        TripBookingBudgetLine(
          category: 'Accommodation',
          amount: accommodationCost,
          isSelected: selectedHotel != null,
        ),
        TripBookingBudgetLine(
          category: 'Activities',
          amount: activitiesCost,
          isSelected: selectedAttractions.isNotEmpty,
        ),
        TripBookingBudgetLine(
          category: 'Food',
          amount: foodCost,
          isSelected: selection.foodIds.isNotEmpty,
        ),
        TripBookingBudgetLine(
          category: 'Transport',
          amount: transportCost,
          isSelected: false,
        ),
      ],
    );
  }

  double _price(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  T? _findById<T>(List<T> items, String? id, String Function(T) getId) {
    if (id == null) return null;
    for (final item in items) {
      if (getId(item) == id) return item;
    }
    return null;
  }
}
