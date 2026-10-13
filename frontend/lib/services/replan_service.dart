import '../core/api/api_client.dart';

class ReplanOption {
  final String id, title, category, area, distance, travelTime, openingHours, duration, why, type;
  const ReplanOption({
    required this.id, required this.title, required this.category, required this.area,
    required this.distance, required this.travelTime, required this.openingHours,
    required this.duration, required this.why, required this.type,
  });
  factory ReplanOption.fromJson(Map j) => ReplanOption(
        id: '${j['id']}', title: '${j['title']}', category: '${j['category'] ?? ''}',
        area: '${j['area'] ?? ''}', distance: '${j['distance'] ?? ''}',
        travelTime: '${j['travelTime'] ?? ''}', openingHours: '${j['openingHours'] ?? ''}',
        duration: '${j['duration'] ?? ''}', why: '${j['why'] ?? ''}', type: '${j['type'] ?? 'attraction'}',
      );
}

class MoveOption {
  final int day;
  final String label, newStart, newEnd;
  const MoveOption({required this.day, required this.label, required this.newStart, required this.newEnd});
  factory MoveOption.fromJson(Map j) => MoveOption(
        day: (j['day'] as num).toInt(), label: '${j['label']}',
        newStart: '${j['newStart']}', newEnd: '${j['newEnd']}',
      );
}

class DelayChange {
  final String id, title, type, action, oldStart, oldEnd, newStart, newEnd;
  final List<MoveOption> moveOptions;
  const DelayChange({
    required this.id, required this.title, required this.type, required this.action,
    required this.oldStart, required this.oldEnd, required this.newStart, required this.newEnd,
    this.moveOptions = const [],
  });
  bool get dropped => action == 'dropped';
  factory DelayChange.fromJson(Map j) => DelayChange(
        id: '${j['id']}', title: '${j['title'] ?? ''}', type: '${j['type'] ?? ''}', action: '${j['action']}',
        oldStart: '${j['oldStart'] ?? ''}', oldEnd: '${j['oldEnd'] ?? ''}',
        newStart: '${j['newStart'] ?? ''}', newEnd: '${j['newEnd'] ?? ''}',
        moveOptions: [for (final o in (j['moveOptions'] as List? ?? [])) MoveOption.fromJson(o as Map)],
      );
}

class DelayPlan {
  final List<DelayChange> changes;
  final List<String> warnings;
  const DelayPlan(this.changes, this.warnings);
}

/// Replanning talks to the backend only: it knows the real places and the saved itinerary.
class ReplanService {
  final ApiClient _api = ApiClient();
  String _b(String tripId) => '/api/replan/$tripId';

  Future<DelayPlan> previewDelay(String tripId, int day, String itemId, int minutes) async {
    final r = await _api.post('${_b(tripId)}/flight-delay/preview',
        {'day_number': day, 'item_id': itemId, 'delay_minutes': minutes}) as Map;
    return _plan(r);
  }

  /// [moves]: stop id -> day to move it to. Stops that no longer fit and are not in [moves] are removed.
  Future<DelayPlan> applyDelay(String tripId, int day, String itemId, int minutes, {Map<String, int> moves = const {}}) async {
    final r = await _api.post('${_b(tripId)}/flight-delay/apply', {
      'day_number': day, 'item_id': itemId, 'delay_minutes': minutes,
      'decisions': {for (final e in moves.entries) e.key: {'action': 'move', 'day': e.value}},
    }) as Map;
    return _plan(r);
  }

  DelayPlan _plan(Map r) => DelayPlan(
        [for (final c in (r['changes'] as List)) DelayChange.fromJson(c as Map)],
        [for (final w in (r['warnings'] as List? ?? [])) '$w'],
      );

  /// [reason] is 'weather' or 'closed'.
  Future<({List<ReplanOption> options, String note})> alternatives(
      String tripId, int day, String itemId, String reason) async {
    final r = await _api.post('${_b(tripId)}/alternatives',
        {'day_number': day, 'item_id': itemId, 'reason': reason}) as Map;
    return (
      options: [for (final o in (r['options'] as List)) ReplanOption.fromJson(o as Map)],
      note: '${r['note'] ?? ''}',
    );
  }

  Future<void> applyAlternative(String tripId, int day, String itemId, ReplanOption o) =>
      _api.post('${_b(tripId)}/apply-alternative', {
        'day_number': day, 'item_id': itemId, 'title': o.title,
        'category': o.category, 'area': o.area, 'type': o.type,
      });
}
