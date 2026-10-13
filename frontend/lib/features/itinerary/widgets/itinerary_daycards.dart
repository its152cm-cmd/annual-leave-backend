import 'package:flutter/material.dart';
import 'package:homempage/core/theme/app_theme.dart';

import '../../../models/itinerary.dart';
import '../../../services/route_service.dart';

class DayOverviewCard extends StatelessWidget {
  final ItineraryDayOverview dayData;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const DayOverviewCard({
    super.key,
    required this.dayData,
    this.isHighlighted = false,
    this.onTap,
  });

  static const primaryGreen = Color(0xFF67CE67);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlighted ? primaryGreen : Colors.grey[300]!,
            width: isHighlighted ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Day ${dayData.dayNumber}, ${dayData.dateString} – ${dayData.location}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: primaryGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: _buildStopsWithSeparators(dayData.stops),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStopsWithSeparators(List<ItineraryStop> stops) {
    final List<Widget> widgets = [];
    for (int i = 0; i < stops.length; i++) {
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            stops[i].name,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );

      if (i < stops.length - 1) {
        widgets.add(
          Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
        );
      }
    }
    return widgets;
  }
}

class TimelineScheduleCard extends StatelessWidget {
  final ItineraryDetailItem item;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPressDelete;
  final VoidCallback? onAdjustDuration;
  final TransferLeg? leg;
  final bool legTight;
  final VoidCallback? onTap;

  const TimelineScheduleCard({
    super.key,
    required this.item,
    this.onDelete,
    this.onLongPressDelete,
    this.onAdjustDuration,
    this.leg,
    this.legTight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeIcon = switch (item.type.toLowerCase()) {
      'flight' => Icons.flight_outlined,
      'transit' || 'transport' => Icons.directions_transit_outlined,
      'hotel' || 'accommodation' => Icons.hotel_outlined,
      _ => null,
    };

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPressDelete,
      onDoubleTap: onAdjustDuration,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(9, 6, 5, 5),
        decoration: BoxDecoration(
          color: item.timeTagBgColor.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: item.timeTagBgColor, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (typeIcon != null) ...[
                  Icon(typeIcon, size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    '${item.timeStart} - ${item.timeEnd}  ${item.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete itinerary item',
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
            ),
            if (leg != null) _legChip(leg!),
          ],
        ),
      ),
    );
  }

  Widget _legChip(TransferLeg l) => TransferLegChip(leg: l, tight: legTight);
}

/// The coloured "walk / taxi from the previous stop" tag.
class TransferLegChip extends StatelessWidget {
  const TransferLegChip({super.key, required this.leg, this.tight = false});

  final TransferLeg leg;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final l = leg;
    final (Color bg, Color fg, IconData icon) = tight
        ? (const Color(0xFFFDE8E8), const Color(0xFFB3261E), Icons.warning_amber_rounded)
        : switch (l.method) {
            'walk' => (const Color(0xFFE3F6E6), const Color(0xFF1B7A33), Icons.directions_walk),
            'transit' => (const Color(0xFFE4EEFB), const Color(0xFF1D5FA8), Icons.train_outlined),
            _ => (const Color(0xFFFFF1D6), const Color(0xFF9A5B00), Icons.local_taxi_outlined),
          };
    final text = tight ? '${l.label} · may not fit before this' : l.label;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                'From previous stop: $text',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
