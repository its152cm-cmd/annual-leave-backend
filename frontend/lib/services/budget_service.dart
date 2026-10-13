import '../mock/mock_budget.dart';
import '../models/budget.dart';
import '../models/trip.dart';
import 'flight_service.dart';
import 'hotel_service.dart';
import 'itinerary_service.dart';

class BudgetService {
  final FlightService _flightService = FlightService();
  final HotelService _hotelService = HotelService();
  final ItineraryService _itineraryService = ItineraryService();

  static double _parsePrice(String value) {
    final cleanedValue = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleanedValue.isEmpty) return 0.0;
    return double.tryParse(cleanedValue) ?? 0.0;
  }

  Future<TripBudgetEstimate> getTripEstimate(Trip trip) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final durationDays = int.tryParse(trip.duration.split(' ').first) ?? 1;
    final travellers = trip.travellerCount < 1 ? 1 : trip.travellerCount;

    final perPersonCategories = <(String, double)>[
      ('Transport', 20 + durationDays * 15),
      ('Accommodation', durationDays * 40),
      ('Food', durationDays * 25),
      ('Activities', durationDays * 17),
      ('Other expenses', durationDays * 3),
    ];
    final calculatedTotal = perPersonCategories.fold<double>(
      0,
      (sum, category) => sum + category.$2 * travellers,
    );
    final estimatedTotal = trip.estimatedBudget ?? calculatedTotal;

    final categories = <BudgetItem>[];
    var allocated = 0.0;
    for (var index = 0; index < perPersonCategories.length; index++) {
      final (name, perPersonAmount) = perPersonCategories[index];
      final amount =
          trip.budgetBreakdown?[name] ??
          (index == perPersonCategories.length - 1
              ? estimatedTotal - allocated
              : perPersonAmount * travellers);
      allocated += amount;
      categories.add(
        BudgetItem(
          category: name,
          amount: amount,
          status: BudgetStatus.estimated,
          percentage: estimatedTotal == 0 ? 0 : amount / estimatedTotal * 100,
          color: budgetCategoryColors[index],
        ),
      );
    }

    return TripBudgetEstimate(
      tripId: trip.id,
      plannedBudget: trip.plannedBudget,
      estimatedTotal: estimatedTotal,
      travellerCount: travellers,
      durationDays: durationDays,
      categories: categories,
    );
  }

  Future<BudgetSummary> getCalculatedBudget(String groupId) async {
    final flights = await _flightService.getFlights();
    final flightCost = flights.isNotEmpty
        ? _parsePrice(flights.first.priceFormatted)
        : 420.0;
    final flightStatus =
        flights.isNotEmpty && flights.first.bookingUrl.isNotEmpty
        ? BudgetStatus.booked
        : BudgetStatus.estimated;

    final hotels = await _hotelService.getHotels();
    final accommodationCost = hotels.isNotEmpty
        ? _parsePrice(hotels.first.pricePerNightFormatted) * 2
        : 360.0;

    final itinerary = await _itineraryService.getItinerary(groupId);
    final activitiesCost = itinerary.days.isEmpty
        ? 140.0
        : itinerary.days.fold<double>(
            0.0,
            (sum, day) => sum + (day.stops.length * 18.0),
          );

    const transportCost = 260.0;
    const foodCost = 360.0;

    final grandTotal =
        flightCost +
        accommodationCost +
        activitiesCost +
        transportCost +
        foodCost;

    double calcPercentage(double cost) {
      if (grandTotal <= 0) return 0.0;
      return (cost / grandTotal) * 100;
    }

    final items = <BudgetItem>[
      BudgetItem(
        category: 'Flight',
        amount: flightCost,
        status: flightStatus,
        percentage: calcPercentage(flightCost),
        color: budgetCategoryColors[0],
      ),
      BudgetItem(
        category: 'Accommodation',
        amount: accommodationCost,
        status: BudgetStatus.pending,
        percentage: calcPercentage(accommodationCost),
        color: budgetCategoryColors[1],
      ),
      BudgetItem(
        category: 'Activities',
        amount: activitiesCost,
        status: BudgetStatus.planned,
        percentage: calcPercentage(activitiesCost),
        color: budgetCategoryColors[2],
      ),
      BudgetItem(
        category: 'Transport',
        amount: transportCost,
        status: BudgetStatus.estimated,
        percentage: calcPercentage(transportCost),
        color: budgetCategoryColors[3],
      ),
      BudgetItem(
        category: 'Food',
        amount: foodCost,
        status: BudgetStatus.estimated,
        percentage: calcPercentage(foodCost),
        color: budgetCategoryColors[4],
      ),
    ];

    return BudgetSummary(
      groupId: groupId,
      totalAmount: grandTotal,
      items: items,
    );
  }
}
