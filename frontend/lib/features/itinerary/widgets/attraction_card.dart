import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/attraction.dart';
import '../../../../models/itinerary.dart';
import 'place_detail_sheet.dart';

class AttractionCard extends StatelessWidget {
  final Attraction attraction;
  final ValueChanged<ItineraryDetailItem> onAddToTimeline;
  final String destinationCity;

  const AttractionCard({
    super.key,
    required this.attraction,
    required this.onAddToTimeline,
    this.destinationCity = '',
  });

  @override
  Widget build(BuildContext context) {
    final scheduleItem = ItineraryScheduleOption.attraction(attraction);
    return Draggable<ItineraryDetailItem>(
      data: scheduleItem,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 320,
          child: _AttractionCardContent(
            attraction: attraction,
            onAdd: () => onAddToTimeline(scheduleItem),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _AttractionCardContent(
          attraction: attraction,
          onAdd: () => onAddToTimeline(scheduleItem),
        ),
      ),
      child: GestureDetector(
        onTap: () => showPlaceDetailSheet(
          context,
          name: attraction.title,
          city: destinationCity.isEmpty ? attraction.location : destinationCity,
          kind: 'attraction',
          imageUrl: attraction.imageUrl,
          subtitle: attraction.location,
          facts: [
            if (attraction.price.isNotEmpty) attraction.price,
            if (attraction.visitDurationMinutes != null)
              '~${attraction.visitDurationMinutes} min visit',
            ...attraction.tags,
            if (attraction.openingHours.isNotEmpty) attraction.openingHours,
          ],
          knownText: attraction.description,
        ),
        child: _AttractionCardContent(
          attraction: attraction,
          onAdd: () => onAddToTimeline(scheduleItem),
        ),
      ),
    );
  }
}

class _AttractionCardContent extends StatelessWidget {
  const _AttractionCardContent({required this.attraction, required this.onAdd});

  final Attraction attraction;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              attraction.imageUrl,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Container(width: 64, height: 64, color: Colors.grey[300]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attraction.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  attraction.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            child: const Text(
              'Add to day',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
