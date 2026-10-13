import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/leave_status.dart';
import 'calendar_grid.dart';

class LeaveCalendarCard extends StatelessWidget {
  final int selectedYear;
  final int currentMonthIndex;
  final Map<String, DateStatus> dateStatuses;
  final DateTimeRange? selectedDateRange;
  final ValueChanged<DateTime> onDateTap;
  final void Function(int year, int monthIndex) onMonthChanged;
  final bool showLegend;
  final Set<String> holidayDates;

  const LeaveCalendarCard({
    super.key,
    required this.selectedYear,
    required this.currentMonthIndex,
    required this.dateStatuses,
    required this.onDateTap,
    required this.onMonthChanged,
    this.selectedDateRange,
    this.showLegend = true,
    this.holidayDates = const {},
  });

  void _goToMonth(int step) {
    final month = DateTime(selectedYear, currentMonthIndex + 1 + step);
    onMonthChanged(month.year, month.month - 1);
  }

  @override
  Widget build(BuildContext context) {
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${months[currentMonthIndex]} $selectedYear',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _goToMonth(-1),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _goToMonth(1),
              ),
            ],
          ),
          if (showLegend) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.start,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildLegendItem(
                  'Busy',
                  AppTheme.statusBusyBg,
                  AppTheme.statusBusyText,
                ),
                _buildLegendItem(
                  'Holiday',
                  AppTheme.statusHolidayBg,
                  AppTheme.statusHolidayText,
                ),
                _buildLegendItem(
                  'Annual Leave Taken',
                  AppTheme.statusAnnualLeaveBg,
                  AppTheme.statusAnnualLeaveText,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          GestureDetector(
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity;
              if (velocity == null || velocity == 0) return;
              final month = DateTime(
                selectedYear,
                currentMonthIndex + 1 + (velocity < 0 ? 1 : -1),
              );
              onMonthChanged(month.year, month.month - 1);
            },
            child: CalendarGrid(
              selectedYear: selectedYear,
              currentMonthIndex: currentMonthIndex,
              dateStatuses: dateStatuses,
              selectedDateRange: selectedDateRange,
              holidayDates: holidayDates,
              onDateTap: onDateTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color background, Color textColor) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: background.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: textColor.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      );
}
