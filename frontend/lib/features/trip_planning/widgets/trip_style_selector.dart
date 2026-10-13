import 'package:flutter/material.dart';
import 'package:homempage/core/theme/app_theme.dart';

class TripStyleSelector extends StatelessWidget {
  final bool isSoloSelected;
  final VoidCallback onSelectSolo;
  final VoidCallback onSelectGroup;
  final bool showTitle;

  const TripStyleSelector({
    super.key,
    required this.isSoloSelected,
    required this.onSelectSolo,
    required this.onSelectGroup,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          const Text(
            'Trip style',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
        if (showTitle) const SizedBox(height: 12),
        Row(
          children: [
            _buildChip(
              label: 'Solo',
              isSelected: isSoloSelected,
              onTap: onSelectSolo,
            ),
            const SizedBox(width: 12),
            _buildChip(
              label: 'Group',
              isSelected: !isSoloSelected,
              onTap: onSelectGroup,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}