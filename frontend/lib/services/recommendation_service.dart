import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../models/recommendation.dart';
import '../models/attraction.dart'; 
import '../models/food_option.dart';
import '../mock/mock_recommendations.dart';
import 'food_service.dart';

class RecommendationService {
  final FoodService _foodService = FoodService();
  final ApiClient _api = ApiClient();

  /// Real places for a trip's city (Geoapify + Wikipedia photos).
  Future<List<Attraction>> getAttractionsForCity(String destination, {String q = ''}) async {
    final city = destination.split(',').first.trim();
    if (city.isEmpty) return [];
    try {
      final r = await _api.get('/api/options/attractions', query: {'city': city, if (q.trim().isNotEmpty) 'q': q.trim()});
      return (r as List)
          .map((e) => Attraction.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[attractions] $e');
      return [];
    }
  }

  Future<List<Object>> getReplanRecommendations({
    required String destination,
    required String situation,
    required int availableMinutes,
    String? availableStart,
    String? availableEnd,
  }) async {
    final results = await Future.wait<dynamic>([
      getRecommendedAttractions(),
      _foodService.getRecommendedEats(destination),
    ]);
    final places = <Object>[
      ...results[0] as List<Attraction>,
      ...results[1] as List<FoodOption>,
    ];
    final city = destination.split(',').first.trim().toLowerCase();
    final words = situation.toLowerCase().split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length > 2).toSet();
    final matches = places.where((place) {
      final location = switch (place) {
        Attraction value => value.location,
        FoodOption value => value.location,
        _ => '',
      }.toLowerCase();
      final visitDurationMinutes = switch (place) {
        Attraction value => value.visitDurationMinutes,
        FoodOption value => value.visitDurationMinutes,
        _ => null,
      };
      final openingHours = switch (place) {
        Attraction value => value.openingHours,
        FoodOption value => value.openingHours,
        _ => '',
      };
      return location.contains(city) &&
          _fitsAvailableTime(visitDurationMinutes, availableMinutes) &&
          _isOpenDuring(openingHours, availableStart, availableEnd);
    }).toList(growable: false);
    if (words.isEmpty || matches.isEmpty) return matches;
    final relevant = matches.where((place) {
      final text = switch (place) {
        Attraction value => '${value.title} ${value.description} ${value.tags.join(' ')}',
        FoodOption value => '${value.name} ${value.description} ${value.cuisineType} ${value.menuItems.join(' ')}',
        _ => '',
      }.toLowerCase();
      return words.any(text.contains);
    }).toList(growable: false);
    return relevant.isEmpty ? matches : relevant;
  }

  bool _fitsAvailableTime(int? visitDurationMinutes, int availableMinutes) {
    return availableMinutes <= 0 ||
        visitDurationMinutes == null ||
        visitDurationMinutes <= availableMinutes;
  }

  bool _isOpenDuring(String openingHours, String? start, String? end) {
    final availableStart = _minutesAfterMidnight(start ?? '');
    final availableEnd = _minutesAfterMidnight(end ?? '');
    if (availableStart == null || availableEnd == null || openingHours.isEmpty) {
      return true;
    }
    if (openingHours.toLowerCase().contains('24 hour')) return true;
    final times = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM)',
      caseSensitive: false,
    ).allMatches(openingHours).toList();
    if (times.length < 2) return true;
    final opens = _minutesFromMatch(times[0]);
    var closes = _minutesFromMatch(times[1]);
    if (closes <= opens) closes += 24 * 60;
    return availableStart < closes && availableEnd > opens;
  }

  int? _minutesAfterMidnight(String value) {
    final match = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    return match == null ? null : _minutesFromMatch(match);
  }

  int _minutesFromMatch(RegExpMatch match) {
    var hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final isPm = match.group(3)!.toUpperCase() == 'PM';
    if (hour == 12) hour = 0;
    if (isPm) hour += 12;
    return hour * 60 + minute;
  }

  Future<List<Recommendation>> getTopPicks() async {
    // Simulate network delay for API readiness
    await Future.delayed(const Duration(milliseconds: 300));
    return mockTopPicks
        .map((json) => Recommendation.fromJson(json))
        .toList();
  }

  Future<List<Attraction>> getRecommendedAttractions() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return mockRecommendedAttractions
        .map((json) => Attraction.fromJson(json))
        .toList();
  }

  Future<bool> setAttractionFavourite(String id, bool isFavourite) {
    final attraction = mockRecommendedAttractions.where(
      (item) => item['id'] == id,
    );
    if (attraction.isEmpty) return Future.value(false);

    attraction.first['is_favourite'] = isFavourite;
    return Future.value(true);
  }
}
