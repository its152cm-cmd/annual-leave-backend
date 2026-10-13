import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/leave_combo.dart';

class LeaveComboCard extends StatelessWidget {
  final int daysOff;
  final String returnMultiplier;
  final int leaveDaysUsed;
  final String dateRange;
  final String description;

  const LeaveComboCard({
    super.key,
    required this.daysOff,
    required this.returnMultiplier,
    required this.leaveDaysUsed,
    required this.dateRange,
    required this.description,
  });

  /// Factory constructor to create card directly from a LeaveCombo model
  factory LeaveComboCard.fromModel({
    Key? key,
    required LeaveCombo combo,
  }) {
    return LeaveComboCard(
      key: key,
      daysOff: combo.daysOff,
      returnMultiplier: combo.returnMultiplier,
      leaveDaysUsed: combo.leaveDaysUsed,
      dateRange: combo.dateRange,
      description: combo.description,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$daysOff ',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const TextSpan(
                      text: 'Days Off',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.badgeGreenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  returnMultiplier,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Use $leaveDaysUsed Leave Day${leaveDaysUsed > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dateRange,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
          ),
        ],
      ),
    );
  }
}