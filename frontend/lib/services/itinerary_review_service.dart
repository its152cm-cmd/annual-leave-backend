import '../core/api/api_client.dart';

class ItemReaction {
  final List<String> agree;
  final List<String> disagree;
  final int comments;
  const ItemReaction({this.agree = const [], this.disagree = const [], this.comments = 0});
}

class ReviewComment {
  final String id;
  final String name;
  final String text;
  final bool canDelete;
  const ReviewComment({required this.id, required this.name, required this.text, required this.canDelete});
}

class ItineraryReview {
  final bool isHost;
  final bool isGroup;
  final String me;
  final Map<String, String> memberNames;
  final Map<String, ItemReaction> items;

  const ItineraryReview({
    required this.isHost,
    required this.isGroup,
    required this.me,
    required this.memberNames,
    required this.items,
  });

  /// Everyone except the host of a group trip can only view and give feedback.
  bool get canEdit => !isGroup || isHost;

  ItemReaction reactionFor(String id) => items[id] ?? const ItemReaction();

  factory ItineraryReview.fromJson(Map<String, dynamic> j) {
    final items = <String, ItemReaction>{};
    (j['items'] as Map? ?? {}).forEach((k, v) {
      final m = v as Map;
      items[k.toString()] = ItemReaction(
        agree: List<String>.from(m['agree'] as List? ?? []),
        disagree: List<String>.from(m['disagree'] as List? ?? []),
        comments: (m['comments'] as num?)?.toInt() ?? 0,
      );
    });
    return ItineraryReview(
      isHost: j['isHost'] == true,
      isGroup: j['isGroup'] == true,
      me: (j['me'] ?? '').toString(),
      memberNames: {
        for (final m in (j['members'] as List? ?? []))
          (m as Map)['id'].toString(): (m['name'] ?? 'Member').toString(),
      },
      items: items,
    );
  }
}

class ItineraryReviewService {
  final ApiClient _api = ApiClient();

  String _base(String tripId) => '/api/itinerary/$tripId/review';
  String _key(String id) => Uri.encodeComponent(id);

  Future<ItineraryReview?> load(String tripId) async {
    try {
      final data = await _api.get(_base(tripId)) as Map;
      return ItineraryReview.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  Future<void> vote(String tripId, String itemId, String vote) =>
      _api.post('${_base(tripId)}/items/${_key(itemId)}/vote', {'vote': vote});

  Future<List<ReviewComment>> comments(String tripId, String itemId) async {
    final data = await _api.get('${_base(tripId)}/items/${_key(itemId)}/comments') as List;
    return [for (final c in data) _comment(c as Map)];
  }

  Future<ReviewComment> addComment(String tripId, String itemId, String text) async {
    final data = await _api.post('${_base(tripId)}/items/${_key(itemId)}/comments', {'text': text}) as Map;
    return _comment(data);
  }

  Future<void> deleteComment(String tripId, String commentId) =>
      _api.delete('${_base(tripId)}/comments/$commentId');

  /// Pins a poll about this item in the group chat.
  Future<void> askGroup(String tripId, String itemId) =>
      _api.post('${_base(tripId)}/items/${_key(itemId)}/poll');

  ReviewComment _comment(Map c) => ReviewComment(
        id: c['id'].toString(),
        name: (c['name'] ?? 'Member').toString(),
        text: (c['text'] ?? '').toString(),
        canDelete: c['canDelete'] == true,
      );
}
