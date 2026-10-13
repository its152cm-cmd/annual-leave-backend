// lib/services/group_planning_service.dart
//
// Real group planning: everyone's budget, favourites shared to the group
// (voting) and the host's final choice. Only for saved groups ("trip_<id>").

import '../core/api/api_client.dart';

class GroupPlanningService {
  final ApiClient _api = ApiClient();

  /// The backend trip id for a saved group chat, or null for sample groups.
  static String? tripIdFor(String groupId) {
    if (!groupId.startsWith('trip_')) return null;
    final id = groupId.substring(5);
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuid.hasMatch(id) ? id : null;
  }

  Future<Map<String, dynamic>> getBudget(String tripId) async =>
      Map<String, dynamic>.from(
        await _api.get('/api/trips/$tripId/budget') as Map,
      );

  Future<Map<String, dynamic>> setBudget(
    String tripId,
    double min,
    double max,
  ) async => Map<String, dynamic>.from(
    await _api.put('/api/trips/$tripId/budget', {
          'budget_min': min,
          'budget_max': max,
        })
        as Map,
  );

  Future<List<Map<String, dynamic>>> getShares(
    String tripId, {
    String? section,
  }) async {
    final r = await _api.get(
      '/api/trips/$tripId/shares',
      query: section == null ? null : {'section': section},
    );
    return (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> share(
    String tripId, {
    required String section,
    required String itemKey,
    required String title,
    String subtitle = '',
    String imageUrl = '',
    String itemId = '',
  }) => _api.post('/api/trips/$tripId/shares', {
    'section': section,
    'item_key': itemKey,
    'title': title,
    'subtitle': subtitle,
    'image_url': imageUrl,
    'item_id': itemId,
  });

  /// The person un-favourited an item: their vote is taken back, and the item
  /// leaves the poll when nobody else is voting for it.
  Future<void> unshare(String tripId, String itemKey) =>
      _api.post('/api/trips/$tripId/shares/unshare', {'item_key': itemKey});

  /// {isHost, activities: [...shared Activities with votes + picked]}
  Future<Map<String, dynamic>> getActivities(String tripId) async =>
      Map<String, dynamic>.from(
        await _api.get('/api/trips/$tripId/activities') as Map,
      );

  Future<void> setActivities(String tripId, List<String> shareIds) =>
      _api.put('/api/trips/$tripId/activities', {'share_ids': shareIds});

  /// {members: [{id,name,preferences,isMe}], combined: [..]}
  Future<Map<String, dynamic>> getPreferences(String tripId) async =>
      Map<String, dynamic>.from(
        await _api.get('/api/trips/$tripId/preferences') as Map,
      );

  Future<Map<String, dynamic>> getComfort(String tripId) async =>
      Map<String, dynamic>.from(
        await _api.get('/api/trips/$tripId/comfort') as Map,
      );

  Future<Map<String, dynamic>> setComfort(
    String tripId,
    Map<String, Object> comfort,
  ) async => Map<String, dynamic>.from(
    await _api.put('/api/trips/$tripId/comfort', comfort) as Map,
  );

  Future<Map<String, dynamic>> resetComfort(String tripId) async =>
      Map<String, dynamic>.from(
        await _api.delete('/api/trips/$tripId/comfort') as Map,
      );

  /// Everyone's food habits and hotel stars: {members: [{id, name, isMe, custom, dietary, hotel_stars}]}
  Future<Map<String, dynamic>> getTaste(String tripId) async =>
      Map<String, dynamic>.from(await _api.get('/api/trips/$tripId/taste') as Map);

  Future<Map<String, dynamic>> setTaste(
    String tripId, {
    List<String>? dietary,
    int? hotelStars,
  }) async => Map<String, dynamic>.from(
    await _api.put('/api/trips/$tripId/taste', {
      if (dietary != null) 'dietary': dietary,
      if (hotelStars != null) 'hotel_stars': hotelStars,
    }) as Map,
  );

  Future<Map<String, dynamic>> resetTaste(String tripId) async =>
      Map<String, dynamic>.from(await _api.delete('/api/trips/$tripId/taste') as Map);

  Future<void> setPreferences(String tripId, List<String> preferences) =>
      _api.put('/api/trips/$tripId/preferences', {'preferences': preferences});

  /// Host only: Gemini merges everyone's input into one itinerary.
  Future<Map<String, dynamic>> generateGroupItinerary(String tripId) async =>
      Map<String, dynamic>.from(
        await _api.post('/api/itinerary/generate-group', {'trip_id': tripId})
            as Map,
      );

  Future<void> vote(String tripId, String shareId) =>
      _api.post('/api/trips/$tripId/shares/$shareId/vote');

  /// {isHost: bool, decisions: {Accommodation: [{title, subtitle, itemId}], Transport: [...]}}
  Future<Map<String, dynamic>> getDecisions(String tripId) async =>
      Map<String, dynamic>.from(
        await _api.get('/api/trips/$tripId/decisions') as Map,
      );

  Future<void> decide(
    String tripId,
    String section, {
    String? shareId,
    String? title,
  }) => _api.put('/api/trips/$tripId/decisions/$section', {
    if (shareId != null) 'share_id': shareId,
    if (title != null) 'title': title,
  });

  /// Removes one choice (give [title]) or every choice of the section.
  Future<void> clearDecision(
    String tripId,
    String section, {
    String? title,
    String itemId = '',
  }) => _api.delete(
    '/api/trips/$tripId/decisions/$section'
    '${title == null ? '' : '?title=${Uri.encodeQueryComponent(title)}&item_id=${Uri.encodeQueryComponent(itemId)}'}',
  );
}
