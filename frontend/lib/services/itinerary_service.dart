import '../core/api/api_client.dart';
import '../mock/mock_itinerary.dart';
import '../models/flight.dart';
import '../models/hotel.dart';
import '../models/itinerary.dart';
import '../models/trip.dart';

class ItineraryService {
  ItineraryService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// Trips whose itinerary the backend does not have (yet).
  static final Set<String> _notOnBackend = {};
  static final Map<String, Future<GeneratedItinerary?>> _loading = {};

  static final Map<String, GeneratedItinerary> _generatedItineraries = {};
  static final Map<String, Map<int, List<ItineraryDetailItem>>> _savedDayItems =
      {};

  /// Forget what is kept in memory for a saved trip so the next read comes from
  /// the backend (after the host replans, or when someone else may have edited).
  static void forget(String itineraryId) {
    if (!_uuid.hasMatch(itineraryId)) return;
    _generatedItineraries.remove(itineraryId);
    _savedDayItems.remove(itineraryId);
    _notOnBackend.remove(itineraryId);
  }

  /// Trips opened from Top Picks whose itinerary has not yet been rearranged by the user's preferences.
  static final Set<String> _topPickTrips = {};
  static void markTopPick(String tripId) => _topPickTrips.add(tripId);
  static void unmarkTopPick(String tripId) => _topPickTrips.remove(tripId);
  static bool isTopPick(String tripId) => _topPickTrips.contains(tripId);
  static bool hasGenerated(String tripId) => _generatedItineraries.containsKey(tripId);

  static void saveGeneratedItinerary(GeneratedItinerary itinerary) {
    _generatedItineraries[itinerary.overview.id] = itinerary;
    _notOnBackend.remove(itinerary.overview.id);
  }

  /// The itinerary kept in memory, or the one saved on the backend (loaded
  /// once and then kept in memory). null = none exists, so callers fall back
  /// to the sample itinerary.
  Future<GeneratedItinerary?> _generatedFor(String itineraryId) {
    final cached = _generatedItineraries[itineraryId];
    if (cached != null) return Future.value(cached);
    if (!_uuid.hasMatch(itineraryId) || _notOnBackend.contains(itineraryId)) {
      return Future.value(null);
    }
    return _loading.putIfAbsent(itineraryId, () async {
      try {
        final response = await _apiClient.get('/api/itinerary/$itineraryId');
        final itinerary = GeneratedItinerary.fromJson(
          Map<String, dynamic>.from(response as Map),
        );
        _generatedItineraries[itineraryId] = itinerary;
        return itinerary;
      } on ApiException catch (error) {
        if (error.statusCode == 404) {
          _notOnBackend.add(itineraryId);
          return null;
        }
        rethrow;
      } finally {
        _loading.remove(itineraryId);
      }
    });
  }

  GeneratedItinerary getOrCreateTopPickItinerary(
    Trip trip, {
    required String flightTime,
    FlightOption? selectedFlight,
    HotelOption? selectedHotel,
    bool onlyConfirmedTravelOptions = false,
  }) {
    final saved = _generatedItineraries[trip.id];
    if (saved != null) return saved;

    const dayThemes = [
      'Arrival and local orientation',
      'Culture and heritage',
      'Scenic highlights',
      'Markets and neighbourhoods',
      'Nature and local cuisine',
      'Farewell and return journey',
    ];
    final dayCount = int.tryParse(trip.duration.split(' ').first) ?? 6;
    final startDate = _startDateFor(trip.dateRange);
    final dayDetails = <int, List<ItineraryDetailItem>>{};
    final days = <ItineraryDayOverview>[];

    for (var dayNumber = 1; dayNumber <= dayCount; dayNumber++) {
      final date = startDate.add(Duration(days: dayNumber - 1));
      final dayTheme = dayThemes[(dayNumber - 1) % dayThemes.length];
      final events = <ItineraryDetailItem>[];
      final stops = <ItineraryStop>[];

      void addEvent({
        required String start,
        required String end,
        required String title,
        required String subtitle,
        required String duration,
        required String mode,
        required String type,
        String bookingUrl = '',
      }) {
        final id = '${trip.id}_D${dayNumber}_E${events.length + 1}';
        events.add(
          ItineraryDetailItem(
            id: id,
            timeStart: start,
            timeEnd: end,
            title: title,
            subtitle: subtitle,
            duration: duration,
            mode: mode,
            type: type,
            bookingUrl: bookingUrl,
          ),
        );
        stops.add(ItineraryStop(id: id, name: title));
      }

      if (dayNumber == 1) {
        if (!onlyConfirmedTravelOptions || selectedFlight != null) {
          addEvent(
            start: _formatTime(selectedFlight?.departureTime, '8:30 AM'),
            end: _formatTime(selectedFlight?.arrivalTime, '11:00 AM'),
            title: selectedFlight == null
                ? 'Flight to ${trip.destination}'
                : 'Flight ${selectedFlight.route}',
            subtitle: selectedFlight == null
                ? '$flightTime · ${trip.originCity} departure'
                : '${selectedFlight.airlineName} · ${selectedFlight.route} · ${selectedFlight.priceFormatted}',
            duration: selectedFlight?.duration ?? flightTime,
            mode: 'Flight',
            type: 'flight',
            bookingUrl: selectedFlight?.bookingUrl ?? '',
          );
        }
        if (!onlyConfirmedTravelOptions) {
          addEvent(
            start: '12:00 PM',
            end: '12:45 PM',
            title: 'Airport transfer',
            subtitle: 'Transfer to your ${trip.destination} accommodation',
            duration: '45 mins',
            mode: 'Transit',
            type: 'transit',
          );
        }
        if (!onlyConfirmedTravelOptions || selectedHotel != null) {
          final hotelTime = _formatTime(selectedHotel?.checkInTime, '2:00 PM');
          addEvent(
            start: hotelTime,
            end: _addMinutesToTime(hotelTime, 60),
            title: selectedHotel == null
                ? 'Hotel check-in'
                : 'Hotel check-in: ${selectedHotel.name}',
            subtitle: selectedHotel == null
                ? '${trip.destination} city hotel · 5-night stay'
                : '${selectedHotel.location} · ${selectedHotel.pricePerNightFormatted}',
            duration: '1 hr',
            mode: 'Stay',
            type: 'hotel',
            bookingUrl: selectedHotel?.bookingUrl ?? '',
          );
        }
      } else if (dayNumber == dayCount && !onlyConfirmedTravelOptions) {
        addEvent(
          start: '8:00 AM',
          end: '9:00 AM',
          title: 'Hotel check-out',
          subtitle: 'Luggage collection and departure preparation',
          duration: '1 hr',
          mode: 'Stay',
          type: 'hotel',
        );
      } else {
        addEvent(
          start: '8:00 AM',
          end: '9:00 AM',
          title: 'Breakfast at the hotel',
          subtitle: '${trip.destination} local breakfast',
          duration: '1 hr',
          mode: 'Meal',
          type: 'food',
        );
      }

      addEvent(
        start: '10:00 AM',
        end: '12:00 PM',
        title: '$dayTheme in ${trip.destination}',
        subtitle: 'Guided highlights and local recommendations',
        duration: '2 hrs',
        mode: 'Explore',
        type: 'attraction',
      );
      addEvent(
        start: '1:00 PM',
        end: '2:00 PM',
        title: 'Lunch near ${trip.destination}',
        subtitle: 'Local cuisine and regional favourites',
        duration: '1 hr',
        mode: 'Meal',
        type: 'food',
      );

      if (dayNumber == dayCount && !onlyConfirmedTravelOptions) {
        addEvent(
          start: '4:00 PM',
          end: '7:00 PM',
          title: 'Return flight to Kuala Lumpur',
          subtitle: '$flightTime · ${trip.destination} departure',
          duration: flightTime,
          mode: 'Flight',
          type: 'flight',
          bookingUrl: selectedFlight?.bookingUrl ?? '',
        );
      } else {
        if (dayNumber != dayCount || !onlyConfirmedTravelOptions) {
          addEvent(
            start: '3:00 PM',
            end: '5:00 PM',
            title: '$dayTheme experience',
            subtitle: 'Flexible time to explore ${trip.destination}',
            duration: '2 hrs',
            mode: 'Explore',
            type: 'attraction',
          );
        }
      }

      if (dayNumber == dayCount &&
          onlyConfirmedTravelOptions &&
          selectedHotel != null) {
        final checkOutTime = _formatTime(selectedHotel.checkOutTime, '9:00 AM');
        addEvent(
          start: checkOutTime,
          end: _addMinutesToTime(checkOutTime, 30),
          title: 'Hotel check-out: ${selectedHotel.name}',
          subtitle: selectedHotel.location,
          duration: '30 mins',
          mode: 'Stay',
          type: 'hotel',
          bookingUrl: selectedHotel.bookingUrl,
        );
      }

      dayDetails[dayNumber] = events;
      days.add(
        ItineraryDayOverview(
          dayNumber: dayNumber,
          dateString: _formatDate(date),
          location: trip.destination,
          stops: stops,
        ),
      );
    }

    final total = trip.estimatedBudget ?? trip.plannedBudget;
    final generated = GeneratedItinerary(
      overview: ItineraryOverview(
        id: trip.id,
        title: '${trip.destination} Itinerary',
        destination: trip.destination,
        dateRange: trip.dateRange,
        durationDays: dayCount,
        days: days,
        categories: const ['Flights', 'Hotels', 'Attractions', 'Food'],
        originCode: 'KUL',
        originCity: trip.originCity,
        destinationCity: trip.destination,
      ),
      dayDetails: dayDetails,
      estimatedBudget: total,
      budgetBreakdown: trip.budgetBreakdown,
    );
    saveGeneratedItinerary(generated);
    return generated;
  }

  DateTime _startDateFor(String dateRange) {
    final sameMonth = RegExp(
      r'^(\d{1,2})\s*-\s*\d{1,2}\s+([A-Za-z]+)\s+(\d{4})$',
    ).firstMatch(dateRange);
    final crossMonth = RegExp(
      r'^(\d{1,2})\s+([A-Za-z]+)\s*-\s*\d{1,2}\s+[A-Za-z]+\s+(\d{4})$',
    ).firstMatch(dateRange);
    final day = int.tryParse(sameMonth?.group(1) ?? crossMonth?.group(1) ?? '');
    final monthName = sameMonth?.group(2) ?? crossMonth?.group(2);
    final year = int.tryParse(
      sameMonth?.group(3) ?? crossMonth?.group(3) ?? '',
    );
    if (day == null || monthName == null || year == null) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    const months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    return DateTime(year, months[monthName.toLowerCase()] ?? 1, day);
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  String _formatTime(String? value, String fallback) {
    if (value == null || value.trim().isEmpty) return fallback;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return value.trim();
    final hour = int.parse(match.group(1)!);
    final minute = match.group(2)!;
    final meridiem = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $meridiem';
  }

  String _addMinutesToTime(String time, int minutesToAdd) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(time);
    if (match == null) return time;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final isPm = match.group(3)!.toUpperCase() == 'PM';
    if (hour == 12) hour = 0;
    if (isPm) hour += 12;
    final totalMinutes = (hour * 60 + minute + minutesToAdd) % (24 * 60);
    final updatedHour = totalMinutes ~/ 60;
    final displayHour = updatedHour % 12 == 0 ? 12 : updatedHour % 12;
    final meridiem = updatedHour < 12 ? 'AM' : 'PM';
    return '$displayHour:${(totalMinutes % 60).toString().padLeft(2, '0')} $meridiem';
  }

  Future<ItineraryOverview> getItineraryOverview(
    String itineraryId, {
    Trip? trip,
  }) async {
    final generated = await _generatedFor(itineraryId);

    if (generated != null) {
      return _overviewWithSavedItems(itineraryId, generated.overview);
    }

    await Future.delayed(const Duration(milliseconds: 300));
    return _overviewWithSavedItems(
      itineraryId,
      ItineraryOverview.fromJson(mockItineraryOverview),
    );
  }

  Future<List<ItineraryDetailItem>> getDayDetailItems(
    String itineraryId,
    int dayNumber,
  ) async {
    final saved = _savedDayItems[itineraryId]?[dayNumber];
    if (saved != null) return List.unmodifiable(saved);

    final generated = await _generatedFor(itineraryId);

    if (generated != null) {
      return generated.dayDetails[dayNumber] ?? const <ItineraryDetailItem>[];
    }

    // Simulates future backend response latency
    await Future.delayed(const Duration(milliseconds: 300));

    final dayDetailsMap =
        mockItineraryOverview['day_details'] as Map<String, dynamic>?;

    if (dayDetailsMap != null &&
        dayDetailsMap.containsKey(dayNumber.toString())) {
      return _mockDayItems(
        dayDetailsMap[dayNumber.toString()] as List<dynamic>,
      );
    }

    return [];
  }

  Future<void> saveDayDetailItems(
    String itineraryId,
    int dayNumber,
    List<ItineraryDetailItem> items,
  ) async {
    _savedDayItems.putIfAbsent(
      itineraryId,
      () => <int, List<ItineraryDetailItem>>{},
    )[dayNumber] = List.unmodifiable(
      items,
    );

    final generated = _generatedItineraries[itineraryId];
    if (_uuid.hasMatch(itineraryId) && !_notOnBackend.contains(itineraryId)) {
      try {
        await _apiClient.put('/api/itinerary/$itineraryId/days/$dayNumber', {
          'items': items.map((item) => item.toJson()).toList(),
        });
      } on ApiException catch (error) {
        if (error.statusCode == 404) _notOnBackend.add(itineraryId);
        // Otherwise keep the change on this device; the backend is retried on
        // the next edit.
      }
    }
    if (generated == null) return;

    final dayDetails = Map<int, List<ItineraryDetailItem>>.from(
      generated.dayDetails,
    )..[dayNumber] = List.unmodifiable(items);
    _generatedItineraries[itineraryId] = GeneratedItinerary(
      overview: _overviewWithSavedItems(itineraryId, generated.overview),
      dayDetails: dayDetails,
      estimatedBudget: generated.estimatedBudget,
      budgetBreakdown: generated.budgetBreakdown,
    );
  }

  List<ItineraryDetailItem> _mockDayItems(List<dynamic> items) => items
      .map((item) => ItineraryDetailItem.fromJson(item as Map<String, dynamic>))
      .toList();

  ItineraryOverview _overviewWithSavedItems(
    String itineraryId,
    ItineraryOverview overview,
  ) {
    final savedDays = _savedDayItems[itineraryId];
    if (savedDays == null) return overview;

    return ItineraryOverview(
      id: overview.id,
      title: overview.title,
      destination: overview.destination,
      dateRange: overview.dateRange,
      durationDays: overview.durationDays,
      days: overview.days.map((day) {
        final items = savedDays[day.dayNumber];
        return items == null
            ? day
            : day.copyWith(
                stops: items
                    .map((item) => ItineraryStop(id: item.id, name: item.title))
                    .toList(),
              );
      }).toList(),
      categories: overview.categories,
      originCode: overview.originCode,
      destinationCode: overview.destinationCode,
      originCity: overview.originCity,
      destinationCity: overview.destinationCity,
    );
  }

  Future<ItineraryOverview> getItinerary(String itineraryId) async {
    final generated = await _generatedFor(itineraryId);

    if (generated != null) {
      return _overviewWithSavedItems(itineraryId, generated.overview);
    }

    await Future.delayed(const Duration(milliseconds: 300));
    return _overviewWithSavedItems(
      itineraryId,
      ItineraryOverview.fromJson(mockItineraryOverview),
    );
  }
}
