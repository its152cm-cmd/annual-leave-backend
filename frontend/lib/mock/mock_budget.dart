import 'package:flutter/material.dart';

final Map<String, dynamic> mockBudgetJson = {
  'groupId': 'group_123',
  'totalAmount': 1540.0,
  'items': [
    {
      'category': 'Flight',
      'amount': 420.0,
      'status': 'booked',
      'percentage': 27.3,
    },
    {
      'category': 'Accommodation',
      'amount': 360.0,
      'status': 'pending',
      'percentage': 23.4,
    },
    {
      'category': 'Activities',
      'amount': 140.0,
      'status': 'planned',
      'percentage': 9.1,
    },
    {
      'category': 'Transport',
      'amount': 260.0,
      'status': 'est.',
      'percentage': 16.9,
    },
    {
      'category': 'Food',
      'amount': 360.0,
      'status': 'est.',
      'percentage': 23.4,
    },
  ],
};

const List<Color> budgetCategoryColors = [
  Color(0xFF6BB1A0), // Flight
  Color(0xFFE89A3C), // Accommodation
  Color(0xFF5B8DEF), // Activities
  Color(0xFF9A72CB), // Transport
  Color(0xFF6BB1A0), // Food
];