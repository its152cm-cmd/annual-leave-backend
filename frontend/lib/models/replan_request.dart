import 'attraction.dart';
import 'food_option.dart';
import 'flight.dart';
import 'hotel.dart';
import 'itinerary.dart';
import 'recommendation.dart';
import 'trip.dart';

class AffectedItineraryRequest {
  const AffectedItineraryRequest({
    required this.itineraryId,
    required this.situation,
    required this.trip,
    required this.overview,
    required this.dayItems,
  });

  final String itineraryId;
  final String situation;
  final Trip trip;
  final ItineraryOverview overview;
  final Map<int, List<ItineraryDetailItem>> dayItems;

  Map<String, dynamic> toJson() => {
    'itinerary_id': itineraryId,
    'situation': situation,
    'trip': trip.toJson(),
    'affected_itinerary': {
      'overview': overview.toJson(),
      'day_details': {
        for (final entry in dayItems.entries)
          entry.key.toString(): entry.value.map((item) => item.toJson()).toList(),
      },
    },
  };
}

class AffectedItineraryResponse {
  const AffectedItineraryResponse({
    required this.dayNumber,
    required this.items,
    this.isFlightDelayed = false,
    this.updatedFlightTime = '',
  });

  final int? dayNumber;
  final List<ItineraryDetailItem> items;
  final bool isFlightDelayed;
  final String updatedFlightTime;

  factory AffectedItineraryResponse.fromJson(Map<String, dynamic> json) {
    final payload = _nestedPayload(json, 'affected_itinerary');
    return AffectedItineraryResponse(
      dayNumber: (payload['affected_day_number'] as num?)?.toInt(),
      items: _itineraryItems(payload['affected_items']),
      isFlightDelayed: payload['is_flight_delayed'] as bool? ?? false,
      updatedFlightTime: payload['updated_flight_time'] as String? ?? '',
    );
  }
}

class FlightAlternativesRequest {
  const FlightAlternativesRequest({
    required this.itineraryId,
    required this.dayNumber,
    required this.destination,
    required this.originCode,
    required this.destinationCode,
    required this.flight,
  });

  final String itineraryId;
  final int dayNumber;
  final String destination;
  final String originCode;
  final String destinationCode;
  final ItineraryDetailItem flight;

  Map<String, dynamic> toJson() => {
    'flight_alternatives': {
      'itinerary_id': itineraryId,
      'day_number': dayNumber,
      'destination': destination,
      'origin_code': originCode,
      'destination_code': destinationCode,
      'current_flight': flight.toJson(),
    },
  };
}

class HotelAlternativesRequest {
  const HotelAlternativesRequest({
    required this.itineraryId,
    required this.dayNumber,
    required this.destination,
    required this.hotel,
  });

  final String itineraryId;
  final int dayNumber;
  final String destination;
  final ItineraryDetailItem hotel;

  Map<String, dynamic> toJson() => {
    'hotel_alternatives': {
      'itinerary_id': itineraryId,
      'day_number': dayNumber,
      'destination': destination,
      'current_hotel': hotel.toJson(),
    },
  };
}

class FlightAlternativesResponse {
  const FlightAlternativesResponse(this.alternatives);
  final List<FlightOption> alternatives;

  factory FlightAlternativesResponse.fromJson(Map<String, dynamic> json) =>
      FlightAlternativesResponse(
        flightOptionsFromJson(_nestedPayload(json, 'flight_alternatives')),
      );
}

class HotelAlternativesResponse {
  const HotelAlternativesResponse(this.alternatives);
  final List<HotelOption> alternatives;

  factory HotelAlternativesResponse.fromJson(Map<String, dynamic> json) =>
      HotelAlternativesResponse(
        hotelOptionsFromJson(_nestedPayload(json, 'hotel_alternatives')),
      );
}

class RearrangedItineraryRequest {
  const RearrangedItineraryRequest({
    required this.itineraryId,
    required this.dayNumber,
    required this.activities,
    required this.flight,
    required this.updatedFlightTime,
  });

  final String itineraryId;
  final int dayNumber;
  final List<ItineraryDetailItem> activities;
  final ItineraryDetailItem flight;
  final String updatedFlightTime;

  Map<String, dynamic> toJson() => {
    'rearranged_itinerary': {
      'itinerary_id': itineraryId,
      'day_number': dayNumber,
      'activities': activities.map((item) => item.toJson()).toList(),
      'flight': flight.toJson(),
      'updated_flight_time': updatedFlightTime,
    },
  };
}

class RearrangedItineraryResponse {
  const RearrangedItineraryResponse({
    required this.dayNumber,
    required this.items,
  });

  final int dayNumber;
  final List<ItineraryDetailItem> items;

  factory RearrangedItineraryResponse.fromJson(Map<String, dynamic> json) {
    final payload = _nestedPayload(json, 'rearranged_itinerary');
    return RearrangedItineraryResponse(
      dayNumber: (payload['day_number'] as num?)?.toInt() ?? 1,
      items: _itineraryItems(payload['items']),
    );
  }
}

class FindAlternativesRequest {
  const FindAlternativesRequest({
    required this.itineraryId,
    required this.situation,
    required this.destination,
    required this.dayNumber,
    required this.affectedItems,
    required this.replaceDescription,
    required this.availableStart,
    required this.availableEnd,
    required this.availableMinutes,
  });

  final String itineraryId;
  final String situation;
  final String destination;
  final int dayNumber;
  final List<ItineraryDetailItem> affectedItems;
  final String replaceDescription;
  final String availableStart;
  final String availableEnd;
  final int availableMinutes;

  Map<String, dynamic> toJson() => {
    'find_alternatives': {
      'itinerary_id': itineraryId,
      'situation': situation,
      'destination': destination,
      'day_number': dayNumber,
      'affected_items': affectedItems.map((item) => item.toJson()).toList(),
      'replace_description': replaceDescription,
      'available_start': availableStart,
      'available_end': availableEnd,
      'available_minutes': availableMinutes,
    },
  };
}

class FindAlternativesResponse {
  const FindAlternativesResponse({
    required this.options,
    this.replacesItemId = '',
  });

  final List<Object> options;
  final String replacesItemId;

  factory FindAlternativesResponse.fromJson(Map<String, dynamic> json) {
    final payload = _nestedPayload(json, 'find_alternatives');
    final raw = payload['alternatives'] as List<dynamic>? ?? const [];
    return FindAlternativesResponse(
      replacesItemId: payload['replaces_item_id'] as String? ?? '',
      options: raw.map((entry) {
      final item = Map<String, dynamic>.from(entry as Map);
      return switch ((item['type'] as String? ?? '').toLowerCase()) {
        'restaurant' || 'food' => FoodOption.fromJson(item),
        'destination' => Recommendation.fromJson(item),
        _ => Attraction.fromJson(item),
      };
      }).toList(growable: false),
    );
  }
}

Map<String, dynamic> _nestedPayload(
  Map<String, dynamic> json,
  String key,
) => json[key] is Map
    ? Map<String, dynamic>.from(json[key] as Map)
    : json;

List<FlightOption> flightOptionsFromJson(Map<String, dynamic> json) =>
    (json['alternatives'] as List<dynamic>? ?? const [])
        .map((item) => FlightOption.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);

List<HotelOption> hotelOptionsFromJson(Map<String, dynamic> json) =>
    (json['alternatives'] as List<dynamic>? ?? const [])
        .map((item) => HotelOption.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);

List<ItineraryDetailItem> _itineraryItems(dynamic raw) =>
    (raw as List<dynamic>? ?? const [])
        .map((item) => ItineraryDetailItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
