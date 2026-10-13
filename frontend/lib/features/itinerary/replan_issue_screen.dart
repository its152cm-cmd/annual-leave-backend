import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/itinerary.dart';
import '../../models/trip.dart';
import '../../services/itinerary_service.dart';
import '../../services/replan_service.dart';
import 'widgets/place_detail_sheet.dart';

enum _Step { problem, flight, delay, preview, day, item, options }

/// Replan Trip: pick what went wrong, then fix it.
///  - Flight delayed: the day is shifted (you see the changes before saving).
///  - Bad weather / Restaurant closed: pick the day and the stop, then choose a real
///    alternative nearby.
class ReplanIssueScreen extends StatefulWidget {
  const ReplanIssueScreen({super.key, required this.itineraryId, required this.trip});

  final String itineraryId;
  final Trip trip;

  @override
  State<ReplanIssueScreen> createState() => _ReplanIssueScreenState();
}

class _ReplanIssueScreenState extends State<ReplanIssueScreen> {
  final ItineraryService _itineraryService = ItineraryService();
  final ReplanService _replan = ReplanService();

  _Step _step = _Step.problem;
  String _problem = ''; // flight | weather | closed
  bool _loadingContext = true;
  bool _busy = false;
  bool _changed = false;
  String? _error;

  ItineraryOverview? _overview;
  Map<int, List<ItineraryDetailItem>> _itemsByDay = {};

  int? _day;
  ItineraryDetailItem? _item;
  int _delay = 60;
  DelayPlan? _plan;
  final Map<String, int> _moves = {}; // dropped stop id -> day to move it to
  List<ReplanOption> _options = [];
  String _note = '';

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    try {
      ItineraryService.forget(widget.itineraryId);
      final overview = await _itineraryService.getItineraryOverview(widget.itineraryId, trip: widget.trip);
      final lists = await Future.wait(
        overview.days.map((d) => _itineraryService.getDayDetailItems(widget.itineraryId, d.dayNumber)),
      );
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _itemsByDay = {for (var i = 0; i < overview.days.length; i++) overview.days[i].dayNumber: lists[i]};
        _loadingContext = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingContext = false;
        _error = 'Could not load the itinerary.';
      });
    }
  }

  Future<void> _reload() async {
    ItineraryService.forget(widget.itineraryId);
    await _loadContext();
  }

  String _msg(Object e) => e is ApiException ? e.message : 'Something went wrong. Please try again.';

  void _go(_Step s) => setState(() {
        _step = s;
        _error = null;
      });

  void _back() {
    switch (_step) {
      case _Step.problem:
        Navigator.of(context).pop(_changed);
      case _Step.flight:
      case _Step.day:
        _go(_Step.problem);
      case _Step.delay:
        _go(_Step.flight);
      case _Step.preview:
        _go(_Step.delay);
      case _Step.item:
        _go(_Step.day);
      case _Step.options:
        _go(_Step.item);
    }
  }

  // ------------------------------------------------------------ helpers
  int? _mins(String t) {
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false).firstMatch(t);
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final ap = m.group(3)?.toUpperCase();
    if (ap != null) h = h % 12 + (ap == 'PM' ? 12 : 0);
    return h * 60 + int.parse(m.group(2)!);
  }

  String _delayLabel(int m) => m % 60 == 0 ? '${m ~/ 60} hr' : (m < 60 ? '$m min' : '${m ~/ 60} hr ${m % 60} min');

  List<({int day, ItineraryDetailItem item})> get _flights => [
        for (final e in _itemsByDay.entries)
          for (final i in e.value)
            if (i.type.toLowerCase() == 'flight') (day: e.key, item: i),
      ];

  List<ItineraryDetailItem> _affectable(int day) => [
        for (final i in _itemsByDay[day] ?? const <ItineraryDetailItem>[])
          if (_problem == 'closed'
              ? i.type.toLowerCase() == 'food'
              : i.type.toLowerCase() == 'attraction')
            i,
      ];

  // ------------------------------------------------------------ actions
  Future<void> _previewDelay() async {
    setState(() { _busy = true; _error = null; });
    try {
      final plan = await _replan.previewDelay(widget.itineraryId, _day!, _item!.id, _delay);
      if (!mounted) return;
      setState(() { _plan = plan; _moves.clear(); _step = _Step.preview; });
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyDelay() async {
    setState(() { _busy = true; _error = null; });
    try {
      final moved = _moves.length;
      await _replan.applyDelay(widget.itineraryId, _day!, _item!.id, _delay, moves: Map.of(_moves));
      _changed = true;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(moved > 0 ? 'Itinerary updated. $moved stop(s) moved to another day.' : 'Itinerary updated for the delayed flight.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _findOptions() async {
    setState(() { _busy = true; _error = null; _options = []; _note = ''; _step = _Step.options; });
    try {
      final o = await _replan.alternatives(widget.itineraryId, _day!, _item!.id, _problem);
      if (mounted) setState(() { _options = o.options; _note = o.note; });
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _use(ReplanOption o) async {
    setState(() { _busy = true; _error = null; });
    try {
      await _replan.applyAlternative(widget.itineraryId, _day!, _item!.id, o);
      _changed = true;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Replaced with ${o.title}.')));
      setState(() { _step = _Step.item; _item = null; });
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime() async {
    final start = _mins(_item!.timeStart) ?? 8 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: ((start + 60) ~/ 60) % 24, minute: start % 60),
    );
    if (picked == null) return;
    final diff = picked.hour * 60 + picked.minute - start;
    if (diff < 5 || diff > 720) {
      setState(() => _error = 'The new departure must be later than ${_item!.timeStart} (and within 12 hours).');
      return;
    }
    setState(() { _delay = diff; _error = null; });
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_busy) _back();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundWhite,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: [
                IconButton(
                  icon: Icon(_step == _Step.problem ? Icons.close : Icons.arrow_back),
                  onPressed: _busy ? null : _back,
                ),
                const Text('REPLAN TRIP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.6)),
              ]),
            ),
            Expanded(
              child: _loadingContext
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : _overview == null
                      ? Center(child: Text(_error ?? 'Could not load the itinerary.', style: const TextStyle(color: AppTheme.textMuted)))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          children: [..._body(), if (_error != null) _errorBox(_error!)],
                        ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _errorBox(String text) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFFEBEA), borderRadius: BorderRadius.circular(12)),
          child: Text(text, style: const TextStyle(color: Color(0xFFD70015), fontSize: 13)),
        ),
      );

  Widget _title(String t, [String? sub]) => Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(sub, style: const TextStyle(fontSize: 14, color: AppTheme.textMuted))),
        ]),
      );

  List<Widget> _body() {
    switch (_step) {
      case _Step.problem:
        return [
          _title('What happened?', 'Pick the problem and we will fix the plan.'),
          _bigCard(Icons.flight_takeoff, 'Flight delayed', 'Shift the day to match the new flight time', () {
            _problem = 'flight';
            _go(_Step.flight);
          }),
          _bigCard(Icons.thunderstorm_outlined, 'Bad weather', 'Find indoor alternatives nearby for an outdoor activity', () {
            _problem = 'weather';
            _go(_Step.day);
          }),
          _bigCard(Icons.no_food_outlined, 'Restaurant closed', 'Find a similar restaurant nearby', () {
            _problem = 'closed';
            _go(_Step.day);
          }),
        ];
      case _Step.flight:
        final flights = _flights;
        return [
          _title('Which flight?', 'Choose the delayed flight.'),
          if (flights.isEmpty) _empty('There is no flight in this itinerary.'),
          for (final f in flights)
            _rowCard(
              Icons.flight, f.item.title,
              'Day ${f.day} · ${f.item.timeStart}${f.item.timeEnd.isEmpty ? '' : ' - ${f.item.timeEnd}'}',
              () { _day = f.day; _item = f.item; _go(_Step.delay); },
            ),
        ];
      case _Step.delay:
        const chips = [30, 60, 120, 180, 240, 360];
        return [
          _title('How late is it?', '${_item!.title} was due at ${_item!.timeStart}.'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in chips)
              ChoiceChip(
                label: Text(_delayLabel(c)),
                selected: _delay == c,
                selectedColor: AppTheme.badgeGreenLight,
                onSelected: (_) => setState(() { _delay = c; _error = null; }),
              ),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _pickTime, icon: const Icon(Icons.schedule), label: const Text('Or enter the new departure time')),
          const SizedBox(height: 16),
          Text('Delay: ${_delayLabel(_delay)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _primary('See what changes', _busy ? null : _previewDelay),
        ];
      case _Step.preview:
        final plan = _plan!;
        return [
          _title('Review the changes', 'Nothing is saved until you confirm.'),
          for (final w in plan.warnings)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(12)),
              child: Text(w, style: const TextStyle(fontSize: 13)),
            ),
          for (final c in plan.changes)
            if (c.dropped) _droppedCard(c) else
              _rowCard(Icons.schedule, c.title, '${c.oldStart} → ${c.newStart}', null),
          const SizedBox(height: 12),
          _primary('Apply changes', _busy ? null : _applyDelay),
        ];
      case _Step.day:
        final days = _overview!.days;
        return [
          _title(_problem == 'closed' ? 'Which day?' : 'Which day is affected?', 'Choose the day of the ${_problem == 'closed' ? 'closed restaurant' : 'bad weather'}.'),
          for (final d in days)
            _rowCard(Icons.calendar_today_outlined, 'Day ${d.dayNumber} · ${d.dateString}', d.location, () { _day = d.dayNumber; _go(_Step.item); }),
        ];
      case _Step.item:
        final items = _affectable(_day!);
        return [
          _title(_problem == 'closed' ? 'Which restaurant?' : 'Which activity?', 'Day $_day'),
          if (items.isEmpty) _empty(_problem == 'closed' ? 'No restaurants planned on this day.' : 'No activities planned on this day.'),
          for (final i in items)
            _rowCard(
              _problem == 'closed' ? Icons.restaurant : Icons.place_outlined, i.title,
              '${i.timeStart}${i.timeEnd.isEmpty ? '' : ' - ${i.timeEnd}'}${i.subtitle.isEmpty ? '' : ' · ${i.subtitle}'}',
              () { _item = i; _findOptions(); },
            ),
        ];
      case _Step.options:
        return [
          _title(_problem == 'closed' ? 'Similar restaurants nearby' : 'Indoor alternatives nearby', _item == null ? null : 'Replacing ${_item!.title}'),
          if (_busy && _options.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))),
          if (_note.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(12)),
              child: Text(_note, style: const TextStyle(fontSize: 13)),
            ),
          for (final o in _options) _optionCard(o),
        ];
    }
  }

  Widget _droppedCard(DelayChange c) {
    final moving = _moves.containsKey(c.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFEBEA), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.error_outline, color: Color(0xFFD70015)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
              const Text('No longer fits today', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            label: const Text('Remove'),
            selected: !moving,
            selectedColor: Colors.white,
            onSelected: (_) => setState(() => _moves.remove(c.id)),
          ),
          ChoiceChip(
            label: const Text('Move to another day'),
            selected: moving,
            selectedColor: Colors.white,
            onSelected: c.moveOptions.isEmpty ? null : (_) => setState(() => _moves[c.id] = c.moveOptions.first.day),
          ),
        ]),
        if (c.moveOptions.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No other day in the same place has free time, so it can only be removed.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ),
        if (moving) ...[
          const SizedBox(height: 10),
          const Text('Days in the same place:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in c.moveOptions)
              ChoiceChip(
                label: Text('${o.label} · ${o.newStart}'),
                selected: _moves[c.id] == o.day,
                selectedColor: AppTheme.badgeGreenLight,
                onSelected: (_) => setState(() => _moves[c.id] = o.day),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _empty(String t) => Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t, style: const TextStyle(color: AppTheme.textMuted))));

  Widget _primary(String label, VoidCallback? onTap) => SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );

  Widget _bigCard(IconData icon, String title, String sub, VoidCallback onTap) => _rowCard(icon, title, sub, onTap, big: true);

  Widget _rowCard(IconData icon, String title, String sub, VoidCallback? onTap, {bool big = false, bool danger = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(big ? 18 : 14),
          decoration: BoxDecoration(
            color: danger ? const Color(0xFFFFEBEA) : AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(children: [
            Icon(icon, color: danger ? const Color(0xFFD70015) : AppTheme.primaryGreen),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))),
              ]),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ]),
        ),
      ),
    );
  }

  void _openDetails(ReplanOption o) {
    final day = _overview?.days.where((d) => d.dayNumber == _day).toList() ?? [];
    final city = day.isNotEmpty && day.first.location.isNotEmpty ? day.first.location : widget.trip.destination;
    showPlaceDetailSheet(
      context,
      name: o.title,
      city: city,
      kind: o.type == 'food' ? 'food' : 'attraction',
      subtitle: [o.category, o.area].where((x) => x.isNotEmpty).join(' · '),
      facts: [if (o.distance.isNotEmpty) '${o.distance} away', if (o.openingHours.isNotEmpty) o.openingHours, if (o.duration.isNotEmpty) o.duration],
      knownText: o.why,
    );
  }

  Widget _optionCard(ReplanOption o) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDetails(o),
      child: _optionBody(o),
    );
  }

  Widget _optionBody(ReplanOption o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(o.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
        const SizedBox(height: 2),
        Text([o.category, o.area].where((x) => x.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        const SizedBox(height: 8),
        Text(o.why, style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _meta(Icons.directions_walk, [o.distance, o.travelTime].where((x) => x.isNotEmpty).join(' · ')),
          _meta(Icons.access_time, o.openingHours),
          _meta(Icons.timelapse, o.duration),
        ]),
        const SizedBox(height: 6),
        const Text('Tap for AI summary and Google Maps link', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : () => _use(o),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Use this'),
          ),
        ),
      ]),
    );
  }

  Widget _meta(IconData i, String t) => t.isEmpty
      ? const SizedBox.shrink()
      : Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Flexible(child: Text(t, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))),
        ]);
}
