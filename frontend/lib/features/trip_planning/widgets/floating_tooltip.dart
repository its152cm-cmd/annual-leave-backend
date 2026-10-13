import 'package:flutter/material.dart';
import 'package:homempage/core/theme/app_theme.dart';

class FloatingTooltip extends StatelessWidget {
  final bool showTooltip;
  final String message;

  const FloatingTooltip({
    super.key,
    required this.showTooltip,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (!showTooltip) return const SizedBox.shrink();

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: showTooltip ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
        ),
      ),
    );
  }
}