import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'widgets/budget_lines_section.dart';

/// Trip budget lines (statuses and booking documents) for a trip that is already confirmed.
class TripBudgetLinesScreen extends StatelessWidget {
  const TripBudgetLinesScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Trip budget'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          BudgetLinesSection(tripId: tripId),
          const SizedBox(height: 8),
          const Text(
            'Amounts are estimates until you mark a line as booked. Nothing is purchased in the app.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 10, height: 1.4),
          ),
        ],
      ),
    );
  }
}
