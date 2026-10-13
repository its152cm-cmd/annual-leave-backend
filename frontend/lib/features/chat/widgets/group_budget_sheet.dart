import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/group_planning_service.dart';

/// Everyone types their own budget range. The group budget is worked out
/// automatically (highest minimum to lowest maximum). Returns true if the
/// person saved their own range.
Future<bool?> showGroupBudgetSheet(
  BuildContext context, {
  required String tripId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _BudgetSheet(tripId: tripId),
  );
}

class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet({required this.tripId});
  final String tripId;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  final _service = GroupPlanningService();
  final _min = TextEditingController();
  final _max = TextEditingController();
  Map<String, dynamic>? _state;
  bool _loading = true;
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  String _money(num v) {
    final s = v.round().toString();
    return 'RM${s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
  }

  List<Map<String, dynamic>> get _members =>
      (_state?['members'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<void> _load() async {
    try {
      final state = await _service.getBudget(widget.tripId);
      if (!mounted) return;
      final me = (state['members'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) => m['isMe'] == true)
          .firstOrNull;
      setState(() {
        _state = state;
        _loading = false;
        if (me != null && me['min'] != null) {
          _min.text = (me['min'] as num).round().toString();
          _max.text = (me['max'] as num).round().toString();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "Couldn't load budgets.";
        });
      }
    }
  }

  Future<void> _save() async {
    final low = double.tryParse(_min.text.replaceAll(',', '').trim());
    final high = double.tryParse(_max.text.replaceAll(',', '').trim());
    if (low == null || high == null) {
      setState(() => _error = 'Enter both a minimum and a maximum amount.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final state = await _service.setBudget(widget.tripId, low, high);
      if (!mounted) return;
      setState(() {
        _state = state;
        _saving = false;
        _saved = true;
      });
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final combined = _state?['combined'] as Map?;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: _loading
          ? const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Budget',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context, _saved),
                      ),
                    ],
                  ),
                  const Text(
                    'Enter what you are comfortable spending. The group budget '
                    'is worked out from everyone\'s range automatically.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  if (combined != null)
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
                          Text(
                            'Group budget: ${_money(combined['min'] as num)}'
                            ' – ${_money(combined['max'] as num)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            combined['conflict'] == true
                                ? 'Some ranges do not overlap, so the lowest '
                                      'maximum is used.'
                                : '${_state!['entered']} of ${_state!['total']}'
                                      ' members have entered theirs.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'Your budget',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _field(_min, 'Minimum (RM)')),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_max, 'Maximum (RM)')),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 12),
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
                        _saving ? 'Saving…' : 'Save my budget',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Everyone',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  for (final m in _members)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              m['isMe'] == true
                                  ? '${m['name']} (you)'
                                  : '${m['name']}',
                            ),
                          ),
                          Text(
                            m['min'] == null
                                ? 'Not entered'
                                : '${_money(m['min'] as num)} – ${_money(m['max'] as num)}',
                            style: TextStyle(
                              color: m['min'] == null
                                  ? AppTheme.textMuted
                                  : AppTheme.textDark,
                              fontWeight: FontWeight.w600,
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

  Widget _field(TextEditingController c, String hint) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      isDense: true,
    ),
  );
}
