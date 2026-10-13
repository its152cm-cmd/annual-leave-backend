import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/chat/scanned_receipt_screen.dart';
import '../../models/budget.dart';
import '../../models/receipt.dart';
import '../../models/trip.dart';
import '../../services/budget_service.dart';
import 'widgets/budget_warning_banner.dart';
import '../../services/chat_list_service.dart';
import '../../services/expense_service.dart';
import '../../services/trip_service.dart';
import '../../services/trip_budget_service.dart';

class FinancialSummaryScreen extends StatefulWidget {
  const FinancialSummaryScreen({super.key, this.tripId = '', this.trip});

  final String tripId;
  final Trip? trip;

  @override
  State<FinancialSummaryScreen> createState() => _FinancialSummaryScreenState();
}

class FinancialSummaryEntryScreen extends StatefulWidget {
  const FinancialSummaryEntryScreen({super.key, required this.tripId, this.trip});

  final String tripId;
  final Trip? trip;

  @override
  State<FinancialSummaryEntryScreen> createState() =>
      _FinancialSummaryEntryScreenState();
}

class _FinancialSummaryEntryScreenState
    extends State<FinancialSummaryEntryScreen> {
  late final Future<bool> _hasGroupChat = _resolveGroupChat();
  Trip? _trip;

  Future<bool> _resolveGroupChat() async {
    final trip = widget.trip ?? await TripService().getTrip(widget.tripId);
    _trip = trip;
    return ChatListService().hasGroupChatForTrip(trip);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _hasGroupChat,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          ),
        );
      }
      if (snapshot.hasError || !snapshot.hasData || _trip == null) {
        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: Text('Unable to load this trip summary.')),
        );
      }
      return snapshot.data!
          ? FinancialSummaryScreen(tripId: widget.tripId, trip: _trip)
          : SoloFinancialSummaryScreen(tripId: widget.tripId, trip: _trip!);
    },
  );
}

class SoloFinancialSummaryScreen extends StatefulWidget {
  const SoloFinancialSummaryScreen({
    super.key,
    required this.tripId,
    required this.trip,
  });

  final String tripId;
  final Trip trip;

  @override
  State<SoloFinancialSummaryScreen> createState() =>
      _SoloFinancialSummaryScreenState();
}

class _SoloFinancialSummaryScreenState
    extends State<SoloFinancialSummaryScreen> {
  final BudgetService _budgetService = BudgetService();
  final ExpenseService _expenseService = ExpenseService();
  late final Future<TripBudgetEstimate> _estimateFuture =
      _budgetService.getTripEstimate(widget.trip);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: FutureBuilder<TripBudgetEstimate>(
        future: _estimateFuture,
        builder: (context, estimateSnapshot) {
          if (estimateSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            );
          }
          if (estimateSnapshot.hasError || !estimateSnapshot.hasData) {
            return const Center(child: Text('Unable to load this trip estimate.'));
          }
          return ValueListenableBuilder<int>(
            valueListenable: ExpenseService.revision,
            builder: (context, _, _) => FutureBuilder<ExpenseFinancialSummary>(
              future: _expenseService.getFinancialSummary(
                groupId: ExpenseService.chatIdForTripId(widget.tripId),
              ),
              builder: (context, summarySnapshot) {
                if (summarySnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (summarySnapshot.hasError || !summarySnapshot.hasData) {
                  return const Center(
                    child: Text('Unable to load expense data.'),
                  );
                }
                final summary = summarySnapshot.data!;
                final estimate = estimateSnapshot.data!;
                final spent = summary.totalSpent;
                final remaining = estimate.plannedBudget - spent;
                final progress = estimate.plannedBudget <= 0
                    ? 0.0
                    : (spent / estimate.plannedBudget).clamp(0.0, 1.0);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.chevron_left, size: 25),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 34,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Your Spending',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    BudgetWarningBanner(spent: spent, budget: estimate.plannedBudget),
                    _SummaryCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Spent',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'RM ${spent.round()}',
                                      style: const TextStyle(
                                        fontSize: 25,
                                        height: 1.1,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1D3B32),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF6F0),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${(progress * 100).round()}% Spent',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF478251),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 7,
                              backgroundColor: const Color(0xFFE8ECE9),
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Remaining RM ${remaining.abs().round()} out of RM ${estimate.plannedBudget.round()}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _CategoryBudgetCard(tripId: widget.tripId, spent: summary.categoryTotals),
                    const SizedBox(height: 14),
                    _buildSoloRecentReceipts(summary),
                  ],
                );
              },
            ),
          );
        },
      ),
    ),
  );

  Widget _buildSoloRecentReceipts(ExpenseFinancialSummary summary) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
        child: Text(
          'Recent Receipts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      for (final receipt in summary.receipts)
        _ReceiptCard(
          receipt: receipt,
          singleTraveller: true,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ConfirmedReceiptDetailScreen(
                groupId: ExpenseService.chatIdForTripId(widget.tripId),
                receipt: receipt,
              ),
            ),
          ),
        ),
    ],
  );
}

class _FinancialSummaryScreenState extends State<FinancialSummaryScreen> {
  final BudgetService _budgetService = BudgetService();
  final ExpenseService _expenseService = ExpenseService();
  late final Future<TripBudgetEstimate> _estimateFuture;
  Trip? _resolvedTrip;
  int _selectedPage = 0;
  String? _expandedMemberId;

  @override
  void initState() {
    super.initState();
    _estimateFuture = _loadEstimate();
  }

  Future<TripBudgetEstimate> _loadEstimate() async {
    final trip = widget.trip ?? await TripService().getTrip(widget.tripId);
    _resolvedTrip = trip;
    return _budgetService.getTripEstimate(trip);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<TripBudgetEstimate>(
          future: _estimateFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Text(
                  'Unable to load this trip estimate: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }
            final estimate = snapshot.data!;
            return ValueListenableBuilder<int>(
              valueListenable: ExpenseService.revision,
              builder: (context, _, _) => FutureBuilder<ExpenseFinancialSummary>(
              future: _expenseService.getFinancialSummary(
                groupId: ExpenseService.chatIdForTripId(widget.tripId),
              ),
                builder: (context, financialSnapshot) {
                  if (financialSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (financialSnapshot.hasError ||
                      !financialSnapshot.hasData) {
                    return const Center(
                      child: Text('Unable to load expense data.'),
                    );
                  }
                  final summary = financialSnapshot.data!;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.chevron_left, size: 25),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 34,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Splitting Cost',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildBudgetSummary(estimate, summary),
                      const SizedBox(height: 14),
                      _CategoryBudgetCard(tripId: widget.tripId, spent: summary.categoryTotals),
                      const SizedBox(height: 14),
                      _SummarySectionTabs(
                        selectedIndex: _selectedPage,
                        onSelected: (index) =>
                            setState(() => _selectedPage = index),
                      ),
                      const SizedBox(height: 14),
                      if (_selectedPage == 0) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
                          child: Text(
                            'People',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildPeople(summary),
                      ] else
                        _buildRecentReceipts(summary),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBudgetSummary(
    TripBudgetEstimate estimate,
    ExpenseFinancialSummary summary,
  ) {
    final total = summary.totalSpent;
    final remaining = estimate.plannedBudget - total;
    final progress = estimate.plannedBudget <= 0
        ? 0.0
        : (total / estimate.plannedBudget).clamp(0.0, 1.0);
    return Column(
      children: [
        BudgetWarningBanner(spent: total, budget: estimate.plannedBudget),
        _SummaryCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FinancialSummaryDetailScreen(
                trip: _resolvedTrip!,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Spent',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _money(total),
                          style: const TextStyle(
                            fontSize: 25,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1D3B32),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF6F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${(progress * 100).round()}% Spent',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF478251),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE8ECE9),
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Remaining RM ${remaining.abs().round()} out of RM ${estimate.plannedBudget.round()}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeople(ExpenseFinancialSummary summary) {
    final outstandingPeople = <({ExpenseMemberBalance balance, double net})>[];
    for (final balance in summary.balances) {
      if (balance.memberId == summary.currentUserId) continue;
      final net = _expenseService.relationshipBalance(summary, balance.memberId);
      if (net.abs() > 0.005) {
        outstandingPeople.add((balance: balance, net: net));
      }
    }

    if (outstandingPeople.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Everyone is settled.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    return Column(
      children: [
        for (final entry in outstandingPeople)
          _PersonExpenseCard(
            balance: entry.balance,
            amount: entry.net.abs(),
            isOwe: entry.net > 0,
            expanded: _expandedMemberId == entry.balance.memberId,
            onTap: () => setState(() {
              _expandedMemberId =
                  _expandedMemberId == entry.balance.memberId
                      ? null
                      : entry.balance.memberId;
            }),
            onSettle: () => _expenseService.settleRelationship(
              summary.currentUserId,
              entry.balance.memberId,
              groupId: ExpenseService.chatIdForTripId(widget.tripId),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentReceipts(ExpenseFinancialSummary summary) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
        child: Text(
          'Recent Receipts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      for (final receipt in summary.receipts)
        _ReceiptCard(
          receipt: receipt,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ConfirmedReceiptDetailScreen(
                groupId: ExpenseService.chatIdForTripId(widget.tripId),
                receipt: receipt,
              ),
            ),
          ),
          onResolve: receipt.isSplitResolved
              ? null
              : () async {
                  await _expenseService.resolveReceipt(
                    receipt.id,
                    groupId: ExpenseService.chatIdForTripId(widget.tripId),
                  );
                },
        ),
    ],
  );

  String _money(double amount) => 'RM ${amount.round()}';
}

/// Per-category budget (from the Trip budget lines) against what has been spent.
class _CategoryBudgetCard extends StatefulWidget {
  const _CategoryBudgetCard({required this.tripId, required this.spent});
  final String tripId;
  final Map<String, double> spent;

  @override
  State<_CategoryBudgetCard> createState() => _CategoryBudgetCardState();
}

class _CategoryBudgetCardState extends State<_CategoryBudgetCard> {
  Map<String, double>? _budget;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!TripBudgetService.isSaved(widget.tripId)) return;
    try {
      final d = await TripBudgetService().load(widget.tripId);
      final totals = <String, double>{};
      for (final l in d.lines) {
        totals.update(l.category, (v) => v + l.amount, ifAbsent: () => l.amount);
      }
      if (mounted) setState(() => _budget = totals);
    } catch (_) {}
  }

  String _label(String c) => switch (c) {
        'Accommodation' => 'Hotel',
        'Activities' => 'Tickets & activities',
        'Other Expenses' => 'Other',
        _ => c,
      };

  String _m(double v) => 'RM ${v.round()}';

  @override
  Widget build(BuildContext context) {
    final budget = _budget;
    if (budget == null) return const SizedBox.shrink();
    final names = [
      for (final c in budgetCategories)
        if ((budget[c] ?? 0) > 0 || (widget.spent[c] ?? 0) > 0) c,
    ];
    if (names.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _SummaryCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Budget by category',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (final c in names) ...[
              Builder(builder: (_) {
                final cap = budget[c] ?? 0;
                final used = widget.spent[c] ?? 0;
                final left = cap - used;
                final over = cap > 0 && left < 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_label(c), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                        Text('Spent ${_m(used)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: cap <= 0 ? 0 : (used / cap).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE8ECE9),
                        color: over ? const Color(0xFFD70015) : AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cap <= 0
                          ? 'No budget set for this'
                          : over
                              ? 'Over by ${_m(-left)} / ${_m(cap)}'
                              : 'Remaining ${_m(left)} / ${_m(cap)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: over ? const Color(0xFFD70015) : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class FinancialSummaryDetailScreen extends StatelessWidget {
  FinancialSummaryDetailScreen({
    super.key,
    required this.trip,
  });

  final Trip trip;
  final ExpenseService _expenseService = ExpenseService();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.chevron_left),
      ),
      title: const Text('Splitting Cost Details'),
    ),
    body: ValueListenableBuilder<int>(
      valueListenable: ExpenseService.revision,
      builder: (context, _, _) => FutureBuilder<ExpenseFinancialSummary>(
        future: _expenseService.getFinancialSummary(
          groupId: ExpenseService.chatIdForTripId(trip.id),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Unable to load expense data.'));
          }
          final summary = snapshot.data!;
          final plannedBudget = trip.plannedBudget;
          final remaining = plannedBudget - summary.totalSpent;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _SummaryCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Spent',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'RM ${summary.totalSpent.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF1D3B32),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: plannedBudget <= 0
                            ? 0
                            : (summary.totalSpent / plannedBudget)
                                  .clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE8ECE9),
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (plannedBudget > 0)
                      Text(
                        'Remaining RM ${remaining.toStringAsFixed(2)} out of RM ${plannedBudget.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _CategoryBreakdownCard(amounts: summary.categoryTotals),
              const SizedBox(height: 16),
              const Text(
                'Resolved vs Unresolved Expenses',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _SummaryCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _SettlementMetric(
                      label: 'Confirmed paid',
                      amount: summary.confirmedPaidAmount,
                      color: AppTheme.primaryGreen,
                    ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SettlementMetric(
                      label: 'Remaining',
                      amount: summary.waitingToResolveAmount,
                      color: const Color(0xFFE34D4D),
                    ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE9ECEA)),
          borderRadius: BorderRadius.circular(17),
        ),
        child: child,
      ),
    ),
  );
}

class _SettlementMetric extends StatelessWidget {
  const _SettlementMetric({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 68),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F7F6),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'RM ${amount.round()}',
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

const _receiptCategoryOrder = [
  'Transport',
  'Accommodation',
  'Food',
  'Activities',
  'Other Expenses',
];

List<MapEntry<String, double>> _orderedCategoryTotals(
  Map<String, double> amounts,
) => [
  for (final category in _receiptCategoryOrder)
    if (amounts.containsKey(category)) MapEntry(category, amounts[category]!),
  for (final entry in amounts.entries)
    if (!_receiptCategoryOrder.contains(entry.key)) entry,
];

Color _receiptCategoryColor(String category) => switch (category) {
  'Transport' => const Color(0xFF6BB1A0),
  'Accommodation' => const Color(0xFF9A72CB),
  'Food' => const Color(0xFFE89A3C),
  'Activities' => const Color(0xFF5B8DEF),
  _ => const Color(0xFF9EA3AA),
};

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.amounts});

  final Map<String, double> amounts;

  @override
  Widget build(BuildContext context) {
    final entries = _orderedCategoryTotals(amounts);
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);

    return _SummaryCard(
      child: entries.isEmpty
          ? const Text(
              'No receipts to categorize yet.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: CustomPaint(
                          painter: _ReceiptCategoryPiePainter(
                            amounts: amounts,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: [
                            for (final entry in entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: _receiptCategoryColor(entry.key),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        '${entry.key} (${total <= 0 ? 0 : (entry.value / total * 100).round()}%)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Category breakdown',
                        style: TextStyle(
                          color: Color(0xFF1D3B32),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Spent',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _receiptCategoryColor(entry.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF293A34),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'RM ${entry.value.round()}',
                          style: const TextStyle(
                            color: Color(0xFF293A34),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ReceiptCategoryPiePainter extends CustomPainter {
  const _ReceiptCategoryPiePainter({required this.amounts});

  final Map<String, double> amounts;

  @override
  void paint(Canvas canvas, Size size) {
    final entries = _orderedCategoryTotals(amounts);
    final total = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.value.clamp(0, double.infinity),
    );
    if (total <= 0) return;

    var startAngle = -math.pi / 2;
    final bounds = Offset.zero & size;
    for (final entry in entries) {
      if (entry.value <= 0) continue;
      final sweepAngle = entry.value / total * math.pi * 2;
      canvas.drawArc(
        bounds,
        startAngle,
        sweepAngle,
        true,
        Paint()
          ..color = _receiptCategoryColor(entry.key)
          ..style = PaintingStyle.fill,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _ReceiptCategoryPiePainter oldDelegate) =>
      oldDelegate.amounts != amounts;
}

class _SummarySectionTabs extends StatelessWidget {
  const _SummarySectionTabs({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F2F1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        for (final (index, icon) in [
          (0, Icons.person_outline_rounded),
          (1, Icons.receipt_long_outlined),
        ])
          Expanded(
            child: Semantics(
              button: true,
              label: index == 0 ? 'People' : 'Receipts',
              selected: selectedIndex == index,
              child: IconButton(
                tooltip: index == 0 ? 'People' : 'Receipts',
                onPressed: () => onSelected(index),
                style: IconButton.styleFrom(
                  backgroundColor: selectedIndex == index
                      ? Colors.white
                      : Colors.transparent,
                  foregroundColor: selectedIndex == index
                      ? AppTheme.primaryGreen
                      : AppTheme.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size.fromHeight(40),
                  elevation: selectedIndex == index ? 1 : 0,
                ),
                icon: Icon(icon, size: 18),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.receipt,
    required this.onTap,
    this.onResolve,
    this.singleTraveller = false,
  });

  final Receipt receipt;
  final VoidCallback onTap;
  final Future<void> Function()? onResolve;
  final bool singleTraveller;

  @override
  Widget build(BuildContext context) {
    final isSettled = receipt.isSplitResolved;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F7),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            receipt.merchantName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            singleTraveller
                                ? receipt.timestamp.split('·').first.trim()
                                : '${receipt.timestamp.split('·').first.trim()} · ${receipt.peopleCount} people · ${receipt.type}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RM ${receipt.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (!singleTraveller) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Paid by ${receipt.paidByMemberName} · ${receipt.memberSplits.map((member) => '${member.name} RM ${receipt.shareFor(member).toStringAsFixed(2)}').join(' · ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isSettled
                              ? AppTheme.primaryGreen
                              : const Color(0xFFFF3030),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isSettled ? 'Settled' : 'Pending split',
                          style: TextStyle(
                            color: isSettled
                                ? AppTheme.primaryGreen
                                : const Color(0xFFFF3030),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (onResolve != null)
                        TextButton(
                          onPressed: onResolve,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Resolve Split'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonExpenseCard extends StatelessWidget {
  const _PersonExpenseCard({
    required this.balance,
    required this.amount,
    required this.isOwe,
    required this.expanded,
    required this.onTap,
    required this.onSettle,
  });

  final ExpenseMemberBalance balance;
  final double amount;
  final bool isOwe;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    final color = Color(balance.colorHex);
    final initials = balance.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    final relationshipColor = isOwe
        ? const Color(0xFFE34D4D)
        : AppTheme.primaryGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9ECEA)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      balance.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${isOwe ? 'Owe' : 'Get'} RM ${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: relationshipColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 0, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isOwe
                          ? 'You owe ${balance.name}'
                          : '${balance.name} owes you',
                      style: TextStyle(
                        color: relationshipColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onSettle,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Settle / Mark as Received'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
