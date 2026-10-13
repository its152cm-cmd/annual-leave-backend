import '../mock/mock_food.dart';
import '../models/food_option.dart';

class FoodService {
  Future<List<FoodOption>> getRecommendedEats(String destination) async {
    // Simulates future API call delay
    await Future.delayed(const Duration(milliseconds: 300));

    final list = mockFoodSearchResults['eats'] as List<dynamic>?;
    if (list != null) {
      return list
          .map((item) => FoodOption.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}