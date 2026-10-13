import 'dart:convert';
import 'dart:typed_data';

import '../core/api/api_client.dart';

class ChecklistEntry {
  ChecklistEntry({
    required this.id,
    required this.title,
    this.isComplete = false,
    this.isPending = false,
    this.isSaved = false,
  });

  final String id;
  final String title;
  bool isComplete;
  final bool isPending;
  final bool isSaved;

  factory ChecklistEntry.fromJson(Map<String, dynamic> json) => ChecklistEntry(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        isComplete: json['isComplete'] as bool? ?? false,
        isPending: json['isPending'] as bool? ?? false,
        isSaved: json['isSaved'] as bool? ?? false,
      );
}

/// A person's own checklist for a trip, saved in the backend.
class ChecklistService {
  ChecklistService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Old sample trips have ids like "TRIP_123"; only real trips have a saved list.
  static bool isSavedTrip(String tripId) => _uuid.hasMatch(tripId);

  Future<List<ChecklistEntry>> getItems(String tripId) async {
    final r = await _api.get('/api/trips/$tripId/checklist');
    return (r as List)
        .map((e) => ChecklistEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ChecklistEntry> addItem(String tripId, String title) async {
    final r = await _api.post('/api/trips/$tripId/checklist', {'title': title});
    return ChecklistEntry.fromJson(Map<String, dynamic>.from(r as Map));
  }

  Future<void> setComplete(String tripId, String itemId, bool value) async {
    await _api.patch('/api/trips/$tripId/checklist/$itemId', {'isComplete': value});
  }

  /// The person's own flight ticket (cities, date and name start from the trip).
  Future<Map<String, String>> getTicket(String tripId) async {
    final r = await _api.get('/api/trips/$tripId/ticket');
    return _strings(r);
  }

  Future<Map<String, String>> saveTicket(
    String tripId,
    Map<String, String> fields,
  ) async {
    final r = await _api.put('/api/trips/$tripId/ticket', fields);
    return _strings(r);
  }

  /// Reads a photo or PDF of the ticket. Returns the fields it found; nothing is saved.
  Future<Map<String, String>> scanTicket(
    String tripId,
    Uint8List bytes,
    String mimeType,
  ) async {
    final r = await _api.post('/api/trips/$tripId/ticket/scan', {
      'mimeType': mimeType,
      'dataBase64': base64Encode(bytes),
    });
    return _strings((r as Map)['fields']);
  }

  Map<String, String> _strings(dynamic r) => {
        for (final e in Map<String, dynamic>.from(r as Map).entries)
          if (e.value is String) e.key: e.value as String,
      };
}
