// lib/mock/mock_group_summary_data_source.dart
//
// Simulates the backend for group summaries and members. Returns raw JSON.
// When the real backend exists, replace this class with an API-client call.

import 'mock_trip_summary.dart';

class GroupSummaryMockDataSource {
  Future<void> createTripGroup({
    required String groupId,
    required String tripId,
    required String title,
    required String destination,
    required String dates,
    required double minimumBudget,
    required double plannedBudget,
  }) async {
    mockTripSummaryDatabase.putIfAbsent(
      groupId,
      () => {
        'summary': {
          'id': groupId,
          'tripId': tripId,
          'title': title,
          'destination': destination,
          'dates': dates,
          if (plannedBudget > 0)
            'budgetRange': {'min': minimumBudget, 'max': plannedBudget},
          'confirmedDetails': {'Destination': destination, 'Dates': dates},
        },
        'members': <Map<String, dynamic>>[],
        'suggestions': <Map<String, dynamic>>[],
      },
    );
  }

  Future<Map<String, dynamic>> fetchGroup(String groupId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return mockTripSummaryDatabase[groupId] ??
        <String, dynamic>{
          'summary': {
            'id': groupId,
            'title': 'New Trip',
            'confirmedDetails': {},
          },
          'members': [],
          'suggestions': [],
        };
  }

  Future<Map<String, List<String>>> fetchPlanningSelections(
    String groupId,
  ) async {
    final group = mockTripSummaryDatabase[groupId];
    final summary = group?['summary'] as Map<String, dynamic>? ?? const {};
    return {
      'Accommodation': List<String>.from(
        summary['selectedAccommodationIds'] as List<dynamic>? ?? const [],
      ),
      'Transport': List<String>.from(
        summary['selectedTransportIds'] as List<dynamic>? ?? const [],
      ),
    };
  }

  Future<void> setPlanningOptionSelected({
    required String groupId,
    required String category,
    required String optionId,
    required bool selected,
  }) async {
    final group = mockTripSummaryDatabase[groupId];
    if (group == null ||
        (category != 'Accommodation' && category != 'Transport')) {
      return;
    }
    final summary = group['summary'] as Map<String, dynamic>;
    final field = category == 'Accommodation'
        ? 'selectedAccommodationIds'
        : 'selectedTransportIds';
    final ids = List<String>.from(summary[field] as List<dynamic>? ?? const []);
    if (selected && !ids.contains(optionId)) {
      ids.add(optionId);
    } else if (!selected) {
      ids.remove(optionId);
    }
    summary[field] = ids;
  }

  Future<void> updateConfirmedDetail({
    required String groupId,
    required String key,
    required String value,
  }) async {
    final group = mockTripSummaryDatabase[groupId];
    if (group == null) return;
    final summary = group['summary'] as Map<String, dynamic>;
    if (key == 'Budget') {
      final amounts = RegExp(r'\d[\d,]*(?:\.\d+)?')
          .allMatches(value)
          .map((match) => double.tryParse(match.group(0)!.replaceAll(',', '')))
          .whereType<double>()
          .toList();
      if (amounts.isEmpty) {
        summary.remove('budgetRange');
        summary.remove('budget');
        final details = Map<String, String>.from(
          summary['confirmedDetails'] as Map? ?? const {},
        )..remove('Budget');
        summary['confirmedDetails'] = details;
      } else if (amounts.length == 1) {
        summary['budgetRange'] = {'min': amounts.first, 'max': amounts.first};
      } else {
        summary['budgetRange'] = {'min': amounts[0], 'max': amounts[1]};
      }
      return;
    }
    final details = Map<String, String>.from(
      summary['confirmedDetails'] as Map? ?? const {},
    );
    details[key] = value;
    summary['confirmedDetails'] = details;
    if (key == 'Destination') summary['destination'] = value;
    if (key == 'Dates') summary['dates'] = value;
  }

  /// Applies [changes] to every matching member. When [groupId] is null the
  /// member is updated in all groups.
  Future<bool> updateMember({
    String? groupId,
    required String memberId,
    required Map<String, dynamic> changes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final targets = <String>[];
    if (groupId != null && mockTripSummaryDatabase.containsKey(groupId)) {
      targets.add(groupId);
    } else if (groupId == null) {
      targets.addAll(mockTripSummaryDatabase.keys);
    }

    var changed = false;
    for (final id in targets) {
      final members = List<dynamic>.from(
        mockTripSummaryDatabase[id]?['members'] as List<dynamic>? ??
            const <dynamic>[],
      );
      for (var index = 0; index < members.length; index++) {
        final member = members[index];
        if (member is! Map<String, dynamic> || member['id'] != memberId) {
          continue;
        }

        final updated = Map<String, dynamic>.from(member);
        updated.addAll(changes.map((key, value) => MapEntry(key, value)));
        members[index] = updated;
        changed = true;
      }
      mockTripSummaryDatabase[id]!['members'] = members;
    }
    return changed;
  }

  Future<bool> updateSuggestionSaved({
    required String groupId,
    required String suggestionId,
    required bool isSaved,
  }) {
    final suggestions =
        mockTripSummaryDatabase[groupId]?['suggestions'] as List<dynamic>?;
    if (suggestions == null) return Future.value(false);

    final suggestion = suggestions.where(
      (entry) => (entry as Map<String, dynamic>)['id'] == suggestionId,
    );
    if (suggestion.isEmpty) return Future.value(false);

    (suggestion.first as Map<String, dynamic>)['isSaved'] = isSaved;
    return Future.value(true);
  }

  Future<bool> addMember(
    String groupId,
    Map<String, dynamic> memberJson,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final group = mockTripSummaryDatabase.putIfAbsent(
      groupId,
      () => {'summary': {}, 'members': [], 'suggestions': []},
    );
    final members = List<dynamic>.from(group['members'] as List? ?? const []);
    if (members.any((entry) => (entry as Map)['id'] == memberJson['id'])) {
      return false; // Member already exists
    }

    members.add(Map<String, dynamic>.from(memberJson));
    group['members'] = members;
    return true;
  }

  /// Makes the saved list of people match the server (people who accepted).
  /// Keeps the extra fields already stored for the same person.
  void replaceMembers(String groupId, List<Map<String, dynamic>> members) {
    final group = mockTripSummaryDatabase.putIfAbsent(
      groupId,
      () => {'summary': {}, 'members': [], 'suggestions': []},
    );
    final old = {
      for (final m in (group['members'] as List? ?? const []))
        if (m is Map) '${m['id']}': Map<String, dynamic>.from(m),
    };
    group['members'] = [
      for (final m in members) {...?old['${m['id']}'], ...m},
    ];
  }

  void updateTitle(String groupId, String title) {
    final group = mockTripSummaryDatabase[groupId];
    if (group == null || title.trim().isEmpty) return;
    final summary = Map<String, dynamic>.from(group['summary'] as Map? ?? const {});
    summary['title'] = title;
    group['summary'] = summary;
  }

  Future<bool> removeMember({
    required String groupId,
    required String requesterId,
    required String memberId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final members =
        mockTripSummaryDatabase[groupId]?['members'] as List<dynamic>?;
    if (members == null) return false;

    final requesterIsHost = members.any(
      (entry) => entry['id'] == requesterId && entry['role'] == 'Host',
    );
    if (!requesterIsHost) return false;

    final index = members.indexWhere(
      (entry) =>
          entry['id'] == memberId &&
          entry['isMe'] != true &&
          entry['role'] != 'Host',
    );
    if (index == -1) return false;

    members.removeAt(index);
    return true;
  }

  /// Stand-in for the backend creating a group when an invitation is accepted.
  Future<void> createGroupFromInvitation({
    required String groupId,
    required String title,
    required String destination,
    required String dates,
    required String hostName,
    String? hostAvatar,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (mockTripSummaryDatabase.containsKey(groupId)) return;

    mockTripSummaryDatabase[groupId] = {
      'summary': {
        'id': 'sum_$groupId',
        'title': title,
        'destination': destination,
        'status': 'Planning',
        'dates': dates,
        'confirmedDetails': <String, String>{},
        'totalItems': 7,
        'pendingDecisions': ['Budget', 'Accommodation', 'Transport'],
      },
      'members': [
        {
          'id': 'host_$groupId',
          'name': hostName,
          'avatarUrl': hostAvatar,
          'role': 'Host',
          'isMe': false,
          'minBudget': 1000,
          'maxBudget': 5000,
          'preferences': <String>[],
          'dateRange': dates,
        },
        {
          'id': 'user_me',
          'name': 'You',
          'role': 'Member',
          'isMe': true,
          'minBudget': 1000,
          'maxBudget': 5000,
          'preferences': <String>[],
          'dateRange': dates,
        },
      ],
      'suggestions': <Map<String, dynamic>>[],
    };
  }
}
