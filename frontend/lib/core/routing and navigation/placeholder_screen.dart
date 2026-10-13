import 'package:flutter/material.dart';
import 'package:homempage/core/theme/app_theme.dart';
/// Generic Navigation Placeholder Screen
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title Screen',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
      ),
    );
  }
}