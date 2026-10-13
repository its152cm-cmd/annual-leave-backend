import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../models/collaborator.dart';

/// People you can add to a trip: real accounts from the backend.
class CollaboratorService {
  CollaboratorService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  List<Collaborator> _parse(dynamic response) => (response as List)
      .map((e) => Collaborator.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  /// People you have travelled with before.
  Future<List<Collaborator>> getCollaborators() async {
    try {
      return _parse(await _api.get('/api/collaborators'));
    } catch (e) {
      debugPrint('[collaborators] $e');
      return [];
    }
  }

  /// Finds accounts by name or email.
  Future<List<Collaborator>> searchCollaborators(String query) async {
    final text = query.trim();
    if (text.isEmpty) return [];
    try {
      return _parse(await _api.get('/api/collaborators/search', query: {'q': text}));
    } catch (e) {
      debugPrint('[collaborators] $e');
      return [];
    }
  }
}
