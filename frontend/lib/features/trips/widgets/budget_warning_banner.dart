import 'package:flutter/material.dart';

/// Shown on the financial summary when 80% or more of the budget is spent.
class BudgetWarningBanner extends StatelessWidget {
  const BudgetWarningBanner({super.key, required this.spent, required this.budget});

  final double spent;
  final double budget;

  @override
  Widget build(BuildContext context) {
    if (budget <= 0 || spent < budget * 0.8) return const SizedBox.shrink();
    final over = spent > budget;
    final color = over ? const Color(0xFFD70015) : const Color(0xFFB26A00);
    final text = over
        ? 'Budget exceeded: RM ${spent.round()} spent of RM ${budget.round()} (over by RM ${(spent - budget).round()}).'
        : 'Heads up: ${(spent / budget * 100).round()}% of the budget is used (RM ${spent.round()} of RM ${budget.round()}).';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: over ? const Color(0xFFFFEBEA) : const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(over ? Icons.error_outline : Icons.warning_amber_rounded, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
