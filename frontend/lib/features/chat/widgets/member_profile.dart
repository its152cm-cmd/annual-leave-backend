import 'member_taste_card.dart';
import 'member_comfort_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homempage/features/home/leave_optimizer/widgets/leave_calendar_card.dart';
import 'package:homempage/models/leave_status.dart';

import 'dart:math' as math;

import '../../../../core/theme/app_theme.dart';
import '../../../models/group_member.dart';
import '../../../models/leave_data.dart';
import '../../../services/group_planning_service.dart';
import '../../../services/group_summary_service.dart';
import '../../../services/trip_service.dart';
import '../../../services/leave_service.dart';

class MemberProfileModal extends StatelessWidget {
  final GroupMember member;
  final VoidCallback? onMemberUpdated;

  const MemberProfileModal({
    super.key,
    required this.member,
    this.onMemberUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = member.avatarUrl;
    final ImageProvider? avatarImage = avatarUrl == null
        ? null
        : avatarUrl.startsWith('assets/')
        ? AssetImage(avatarUrl)
        : NetworkImage(avatarUrl);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                backgroundImage: avatarImage,
                child: avatarUrl == null
                    ? Text(
                        member.name.isNotEmpty ? member.name[0] : '',
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  Text(
                    'Synced with Leave Optimizer',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          MemberProfileCardWidget(
            member: member,
            onMemberUpdated: onMemberUpdated,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class MemberProfileCardWidget extends StatefulWidget {
  final GroupMember member;
  final VoidCallback? onMemberUpdated;
  final String groupId;

  const MemberProfileCardWidget({
    super.key,
    required this.member,
    this.onMemberUpdated,
    this.groupId = '',
  });

  @override
  State<MemberProfileCardWidget> createState() =>
      _MemberProfileCardWidgetState();
}

class _MemberProfileCardWidgetState extends State<MemberProfileCardWidget> {
  final LeaveService _leaveService = LeaveService();
  final GroupSummaryService _summaryService = GroupSummaryService();

  late RangeValues _budgetRange;
  late List<String> _preferences;
  late DateTime _calendarMonth;
  late final TextEditingController _minimumBudgetController;
  late final TextEditingController _maximumBudgetController;
  bool _isEditingBudget = false;
  LeaveData? _leaveData;
  bool _isLoadingLeave = true;
  final GroupPlanningService _planning = GroupPlanningService();
  bool _budgetEntered = true;

  String? get _tripId => GroupPlanningService.tripIdFor(widget.groupId);

  /// Real groups: the budget shown here is the one saved for this person
  /// (the same numbers that make up the group budget in Planning status).
  Future<void> _loadBudget() async {
    final tripId = _tripId;
    if (tripId == null) return;
    try {
      final state = await _planning.getBudget(tripId);
      final entry = (state['members'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) => m['id'] == widget.member.id)
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        if (entry != null && entry['min'] != null) {
          _budgetEntered = true;
          _budgetRange = RangeValues(
            (entry['min'] as num).toDouble(),
            (entry['max'] as num).toDouble(),
          );
        } else {
          _budgetEntered = false;
        }
        _minimumBudgetController.text = _budgetEntered
            ? _budgetRange.start.round().toString()
            : '';
        _maximumBudgetController.text = _budgetEntered
            ? _budgetRange.end.round().toString()
            : '';
      });
    } catch (_) {}
  }

  Future<void> _loadPreferences() async {
    final tripId = _tripId;
    if (tripId == null) return;
    try {
      final state = await _planning.getPreferences(tripId);
      final entry = (state['members'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) => m['id'] == widget.member.id)
          .firstOrNull;
      if (!mounted || entry == null) return;
      setState(() {
        _preferences = List<String>.from(
          (entry['preferences'] as List? ?? const []).map((e) => '$e'),
        );
      });
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    final tripId = _tripId;
    if (tripId == null) {
      _summaryService.updateMemberPreferences(
        memberId: widget.member.id,
        preferences: _preferences,
      );
      return;
    }
    try {
      await _planning.setPreferences(tripId, _preferences);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save preference: $error')),
        );
      }
    }
  }

  String? get _leaveDataMemberId =>
      widget.member.isMe ? null : widget.member.id;

  @override
  void didUpdateWidget(covariant MemberProfileCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final memberIdentityChanged = oldWidget.member.id != widget.member.id;
    final memberBudgetChanged =
        memberIdentityChanged ||
        oldWidget.member.minBudget != widget.member.minBudget ||
        oldWidget.member.maxBudget != widget.member.maxBudget;
    if (memberIdentityChanged) {
      _isEditingBudget = false;
      _preferences = List.from(widget.member.preferences);
      _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
      _loadLeaveData(year: _calendarMonth.year);
      _loadBudget();
      _loadPreferences();
    }
    if (memberBudgetChanged && !_isEditingBudget) {
      _budgetRange = RangeValues(
        widget.member.minBudget,
        widget.member.maxBudget,
      );
      _minimumBudgetController.text = _budgetRange.start.round().toString();
      _maximumBudgetController.text = _budgetRange.end.round().toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _budgetRange = RangeValues(
      widget.member.minBudget,
      widget.member.maxBudget,
    );
    _minimumBudgetController = TextEditingController(
      text: _budgetRange.start.round().toString(),
    );
    _maximumBudgetController = TextEditingController(
      text: _budgetRange.end.round().toString(),
    );
    _preferences = List.from(widget.member.preferences);
    _budgetEntered = _tripId == null;
    // The calendar opens on the current month.
    _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadLeaveData(year: _calendarMonth.year);
    _loadBudget();
    _loadPreferences();
  }

  @override
  void dispose() {
    _minimumBudgetController.dispose();
    _maximumBudgetController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaveData({required int year}) async {
    // Only your own calendar is ever shown.
    if (!widget.member.isMe) {
      if (mounted) setState(() => _isLoadingLeave = false);
      return;
    }
    if (mounted) setState(() => _isLoadingLeave = true);
    final memberId = _leaveDataMemberId;
    final leaveData = await _leaveService.getUserLeaveData(
      year: year,
      memberId: memberId,
    );
    if (mounted && memberId == _leaveDataMemberId) {
      setState(() {
        _leaveData = leaveData;
        _isLoadingLeave = false;
      });
    }
  }

  Future<void> _changeCalendarMonth(int year, int monthIndex) async {
    final month = DateTime(year, monthIndex + 1);
    setState(() => _calendarMonth = month);
    if (_leaveData?.selectedYear != year) {
      await _loadLeaveData(year: year);
    }
  }

  Future<void> _showLeaveStatusPicker(DateTime date) async {
    if (!widget.member.isMe) return;
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final currentStatus =
        _leaveData?.dateStatuses[dateKey] ?? DateStatus.normal;
    if (currentStatus == DateStatus.holiday &&
        !(_leaveData?.holidayDates.contains(dateKey) ?? false)) {
      return;
    }

    final status = await showModalBottomSheet<DateStatus>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusTile(
              context,
              dateKey,
              'Busy',
              DateStatus.busy,
            ),
            _statusTile(
              context,
              dateKey,
              'Normal',
              DateStatus.normal,
            ),
            _statusTile(
              context,
              dateKey,
              'Leave Taken',
              DateStatus.annualLeave,
            ),
          ],
        ),
      ),
    );
    if (status == null) return;

    final updated = await _leaveService.updateDateStatus(
      dateKey,
      status,
      memberId: _leaveDataMemberId,
    );
    if (!updated || !mounted) return;
    await _loadLeaveData(year: date.year);
  }

  Widget _statusTile(
    BuildContext context,
    String dateKey,
    String label,
    DateStatus status,
  ) => ListTile(
    title: Text(label),
    trailing: _leaveData?.dateStatuses[dateKey] == status
        ? const Icon(Icons.check, color: AppTheme.primaryGreen)
        : null,
    onTap: () => Navigator.pop(context, status),
  );

  void _startBudgetEdit() {
    if (!widget.member.isMe) return;
    _minimumBudgetController.text = _budgetRange.start.round().toString();
    _maximumBudgetController.text = _budgetRange.end.round().toString();
    setState(() => _isEditingBudget = true);
  }

  void _cancelBudgetEdit() {
    _minimumBudgetController.text = _budgetRange.start.round().toString();
    _maximumBudgetController.text = _budgetRange.end.round().toString();
    setState(() => _isEditingBudget = false);
  }

  Future<void> _saveBudgetEdit() async {
    final minimum = int.tryParse(_minimumBudgetController.text);
    final maximum = int.tryParse(_maximumBudgetController.text);
    if (minimum == null || maximum == null || maximum < minimum) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid minimum and maximum budget.')),
      );
      return;
    }

    final updated = RangeValues(minimum.toDouble(), maximum.toDouble());
    final tripId = _tripId;
    if (tripId != null) {
      try {
        await _planning.setBudget(tripId, updated.start, updated.end);
        TripService.tripListRevision.value++; // refresh Planning status
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save your budget.')),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _budgetRange = RangeValues(
          math.min(updated.start, updated.end),
          math.max(updated.start, updated.end),
        );
        _budgetEntered = true;
        _isEditingBudget = false;
      });
      widget.onMemberUpdated?.call();
      return;
    }
    final saved = await _summaryService.updateMemberBudget(
      memberId: widget.member.id,
      minBudget: updated.start,
      maxBudget: updated.end,
    );
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update the trip budget.')),
      );
      return;
    }

    setState(() {
      _budgetRange = updated;
      _isEditingBudget = false;
    });
    widget.onMemberUpdated?.call();
  }

  void _addPreferenceDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Preference'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Vegetarian only, Morning start',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  _preferences.add(text);
                });
                _savePreferences();
                widget.onMemberUpdated?.call();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _removePreference(String item) {
    if (!widget.member.isMe) return;
    setState(() {
      _preferences.remove(item);
    });
    _savePreferences();
    widget.onMemberUpdated?.call();
  }

  @override
  Widget build(BuildContext context) {
    final minVal = _budgetRange.start.round();
    final maxVal = _budgetRange.end.round();
    final leaveBalanceLabel = widget.member.isMe
        ? (_leaveData == null
              ? widget.member.leaveBalanceSummary
              : '${_leaveData!.leaveBalance} Leave Days Left')
        : widget.member.leaveBalanceSummary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. AVAILABLE DATES: private, only on your own profile.
          if (widget.member.isMe) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'AVAILABLE DATES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF788896),
                    letterSpacing: 0.5,
                  ),
                ),
                Flexible(
                  child: Text(
                    leaveBalanceLabel,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a day you cannot travel and mark it Busy. Only you can see '
              'and edit this; the group dates are worked out from everyone\'s '
              'calendar.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            _isLoadingLeave
                ? const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _buildLeaveOptimizerCalendar(),
            const SizedBox(height: 16),
          ],

          // 2. TRIP BUDGET RANGE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TRIP BUDGET RANGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF788896),
                  letterSpacing: 0.5,
                ),
              ),
              if (!_isEditingBudget)
                InkWell(
                  onTap: widget.member.isMe ? _startBudgetEdit : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      !_budgetEntered
                          ? (widget.member.isMe ? 'Tap to set' : 'Not entered')
                          : 'RM$minVal – RM$maxVal',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_isEditingBudget) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minimumBudgetController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      prefixText: 'RM ',
                      hintText: 'Min',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _maximumBudgetController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      prefixText: 'RM ',
                      hintText: 'Max',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Save budget',
                  visualDensity: VisualDensity.compact,
                  onPressed: _saveBudgetEdit,
                  icon: const Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel editing',
                  visualDensity: VisualDensity.compact,
                  onPressed: _cancelBudgetEdit,
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // 3. PREFERENCES (Editable for 'Ying (You)')
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PREFERENCES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF788896),
                  letterSpacing: 0.5,
                ),
              ),
              if (widget.member.isMe)
                InkWell(
                  onTap: _addPreferenceDialog,
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 14, color: AppTheme.primaryGreen),
                      SizedBox(width: 2),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          ..._preferences.map(
            (pref) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      pref,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.member.isMe)
                    InkWell(
                      onTap: () => _removePreference(pref),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_tripId != null)
            MemberTasteCard(
              tripId: _tripId!,
              memberId: widget.member.id,
              isMe: widget.member.isMe,
            ),
          if (_tripId != null)
            MemberComfortCard(
              tripId: _tripId!,
              memberId: widget.member.id,
              isMe: widget.member.isMe,
            ),
        ],
      ),
    );
  }

  Widget _buildLeaveOptimizerCalendar() {
    return LeaveCalendarCard(
      selectedYear: _calendarMonth.year,
      currentMonthIndex: _calendarMonth.month - 1,
      dateStatuses: _leaveData?.dateStatuses ?? const {},
      holidayDates: _leaveData?.holidayDates ?? const {},
      selectedDateRange: null,
      onDateTap: _showLeaveStatusPicker,
      onMonthChanged: _changeCalendarMonth,
      showLegend: false,
    );
  }
}
