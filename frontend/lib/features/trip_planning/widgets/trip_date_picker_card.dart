import 'package:flutter/material.dart';
import 'package:homempage/core/theme/app_theme.dart';
import 'package:homempage/models/leave_combo.dart';
import 'package:homempage/services/leave_service.dart';

class TripDatePickerCard extends StatelessWidget {
  final DateTimeRange? selectedDates;
  final ValueChanged<DateTimeRange> onDatesSelected;

  const TripDatePickerCard({
    super.key,
    required this.selectedDates,
    required this.onDatesSelected,
  });

  @override
  Widget build(BuildContext context) {
    final dates = selectedDates;
    final int dayCount = dates == null
        ? 0
        : dates.end.difference(dates.start).inDays;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dates',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2025),
              lastDate: DateTime(2030),
              initialDateRange: selectedDates,
            );
            if (picked != null) {
              onDatesSelected(picked);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dates == null
                        ? 'Select your dates'
                        : '${dates.start.day} ${months[dates.start.month - 1]} - '
                            '${dates.end.day} ${months[dates.end.month - 1]} '
                            '${dates.end.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: dates == null ? AppTheme.textMuted : AppTheme.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (dates != null)
                  Text(
                    '($dayCount days)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _showSuggestions(context),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Suggest dates from my leave'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGreen),
          ),
        ),
      ],
    );
  }

  Future<void> _showSuggestions(BuildContext context) async {
    final picked = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _LeaveSuggestionsSheet(),
    );
    if (picked != null) onDatesSelected(picked);
  }
}

/// Best breaks from the person's own leave balance, calendar and public holidays (the Leave Optimizer).
class _LeaveSuggestionsSheet extends StatefulWidget {
  const _LeaveSuggestionsSheet();

  @override
  State<_LeaveSuggestionsSheet> createState() => _LeaveSuggestionsSheetState();
}

class _LeaveSuggestionsSheetState extends State<_LeaveSuggestionsSheet> {
  late Future<List<LeaveCombo>> _future = _load();

  Future<List<LeaveCombo>> _load() async {
    final service = LeaveService();
    final now = DateTime.now();
    final months = [for (var i = 0; i < 5; i++) DateTime(now.year, now.month + i)];
    final lists = await Future.wait(
      months.map((m) => service.getLeaveCombos(year: m.year, month: m.month).catchError((_) => <LeaveCombo>[])),
    );
    final seen = <String>{};
    final all = <LeaveCombo>[];
    for (final list in lists) {
      for (final c in list) {
        if (c.startDate != null && c.endDate != null && seen.add(c.id)) all.add(c);
      }
    }
    all.sort((a, b) => a.startDate!.compareTo(b.startDate!));
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return SizedBox(
      height: height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Suggested dates',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Text(
              'The longest breaks for the fewest leave days, from your own leave balance, calendar and public holidays.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<LeaveCombo>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primaryGreen),
                          SizedBox(height: 12),
                          Text('Finding your best breaks...', style: TextStyle(color: AppTheme.textMuted)),
                        ],
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: () => setState(() => _future = _load()),
                        child: const Text("Couldn't load suggestions. Tap to try again."),
                      ),
                    );
                  }
                  final combos = snap.data ?? const <LeaveCombo>[];
                  if (combos.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No good breaks found in the next months. You can still pick your own dates.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: combos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = combos[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(context, DateTimeRange(start: c.startDate!, end: c.endDate!)),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.dateRange,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                    ),
                                  ),
                                  Text(
                                    '${c.daysOff} days off',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${c.leaveDaysUsed} leave day${c.leaveDaysUsed == 1 ? '' : 's'} · ${c.returnMultiplier}',
                                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                              ),
                              if (c.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(c.description, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
