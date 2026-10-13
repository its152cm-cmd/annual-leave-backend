import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/group_planning_service.dart';

/// Food habits and hotel star preference of one member for this group trip.
/// Everyone sets their own; the suggestions each person sees follow their own choices.
class MemberTasteCard extends StatefulWidget {
  const MemberTasteCard({
    super.key,
    required this.tripId,
    required this.memberId,
    required this.isMe,
  });

  final String tripId;
  final String memberId;
  final bool isMe;

  @override
  State<MemberTasteCard> createState() => _MemberTasteCardState();
}

class _MemberTasteCardState extends State<MemberTasteCard> {
  static const _habits = ['Vegetarian', 'Vegan', 'Halal', 'Gluten-Free', 'No Seafood'];
  static const _stars = [0, 3, 4, 5];

  final GroupPlanningService _planning = GroupPlanningService();
  List<String> _dietary = [];
  int _hotelStars = 0;
  bool _custom = false;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MemberTasteCard old) {
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
      _dietary = List<String>.from(entry?['dietary'] as List? ?? const []);
      _hotelStars = (entry?['hotel_stars'] as num?)?.toInt() ?? 0;
      _custom = entry?['custom'] == true;
      _loaded = true;
      _error = null;
    });
  }

  Future<void> _load() async {
    try {
      _apply(await _planning.getTaste(widget.tripId));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load food and hotel settings.');
    }
  }

  Future<void> _save({List<String>? dietary, int? stars}) async {
    try {
      _apply(await _planning.setTaste(widget.tripId, dietary: dietary, hotelStars: stars));
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not save.');
    }
  }

  Future<void> _reset() async {
    try {
      _apply(await _planning.resetTaste(widget.tripId));
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not reset.');
    }
  }

  static const _label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: Color(0xFF788896),
    letterSpacing: 0.5,
  );

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(_error ?? 'Loading...', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('FOOD HABITS', style: _label),
            if (widget.isMe && _custom)
              InkWell(
                onTap: _reset,
                child: const Text('Use my account settings', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.isMe)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final h in _habits)
                FilterChip(
                  label: Text(h),
                  selected: _dietary.contains(h),
                  showCheckmark: false,
                  selectedColor: AppTheme.primaryGreen,
                  backgroundColor: AppTheme.cardBackground,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _dietary.contains(h) ? Colors.white : AppTheme.textDark,
                  ),
                  onSelected: (on) => _save(
                    dietary: on ? [..._dietary, h] : _dietary.where((x) => x != h).toList(),
                  ),
                ),
            ],
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_dietary.isEmpty) _pill('No special food habits') else for (final h in _dietary) _pill(h),
            ],
          ),
        const SizedBox(height: 14),
        const Text('HOTEL STARS', style: _label),
        const SizedBox(height: 8),
        if (widget.isMe)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final s in _stars)
                ChoiceChip(
                  label: Text(s == 0 ? 'Any' : '$s ★'),
                  selected: _hotelStars == s,
                  showCheckmark: false,
                  selectedColor: AppTheme.primaryGreen,
                  backgroundColor: AppTheme.cardBackground,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _hotelStars == s ? Colors.white : AppTheme.textDark,
                  ),
                  onSelected: (_) => _save(stars: s),
                ),
            ],
          )
        else
          Wrap(children: [_pill(_hotelStars == 0 ? 'Any hotel' : '$_hotelStars-star hotels')]),
        if (widget.isMe)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Suggestions you see follow your own choices. They start from your account settings.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!, style: const TextStyle(fontSize: 11, color: Color(0xFFD70015))),
          ),
      ],
    );
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppTheme.surfaceSecondary, borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      );
}
