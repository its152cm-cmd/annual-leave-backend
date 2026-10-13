import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/group_planning_service.dart';

/// Comfort settings of one member for this group trip. Everyone sets their own; the AI plans
/// the itinerary, chat suggestions and replans around the strictest of the group.
class MemberComfortCard extends StatefulWidget {
  const MemberComfortCard({super.key, required this.tripId, required this.memberId, required this.isMe});

  final String tripId;
  final String memberId;
  final bool isMe;

  @override
  State<MemberComfortCard> createState() => _MemberComfortCardState();
}

class _MemberComfortCardState extends State<MemberComfortCard> {
  final GroupPlanningService _planning = GroupPlanningService();
  Map<String, dynamic>? _mine; // this member's comfort
  Map<String, dynamic>? _group; // strictest of everybody
  bool _custom = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MemberComfortCard old) {
    super.didUpdateWidget(old);
    if (old.memberId != widget.memberId) _load();
  }

  void _apply(Map<String, dynamic> state) {
    final entry = (state['members'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((m) => m['id'] == widget.memberId)
        .firstOrNull;
    if (!mounted) return;
    setState(() {
      _mine = entry == null ? null : Map<String, dynamic>.from(entry['comfort'] as Map);
      _custom = entry?['custom'] == true;
      _group = Map<String, dynamic>.from(state['combined'] as Map);
      _error = null;
    });
  }

  Future<void> _load() async {
    try {
      _apply(await _planning.getComfort(widget.tripId));
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load comfort settings.');
    }
  }

  Future<void> _save(Map<String, Object> changes) async {
    try {
      _apply(await _planning.setComfort(widget.tripId, changes));
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not save.');
    }
  }

  Future<void> _reset() async {
    try {
      _apply(await _planning.resetComfort(widget.tripId));
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not reset.');
    }
  }

  String _rest(int v) => switch (v) { 1 => 'Often (every hour)', 2 => 'Sometimes (every 2 hours)', _ => 'Rarely (every 3 hours)' };

  @override
  Widget build(BuildContext context) {
    final c = _mine;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('COMFORT SETTINGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF788896), letterSpacing: 0.5)),
        if (widget.isMe && _custom)
          InkWell(onTap: _reset, child: const Text('Use my account settings', style: TextStyle(fontSize: 11, color: AppTheme.textMuted))),
      ]),
      const SizedBox(height: 8),
      if (c == null)
        Text(_error ?? 'Loading...', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))
      else if (widget.isMe) ...[
        _slider('Walking between places', '${c['max_walking_minutes']} min', (c['max_walking_minutes'] as num).toDouble(), 5, 30, 25, (v) => _save({'max_walking_minutes': v.round()})),
        _slider('Activities per day', '${c['max_activities_per_day']}', (c['max_activities_per_day'] as num).toDouble(), 1, 8, 7, (v) => _save({'max_activities_per_day': v.round()})),
        _slider('Rest breaks', _rest((c['rest_break_frequency'] as num).toInt()), (c['rest_break_frequency'] as num).toDouble(), 1, 3, 2, (v) => _save({'rest_break_frequency': v.round()})),
        _switch('Step-free, accessible transport only', c['accessible_transport_only'] == true, (v) => _save({'accessible_transport_only': v})),
        _switch('Restrooms nearby', c['nearby_restrooms_priority'] == true, (v) => _save({'nearby_restrooms_priority': v})),
        _switch('Avoid stairs and steep climbs', c['minimize_stairs'] == true, (v) => _save({'minimize_stairs': v})),
      ] else
        Wrap(spacing: 6, runSpacing: 6, children: [
          _pill('Walk ${c['max_walking_minutes']} min'),
          _pill('${c['max_activities_per_day']} activities/day'),
          _pill(_rest((c['rest_break_frequency'] as num).toInt())),
          if (c['accessible_transport_only'] == true) _pill('Step-free transport'),
          if (c['nearby_restrooms_priority'] == true) _pill('Restrooms nearby'),
          if (c['minimize_stairs'] == true) _pill('Avoid stairs'),
        ]),
      if (_group != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.badgeGreenLight, borderRadius: BorderRadius.circular(10)),
          child: Text(
            'The AI plans for the whole group: walk up to ${_group!['max_walking_minutes']} min, '
            '${_group!['max_activities_per_day']} activities a day'
            '${_group!['accessible_transport_only'] == true ? ', step-free transport' : ''}'
            '${_group!['minimize_stairs'] == true ? ', no stairs' : ''}.',
            style: const TextStyle(fontSize: 11, color: AppTheme.textDark),
          ),
        ),
      ],
      if (_error != null && c != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: const TextStyle(fontSize: 11, color: Color(0xFFD70015)))),
    ]);
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppTheme.surfaceSecondary, borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _slider(String label, String value, double v, double min, double max, int divisions, ValueChanged<double> onDone) {
    return StatefulBuilder(builder: (context, setS) {
      var shown = v;
      return StatefulBuilder(builder: (context, setInner) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ]),
          Slider(
            value: shown.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppTheme.primaryGreen,
            onChanged: (x) => setInner(() => shown = x),
            onChangeEnd: onDone,
          ),
        ]);
      });
    });
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        value: value,
        activeThumbColor: AppTheme.primaryGreen,
        onChanged: onChanged,
      );
}
