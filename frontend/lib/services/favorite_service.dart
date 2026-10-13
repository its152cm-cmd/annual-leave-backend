import 'package:flutter/foundation.dart';

import '../mock/mock_favorites.dart';
import '../models/attraction.dart';
import '../models/favorite_attraction.dart';

class FavoriteService {
  static final List<FavoriteAttraction> _favorites =
      mockFavorites.map(FavoriteAttraction.fromJson).toList();

  /// Bumps whenever favourites change so other screens can rebuild.
  static final ValueNotifier<int> favoritesRevision = ValueNotifier(0);

  Future<List<FavoriteAttraction>> getFavorites() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_favorites);
  }

  Future<Set<String>> getFavoriteIds() async {
    final favorites = await getFavorites();
    return favorites.map((item) => item.id).toSet();
  }

  /// Adds the attraction if it is not saved, removes it otherwise.
  /// Returns true when the attraction is now a favourite.
  Future<bool> toggleFavorite(Attraction attraction) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final index = _favorites.indexWhere((item) => item.id == attraction.id);
    final isNowFavorite = index == -1;
    if (isNowFavorite) {
      _favorites.insert(0, FavoriteAttraction.fromAttraction(attraction));
    } else {
      _favorites.removeAt(index);
    }
    favoritesRevision.value++;
    return isNowFavorite;
  }
}