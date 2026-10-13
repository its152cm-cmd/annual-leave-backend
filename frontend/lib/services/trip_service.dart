import '../core/api/api_client.dart';
import '../models/trip.dart';
import '../models/recommendation.dart';

import 'package:flutter/foundation.dart';

class TripService {
  TripService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static final List<Trip> _createdTrips = [];
  static final ValueNotifier<int> tripListRevision = ValueNotifier(0);

  /// Trips come from the backend (GET /api/trips). Only trips kept on this
  /// device (group-chat planning trips) are shown on top of them.
  Future<List<Trip>> getTrips() async {
    final response = await _apiClient.get('/api/trips');
    final remoteTrips = (response as List<dynamic>)
        .map((json) => Trip.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();

    String identity(Trip trip) => [
      trip.destination,
      trip.dateRange,
      trip.duration,
      trip.status.toLowerCase(),
    ].map((value) => value.trim().toLowerCase()).join('|');

    final remoteIds = remoteTrips.map((trip) => trip.id).toSet();
    final remoteIdentities = remoteTrips.map(identity).toSet();
    final localOnlyTrips = _createdTrips.where(
      (trip) =>
          !remoteIds.contains(trip.id) &&
          !remoteIdentities.contains(identity(trip)),
    );
    return [...localOnlyTrips, ...remoteTrips];
  }

  Future<Trip> getTrip(String tripId) async {
    for (final trip in _createdTrips) {
      if (trip.id == tripId) return trip;
    }
    final response = await _apiClient.get('/api/trips/$tripId');
    return Trip.fromJson(Map<String, dynamic>.from(response as Map));
  }

  static final Map<String, Trip> _topPickTrips = {};

  /// Forgets everything kept on this device (used when someone signs in or out).
  static void clearCache() {
    _createdTrips.clear();
    _topPickTrips.clear();
    tripListRevision.value++;
  }

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  bool _isBackendId(String id) => _uuid.hasMatch(id);

  Future<Trip> getOrCreateTopPickTrip(Recommendation recommendation) async {
    final cached = _topPickTrips[recommendation.id];
    if (cached != null) return cached;

    final travellerCount = 4;
    final perPersonAmount = _parseAmount(recommendation.cost);
    final plannedBudget = perPersonAmount > 0
        ? perPersonAmount * travellerCount
        : 3000.0;
    final startDate = DateTime.now().add(const Duration(days: 21));
    final endDate = startDate.add(const Duration(days: 5));
    final trip = Trip(
      id: 'TRIP_${recommendation.id}',
      destination: recommendation.destination,
      dateRange: _formatDateRange(startDate, endDate),
      duration: '6 days',
      budget: 'RM ${_formatAmount(plannedBudget)} budget',
      imageUrl: recommendation.imageUrl,
      status: 'draft',
      travellerCount: travellerCount,
      plannedBudget: plannedBudget,
      estimatedBudget: plannedBudget,
      budgetBreakdown: {
        'Transport': plannedBudget * 0.30,
        'Accommodation': plannedBudget * 0.30,
        'Food': plannedBudget * 0.16,
        'Activities': plannedBudget * 0.16,
        'Other expenses': plannedBudget * 0.08,
      },
    );
    final saved = await saveDraft(trip);
    _topPickTrips[recommendation.id] = saved;
    return saved;
  }

  /// Saves the trip to the backend as a draft and returns it with its real id.
  Future<Trip> saveDraft(Trip trip) async {
    return _saveRemote('/api/trips/draft', trip);
  }

  /// Confirms the trip (status becomes "upcoming") and returns the saved trip.
  Future<Trip> confirmTrip(Trip trip) async {
    return _saveRemote('/api/trips/confirm', trip);
  }

  /// Keeps a trip on this device only (used by the group-chat planning flow
  /// until the group chat is connected to the backend).
  Future<void> saveDraftLocal(Trip trip) async {
    _upsertCreatedTrip(trip.copyWith(status: 'draft'));
    tripListRevision.value++;
  }

  /// Deletes a draft trip on the backend (host only).
  /// Makes a real trip a group trip and invites the people picked in
  /// "Add member". Old sample trips are skipped. Throws if the server says no.
  Future<void> createGroupChat(String tripId, List<String> memberIds) async {
    if (!_isBackendId(tripId)) return;
    await _apiClient.post('/api/trips/$tripId/group-chat', {
      'memberIds': memberIds,
    });
  }

  Future<void> deleteDraft(String tripId) async {
    if (_isBackendId(tripId)) {
      await _apiClient.delete('/api/trips/$tripId');
    }
    _createdTrips.removeWhere((item) => item.id == tripId);
    _topPickTrips.removeWhere((_, trip) => trip.id == tripId);
    tripListRevision.value++;
  }

  Future<void> saveBookedItemIds(Trip trip, Iterable<String> itemIds) async {
    final ids = List<String>.unmodifiable(itemIds);
    if (_isBackendId(trip.id)) {
      await _apiClient.put(
        '/api/trips/${trip.id}/booked-items',
        {'item_ids': ids},
      );
    } else {
      _upsertCreatedTrip(trip.copyWith(bookedItemIds: ids));
    }
    tripListRevision.value++;
  }

  Future<Trip> _saveRemote(String path, Trip trip) async {
    final response = await _apiClient.post(path, trip.toJson());
    final saved = Trip.fromJson(Map<String, dynamic>.from(response as Map));
    // The backend gave the trip its real id, so drop the temporary local copy.
    _createdTrips.removeWhere((item) => item.id == trip.id);
    tripListRevision.value++;
    return saved;
  }

  void _upsertCreatedTrip(Trip trip) {
    final existingIndex = _createdTrips.indexWhere(
      (item) => item.id == trip.id,
    );
    if (existingIndex == -1) {
      _createdTrips.insert(0, trip);
    } else {
      _createdTrips[existingIndex] = trip;
    }
  }

  double _parseAmount(String value) {
    final amount = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(amount) ?? 0;
  }

  String _formatAmount(double amount) {
    final rounded = amount.round().toString();
    final formatted = StringBuffer();
    for (var index = 0; index < rounded.length; index++) {
      if (index > 0 && (rounded.length - index) % 3 == 0) {
        formatted.write(',');
      }
      formatted.write(rounded[index]);
    }
    return formatted.toString();
  }

  String _formatDateRange(DateTime start, DateTime end) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final endLabel = '${end.day} ${months[end.month - 1]} ${end.year}';
    if (start.month == end.month && start.year == end.year) {
      return '${start.day} - $endLabel';
    }
    return '${start.day} ${months[start.month - 1]} - $endLabel';
  }

}
