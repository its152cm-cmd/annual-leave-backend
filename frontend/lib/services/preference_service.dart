import '../core/api/api_client.dart';
import '../mock/mock_preferences.dart';
import '../models/itinerary.dart';
import '../models/travel_preference.dart';
import '../models/trip.dart';
import '../models/trip_customization.dart';

class PreferenceService {
  final ApiClient _apiClient;

  PreferenceService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  // --- Travel Preferences Methods ---

  Future<TravelPreference> getPreferences() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return TravelPreference.fromJson(mockTravelPreference);
  }

  Future<List<TravelPreferenceCategory>> getDefaultPreferenceCategories() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return mockDefaultPreferenceCategories
        .map(TravelPreferenceCategory.fromJson)
        .toList();
  }

  Future<void> saveDefaultPreferenceCategories(
    List<TravelPreferenceCategory> categories,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Replace this mock write with the preferences API when it is available.
    mockDefaultPreferenceCategories
      ..clear()
      ..addAll(categories.map((category) => category.toJson()));
  }

  Future<bool> savePreferences(TravelPreference preference) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // FUTURE PYTHON BACKEND CALL:
    // await apiClient!.post('/api/preferences', preference.toJson());
    return true;
  }

  /// Asks the backend (Gemini) for an itinerary. Errors are passed on so the
  /// screen can tell the user what went wrong.
  Future<GeneratedItinerary> generateItinerary({
    required Trip trip,
    required TravelPreference preference,
    List<String> liked = const [],
    List<String> disliked = const [],
  }) async {
    final response = await _apiClient.post('/api/itinerary/generate', {
      'trip': trip.toJson(),
      'preferences': {
        ...preference.toJson(),
        if (liked.isNotEmpty) 'liked': liked,
        if (disliked.isNotEmpty) 'disliked': disliked,
      },
    });
    return GeneratedItinerary.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  // --- Swipe / Trip Customization Methods ---

  /// Cards for the chosen destination (full "City, Country").
  Future<List<PreferenceCardItem>> getSwipeCards(String city) async {
    final r = await _apiClient.get('/api/options/swipe-cards', query: {'city': city});
    final list = (r is Map ? r['cards'] : r) as List? ?? const [];
    return [
      for (final e in list)
        PreferenceCardItem.fromJson({...Map<String, dynamic>.from(e as Map), 'city': city}),
    ];
  }

  Future<bool> saveTripCustomization({
    required List<PreferenceCardItem> top3Choices,
    required List<String> interestedIds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // FUTURE PYTHON BACKEND CALL:
    // await apiClient!.post('/api/trips/customize', {
    //   'top_3': top3Choices.map((e) => e.id).toList(),
    //   'interested_ids': interestedIds,
    // });
    return true;
  }
}
