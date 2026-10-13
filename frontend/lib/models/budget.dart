import 'package:flutter/material.dart';

enum BudgetStatus { booked, pending, planned, estimated }

class BudgetItem {
  final String category;
  final double amount;
  final BudgetStatus status;
  final double percentage;
  final Color color;

  BudgetItem({
    required this.category,
    required this.amount,
    required this.status,
    required this.percentage,
    required this.color,
  });

  String get statusLabel {
    switch (status) {
      case BudgetStatus.booked:
        return 'Booked';
      case BudgetStatus.pending:
        return 'Pending';
      case BudgetStatus.planned:
        return 'Planned';
      case BudgetStatus.estimated:
        return 'Estimated';
    }
  }

  String get badgeLabel {
    switch (status) {
      case BudgetStatus.booked:
        return 'Booked';
      case BudgetStatus.pending:
        return 'Pending';
      case BudgetStatus.planned:
        return 'Planned';
      case BudgetStatus.estimated:
        return 'Est.';
    }
  }

  factory BudgetItem.fromJson(Map<String, dynamic> json, Color categoryColor) {
    return BudgetItem(
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: _parseStatus(json['status'] as String),
      percentage: (json['percentage'] as num).toDouble(),
      color: categoryColor,
    );
  }

  static BudgetStatus _parseStatus(String statusStr) {
    switch (statusStr.toLowerCase()) {
      case 'booked':
        return BudgetStatus.booked;
      case 'pending':
        return BudgetStatus.pending;
      case 'planned':
        return BudgetStatus.planned;
      case 'est.':
      case 'estimated':
      default:
        return BudgetStatus.estimated;
    }
  }
}

class BudgetSummary {
  final String groupId;
  final double totalAmount;
  final List<BudgetItem> items;

  BudgetSummary({
    required this.groupId,
    required this.totalAmount,
    required this.items,
  });
}

class TripBudgetEstimate {
  final String tripId;
  final double plannedBudget;
  final double estimatedTotal;
  final int travellerCount;
  final int durationDays;
  final List<BudgetItem> categories;

  const TripBudgetEstimate({
    required this.tripId,
    required this.plannedBudget,
    required this.estimatedTotal,
    required this.travellerCount,
    required this.durationDays,
    required this.categories,
  });

  double get costPerPerson =>
      travellerCount == 0 ? 0 : estimatedTotal / travellerCount;

  double get remainingBudget => plannedBudget - estimatedTotal;

  double get budgetProgress =>
      plannedBudget <= 0 ? 0 : (estimatedTotal / plannedBudget).clamp(0, 1);
}
