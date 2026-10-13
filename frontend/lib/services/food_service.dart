import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../mock/mock_food.dart';
import '../models/food_option.dart';

class FoodService {
  final ApiClient _api = ApiClient();

  Future<List<FoodOption>> getRecommendedEats(String destination, {String q = '', String tripId = ''}) async {
    final cityName = destination.split(',').first.trim();
    if (cityName.isNotEmpty) {
      try {
        final r = await _api.get('/api/options/food', query: {'city': cityName, if (q.trim().isNotEmpty) 'q': q.trim(), if (tripId.isNotEmpty) 'trip_id': tripId});
        return (r as List)
            .map((e) => FoodOption.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e) {
        debugPrint('[food] $e');
        return [];
      }
    }
    await Future.delayed(const Duration(milliseconds: 300));

    final list = mockFoodSearchResults['eats'] as List<dynamic>?;
    if (list != null) {
      final city = destination.split(',').first.trim().toLowerCase();
      return list
          .map((item) => FoodOption.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((food) => city.isEmpty || food.location.toLowerCase().contains(city))
          .toList();
    }
    return [];
  }

  Future<bool> setFoodFavourite(String id, bool isFavourite) {
    final eats = mockFoodSearchResults['eats'] as List<dynamic>? ?? const [];
    final food = eats.where((item) => (item as Map)['id'] == id);
    if (food.isEmpty) return Future.value(false);

    (food.first as Map<String, dynamic>)['is_favourite'] = isFavourite;
    return Future.value(true);
  }
}
