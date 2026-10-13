import 'package:flutter/material.dart';

import 'attraction.dart';
import 'flight.dart';
import 'food_option.dart';
import 'hotel.dart';

class ItineraryScheduleOption {
  const ItineraryScheduleOption._();

  /// "Marunouchi, Tokyo" or "Kita Ward, Osaka · 淀屋橋" -> "Tokyo" / "Osaka".
  static String cityOf(String location) =>
      location.split(' · ').first.split(',').last.trim();

  static ItineraryDetailItem flight(FlightOption flight) {
    return ItineraryDetailItem(
      id: 'flight-${flight.id}',
      timeStart: '9:00 AM',
      timeEnd: '10:30 AM',
      title: '${flight.airlineName} · ${flight.flightType}',
      subtitle:
          '${flight.departureTime} - ${flight.arrivalTime} · ${flight.duration} · ${flight.priceFormatted}',
      duration: flight.duration,
      mode: 'Flight',
      type: 'flight',
      bookingUrl: flight.bookingUrl,
    );
  }

  static ItineraryDetailItem hotel(HotelOption hotel) {
    return ItineraryDetailItem(
      id: 'hotel-${hotel.id}',
      timeStart: '2:00 PM',
      timeEnd: '3:00 PM',
      title: hotel.name,
      subtitle: '${hotel.location} · ${hotel.pricePerNightFormatted}',
      duration: '1 hr',
      mode: 'Stay',
      type: 'hotel',
      bookingUrl: hotel.bookingUrl,
      city: cityOf(hotel.location),
    );
  }

  static ItineraryDetailItem attraction(Attraction attraction) {
    return ItineraryDetailItem(
      id: 'attraction-${attraction.id}',
      timeStart: '10:00 AM',
      timeEnd: '11:30 AM',
      title: attraction.title,
      subtitle: attraction.location,
      duration: '1 hr 30 mins',
      mode: 'Visit',
      type: 'attraction',
      city: cityOf(attraction.location),
    );
  }

  static ItineraryDetailItem food(FoodOption food) {
    return ItineraryDetailItem(
      id: 'food-${food.id}',
      timeStart: '12:00 PM',
      timeEnd: '1:00 PM',
      title: food.name,
      subtitle: [
        if (food.cuisineType.isNotEmpty) food.cuisineType,
        if (food.location.isNotEmpty) food.location,
      ].join(' · '),
      duration: '1 hr',
      mode: 'Meal',
      type: 'food',
      city: cityOf(food.location),
    );
  }
}

class ItineraryOverview {
  final String id;
  final String title;
  final String destination;
  final String dateRange;
  final int durationDays;
  final List<ItineraryDayOverview> days;
  final List<String>? categories;
  final String? originCode;
  final String? destinationCode;
  final String? originCity;
  final String? destinationCity;

  const ItineraryOverview({
    required this.id,
    required this.title,
    required this.destination,
    required this.dateRange,
    required this.durationDays,
    required this.days,
    this.categories,
    this.originCode,
    this.destinationCode,
    this.originCity,
    this.destinationCity,
  });

  factory ItineraryOverview.fromJson(Map<String, dynamic> json) {
    return ItineraryOverview(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      dateRange: json['date_range'] as String? ?? '',
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
      days: (json['days'] as List<dynamic>? ?? [])
          .map(
            (day) => ItineraryDayOverview.fromJson(day as Map<String, dynamic>),
          )
          .toList(),
      categories: (json['categories'] as List<dynamic>?)
          ?.map((category) => category as String)
          .toList(),
      originCode: json['origin_code'] as String?,
      destinationCode: json['destination_code'] as String?,
      originCity: json['origin_city'] as String?,
      destinationCity: json['destination_city'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'destination': destination,
    'date_range': dateRange,
    'duration_days': durationDays,
    'days': days.map((day) => day.toJson()).toList(),
    'categories': categories,
    'origin_code': originCode,
    'destination_code': destinationCode,
    'origin_city': originCity,
    'destination_city': destinationCity,
  };
}

class ItineraryDayOverview {
  final int dayNumber;
  final String dateString;
  final String location;
  final List<ItineraryStop> stops;

  const ItineraryDayOverview({
    required this.dayNumber,
    required this.dateString,
    required this.location,
    required this.stops,
  });

  factory ItineraryDayOverview.fromJson(Map<String, dynamic> json) {
    return ItineraryDayOverview(
      dayNumber: (json['day_number'] as num?)?.toInt() ?? 0,
      dateString: json['date_string'] as String? ?? '',
      location: json['location'] as String? ?? '',
      stops: (json['stops'] as List<dynamic>? ?? [])
          .map((stop) => ItineraryStop.fromJson(stop as Map<String, dynamic>))
          .toList(),
    );
  }

  ItineraryDayOverview copyWith({List<ItineraryStop>? stops}) =>
      ItineraryDayOverview(
        dayNumber: dayNumber,
        dateString: dateString,
        location: location,
        stops: stops ?? this.stops,
      );

  Map<String, dynamic> toJson() => {
    'day_number': dayNumber,
    'date_string': dateString,
    'location': location,
    'stops': stops.map((stop) => stop.toJson()).toList(),
  };
}

class ItineraryStop {
  final String id;
  final String name;

  const ItineraryStop({required this.id, required this.name});

  factory ItineraryStop.fromJson(Map<String, dynamic> json) {
    return ItineraryStop(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class ItineraryDetailItem {
  final String id;
  final String timeStart;
  final String timeEnd;
  final String title;
  final String subtitle;
  final String duration;
  final String minimumDuration;
  final String mode;
  final String type;
  final String bookingUrl;
  final String city; // city this place is in, when known (used to keep a day in one city)

  ItineraryDetailItem({
    required this.id,
    required this.timeStart,
    required this.timeEnd,
    required this.title,
    required this.subtitle,
    required this.duration,
    String? minimumDuration,
    required this.mode,
    required this.type,
    this.bookingUrl = '',
    this.city = '',
  }) : minimumDuration = minimumDuration ?? duration;

  bool get isFixed =>
      const {
        'flight',
        'hotel',
        'accommodation',
        'transit',
        'transport',
      }.contains(type.toLowerCase()) ||
      const {
        'flight',
        'stay',
        'transit',
        'bus',
        'transport',
      }.contains(mode.toLowerCase());

  factory ItineraryDetailItem.fromJson(Map<String, dynamic> json) {
    return ItineraryDetailItem(
      id: json['id'] ?? '',
      timeStart: json['time_start'] ?? '',
      timeEnd: json['time_end'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      duration: json['duration'] ?? '',
      minimumDuration: json['minimum_duration'] as String?,
      mode: json['mode'] ?? '',
      type: json['type'] ?? '',
      bookingUrl: json['booking_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'time_start': timeStart,
    'time_end': timeEnd,
    'title': title,
    'subtitle': subtitle,
    'duration': duration,
    'minimum_duration': minimumDuration,
    'mode': mode,
    'type': type,
    'booking_url': bookingUrl,
  };

  ItineraryDetailItem copyWith({
    String? timeStart,
    String? timeEnd,
    String? duration,
    String? title,
    String? subtitle,
    String? mode,
    String? type,
    String? bookingUrl,
  }) {
    return ItineraryDetailItem(
      id: id,
      timeStart: timeStart ?? this.timeStart,
      timeEnd: timeEnd ?? this.timeEnd,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      duration: duration ?? this.duration,
      minimumDuration: minimumDuration,
      mode: mode ?? this.mode,
      type: type ?? this.type,
      bookingUrl: bookingUrl ?? this.bookingUrl,
    );
  }

  Color get timeTagBgColor {
    switch (type) {
      case 'flight':
        return const Color(0xFFE2ECF2);
      case 'transit':
      case 'transport':
        return const Color(0xFFE2ECF2);
      case 'hotel':
      case 'accommodation':
        return const Color(0xFFEDE4F7);
      default:
        return const Color(0xFFE2F0E8);
    }
  }
}

class GeneratedItinerary {
  const GeneratedItinerary({
    required this.overview,
    required this.dayDetails,
    this.estimatedBudget,
    this.budgetBreakdown,
  });

  final ItineraryOverview overview;
  final Map<int, List<ItineraryDetailItem>> dayDetails;
  final double? estimatedBudget;
  final Map<String, double>? budgetBreakdown;

  factory GeneratedItinerary.fromJson(Map<String, dynamic> json) {
    final itineraryJson = json['itinerary'];
    final detailsJson = json['day_details'];
    if (itineraryJson is! Map<String, dynamic> ||
        detailsJson is! Map<String, dynamic>) {
      throw const FormatException(
        'The generated itinerary response must contain itinerary and day_details objects.',
      );
    }

    final overview = ItineraryOverview.fromJson(itineraryJson);
    if (overview.id.isEmpty ||
        overview.title.isEmpty ||
        overview.destination.isEmpty ||
        overview.days.isEmpty ||
        overview.durationDays != overview.days.length) {
      throw const FormatException(
        'The generated itinerary is missing its identity or a complete daily plan.',
      );
    }

    final dayDetails = <int, List<ItineraryDetailItem>>{};
    for (final entry in detailsJson.entries) {
      final dayNumber = int.tryParse(entry.key);
      final rawItems = entry.value;
      if (dayNumber == null || rawItems is! List) {
        throw const FormatException(
          'Each day_details key must be a day number and its value must be a list.',
        );
      }
      dayDetails[dayNumber] = rawItems.map((rawItem) {
        if (rawItem is! Map<String, dynamic>) {
          throw const FormatException(
            'Each generated itinerary activity must be a JSON object.',
          );
        }
        final item = ItineraryDetailItem.fromJson(rawItem);
        if (item.id.isEmpty || item.title.isEmpty) {
          throw const FormatException(
            'Each generated itinerary activity must have an id and title.',
          );
        }
        return item;
      }).toList();
    }

    for (var index = 0; index < overview.days.length; index++) {
      final day = overview.days[index];
      if (day.dayNumber != index + 1 ||
          day.dateString.isEmpty ||
          day.location.isEmpty ||
          day.stops.isEmpty ||
          (dayDetails[day.dayNumber]?.isEmpty ?? true)) {
        throw FormatException(
          'The generated itinerary must include valid overview and activity data for day ${index + 1}.',
        );
      }
    }

    final rawEstimatedBudget = json['estimated_budget'];
    final rawBreakdown = json['budget_breakdown'];
    if (rawEstimatedBudget != null && rawEstimatedBudget is! num) {
      throw const FormatException('estimated_budget must be a number.');
    }
    if (rawBreakdown != null && rawBreakdown is! Map) {
      throw const FormatException('budget_breakdown must be an object.');
    }
    if (rawBreakdown is Map &&
        rawBreakdown.values.any((value) => value is! num)) {
      throw const FormatException(
        'Each budget_breakdown amount must be a number.',
      );
    }
    return GeneratedItinerary(
      overview: overview,
      dayDetails: dayDetails,
      estimatedBudget: rawEstimatedBudget is num
          ? rawEstimatedBudget.toDouble()
          : null,
      budgetBreakdown: rawBreakdown is Map
          ? {
              for (final entry in rawBreakdown.entries)
                if (entry.value is num)
                  entry.key.toString(): (entry.value as num).toDouble(),
            }
          : null,
    );
  }
}
