import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/favourites_service.dart';
import '../itinerary/widgets/place_detail_sheet.dart';

/// Everything the person has hearted (places keep a small saved copy).
class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  @override
  void initState() {
    super.initState();
    SuggestionFavoritesService.favoritesRevision.addListener(_refresh);
  }

  @override
  void dispose() {
    SuggestionFavoritesService.favoritesRevision.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  IconData _icon(String kind) => switch (kind) {
        'food' => Icons.restaurant,
        'hotel' => Icons.hotel,
        'flight' => Icons.flight,
        _ => Icons.place_outlined,
      };

  String _label(String kind) => switch (kind) {
        'food' => 'Restaurant',
        'hotel' => 'Stay',
        'flight' => 'Flight',
        _ => 'Attraction',
      };

  @override
  Widget build(BuildContext context) {
    final entries = SuggestionFavoritesService.savedEntries();
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundWhite,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        title: const Text('Favourites'),
      ),
      body: entries.isEmpty
          ? const Center(child: Text('No favourite suggestions yet.'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final key = entries[index].key;
                final d = entries[index].value;
                final kind = '${d['kind'] ?? 'attraction'}';
                final image = '${d['imageUrl'] ?? ''}';
                final subtitle = '${d['subtitle'] ?? ''}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: kind == 'flight'
                          ? null
                          : () => showPlaceDetailSheet(
                                context,
                                name: '${d['name'] ?? ''}',
                                city: '${d['city'] ?? ''}',
                                kind: kind,
                                imageUrl: image,
                                subtitle: subtitle,
                                facts: [for (final f in (d['facts'] as List? ?? const [])) '$f'],
                                knownText: '${d['description'] ?? ''}',
                              ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (image.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  image,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${d['name'] ?? ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_icon(kind), size: 14, color: AppTheme.textMuted),
                                      const SizedBox(width: 4),
                                      Text(_label(kind), style: const TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove from favourites',
                              icon: const Icon(Icons.favorite, color: Colors.red),
                              onPressed: () =>
                                  SuggestionFavoritesService().setFavorite(key, false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
