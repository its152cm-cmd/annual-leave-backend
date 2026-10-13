import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class _Q {
  final String title;
  final bool multi;
  final List<String> options; // shown on the chip
  final List<String> phrases; // sentence part for each option
  const _Q(this.title, this.multi, this.options, this.phrases);
}

const List<_Q> _questions = [
  _Q('How do you like your days?', false,
      ['Relaxed', 'Balanced', 'Packed'],
      ['I prefer a relaxed pace with plenty of free time.', 'I like a balanced pace.', 'I want a packed schedule to see as much as possible.']),
  _Q('What do you enjoy most?', true,
      ['Nature', 'Culture & temples', 'Shopping', 'Nightlife', 'Theme parks', 'Hidden gems'],
      ['nature and scenic views', 'culture, history and temples', 'shopping', 'nightlife', 'theme parks', 'hidden local gems']),
  _Q('What about food?', true,
      ['Local street food', 'Authentic local cuisine', 'Cafes', 'Halal', 'Vegetarian', 'Seafood'],
      ['local street food', 'authentic local cuisine', 'cafes', 'halal food', 'vegetarian food', 'seafood']),
  _Q('How do you spend?', false,
      ['Budget', 'Mid-range', 'Treat myself'],
      ['I want to keep costs low.', 'I prefer mid-range options.', 'I am happy to splurge on good experiences.']),
  _Q('How do you like to get around?', false,
      ['Mostly walking', 'Public transport', 'Taxi when needed'],
      ['I like walking between places.', 'I prefer public transport.', 'Taxis are fine when it saves time.']),
];

/// A short multiple-choice quiz. Returns a sentence describing the answers (or null if closed).
Future<String?> showPreferenceQuiz(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _QuizSheet(),
  );
}

class _QuizSheet extends StatefulWidget {
  const _QuizSheet();

  @override
  State<_QuizSheet> createState() => _QuizSheetState();
}

class _QuizSheetState extends State<_QuizSheet> {
  int _step = 0;
  final List<Set<int>> _answers = List.generate(_questions.length, (_) => <int>{});

  String _sentence() {
    final parts = <String>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final picked = _answers[i].toList()..sort();
      if (picked.isEmpty) continue;
      if (i == 1) {
        parts.add('I enjoy ${_join(picked.map((k) => q.phrases[k]).toList())}.');
      } else if (i == 2) {
        parts.add('For food I like ${_join(picked.map((k) => q.phrases[k]).toList())}.');
      } else {
        parts.add(q.phrases[picked.first]);
      }
    }
    return parts.join(' ');
  }

  String _join(List<String> items) {
    if (items.length <= 1) return items.join();
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_step];
    final last = _step == _questions.length - 1;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Question ${_step + 1} of ${_questions.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            LinearProgressIndicator(
              value: (_step + 1) / _questions.length,
              color: AppTheme.primaryGreen,
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 16),
            Text(q.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (q.multi)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Pick as many as you like', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var k = 0; k < q.options.length; k++)
                  ChoiceChip(
                    label: Text(q.options[k]),
                    selected: _answers[_step].contains(k),
                    selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    onSelected: (_) => setState(() {
                      final set = _answers[_step];
                      if (q.multi) {
                        set.contains(k) ? set.remove(k) : set.add(k);
                      } else {
                        set
                          ..clear()
                          ..add(k);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_step > 0)
                  TextButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  onPressed: () {
                    if (last) {
                      Navigator.pop(context, _sentence());
                    } else {
                      setState(() => _step++);
                    }
                  },
                  child: Text(last ? 'Add to my preferences' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
