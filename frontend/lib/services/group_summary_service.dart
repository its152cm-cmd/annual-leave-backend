// lib/services/group_summary_service.dart

import '../mock/mock_group_summary_data_source.dart';
import '../models/group_member.dart';
import '../models/group_trip_summary.dart';
import '../models/trip.dart';
import '../core/api/api_client.dart';
import 'account_service.dart';
import 'expense_service.dart';
import 'group_planning_service.dart';
import 'trip_service.dart';

class GroupSummaryService {
  GroupSummaryService({GroupSummaryMockDataSource? dataSource})
    : _dataSource = dataSource ?? GroupSummaryMockDataSource();

  final GroupSummaryMockDataSource _dataSource;
  final AccountService _accountService = AccountService();
  final TripService _tripService = TripService();
  final GroupPlanningService _planning = GroupPlanningService();

  Future<void> createTripGroup({required String groupId, required Trip trip}) =>
      _dataSource.createTripGroup(
        groupId: groupId,
        tripId: trip.id,
        title: trip.destination.isEmpty
            ? 'New Group Trip'
            : '${trip.destination} Group Chat',
        destination: trip.destination,
        dates: trip.dateRange,
        minimumBudget: trip.minimumBudget,
        plannedBudget: trip.plannedBudget,
      );

  Future<GroupTripSummary> getTripSummary(String groupId) async {
    final groupData = await _dataSource.fetchGroup(groupId);
    final membersData =
        groupData['members'] as List<dynamic>? ?? const <dynamic>[];
    final summaryData = Map<String, dynamic>.from(
      groupData['summary'] as Map? ?? const <String, dynamic>{},
    );
    final itineraryId =
      summaryData['tripId'] as String? ?? 'GROUP_$groupId';
    final matchingTrip = (await _tripService.getTrips())
      .where((trip) => trip.id == itineraryId)
      .firstOrNull;

    final savedDetails = Map<String, String>.from(
      summaryData['confirmedDetails'] as Map? ?? const {},
    );
    final real = ExpenseService.isSavedGroup(groupId) && matchingTrip != null;
    final destination = real
        ? matchingTrip.destination
        : (summaryData['destination'] as String?) ??
              savedDetails['Destination'] ??
              '';
    final dates = real
        ? matchingTrip.dateRange
        : (summaryData['dates'] as String?) ?? savedDetails['Dates'] ?? '';
    final selections = await _dataSource.fetchPlanningSelections(groupId);
    final tripId = GroupPlanningService.tripIdFor(groupId);
    Map<String, dynamic>? decisions;
    String? realBudget;
    int? pickedActivities;
    List<String>? realPreferenceTags;
    if (tripId != null) {
      try {
        final a = await _planning.getActivities(tripId);
        pickedActivities = (a['activities'] as List)
            .where((x) => (x as Map)['picked'] == true)
            .length;
      } catch (_) {}
      try {
        final p = await _planning.getPreferences(tripId);
        realPreferenceTags = List<String>.from(p['combined'] as List);
      } catch (_) {}
      try {
        final d = await _planning.getDecisions(tripId);
        decisions = Map<String, dynamic>.from(d['decisions'] as Map);
      } catch (_) {}
      try {
        final b = await _planning.getBudget(tripId);
        final c = b['combined'] as Map?;
        realBudget = c == null
            ? ''
            : _formatTripBudget({'min': c['min'], 'max': c['max']});
      } catch (_) {}
    }
    final budgetRange =
        realBudget ??
        _formatTripBudget(
          summaryData['budgetRange'] ??
              summaryData['budget'] ??
              savedDetails['Budget'],
        );
    final preferenceTags = realPreferenceTags ?? membersData
        .expand(
          (member) =>
              (member as Map<String, dynamic>)['preferences']
                  as List<dynamic>? ??
              const <dynamic>[],
        )
        .map((entry) => entry.toString())
        .toSet()
        .toList();

    String decisionText(String key, String selectionKey) {
      final d = decisions;
      if (d != null) {
        final entry = d[key];
        if (entry is List && entry.isNotEmpty) {
          final first = (entry.first as Map)['title'] as String? ?? '';
          return entry.length == 1 ? first : '$first +${entry.length - 1}';
        }
        // Nothing chosen: the AI suggests, so this never blocks "Ready".
        return 'AI will suggest';
      }
      return selections[selectionKey]!.isNotEmpty
          ? 'Selected'
          : 'Needs decision';
    }

    final accommodationText = decisionText('Accommodation', 'Accommodation');
    final transportText = decisionText('Transport', 'Transport');
    final confirmedDetails = <String, String>{
      'Accommodation': accommodationText,
      'Transport': transportText,
      'Destination': destination.isNotEmpty ? destination : 'To be decided',
      'Dates': dates.isNotEmpty ? dates : 'To be decided',
      'Traveller': membersData.isNotEmpty
          ? '${membersData.length}'
          : 'Needs decision',
      'Budget': budgetRange.isEmpty ? 'Needs decision' : budgetRange,
      if (pickedActivities != null)
        'Activities': pickedActivities == 0
            ? 'AI will choose'
            : '$pickedActivities selected',
    };
    final pendingDecisions = confirmedDetails.entries
        .where((entry) => entry.value == 'Needs decision')
        .map((entry) => entry.key)
        .toList();
    final totalItems = confirmedDetails.length;
    final completedItems = totalItems - pendingDecisions.length;

    return GroupTripSummary.fromJson({
      'groupId': groupId,
      'itineraryId': itineraryId,
      'tripStatus': matchingTrip?.status ?? 'draft',
      'title': summaryData['title'] ?? 'New Trip',
      'dates': dates,
      'destination': destination,
      'budget': budgetRange,
      'progress': totalItems > 0 ? completedItems / totalItems : 0.0,
      'completedItems': completedItems,
      'totalItems': totalItems,
      'pendingDecisions': pendingDecisions,
      'confirmedDetails': confirmedDetails,
      'preferenceTags': preferenceTags,
      'isReadyToPlan': pendingDecisions.isEmpty,
    });
  }

  Future<Trip> getOrCreatePlanningTrip(GroupTripSummary summary) async {
    final groupData = await _dataSource.fetchGroup(summary.groupId);
    final rawSummary = Map<String, dynamic>.from(
      groupData['summary'] as Map? ?? const <String, dynamic>{},
    );
    final tripId =
        rawSummary['tripId'] as String? ?? 'GROUP_${summary.groupId}';
    final existingTrip = (await _tripService.getTrips())
        .where((trip) => trip.id == tripId)
        .firstOrNull;
    final budgetAmounts = RegExp(r'\d[\d,]*(?:\.\d+)?')
        .allMatches(summary.budget.replaceAll(',', ''))
        .map((match) => double.tryParse(match.group(0)!))
        .whereType<double>()
        .toList();
    final minimumBudget = budgetAmounts.isNotEmpty
        ? budgetAmounts.first
        : existingTrip?.minimumBudget ?? 0.0;
    final plannedBudget = budgetAmounts.isNotEmpty
        ? budgetAmounts.last
        : existingTrip?.plannedBudget ?? 2000.0;
    final travellerCount =
        int.tryParse(summary.confirmedDetails['Traveller'] ?? '') ??
        existingTrip?.travellerCount ??
        1;
    final trip = Trip(
      id: tripId,
      destination: summary.destination,
      dateRange: summary.dates,
      duration: '${_durationDays(summary.dates)} days',
      budget: summary.budget,
      imageUrl: existingTrip?.imageUrl ?? '',
      status: 'draft',
      generatedFromGroupChat: true,
      travellerCount: travellerCount,
      minimumBudget: minimumBudget,
      plannedBudget: plannedBudget,
      originCity: existingTrip?.originCity ?? 'Kuala Lumpur',
      estimatedBudget: existingTrip?.estimatedBudget,
      budgetBreakdown: existingTrip?.budgetBreakdown,
    );
    await _tripService.saveDraftLocal(trip);
    return trip;
  }

  int _durationDays(String dateRange) {
    const months = {
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };
    final abbreviatedMonthRange = RegExp(
      r'([A-Za-z]+)\s+(\d{1,2})\s*-\s*(?:[A-Za-z]+\s+)?(\d{1,2}),?\s+(\d{4})',
    ).firstMatch(dateRange);
    if (abbreviatedMonthRange != null) {
      final month = months[abbreviatedMonthRange.group(1)!.toLowerCase()];
      final year = int.tryParse(abbreviatedMonthRange.group(4)!);
      if (month != null && year != null) {
        final start = DateTime(
          year,
          month,
          int.parse(abbreviatedMonthRange.group(2)!),
        );
        final end = DateTime(
          year,
          month,
          int.parse(abbreviatedMonthRange.group(3)!),
        );
        return end.difference(start).inDays.clamp(1, 365);
      }
    }

    final fullMonthRange = RegExp(
      r'(\d{1,2})\s+([A-Za-z]+)\s*-\s*(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})',
    ).firstMatch(dateRange);
    if (fullMonthRange != null) {
      final startMonth = months[fullMonthRange.group(2)!.toLowerCase()];
      final endMonth = months[fullMonthRange.group(4)!.toLowerCase()];
      final year = int.tryParse(fullMonthRange.group(5)!);
      if (startMonth != null && endMonth != null && year != null) {
        final start = DateTime(
          year,
          startMonth,
          int.parse(fullMonthRange.group(1)!),
        );
        final end = DateTime(
          year,
          endMonth,
          int.parse(fullMonthRange.group(3)!),
        );
        return end.difference(start).inDays.clamp(1, 365);
      }
    }
    return 1;
  }

  Future<List<GroupSuggestion>> getGroupSuggestions(String groupId) async {
    final groupData = await _dataSource.fetchGroup(groupId);
    final list =
        groupData['suggestions'] as List<dynamic>? ?? const <dynamic>[];
    return list
        .map((json) => GroupSuggestion.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<bool> setGroupSuggestionSaved({
    required String groupId,
    required String suggestionId,
    required bool isSaved,
  }) {
    return _dataSource.updateSuggestionSaved(
      groupId: groupId,
      suggestionId: suggestionId,
      isSaved: isSaved,
    );
  }

  String _formatTripBudget(dynamic rawBudget) {
    if (rawBudget is num) return 'RM${_formatAmount(rawBudget)}';
    if (rawBudget is Map) {
      final minimum = rawBudget['min'] as num?;
      final maximum = rawBudget['max'] as num?;
      if (minimum == null && maximum == null) return '';
      if (minimum == null || maximum == null || minimum == maximum) {
        return 'RM${_formatAmount(minimum ?? maximum!)}';
      }
      return 'RM${_formatAmount(minimum)}–RM${_formatAmount(maximum)}';
    }
    if (rawBudget is String) {
      final text = rawBudget.trim();
      if (text.isEmpty || text == 'Needs decision' || text == 'Selected') {
        return '';
      }
      final amounts = RegExp(r'\d[\d,]*(?:\.\d+)?')
          .allMatches(text)
          .map((match) => double.tryParse(match.group(0)!.replaceAll(',', '')))
          .whereType<double>()
          .toList();
      if (amounts.isEmpty) return '';
      if (amounts.length == 1) return 'RM${_formatAmount(amounts.first)}';
      return 'RM${_formatAmount(amounts[0])}–RM${_formatAmount(amounts[1])}';
    }
    return '';
  }

  String _formatAmount(num amount) {
    final value = amount.toDouble();
    final fixed = value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return parts.length == 1 ? whole : '$whole.${parts.last}';
  }

  /// Ids of the host's chosen hotel / flight (real groups), or the sample
  /// group's own selections.
  Future<Map<String, List<String>>> getPlanningSelections(
    String groupId,
  ) async {
    final tripId = GroupPlanningService.tripIdFor(groupId);
    if (tripId == null) return _dataSource.fetchPlanningSelections(groupId);
    try {
      final d = await _planning.getDecisions(tripId);
      final dec = Map<String, dynamic>.from(d['decisions'] as Map);
      List<String> idOf(String k) => [
        for (final e in (dec[k] as List? ?? const []))
          if (((e as Map)['itemId'] as String? ?? '').isNotEmpty)
            e['itemId'] as String,
      ];

      return {'Accommodation': idOf('Accommodation'), 'Transport': idOf('Transport')};
    } catch (_) {
      return {'Accommodation': <String>[], 'Transport': <String>[]};
    }
  }

  /// Whether the signed-in person is the host of this group. Sample groups
  /// have no real host, so everyone counts as one there.
  Future<bool> isHost(String groupId) async {
    if (GroupPlanningService.tripIdFor(groupId) == null) return true;
    final members = await getGroupMembers(groupId);
    return members.any((m) => m.isMe && m.role == 'Host');
  }

  Future<void> setPlanningOptionSelected({
    required String groupId,
    required String category,
    required String optionId,
    required bool selected,
  }) => _dataSource.setPlanningOptionSelected(
    groupId: groupId,
    category: category,
    optionId: optionId,
    selected: selected,
  );

  Future<void> updateConfirmedDetail({
    required String groupId,
    required String key,
    required String value,
  }) async {
    if (ExpenseService.isSavedGroup(groupId)) {
      final tripId = groupId.substring('trip_'.length);
      Map<String, dynamic>? body;
      if (key == 'Destination') {
        body = {'destination': value};
      } else if (key == 'Dates') {
        body = {'date_range': value};
      }
      if (body != null) {
        await ApiClient().patch('/api/trips/$tripId/details', body);
        TripService.tripListRevision.value++;
      }
    }
    await _dataSource.updateConfirmedDetail(
      groupId: groupId,
      key: key,
      value: value,
    );
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final groupData = await _dataSource.fetchGroup(groupId);
    final profile = await _accountService.getCurrentUser();
    final list = groupData['members'] as List<dynamic>? ?? const <dynamic>[];

    final membersById = <String, GroupMember>{};
    for (final json in list) {
      final memberJson = Map<String, dynamic>.from(
        json as Map<String, dynamic>,
      );
      // The group's own member list is the source of truth for everyone except
      // the signed-in user, whose avatar always follows their account profile.
      final isMe = memberJson['isMe'] as bool? ?? memberJson['id'] == 'user_me';
      if (isMe && profile != null && profile.avatarUrl.isNotEmpty) {
        memberJson['avatarUrl'] = profile.avatarUrl;
      }
      final member = GroupMember.fromJson(memberJson);
      membersById.putIfAbsent(member.id, () => member);
    }
    return membersById.values.toList();
  }

  Future<int> getGroupMemberCount(String groupId) async =>
      (await getGroupMembers(groupId)).length;

  Future<bool> updateMemberBudget({
    required String memberId,
    required double minBudget,
    required double maxBudget,
    String? groupId,
  }) {
    return _dataSource.updateMember(
      groupId: groupId,
      memberId: memberId,
      changes: {'minBudget': minBudget, 'maxBudget': maxBudget},
    );
  }

  Future<bool> updateMemberDateRange({
    required String memberId,
    required String dateRange,
    String? groupId,
  }) {
    return _dataSource.updateMember(
      groupId: groupId,
      memberId: memberId,
      changes: {'dateRange': dateRange},
    );
  }

  Future<bool> updateMemberPreferences({
    required String memberId,
    required List<String> preferences,
    String? groupId,
  }) {
    return _dataSource.updateMember(
      groupId: groupId,
      memberId: memberId,
      changes: {'preferences': List<String>.from(preferences)},
    );
  }

  Future<bool> addGroupMember(String groupId, GroupMember member) {
    return _dataSource.addMember(groupId, member.toJson());
  }

  /// People invited but not yet accepted, per group (they are not counted as members).
  static final Map<String, List<GroupMember>> pendingByGroup = {};

  /// Brings the member list and the chat name in line with the server.
  /// Only people who accepted are members; the others are "pending".
  /// Returns true when something changed.
  Future<bool> syncMembers(String groupId) async {
    if (!ExpenseService.isSavedGroup(groupId) || ApiClient.sessionToken == null) {
      return false;
    }
    try {
      final tripId = groupId.substring('trip_'.length);
      final r = Map<String, dynamic>.from(
        await ApiClient().get('/api/chats/$tripId/members') as Map,
      );
      final accepted = <Map<String, dynamic>>[];
      final pending = <GroupMember>[];
      for (final raw in (r['members'] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(raw as Map);
        final member = GroupMember(
          id: m['id'] as String,
          name: m['name'] as String? ?? '',
          role: m['role'] as String? ?? 'Member',
          avatarUrl: m['avatarUrl'] as String?,
          isMe: m['isMe'] as bool? ?? false,
          leaveBalanceSummary: '',
        );
        if (m['status'] == 'accepted') {
          accepted.add(member.toJson());
        } else {
          pending.add(member);
        }
      }
      final oldGroup = await _dataSource.fetchGroup(groupId);
      final oldTitle = (oldGroup['summary'] as Map?)?['title'] ?? '';
      final before = '${(await getGroupMembers(groupId)).map((m) => m.id).join(',')}|'
          '${pendingByGroup[groupId]?.map((m) => m.id).join(',') ?? ''}|$oldTitle';
      _dataSource.replaceMembers(groupId, accepted);
      pendingByGroup[groupId] = pending;
      final title = (r['title'] as String? ?? '').trim();
      if (title.isNotEmpty) _dataSource.updateTitle(groupId, title);
      final newTitle = title.isNotEmpty ? title : oldTitle;
      final after = '${accepted.map((m) => m['id']).join(',')}|${pending.map((m) => m.id).join(',')}|$newTitle';
      return before != after;
    } catch (_) {
      return false;
    }
  }

  /// Renames the group chat. For a saved group the name is stored on the server.
  Future<String> renameGroup(String groupId, String title) async {
    var saved = title.trim();
    if (ExpenseService.isSavedGroup(groupId)) {
      final tripId = groupId.substring('trip_'.length);
      final r = await ApiClient().patch('/api/chats/$tripId', {'title': saved});
      saved = (r as Map)['title'] as String? ?? saved;
      TripService.tripListRevision.value++;
    }
    _dataSource.updateTitle(groupId, saved);
    return saved;
  }

  Future<bool> removeGroupMember({
    required String groupId,
    required String requesterId,
    required String memberId,
  }) async {
    if (ExpenseService.isSavedGroup(groupId)) {
      try {
        final tripId = groupId.substring('trip_'.length);
        await ApiClient().delete('/api/chats/$tripId/members/$memberId');
        await syncMembers(groupId);
        return true;
      } catch (_) {
        return false;
      }
    }
    return _dataSource.removeMember(
      groupId: groupId,
      requesterId: requesterId,
      memberId: memberId,
    );
  }
}
