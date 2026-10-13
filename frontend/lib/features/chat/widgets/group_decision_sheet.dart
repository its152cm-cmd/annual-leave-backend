import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/group_planning_service.dart';

/// Ranked options the group shared and voted on (most votes first).
/// [decision] is 'Accommodation' or 'Transport'. Only the host can choose
/// (or type their own); everyone else can just look. Returns true if the
/// choice changed.
Future<bool?> showGroupDecisionSheet(
  BuildContext context, {
  required String tripId,
  required String decision,
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
    builder: (_) => _DecisionSheet(
      tripId: tripId,
      decision: decision,
      canDecide: canDecide,
    ),
  );
}

class _DecisionSheet extends StatefulWidget {
  const _DecisionSheet({
    required this.tripId,
    required this.decision,
    required this.canDecide,
  });
  final String tripId;
  final String decision;
  final bool canDecide;

  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  final _service = GroupPlanningService();
  final _typed = TextEditingController();
  List<Map<String, dynamic>> _shares = [];
  List<Map<String, dynamic>> _chosen = [];
  bool _loading = true;
  bool _changed = false;
  String? _error;

  String get _section =>
      widget.decision == 'Accommodation' ? 'Accommodation' : 'Flights';
  String get _label =>
      widget.decision == 'Accommodation' ? 'Accommodation' : 'Transport';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final shares = await _service.getShares(widget.tripId, section: _section);
      final d = await _service.getDecisions(widget.tripId);
      if (!mounted) return;
      setState(() {
        _shares = shares;
        _chosen = [
          for (final e in ((d['decisions'] as Map?)?[widget.decision] as List? ??
              const []))
            Map<String, dynamic>.from(e as Map),
        ];
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "Couldn't load the options.";
        });
      }
    }
  }

  Future<void> _decide({String? shareId, String? title}) async {
    try {
      await _service.decide(
        widget.tripId,
        widget.decision,
        shareId: shareId,
        title: title,
      );
      _changed = true;
      _typed.clear();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't save the choice.");
    }
  }

  Future<void> _clear({Map<String, dynamic>? only}) async {
    try {
      await _service.clearDecision(
        widget.tripId,
        widget.decision,
        title: only == null ? null : '${only['title']}',
        itemId: only == null ? '' : '${only['itemId'] ?? ''}',
      );
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't clear the choice.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SizedBox(
      height: height * 0.75,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, _changed),
                ),
              ],
            ),
            Text(
              widget.canDecide
                  ? (widget.decision == 'Accommodation'
                        ? 'Options your group shared, ranked by votes. Pick one '
                              'or more (you may stay in several places), or type '
                              'your own. Leave empty and the AI will suggest.'
                        : 'Options your group shared, ranked by votes. Pick one, '
                              'or type your own. Leave empty and the AI will '
                              'suggest.')
                  : 'Options your group shared, ranked by votes. Only the '
                        'host can make the final choice.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            if (_chosen.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in _chosen)
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryGreen,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${c['title']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (widget.canDecide)
                            TextButton(
                              onPressed: () => _clear(only: c),
                              child: const Text('Remove'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : _shares.isEmpty
                  ? Center(
                      child: Text(
                        _error ??
                            'Nobody has shared an option yet.\nFavourite one '
                                'in Suggestions, then tap "Share to group".',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _shares.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _row(_shares[i], i),
                    ),
            ),
            if (_error != null && _shares.isNotEmpty)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (widget.canDecide) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _typed,
                      maxLength: 120,
                      decoration: InputDecoration(
                        hintText: 'Or type your own',
                        counterText: '',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final t = _typed.text.trim();
                      if (t.isNotEmpty) _decide(title: t);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                    child: const Text(
                      'Use',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> s, int index) {
    final isChosen = _chosen.any(
      (c) =>
          c['title'] == s['title'] && (c['itemId'] ?? '') == (s['itemId'] ?? ''),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isChosen ? AppTheme.primaryGreen : Colors.grey.shade300,
          width: isChosen ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
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
                    maxLines: 2,
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
          if (widget.canDecide && !isChosen)
            TextButton(
              onPressed: () => _decide(shareId: s['id'] as String),
              child: Text(
                widget.decision == 'Accommodation' && _chosen.isNotEmpty
                    ? 'Add'
                    : 'Choose',
              ),
            ),
          if (isChosen)
            const Icon(Icons.check_circle, color: AppTheme.primaryGreen),
        ],
      ),
    );
  }
}
