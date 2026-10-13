Map<String, dynamic> _memberLeaveData(
  int leaveBalance,
  Map<String, String> dateStatuses,
) => {
  'selected_year': 2026,
  'leave_balance': leaveBalance,
  'date_statuses': dateStatuses,
};

/// Independent initial calendar fixtures for the identities used by the
/// sample trip groups. LeaveService deep-copies the selected fixture so edits
/// are retained per member without changing these defaults or other members.
final Map<String, Map<String, dynamic>> mockLeaveDataByMemberId = {
  '5574 5687 1125 5115': _memberLeaveData(18, {
    '2026-10-05': 'holiday',
    '2026-10-07': 'busy',
    '2026-10-08': 'busy',
    '2026-10-10': 'annual_leave',
    '2026-11-01': 'holiday',
    '2026-11-04': 'busy',
    '2026-11-05': 'annual_leave',
    '2026-12-12': 'holiday',
    '2026-12-13': 'busy',
    '2026-12-16': 'annual_leave',
  }),
  'collab_1': _memberLeaveData(12, {
    '2026-10-05': 'holiday',
    '2026-10-06': 'busy',
    '2026-10-09': 'busy',
    '2026-10-15': 'annual_leave',
    '2026-11-01': 'holiday',
    '2026-11-02': 'busy',
    '2026-11-06': 'annual_leave',
    '2026-12-10': 'holiday',
    '2026-12-11': 'busy',
    '2026-12-15': 'annual_leave',
  }),
  'collab_2': _memberLeaveData(14, {
    '2026-10-02': 'holiday',
    '2026-10-11': 'busy',
    '2026-10-13': 'annual_leave',
    '2026-11-02': 'holiday',
    '2026-11-04': 'busy',
    '2026-11-05': 'busy',
    '2026-11-06': 'annual_leave',
    '2026-12-12': 'holiday',
    '2026-12-14': 'busy',
    '2026-12-18': 'annual_leave',
  }),
  'collab_3': _memberLeaveData(10, {
    '2026-10-05': 'holiday',
    '2026-10-07': 'busy',
    '2026-10-16': 'annual_leave',
    '2026-11-01': 'holiday',
    '2026-11-04': 'busy',
    '2026-11-07': 'annual_leave',
    '2026-12-10': 'holiday',
    '2026-12-12': 'busy',
    '2026-12-17': 'annual_leave',
  }),
  'collab_4': _memberLeaveData(16, {
    '2026-10-03': 'busy',
    '2026-10-05': 'holiday',
    '2026-10-14': 'annual_leave',
    '2026-11-03': 'holiday',
    '2026-11-05': 'busy',
    '2026-11-06': 'annual_leave',
    '2026-12-11': 'holiday',
    '2026-12-13': 'busy',
    '2026-12-16': 'annual_leave',
  }),
  'collab_6': _memberLeaveData(11, {
    '2026-10-04': 'busy',
    '2026-10-06': 'holiday',
    '2026-10-12': 'annual_leave',
    '2026-11-01': 'busy',
    '2026-11-04': 'holiday',
    '2026-11-07': 'annual_leave',
    '2026-12-10': 'busy',
    '2026-12-13': 'holiday',
    '2026-12-15': 'annual_leave',
  }),
};

Map<String, dynamic> createMemberLeaveDataFallback(String memberId) {
  final seed = memberId.codeUnits.fold<int>(
    0,
    (value, unit) => (value * 31 + unit) & 0x7fffffff,
  );
  final offset = seed % 5;
  final statuses = <String, String>{};
  for (var month = 10; month <= 12; month++) {
    final prefix = '2026-${month.toString().padLeft(2, '0')}';
    statuses['$prefix-${(4 + offset).toString().padLeft(2, '0')}'] = 'busy';
    statuses['$prefix-${(9 + offset).toString().padLeft(2, '0')}'] = 'holiday';
    statuses['$prefix-${(15 + offset).toString().padLeft(2, '0')}'] =
        'annual_leave';
  }
  return _memberLeaveData(10 + seed % 9, statuses);
}

final List<Map<String, dynamic>> mockLeaveCombos = [
  {
    "id": "COMBO_001",
    "days_off": 4,
    "return_multiplier": "4x Return",
    "leave_days_used": 1,
    "date_range": "Oct 2 - Oct 5",
    "description": "Book off Friday Oct 2 before Labour Day (Mon Oct 5) for a fantastic 4-day weekend getaway.",
  }
];
