class LeaveCombo {
  final String id;
  final int daysOff;
  final String returnMultiplier;
  final int leaveDaysUsed;
  final String dateRange;
  final String description;
  final DateTime? startDate; // exact first and last day (null for older backends)
  final DateTime? endDate;

  LeaveCombo({
    required this.id,
    required this.daysOff,
    required this.returnMultiplier,
    required this.leaveDaysUsed,
    required this.dateRange,
    required this.description,
    this.startDate,
    this.endDate,
  });

  factory LeaveCombo.fromJson(Map<String, dynamic> json) {
    return LeaveCombo(
      id: json['id'] ?? '',
      daysOff: json['days_off'] ?? 0,
      returnMultiplier: json['return_multiplier'] ?? '',
      leaveDaysUsed: json['leave_days_used'] ?? 0,
      dateRange: json['date_range'] ?? '',
      description: json['description'] ?? '',
      startDate: DateTime.tryParse('${json['start_date'] ?? ''}'),
      endDate: DateTime.tryParse('${json['end_date'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'days_off': daysOff,
      'return_multiplier': returnMultiplier,
      'leave_days_used': leaveDaysUsed,
      'date_range': dateRange,
      'description': description,
    };
  }
}