import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/itinerary.dart';
import '../../../../services/favourites_service.dart';
import 'place_detail_sheet.dart';

/// The places the traveller hearted in Explore, for this trip's cities,
/// ready to be added to a day.
class SavedPlacesView extends StatelessWidget {
  const SavedPlacesView({
    super.key,
    required this.cities,
    required this.onAddToTimeline,
  });

  /// City names of the trip (for example Tokyo, Kyoto, Osaka).
  final List<String> cities;
  final ValueChanged<ItineraryDetailItem> onAddToTimeline;

  static String _cityOf(Object? v) =>
      '$v'.split(',').first.trim().toLowerCase();

  ItineraryDetailItem _toItem(String key, Map<String, dynamic> d) {
    final kind = '${d['kind'] ?? 'attraction'}';
    final name = '${d['name'] ?? ''}';
    final subtitle = '${d['subtitle'] ?? ''}';
    final city = '${d['city'] ?? ''}'.split(',').first.trim();
    return switch (kind) {
      'hotel' => ItineraryDetailItem(
          id: 'fav-$key',
          timeStart: '2:00 PM',
          timeEnd: '3:00 PM',
          title: name,
          subtitle: subtitle,
          duration: '1 hr',
          mode: 'Stay',
          type: 'hotel',
          city: city,
        ),
      'food' => ItineraryDetailItem(
          id: 'fav-$key',
          timeStart: '12:00 PM',
          timeEnd: '1:00 PM',
          title: name,
          subtitle: subtitle,
          duration: '1 hr',
          mode: 'Meal',
          type: 'food',
          city: city,
        ),
      _ => ItineraryDetailItem(
          id: 'fav-$key',
          timeStart: '10:00 AM',
          timeEnd: '11:30 AM',
          title: name,
          subtitle: subtitle,
          duration: '1 hr 30 mins',
          mode: 'Visit',
          type: 'attraction',
          city: city,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SuggestionFavoritesService.favoritesRevision,
      builder: (context, _, _) {
        final wanted = {for (final c in cities) c.trim().toLowerCase()};
        final entries = [
          for (final e in SuggestionFavoritesService.savedEntries())
            if ('${e.value['kind']}' != 'flight' &&
                (wanted.isEmpty || wanted.contains(_cityOf(e.value['city']))))
              e,
        ];
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Nothing saved for ${cities.isEmpty ? 'this trip' : cities.join(', ')} yet.\nTap the heart on places in Explore on the Home page and they will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final key = entries[i].key;
            final d = entries[i].value;
            final item = _toItem(key, d);
            return GestureDetector(
              onTap: () => showPlaceDetailSheet(
                context,
                name: '${d['name'] ?? ''}',
                city: '${d['city'] ?? ''}',
                kind: '${d['kind'] ?? 'attraction'}',
                imageUrl: '${d['imageUrl'] ?? ''}',
                subtitle: '${d['subtitle'] ?? ''}',
                facts: [for (final f in (d['facts'] as List? ?? const [])) '$f'],
                knownText: '${d['description'] ?? ''}',
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.red, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          if (item.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => onAddToTimeline(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 0,
                      ),
                      child: const Text('Add to day', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
