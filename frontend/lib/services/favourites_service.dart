import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';

/// Stores suggestion favourites by category and stable model id.
///
/// Hearts belong to one account and are saved in the backend, so they are
/// still there after signing out and in.
class SuggestionFavoritesService {
  static final Map<String, bool> _favorites = {};
  static final ValueNotifier<int> favoritesRevision = ValueNotifier(0);

  /// A small copy of each hearted place (name, area, photo...) so the Favourites list can show it.
  static final Map<String, Map<String, dynamic>> _snapshots = {};

  /// The hearted places that have a saved copy, newest changes last.
  static List<MapEntry<String, Map<String, dynamic>>> savedEntries() => [
        for (final e in _snapshots.entries)
          if (_favorites[e.key] == true) e,
      ];

  /// Favourites belong to one person: forget them when someone signs in/out.
  static void reset() {
    _favorites.clear();
    _snapshots.clear();
    favoritesRevision.value++;
  }

  /// Loads the signed-in person's saved hearts.
  static Future<void> load() async {
    try {
      final data = await ApiClient().get('/api/favourites') as Map;
      final keys = List<String>.from(data['keys'] as List);
      _favorites
        ..clear()
        ..addAll({for (final k in keys) k: true});
      _snapshots.clear();
      for (final e in (data['items'] as List? ?? const [])) {
        final m = e as Map;
        if (m['item'] is Map) {
          _snapshots['${m['key']}'] = Map<String, dynamic>.from(m['item'] as Map);
        }
      }
      favoritesRevision.value++;
    } catch (_) {}
  }

  bool? isFavorite(String key) => _favorites[key];

  /// [save] is false when the screen only mirrors what is already known.
  void setFavorite(
    String key,
    bool isFavorite, {
    bool save = true,
    Map<String, dynamic>? snapshot,
  }) {
    final hasCopy = _snapshots.containsKey(key);
    if (_favorites[key] == isFavorite &&
        (snapshot == null || !isFavorite || hasCopy)) {
      return;
    }
    _favorites[key] = isFavorite;
    if (isFavorite && snapshot != null) _snapshots[key] = snapshot;
    if (!isFavorite) _snapshots.remove(key);
    favoritesRevision.value++;
    if (save) _save(key, isFavorite, isFavorite ? snapshot : null);
  }

  Future<void> _save(String key, bool isFavorite, Map<String, dynamic>? snapshot) async {
    try {
      await ApiClient().put('/api/favourites', {
        'key': key,
        'favourite': isFavorite,
        if (snapshot != null) 'item': snapshot,
      });
    } catch (_) {}
  }
}
