import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../mock/mock_hotels.dart';
import '../models/hotel.dart';

class HotelService {
  final ApiClient _api = ApiClient();

  Future<List<HotelOption>> searchHotels(String destination, {String q = '', String tripId = ''}) async {
    final city = destination.split(',').first.trim();
    if (city.isNotEmpty) {
      try {
        final r = await _api.get('/api/options/hotels', query: {'city': city, if (q.trim().isNotEmpty) 'q': q.trim(), if (tripId.isNotEmpty) 'trip_id': tripId});
        return (r as List)
            .map((e) => HotelOption.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e) {
        debugPrint('[hotels] $e');
        return [];
      }
    }
    await Future.delayed(const Duration(milliseconds: 300));

    final list = mockHotelSearchResults['hotels'] as List<dynamic>?;
    if (list != null) {
      return list
          .map((item) => HotelOption.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<HotelOption>> getHotels() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final list = mockHotelSearchResults['hotels'] as List<dynamic>? ?? [];
    return list
        .map((item) => HotelOption.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> setHotelFavourite(String id, bool isFavourite) {
    final hotels = mockHotelSearchResults['hotels'] as List<dynamic>? ?? const [];
    final hotel = hotels.where((item) => (item as Map)['id'] == id);
    if (hotel.isEmpty) return Future.value(false);

    (hotel.first as Map<String, dynamic>)['is_favourite'] = isFavourite;
    return Future.value(true);
  }
}