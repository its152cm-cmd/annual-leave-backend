import 'dart:convert';
import 'dart:typed_data';

import '../core/api/api_client.dart';

const budgetStatuses = ['estimated', 'planned', 'pending', 'booked'];
const budgetCategories = ['Transport', 'Accommodation', 'Food', 'Activities', 'Other Expenses'];

String statusLabel(String s) => switch (s) {
      'booked' => 'Booked',
      'pending' => 'Pending',
      'planned' => 'Planned',
      _ => 'Estimated',
    };

class BudgetDoc {
  final String id, fileName, contentType, checkStatus;
  final List<String> notes;
  const BudgetDoc({required this.id, required this.fileName, required this.contentType, required this.checkStatus, required this.notes});
  factory BudgetDoc.fromJson(Map j) => BudgetDoc(
        id: '${j['id']}', fileName: '${j['fileName']}', contentType: '${j['contentType']}',
        checkStatus: '${j['checkStatus']}', notes: [for (final n in (j['notes'] as List? ?? [])) '$n'],
      );
}

class BudgetLine {
  final String id, category, title, status, bookingUrl;
  final double amount;
  final List<BudgetDoc> documents;
  const BudgetLine({
    required this.id, required this.category, required this.title, required this.status,
    required this.bookingUrl, required this.amount, required this.documents,
  });
  factory BudgetLine.fromJson(Map j) => BudgetLine(
        id: '${j['id']}', category: '${j['category']}', title: '${j['title']}', status: '${j['status']}',
        bookingUrl: '${j['bookingUrl'] ?? ''}', amount: (j['amount'] as num?)?.toDouble() ?? 0,
        documents: [for (final d in (j['documents'] as List? ?? [])) BudgetDoc.fromJson(d as Map)],
      );
}

class BudgetLinesData {
  final bool canEdit;
  final List<BudgetLine> lines;
  final double total, budget;
  final double? remaining;
  final Map<String, double> byStatus;
  final String currency;
  const BudgetLinesData({
    required this.canEdit, required this.lines, required this.total, required this.budget,
    required this.remaining, required this.byStatus, required this.currency,
  });
  factory BudgetLinesData.fromJson(Map j) {
    final s = (j['summary'] as Map?) ?? {};
    return BudgetLinesData(
      canEdit: j['canEdit'] == true,
      lines: [for (final l in (j['lines'] as List? ?? [])) BudgetLine.fromJson(l as Map)],
      total: (s['total'] as num?)?.toDouble() ?? 0,
      budget: (s['budget'] as num?)?.toDouble() ?? 0,
      remaining: (s['remaining'] as num?)?.toDouble(),
      byStatus: {for (final e in ((s['byStatus'] as Map?) ?? {}).entries) '${e.key}': (e.value as num).toDouble()},
      currency: '${s['currency'] ?? 'RM'}',
    );
  }
}

class TripBudgetService {
  final ApiClient _api = ApiClient();
  static final RegExp _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

  /// Sample trips (not saved on the backend) have no budget lines.
  static bool isSaved(String tripId) => _uuid.hasMatch(tripId);

  String _b(String tripId) => '/api/trips/$tripId/lines';

  Future<BudgetLinesData> load(String tripId) async =>
      BudgetLinesData.fromJson(await _api.get(_b(tripId)) as Map);

  Future<void> add(String tripId, {required String category, required String title, required double amount, required String status, String bookingUrl = ''}) =>
      _api.post(_b(tripId), {'category': category, 'title': title, 'amount': amount, 'status': status, 'bookingUrl': bookingUrl});

  Future<void> update(String tripId, String lineId, Map<String, Object?> changes) =>
      _api.patch('${_b(tripId)}/$lineId', changes);

  Future<void> remove(String tripId, String lineId) => _api.delete('${_b(tripId)}/$lineId');

  Future<BudgetDoc> upload(String tripId, String lineId, {required String fileName, required String mimeType, required Uint8List bytes}) async {
    final r = await _api.post('${_b(tripId)}/$lineId/documents',
        {'fileName': fileName, 'mimeType': mimeType, 'dataBase64': base64Encode(bytes)}) as Map;
    return BudgetDoc.fromJson(r['document'] as Map);
  }

  Future<BudgetDoc> recheck(String tripId, String lineId, String docId) async {
    final r = await _api.post('${_b(tripId)}/$lineId/documents/$docId/recheck') as Map;
    return BudgetDoc.fromJson(r['document'] as Map);
  }

  Future<String> documentUrl(String tripId, String lineId, String docId) async {
    final r = await _api.get('${_b(tripId)}/$lineId/documents/$docId/url') as Map;
    return '${r['url']}';
  }

  Future<void> removeDocument(String tripId, String lineId, String docId) =>
      _api.delete('${_b(tripId)}/$lineId/documents/$docId');
}
