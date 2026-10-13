import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Bottom-sheet modal detailing card swipe controls.
class SwipeInstructionsModal extends StatelessWidget {
  const SwipeInstructionsModal({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'How to Customize Your Trip',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Swipe through travel preferences to tailor your itinerary:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          _buildGestureTile(
            icon: Icons.arrow_back_rounded,
            iconColor: Colors.red.shade400,
            bgColor: Colors.red.shade50,
            title: 'Swipe Left',
            subtitle: 'Dislike or skip this preference',
          ),
          const SizedBox(height: 12),
          _buildGestureTile(
            icon: Icons.arrow_upward_rounded,
            iconColor: Colors.amber.shade700,
            bgColor: Colors.amber.shade50,
            title: 'Tap Skip',
            subtitle: 'Neutral or skip for now (button below the card)',
          ),
          const SizedBox(height: 12),
          _buildGestureTile(
            icon: Icons.arrow_forward_rounded,
            iconColor: AppTheme.primaryGreen,
            bgColor: Colors.green.shade50,
            title: 'Swipe Right',
            subtitle: 'Like and include in your trip profile',
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Got It, Let\'s Start',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGestureTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
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