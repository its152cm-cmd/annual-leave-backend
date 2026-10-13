import 'package:flutter/material.dart';
import 'package:homempage/core/theme/app_theme.dart';

enum DateStatus { normal, busy, holiday, annualLeave, recommended }

extension DateStatusX on DateStatus {
  Color get backgroundColor {
    switch (this) {
      case DateStatus.busy:
        return AppTheme.statusBusyBg;
      case DateStatus.holiday:
        return AppTheme.statusHolidayBg;
      case DateStatus.annualLeave:
        return AppTheme.statusAnnualLeaveBg;
      case DateStatus.recommended:
        return AppTheme.statusRecommendedBg;
      case DateStatus.normal:
        return AppTheme.statusNormalBg;
    }
  }

  Color get textColor {
    switch (this) {
      case DateStatus.busy:
        return AppTheme.statusBusyText;
      case DateStatus.holiday:
        return AppTheme.statusHolidayText;
      case DateStatus.annualLeave:
        return AppTheme.statusAnnualLeaveText;
      case DateStatus.recommended:
        return AppTheme.statusRecommendedText;
      case DateStatus.normal:
        return AppTheme.textDark;
    }
  }

  /// Converts backend JSON string to DateStatus enum
  static DateStatus fromString(String? status) {
    switch (status) {
      case 'busy':
        return DateStatus.busy;
      case 'annual_leave':
      case 'annualLeave':
        return DateStatus.annualLeave;
      case 'recommended':
        return DateStatus.recommended;
      case 'holiday':
        return DateStatus.holiday;
      default:
        return DateStatus.normal;
    }
  }

  /// Converts DateStatus enum to backend-compatible string
  String toJson() {
    switch (this) {
      case DateStatus.busy:
        return 'busy';
      case DateStatus.holiday:
        return 'holiday';
      case DateStatus.annualLeave:
        return 'annual_leave';
      case DateStatus.recommended:
        return 'recommended';
      case DateStatus.normal:
        return 'normal';
    }
  }
}
