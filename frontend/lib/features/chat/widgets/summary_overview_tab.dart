import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/group_trip_summary.dart';
import '../../../services/expense_service.dart';
import 'destination_picker_sheet.dart';
import 'group_dates_sheet.dart';
import 'group_budget_sheet.dart';
import 'group_decision_sheet.dart';
import 'group_activities_sheet.dart';
import '../../../services/group_planning_service.dart';

class SummaryOverviewTab extends StatelessWidget {
  final GroupTripSummary tripSummary;
  final ValueChanged<String> onSelectPendingDecision;
  final VoidCallback onTagsUpdated;
  final Function(String key, String newValue) onConfirmedDetailUpdated;
  final String groupId;
  final bool isHost;
  final VoidCallback? onNeedsRefresh;

  const SummaryOverviewTab({
    super.key,
    required this.tripSummary,
    required this.onSelectPendingDecision,
    required this.onTagsUpdated,
    required this.onConfirmedDetailUpdated,
    this.groupId = '',
    this.isHost = true,
    this.onNeedsRefresh,
  });

  IconData _getCategoryIcon(String key) {
    final lowerKey = key.toLowerCase();
    if (lowerKey.contains('budget')) return Icons.account_balance_wallet_outlined;
    if (lowerKey.contains('accommodation') || lowerKey.contains('hotel')) {
      return Icons.hotel_outlined;
    }
    if (lowerKey.contains('flight')) return Icons.flight_takeoff_outlined;
    if (lowerKey.contains('destination')) return Icons.location_on_outlined;
    if (lowerKey.contains('date')) return Icons.calendar_today_outlined;
    if (lowerKey.contains('duration')) return Icons.schedule_outlined;
    if (lowerKey.contains('transport')) return Icons.directions_bus_outlined;
    if (lowerKey.contains('activit')) return Icons.local_activity_outlined;
    if (lowerKey.contains('friend') ||
        lowerKey.contains('traveller') ||
        lowerKey.contains('traveler')) {
      return Icons.people_outline;
    }
    return Icons.check_circle_outline;
  }

  String _budgetKey(GroupTripSummary summary) {
    for (final key in summary.confirmedDetails.keys) {
      if (key.toLowerCase().contains('budget')) return key;
    }
    return 'Budget';
  }

  void _showEditDetailSheet(
    BuildContext context,
    String key,
    String currentValue,
  ) {
    final TextEditingController controller = TextEditingController(
      text: currentValue,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit $key',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Confirmed $key',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final newValue = controller.text.trim();
                    if (newValue.isNotEmpty) {
                      onConfirmedDetailUpdated(key, newValue);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditBudgetSheet(
    BuildContext context,
    String key,
    String currentValue,
  ) {
    final values = RegExp(r'\d+(?:\.\d+)?')
        .allMatches(currentValue.replaceAll(',', ''))
        .map((match) => match.group(0)!)
        .toList();
    final minController = TextEditingController(
      text: values.isNotEmpty ? values.first : '',
    );
    final maxController = TextEditingController(
      text: values.length > 1 ? values[1] : '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Budget Range',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Minimum (RM)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: maxController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Maximum (RM)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final minimum = double.tryParse(minController.text.trim());
                  final maximum = double.tryParse(maxController.text.trim());
                  if (minimum == null ||
                      maximum == null ||
                      minimum < 0 ||
                      maximum < minimum) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid minimum and maximum.'),
                      ),
                    );
                    return;
                  }
                  String formatAmount(double amount) =>
                      amount == amount.truncateToDouble()
                          ? amount.toStringAsFixed(0)
                          : amount.toStringAsFixed(2);
                  onConfirmedDetailUpdated(
                    key,
                    'RM${formatAmount(minimum)} - RM${formatAmount(maximum)}',
                  );
                  Navigator.pop(sheetContext);
                },
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      minController.dispose();
      maxController.dispose();
    });
  }

  Future<void> _showPreferenceDialog(
    BuildContext context,
    List<String> tags, {
    String? existingTag,
  }) async {
    final controller = TextEditingController(text: existingTag ?? '');
    final preference = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existingTag == null ? 'Add Preference' : 'Edit Preference'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Enter a preference',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (preference == null || preference.isEmpty) return;

    if (existingTag == null) {
      tags.add(preference);
    } else {
      final index = tags.indexOf(existingTag);
      if (index != -1) tags[index] = preference;
    }
    onTagsUpdated();
  }

  @override
  Widget build(BuildContext context) {
    final planningKeys = [
      'Accommodation',
      'Transport',
      'Destination',
      'Dates',
      'Traveller',
      'Budget',
      if (GroupPlanningService.tripIdFor(groupId) != null) 'Activities',
    ];
    final pendingDecisionCount = tripSummary.pendingDecisions.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. Planning Status Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Planning status',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pendingDecisionCount TO DECIDE',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'You may leave these blank if you have no ideas regarding the attractions or hotels. Our AI will assist you with suggestions.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),

          // B. Status grid: every card (pending or confirmed) shares one
          // fixed height and the same two-column layout.
          GridView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: _StatusTile.height,
            ),
            children: planningKeys.map((key) {
              final value = key == 'Budget'
                  ? (tripSummary.budget.trim().isEmpty
                        ? 'Needs decision'
                        : tripSummary.budget)
                  : tripSummary.confirmedDetails[key] ?? '';
              final isStatus = const {'Accommodation', 'Transport', 'Budget'}
                  .contains(key);
              final isPending = value == 'Needs decision';
              VoidCallback onTap;
              final tripId = GroupPlanningService.tripIdFor(groupId);
              final real = tripId != null;
              final hostOnly = const {
                'Destination',
                'Dates',
                'Accommodation',
                'Transport',
                'Activities',
              }.contains(key);
              void hostMessage() =>
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Only the host can change this.'),
                    ),
                  );
              if (key == 'Budget' && tripId != null) {
                onTap = () async {
                  final saved = await showGroupBudgetSheet(
                    context,
                    tripId: tripId,
                  );
                  if (saved == true) onNeedsRefresh?.call();
                };
              } else if (key == 'Activities' && tripId != null) {
                onTap = () async {
                  final changed = await showGroupActivitiesSheet(
                    context,
                    tripId: tripId,
                    canDecide: isHost,
                  );
                  if (changed == true) onNeedsRefresh?.call();
                };
              } else if ((key == 'Accommodation' || key == 'Transport') &&
                  tripId != null) {
                onTap = () async {
                  final changed = await showGroupDecisionSheet(
                    context,
                    tripId: tripId,
                    decision: key,
                    canDecide: isHost,
                  );
                  if (changed == true) onNeedsRefresh?.call();
                };
              } else if (real && !isHost && hostOnly) {
                onTap = hostMessage;
              } else if (key == 'Budget') {
                onTap = () => _showEditBudgetSheet(
                  context,
                  _budgetKey(tripSummary),
                  tripSummary.budget,
                );
              } else if (key == 'Accommodation' || key == 'Transport') {
                onTap = () => onSelectPendingDecision(key);
              } else if (key == 'Traveller') {
                onTap = () {};
              } else if (key == 'Destination') {
                onTap = () async {
                  final result = await showDestinationPicker(
                    context,
                    current: value == 'To be decided' ? '' : value,
                  );
                  if (result != null && result.isNotEmpty) {
                    onConfirmedDetailUpdated('Destination', result);
                  }
                };
              } else if (key == 'Dates' &&
                  ExpenseService.isSavedGroup(groupId)) {
                onTap = () async {
                  final result = await showGroupDatesSheet(
                    context,
                    tripId: groupId.substring('trip_'.length),
                  );
                  if (result != null && result.isNotEmpty) {
                    onConfirmedDetailUpdated('Dates', result);
                  }
                };
              } else {
                onTap = () => _showEditDetailSheet(context, key, value);
              }
              return _StatusTile(
                kind: isStatus && isPending
                    ? _TileKind.pending
                    : _TileKind.confirmed,
                icon: isPending ? Icons.help_outline : _getCategoryIcon(key),
                label: key == 'Accommodation' ? 'Hotel' : key,
                // "AI will suggest / choose" is not shown: a blank card simply means the AI will help
                value: (value == 'AI will suggest' || value == 'AI will choose') ? '' : value,
                onTap: onTap,
                fitValue: key == 'Dates',
                editable: key != 'Traveller' &&
                    !(real && key == 'Budget') &&
                    (!real || isHost || !hostOnly),
              );
            }).toList(),
          ),

          const SizedBox(height: 22),

          // C. Group Preferences (sits directly under the status grid)
          const Text(
            'Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),

          if (GroupPlanningService.tripIdFor(groupId) != null) ...[
            // Real groups: these are everyone's own preferences combined. Each
            // person edits theirs under Trip Members.
            if (tripSummary.preferenceTags.isEmpty)
              const Text(
                'Nobody has added preferences yet. Add yours under Trip Members.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tripSummary.preferenceTags)
                    Chip(
                      label: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: AppTheme.cardBackground,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                ],
              ),
          ] else
            _buildEditablePreferences(context, tripSummary.preferenceTags),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEditablePreferences(BuildContext context, List<String> tags) {
    const chipShape = StadiumBorder();
    const chipBorder = BorderSide(color: AppTheme.borderSubtle);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
          ...tags.map(
          (tag) => InputChip(
            label: Text(
              tag,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppTheme.cardBackground,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: chipShape,
            side: chipBorder,
            onPressed: () => _showPreferenceDialog(
              context,
              tags,
              existingTag: tag,
            ),
            onDeleted: () {
              tags.remove(tag);
              onTagsUpdated();
            },
            deleteIcon: const Icon(
              Icons.close,
              size: 16,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 16, color: AppTheme.primaryGreen),
          label: const Text(
            'Add',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.cardBackground,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: chipShape,
          side: chipBorder,
          onPressed: () => _showPreferenceDialog(context, tags),
        ),
      ],
    );
  }
}

enum _TileKind { pending, confirmed }

/// One compact card in the planning-status grid.
///
/// Pending and confirmed items use the exact same layout and height
/// ([height]); only the colours and the status line differ.
class _StatusTile extends StatelessWidget {
  static const double height = 60;

  final _TileKind kind;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool fitValue;
  final bool editable;

  const _StatusTile({
    required this.kind,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.fitValue = false,
    this.editable = true,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = kind == _TileKind.pending;

    final Color background = isPending
        ? const Color(0xFFFFF8E1)
        : const Color(0xFFE8F5E9);
    final Color border = isPending
        ? const Color(0xFFFFE082)
        : const Color(0xFFA5D6A7);
    final Color accent = isPending
        ? const Color(0xFFC79100)
        : AppTheme.primaryGreen;
    final Color valueColor = isPending
        ? const Color(0xFF9A6B00)
        : AppTheme.textDark;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                        if (!isPending && editable)
                          Icon(Icons.edit_outlined, size: 12, color: accent),
                      ],
                    ),
                    const SizedBox(height: 2),
                    fitValue
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: valueColor,
                              ),
                            ),
                          )
                        : Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: valueColor,
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
