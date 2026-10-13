import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../mock/mock_flights.dart';
import '../models/flight.dart';

class FlightService {
  final ApiClient _api = ApiClient();
  static final Map<String, Future<Map<String, dynamic>>> _pending = {};

  /// One request answers both the flights and the date chips.
  Future<Map<String, dynamic>> _load(String origin, String dest,
      {String? tripId, String originCity = '', String destinationCity = ''}) {
    final key = '$tripId|$origin|$dest';
    return _pending.putIfAbsent(key, () async {
      try {
        final r = await _api.get('/api/options/flights', query: {
          'origin': origin,
          'destination': dest,
          if (originCity.isNotEmpty) 'origin_city': originCity,
          if (destinationCity.isNotEmpty) 'destination_city': destinationCity,
          if (tripId != null && tripId.isNotEmpty) 'trip_id': tripId,
        });
        return Map<String, dynamic>.from(r as Map);
      } catch (e) {
        debugPrint('[flights] $e');
        _pending.remove(key);
        return {'flights': [], 'date_chips': []};
      }
    });
  }

  bool _isCode(String v) => RegExp(r'^[A-Za-z]{3}$').hasMatch(v.trim());

  Future<List<FlightOption>> searchFlights(String originCode, String destinationCode,
      {String? tripId, String originCity = '', String destinationCity = ''}) async {
    if (!_isCode(originCode) || !_isCode(destinationCode)) return [];
    final r = await _load(originCode.trim(), destinationCode.trim(),
        tripId: tripId, originCity: originCity, destinationCity: destinationCity);
    return (r['flights'] as List? ?? [])
        .map((e) => FlightOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<FlightDateChip>> getFlightDateChips(String originCode, String destinationCode,
      {String? tripId, String originCity = '', String destinationCity = ''}) async {
    if (!_isCode(originCode) || !_isCode(destinationCode)) return [];
    final r = await _load(originCode.trim(), destinationCode.trim(),
        tripId: tripId, originCity: originCity, destinationCity: destinationCity);
    return (r['date_chips'] as List? ?? [])
        .map((e) => FlightDateChip.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Flights when only the cities are known (e.g. a group trip planned in the
  /// chat): the server works out the airports. [tripId] supplies the dates and
  /// the origin city; without an origin the server assumes Kuala Lumpur.
  Future<List<FlightOption>> searchFlightsByCity(
    String destinationCity, {
    String originCity = '',
    String? tripId,
  }) async {
    if (destinationCity.trim().isEmpty) return [];
    final key = 'city|$tripId|$originCity|$destinationCity';
    final r = await _pending.putIfAbsent(key, () async {
      try {
        final response = await _api.get('/api/options/flights', query: {
          'destination_city': destinationCity.trim(),
          if (originCity.isNotEmpty) 'origin_city': originCity,
          if (tripId != null && tripId.isNotEmpty) 'trip_id': tripId,
        });
        return Map<String, dynamic>.from(response as Map);
      } catch (e) {
        debugPrint('[flights] $e');
        _pending.remove(key);
        return {'flights': [], 'date_chips': []};
      }
    });
    return (r['flights'] as List? ?? [])
        .map((e) => FlightOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<FlightOption>> getFlights() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final flights = mockFlightSearchResults['flights'] as List<dynamic>? ?? [];
    return flights
        .map((item) => FlightOption.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}