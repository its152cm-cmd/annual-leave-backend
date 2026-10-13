import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

import 'package:homempage/models/leave_status.dart';

class CalendarGrid extends StatelessWidget {
  final int selectedYear;
  final int currentMonthIndex; // 0 for Jan, 11 for Dec
  final Map<String, DateStatus> dateStatuses;
  final Function(DateTime date) onDateTap;
  final DateTimeRange? selectedDateRange;
  final Set<String> holidayDates;

  const CalendarGrid({
    super.key,
    required this.selectedYear,
    required this.currentMonthIndex,
    required this.dateStatuses,
    required this.onDateTap,
    this.selectedDateRange,
    this.holidayDates = const {},
  });

  /// Helper to get total days in a given month/year
  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// Helper to get the weekday offset for the 1st of the month
  /// Returns 0 for Monday, 1 for Tuesday, ..., 6 for Sunday
  int _getStartingWeekdayOffset(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    return firstDay.weekday - 1; // DateTime.weekday: Mon = 1, Sun = 7
  }

  @override
  Widget build(BuildContext context) {
    final daysInWeek = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    // Month numbers in DateTime are 1-indexed (1 to 12)
    final monthNumber = currentMonthIndex + 1;
    final totalDaysInMonth = _getDaysInMonth(selectedYear, monthNumber);
    final startingOffset = _getStartingWeekdayOffset(selectedYear, monthNumber);

    // Total cells required = leading empty offset + actual days in month
    final totalGridCells = startingOffset + totalDaysInMonth;

    return Column(
      children: [
        // Day of Week Header (M T W T F S S)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: daysInWeek
              .map(
                (d) => Text(
                  d,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),

        // Calendar Grid View
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalGridCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            // Empty placeholder cells before the 1st of the month
            if (index < startingOffset) {
              return const SizedBox.shrink();
            }

            final dayNumber = index - startingOffset + 1;
            final date = DateTime(selectedYear, monthNumber, dayNumber);

            // Format date key as YYYY-MM-DD to match model format
            final dateKey =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

            final storedStatus = dateStatuses[dateKey] ?? DateStatus.normal;
            final isPublicHoliday = holidayDates.contains(dateKey);
            // A public holiday keeps its colour; the user's own tag on that
            // day (busy / leave) is shown as a small dot on top of it.
            final DateStatus? extraTag = isPublicHoliday &&
                    (storedStatus == DateStatus.busy ||
                        storedStatus == DateStatus.annualLeave)
                ? storedStatus
                : null;
            final status = isPublicHoliday
                ? DateStatus.holiday
                : storedStatus == DateStatus.holiday ||
                        storedStatus == DateStatus.busy ||
                        storedStatus == DateStatus.annualLeave
                    ? storedStatus
                    : DateStatus.normal;
            final selectedRange = selectedDateRange;
            final isInSelectedRange =
                selectedRange != null &&
                !date.isBefore(
                  DateTime(
                    selectedRange.start.year,
                    selectedRange.start.month,
                    selectedRange.start.day,
                  ),
                ) &&
                !date.isAfter(
                  DateTime(
                    selectedRange.end.year,
                    selectedRange.end.month,
                    selectedRange.end.day,
                  ),
                );

            final isMarked = status != DateStatus.normal;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onDateTap(date),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: status.backgroundColor,
                    borderRadius: BorderRadius.circular(11),
                    border: isInSelectedRange
                        ? Border.all(
                            color: AppTheme.primaryGreen,
                            width: 1.5,
                          )
                        : Border.all(
                            color: isMarked
                                ? status.textColor.withValues(alpha: 0.24)
                                : Colors.transparent,
                            width: 1,
                          ),
                    boxShadow: isMarked
                        ? [
                            BoxShadow(
                              color: status.textColor.withValues(alpha: 0.08),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isMarked ? FontWeight.w700 : FontWeight.w600,
                          color: status.textColor,
                        ),
                      ),
                      if (extraTag != null)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: extraTag.textColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: extraTag.backgroundColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
