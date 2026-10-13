import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/group_planning_service.dart';

/// The activities the group shared and voted for. The host ticks the ones that
/// go into the itinerary; everyone else can see the ranking and the ticks.
/// If nothing is ticked the AI chooses places itself. Returns true if saved.
Future<bool?> showGroupActivitiesSheet(
  BuildContext context, {
  required String tripId,
  required bool canDecide,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ActivitiesSheet(tripId: tripId, canDecide: canDecide),
  );
}

class _ActivitiesSheet extends StatefulWidget {
  const _ActivitiesSheet({required this.tripId, required this.canDecide});
  final String tripId;
  final bool canDecide;

  @override
  State<_ActivitiesSheet> createState() => _ActivitiesSheetState();
}

class _ActivitiesSheetState extends State<_ActivitiesSheet> {
  final _service = GroupPlanningService();
  List<Map<String, dynamic>> _items = [];
  final Set<String> _picked = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _service.getActivities(widget.tripId);
      if (!mounted) return;
      final items = (r['activities'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _items = items;
        _picked
          ..clear()
          ..addAll([
            for (final i in items)
              if (i['picked'] == true) i['id'] as String,
          ]);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "Couldn't load the activities.";
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.setActivities(widget.tripId, _picked.toList());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save. Try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return SizedBox(
      height: height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Activities',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            Text(
              widget.canDecide
                  ? 'Places your group shared, most votes first. Tick the ones '
                        'to put in the itinerary. If you tick none, the AI '
                        'chooses for you.'
                  : 'Places your group shared, most votes first. The host '
                        'ticks the ones that go into the itinerary.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : _items.isEmpty
                  ? Center(
                      child: Text(
                        _error ??
                            'Nothing shared yet.\nFavourite an attraction in '
                                'Suggestions, then tap "Share to group".',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _row(_items[i]),
                    ),
            ),
            if (_error != null && _items.isNotEmpty)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (widget.canDecide) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : _picked.isEmpty
                        ? 'Save (AI will choose)'
                        : 'Save ${_picked.length} selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> s) {
    final id = s['id'] as String;
    final on = _picked.contains(id);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: widget.canDecide
          ? () => setState(() => on ? _picked.remove(id) : _picked.add(id))
          : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on ? AppTheme.primaryGreen : Colors.grey.shade300,
            width: on ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              on ? Icons.check_box : Icons.check_box_outline_blank,
              color: widget.canDecide || on
                  ? AppTheme.primaryGreen
                  : Colors.grey.shade400,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s['title']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if ('${s['subtitle']}'.isNotEmpty)
                    Text(
                      '${s['subtitle']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  Text(
                    '${s['votes']} vote${s['votes'] == 1 ? '' : 's'} · shared by ${s['sharedBy']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
