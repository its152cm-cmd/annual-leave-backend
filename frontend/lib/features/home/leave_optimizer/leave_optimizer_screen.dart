import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

import 'package:homempage/models/leave_status.dart';

import '../../../models/leave_combo.dart';
import '../../../services/leave_service.dart';
import 'widgets/leave_combo_card.dart';

import 'package:homempage/features/home/leave_optimizer/widgets/leave_calendar_card.dart';

class LeaveOptimizerScreen extends StatefulWidget {
  const LeaveOptimizerScreen({super.key});

  @override
  State<LeaveOptimizerScreen> createState() => _LeaveOptimizerScreenState();
}

class _LeaveOptimizerScreenState extends State<LeaveOptimizerScreen> {
  final LeaveService _leaveService = LeaveService();
  late Future<List<LeaveCombo>> _leaveCombosFuture;

  bool _isLoading = true;

  // Dynamic initial date instead of hardcoded values
  int _selectedYear = DateTime.now().year;
  int _currentMonthIndex = DateTime.now().month - 1;

  int _leaveBalance = 0;
  Map<String, DateStatus> _dateStatuses = {};
  Set<String> _holidayDates = {};

  final List<String> _months = [
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

  late final List<int> _availableYears;

  @override
  void initState() {
    super.initState();

    // Automatically generate a year range around the current year
    final currentYear = DateTime.now().year;

    _availableYears = List.generate(5, (index) => currentYear - 2 + index);

    _loadInitialData();
  }

  /// 1. Dynamic Initial Load & Refetch Function
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final leaveData = await _leaveService.getUserLeaveData(
        year: _selectedYear,
      );

      _leaveCombosFuture = _leaveService.getLeaveCombos(
        year: _selectedYear,
        month: _currentMonthIndex + 1,
      );

      if (mounted) {
        setState(() {
          _selectedYear = leaveData.selectedYear;
          _leaveBalance = leaveData.leaveBalance;
          _dateStatuses = leaveData.dateStatuses;
          _holidayDates = leaveData.holidayDates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load leave data: $e')),
        );
      }
    }
  }

  /// 2. Reload Combos when Month or Year changes
  void _onMonthOrYearChanged() {
    setState(() {
      _leaveCombosFuture = _leaveService.getLeaveCombos(
        year: _selectedYear,
        month: _currentMonthIndex + 1,
      );
    });
  }

  void _onCalendarMonthChanged(int year, int monthIndex) {
    if (year == _selectedYear) {
      setState(() => _currentMonthIndex = monthIndex);
      _onMonthOrYearChanged();
    } else if (_availableYears.contains(year)) {
      setState(() {
        _selectedYear = year;
        _currentMonthIndex = monthIndex;
      });
      _loadInitialData();
    }
  }

  void _showLeaveBalanceDialog() {
    final controller = TextEditingController(text: _leaveBalance.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Annual Leave'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Total Leave Days Remaining',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            onPressed: () async {
              final val = int.tryParse(controller.text);

              if (val != null) {
                setState(() => _leaveBalance = val);
                await _leaveService.updateLeaveBalance(
                  val,
                  year: _selectedYear,
                );
              }

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(color: AppTheme.backgroundWhite),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusPickerBottomSheet(DateTime date) {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final currentStatus = _dateStatuses[dateKey] ?? DateStatus.normal;

    // Public Holidays are system-provided and cannot be directly modified by the user
    if (currentStatus == DateStatus.holiday &&
        !_holidayDates.contains(dateKey)) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppTheme.statusHolidayBg,
                    radius: 12,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_months[date.month - 1]} ${date.day}, ${date.year}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'This day is an official Public Holiday. Public holidays are retrieved automatically and cannot be modified manually.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: AppTheme.backgroundWhite),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Interactive picker for user-editable statuses
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set Status for ${_months[date.month - 1]} ${date.day}, ${date.year}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_holidayDates.contains(dateKey)) ...[
              const SizedBox(height: 8),
              const Text(
                'This is a public holiday. It stays marked, and any tag you add here is shown on top of it (for example if your company works on this day).',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ],
            const SizedBox(height: 16),
            _buildStatusOption(
              context,
              dateKey,
              'Busy',
              DateStatus.busy,
              AppTheme.statusBusyBg,
              currentStatus,
            ),
            _buildStatusOption(
              context,
              dateKey,
              'Normal',
              DateStatus.normal,
              AppTheme.cardBackground,
              currentStatus,
            ),
            _buildStatusOption(
              context,
              dateKey,
              'Leave Taken',
              DateStatus.annualLeave,
              AppTheme.statusAnnualLeaveBg,
              currentStatus,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    BuildContext context,
    String dateKey,
    String label,
    DateStatus status,
    Color color,
    DateStatus selectedStatus,
  ) {
    final isSelected = status == selectedStatus;

    return ListTile(
      leading: CircleAvatar(backgroundColor: color, radius: 12),
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppTheme.primaryGreen)
          : null,
      onTap: () async {
        final previousStatus = _dateStatuses[dateKey];

        // Optimistic UI Update
        setState(() {
          if (status == DateStatus.normal) {
            if (_holidayDates.contains(dateKey)) {
              _dateStatuses[dateKey] = DateStatus.holiday;
            } else {
              _dateStatuses.remove(dateKey);
            }
          } else {
            _dateStatuses[dateKey] = status;
          }
        });

        Navigator.pop(context);

        // Send to backend API
        final success = await _leaveService.updateDateStatus(dateKey, status);

        // Rollback if sync fails
        if (!success && mounted) {
          setState(() {
            if (previousStatus != null) {
              _dateStatuses[dateKey] = previousStatus;
            } else {
              _dateStatuses.remove(dateKey);
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update date status on backend'),
            ),
          );
        } else {
          // Re-evaluate recommendations based on new status
          _onMonthOrYearChanged();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Leave Optimizer',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.textMuted.withValues(alpha: 0.2),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedYear,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                            items: _availableYears.map((int yr) {
                              return DropdownMenuItem<int>(
                                value: yr,
                                child: Text('$yr'),
                              );
                            }).toList(),
                            onChanged: (newYear) {
                              if (newYear != null && newYear != _selectedYear) {
                                setState(() {
                                  _selectedYear = newYear;
                                });

                                _loadInitialData();
                              }
                            },
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _showLeaveBalanceDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.badgeGreenLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$_leaveBalance Days Remaining',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              const Text(
                                'TAP TO EDIT BALANCE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LeaveCalendarCard(
                    selectedYear: _selectedYear,
                    currentMonthIndex: _currentMonthIndex,
                    dateStatuses: _dateStatuses,
                    holidayDates: _holidayDates,
                    onDateTap: _showStatusPickerBottomSheet,
                    onMonthChanged: _onCalendarMonthChanged,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Recommended Leave Combos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<LeaveCombo>>(
                    future: _leaveCombosFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Text(
                              'Unable to fetch recommendations',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Text(
                              'No leave recommendations available for this month.',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          ),
                        );
                      }

                      final combos = snapshot.data!;

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: combos.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return LeaveComboCard.fromModel(combo: combos[index]);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
