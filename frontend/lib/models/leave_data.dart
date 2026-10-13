import 'package:homempage/models/leave_status.dart';

class LeaveData {
  final int selectedYear;
  final int leaveBalance;
  final Map<String, DateStatus> dateStatuses;

  /// Public holiday dates (YYYY-MM-DD). They stay listed even when the user
  /// adds their own tag (busy / leave) on the same day.
  final Set<String> holidayDates;

  LeaveData({
    required this.selectedYear,
    required this.leaveBalance,
    required this.dateStatuses,
    this.holidayDates = const {},
  });

  factory LeaveData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawStatuses = json['date_statuses'] ?? {};
    final Map<String, DateStatus> parsedStatuses = {};

    rawStatuses.forEach((key, value) {
      parsedStatuses[key] = DateStatusX.fromString(value.toString());
    });

    return LeaveData(
      selectedYear: json['selected_year'] ?? 2026,
      leaveBalance: json['leave_balance'] ?? 0,
      dateStatuses: parsedStatuses,
      holidayDates: ((json['holiday_dates'] as List<dynamic>?) ?? const [])
          .map((value) => value.toString())
          .toSet(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, String> jsonStatuses = {};
    dateStatuses.forEach((key, value) {
      jsonStatuses[key] = value.toJson();
    });

    return {
      'selected_year': selectedYear,
      'leave_balance': leaveBalance,
      'date_statuses': jsonStatuses,
      'holiday_dates': holidayDates.toList(),
    };
  }
}