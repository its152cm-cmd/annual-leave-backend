import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/flight.dart';

class FlightDateChipsBar extends StatelessWidget {
  final Future<List<FlightDateChip>> dateChipsFuture;

  const FlightDateChipsBar({super.key, required this.dateChipsFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FlightDateChip>>(
      future: dateChipsFuture,
      builder: (context, snapshot) {
        final chips = snapshot.data ?? [];
        if (chips.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chips.length + 1,
            itemBuilder: (context, index) {
              if (index == chips.length) {
                return Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month_outlined, color: AppTheme.primaryColor, size: 20),
                );
              }

              final chip = chips[index];
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: chip.isSelected ? AppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: chip.isSelected ? AppTheme.primaryColor : Colors.grey[300]!),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      chip.dateString,
                      style: TextStyle(
                        fontSize: 10,
                        color: chip.isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      chip.priceFormatted,
                      style: TextStyle(
                        fontSize: 11,
                        color: chip.isSelected ? Colors.white : AppTheme.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}