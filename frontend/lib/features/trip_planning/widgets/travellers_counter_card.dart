import 'package:flutter/material.dart';
import 'package:homempage/core/theme/app_theme.dart';

class TravellersCounterCard extends StatelessWidget {
  final int count;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const TravellersCounterCard({
    super.key,
    required this.count,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Number of travellers',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_outline, color: AppTheme.textMuted),
              const SizedBox(width: 12),
              Text(
                '$count People',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryGreen),
                onPressed: count > 1 ? onDecrement : null,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGreen),
                onPressed: onIncrement,
              ),
            ],
          ),
        ),
      ],
    );
  }
}