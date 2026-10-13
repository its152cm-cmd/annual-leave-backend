import 'package:flutter/material.dart';
import 'package:homempage/core/theme/app_theme.dart';

class CollaboratorSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const CollaboratorSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: const InputDecoration(
          hintText: 'Search people or email',
          hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 15),
          prefixIcon: Icon(Icons.search, color: AppTheme.textMuted),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}