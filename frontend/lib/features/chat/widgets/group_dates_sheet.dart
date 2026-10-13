import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// Date options for a group trip. They come from every member's own calendar:
/// days people marked busy are avoided, and leave balances are respected.
/// Returns the chosen range (e.g. "12 - 18 December 2026"), or null.
Future<String?> showGroupDatesSheet(
  BuildContext context, {
  required String tripId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _GroupDatesSheet(tripId: tripId),
  );
}

class _GroupDatesSheet extends StatefulWidget {
  const _GroupDatesSheet({required this.tripId});

  final String tripId;

  @override
  State<_GroupDatesSheet> createState() => _GroupDatesSheetState();
}

class _GroupDatesSheetState extends State<_GroupDatesSheet> {
  int? _length; // null = let the Leave Optimizer pick the best lengths
  final TextEditingController _daysController = TextEditingController();
  bool get _typing => _daysController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  void _applyTypedDays(String text) {
    final n = int.tryParse(text.trim());
    if (n == null || n < 1 || n > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a number of days from 1 to 30.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _length = n;
      _future = _load();
    });
  }
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {
    final r = await ApiClient().get(
      '/api/leave/group-dates',
      query: {
        'trip_id': widget.tripId,
        if (_length != null) 'length': _length,
      },
    );
    return Map<String, dynamic>.from(r as Map);
  }

  /// The host picks their own dates; the app then checks them against
  /// everyone's calendar and leave balance and warns about clashes.
  Future<void> _pickOwnDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Pick your trip dates',
    );
    if (picked == null || !mounted) return;
    String ymd(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    Map<String, dynamic> check;
    try {
      final r = await ApiClient().get(
        '/api/leave/group-check',
        query: {
          'trip_id': widget.tripId,
          'start_date': ymd(picked.start),
          'end_date': ymd(picked.end),
        },
      );
      check = Map<String, dynamic>.from(r as Map);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't check those dates (60 days at most).")),
      );
      return;
    }
    if (!mounted) return;
    final use = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final problems = (check['problems'] as List).cast<String>();
        final people = (check['members'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return AlertDialog(
          title: Text('${check['date_range']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${check['days']} days'),
                const SizedBox(height: 8),
                for (final p in people)
                  Text(
                    '${p['name']}: ${p['leave_days_needed']} leave day'
                    '${p['leave_days_needed'] == 1 ? '' : 's'} '
                    '(has ${p['balance']})',
                    style: const TextStyle(fontSize: 13),
                  ),
                const SizedBox(height: 10),
                if (problems.isEmpty)
                  const Text(
                    'Everyone is free and has enough leave.',
                    style: TextStyle(color: AppTheme.primaryGreen),
                  )
                else ...[
                  const Text(
                    'Heads up:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC77700),
                    ),
                  ),
                  for (final pr in problems)
                    Text('• $pr', style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
              ),
              child: Text(
                problems.isEmpty ? 'Use these dates' : 'Use anyway',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
    if (use == true && mounted) {
      Navigator.pop(context, (check['date_range'] ?? '').toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return SizedBox(
      height: height * 0.72,
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Text(
              'The Leave Optimizer suggests dates when everyone is free, using '
              'the fewest leave days. Choose how long you want to go, or pick '
              'your own dates and we will check them for you.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  for (final n in <int?>[null, 3, 4, 5])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(n == null ? 'Best' : '$n days'),
                        selected: _length == n && !_typing,
                        showCheckmark: false,
                        selectedColor: AppTheme.primaryGreen,
                        labelStyle: TextStyle(
                          color: (_length == n && !_typing)
                              ? Colors.white
                              : AppTheme.textDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          _daysController.clear();
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _length = n;
                            _future = _load();
                          });
                        },
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _daysController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'How many days',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _applyTypedDays,
                    ),
                  ),
                  if (_typing)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Find dates',
                      onPressed: () => _applyTypedDays(_daysController.text),
                      icon: const Icon(
                        Icons.search,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickOwnDates,
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('Pick my own dates'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  side: const BorderSide(color: AppTheme.primaryGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                      ),
                    );
                  }
                  if (snap.hasError || snap.data == null) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Couldn't load the date options."),
                          TextButton(
                            onPressed: () =>
                                setState(() => _future = _load()),
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    );
                  }
                  final options = (snap.data!['options'] as List? ?? const [])
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .toList();
                  if (options.isEmpty) {
                    return Center(
                      child: Text(
                        (snap.data!['reason'] ?? 'No dates found.').toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _OptionCard(option: options[index]),
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.option});

  final Map<String, dynamic> option;

  @override
  Widget build(BuildContext context) {
    final people = (option['members'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F9F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (option['date_range'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              Text(
                '${option['days_off']} days',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            (option['description'] ?? '').toString(),
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in people)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${p['name']}: ${p['leave_days_needed']} leave day'
                    '${p['leave_days_needed'] == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, (option['date_range'] ?? '').toString()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Choose these dates',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
