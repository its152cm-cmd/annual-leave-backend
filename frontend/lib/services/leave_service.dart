import '../core/api/api_client.dart';
import '../mock/mock_leave.dart';
import '../models/leave_combo.dart';
import '../models/leave_data.dart';
import '../models/leave_status.dart';

class LeaveService {
  LeaveService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  // Sample calendars for group members that are not real backend users yet
  // (the group chat still uses sample members). Removed once group chat is
  // connected to the backend.
  static final Map<String, Map<String, dynamic>> _sampleDataByMemberId = {};

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// null = the signed-in user. A UUID = a real user. Anything else = a
  /// sample member from the mock group chat.
  bool _isSample(String? memberId) {
    final id = memberId?.trim();
    return id != null && id.isNotEmpty && !_uuid.hasMatch(id);
  }

  Map<String, dynamic> _sampleData(String memberId) {
    final key = memberId.trim();
    return _sampleDataByMemberId.putIfAbsent(key, () {
      final fixture =
          mockLeaveDataByMemberId[key] ?? createMemberLeaveDataFallback(key);
      return {
        ...fixture,
        'date_statuses': Map<String, dynamic>.from(
          fixture['date_statuses'] as Map<String, dynamic>,
        ),
      };
    });
  }

  Future<LeaveData> getUserLeaveData({int? year, String? memberId}) async {
    if (_isSample(memberId)) {
      await Future.delayed(const Duration(milliseconds: 200));
      final leaveData = LeaveData.fromJson(_sampleData(memberId!));
      final requestedYear = year ?? leaveData.selectedYear;
      if (requestedYear == leaveData.selectedYear) return leaveData;
      final yearPrefix = '$requestedYear-';
      return LeaveData(
        selectedYear: requestedYear,
        leaveBalance: leaveData.leaveBalance,
        dateStatuses: Map.fromEntries(
          leaveData.dateStatuses.entries.where(
            (entry) => entry.key.startsWith(yearPrefix),
          ),
        ),
      );
    }

    final response = await _apiClient.get(
      '/api/leave',
      query: {
        if (year != null) 'year': year,
        if (memberId != null && memberId.trim().isNotEmpty)
          'member_id': memberId.trim(),
      },
    );
    return LeaveData.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<List<LeaveCombo>> getLeaveCombos({
    int year = 2026,
    int month = 10,
  }) async {
    final response = await _apiClient.get(
      '/api/leave/combos',
      query: {'year': year, 'month': month},
    );
    return (response as List<dynamic>)
        .map((json) => LeaveCombo.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<bool> updateDateStatus(
    String dateKey,
    DateStatus status, {
    String? memberId,
  }) async {
    if (_isSample(memberId)) {
      final statuses =
          _sampleData(memberId!)['date_statuses'] as Map<String, dynamic>;
      if (status == DateStatus.normal) {
        statuses.remove(dateKey);
      } else {
        statuses[dateKey] = status.toJson();
      }
      return true;
    }
    try {
      await _apiClient.put('/api/leave/dates', {
        'date': dateKey,
        'status': status.toJson(),
      });
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<bool> updateLeaveBalance(
    int newBalance, {
    String? memberId,
    int? year,
  }) async {
    if (_isSample(memberId)) {
      _sampleData(memberId!)['leave_balance'] = newBalance;
      return true;
    }
    try {
      await _apiClient.put('/api/leave/balance', {
        'year': year ?? DateTime.now().year,
        'leave_balance': newBalance,
      });
      return true;
    } on ApiException {
      return false;
    }
  }
}