import 'attraction.dart';
import 'flight.dart';
import 'food_option.dart';
import 'hotel.dart';

class TripBookingOptions {
  const TripBookingOptions({
    required this.flights,
    required this.hotels,
    required this.attractions,
    required this.food,
  });

  final List<FlightOption> flights;
  final List<HotelOption> hotels;
  final List<Attraction> attractions;
  final List<FoodOption> food;
}

class TripBookingSelection {
  const TripBookingSelection({
    this.flightId,
    this.hotelId,
    this.attractionIds = const [],
    this.foodIds = const [],
  });

  final String? flightId;
  final String? hotelId;
  final List<String> attractionIds;
  final List<String> foodIds;
}

class TripBookingBudgetLine {
  const TripBookingBudgetLine({
    required this.category,
    required this.amount,
    required this.isSelected,
  });

  final String category;
  final double amount;
  final bool isSelected;
}

class TripBookingQuote {
  const TripBookingQuote({
    required this.lines,
    required this.plannedBudget,
    required this.travellerCount,
  });

  final List<TripBookingBudgetLine> lines;
  final double plannedBudget;
  final int travellerCount;

  double get total => lines.fold(0, (sum, line) => sum + line.amount);
  double get remaining => plannedBudget - total;
}
