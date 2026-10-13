import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/attraction.dart';
import '../../../models/food_option.dart';
import '../../../models/hotel.dart';
import '../../../services/favourites_service.dart';
import '../../../core/api/api_client.dart';
import 'city_picker_sheet.dart';
import '../../itinerary/widgets/place_detail_sheet.dart';
import '../favourites_screen.dart';

class RecommendedAttractionsSection extends StatefulWidget {
  const RecommendedAttractionsSection({super.key});

  @override
  State<RecommendedAttractionsSection> createState() =>
      _RecommendedAttractionsSectionState();
}

enum _Kind { attractions, restaurants, stays }

class _RecommendedAttractionsSectionState
    extends State<RecommendedAttractionsSection> {
  final SuggestionFavoritesService _favorites = SuggestionFavoritesService();
  final TextEditingController _searchController = TextEditingController();

  String _city = ''; // "City, Country"
  _Kind _kind = _Kind.attractions;
  String _query = '';
  final Map<_Kind, Future<List<Object>>> _lists = {};

  @override
  void initState() {
    super.initState();
    SuggestionFavoritesService.favoritesRevision.addListener(_onFavorites);
  }

  @override
  void dispose() {
    SuggestionFavoritesService.favoritesRevision.removeListener(_onFavorites);
    _searchController.dispose();
    super.dispose();
  }

  void _onFavorites() {
    if (mounted) setState(() {});
  }

  Future<void> _changeCity() async {
    final value = await showCityPicker(context, current: _city);
    final city = (value ?? '').trim();
    if (city.isEmpty || !mounted) return;
    setState(() {
      _city = city;
      _lists.clear();
      _query = '';
      _searchController.clear();
    });
  }

  String get _cityName => _city.split(',').first.trim();

  Future<List<Object>> _fetch(_Kind kind, {String q = ''}) async {
    final path = switch (kind) {
      _Kind.attractions => '/api/options/attractions',
      _Kind.restaurants => '/api/options/food',
      _Kind.stays => '/api/options/hotels',
    };
    try {
      final r = await ApiClient().get(
        path,
        query: {'city': _city, if (q.isNotEmpty) 'q': q},
      );
      final list = (r as List).map((e) => Map<String, dynamic>.from(e as Map));
      final items = <Object>[
        for (final j in list)
          switch (kind) {
            _Kind.attractions => Attraction.fromJson(j),
            _Kind.restaurants => FoodOption.fromJson(j),
            _Kind.stays => HotelOption.fromJson(j),
          },
      ];
      for (final item in items) {
        final key = _favoriteKey(item);
        if (_favorites.isFavorite(key) == null) {
          _favorites.setFavorite(key, _modelFavorite(item));
        }
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<List<Object>> _listFor(_Kind kind) =>
      _lists.putIfAbsent(kind, () => _fetch(kind));

  void _search(String value) {
    final q = value.trim();
    setState(() {
      _query = q;
      // a typed search asks the places service, so it also finds places that are not in the short list
      _lists[_kind] = q.isEmpty ? _fetch(_kind) : _fetch(_kind, q: q);
    });
  }

  void _openFavourites() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const FavouritesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Explore',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _changeCity,
              icon: const Icon(Icons.place_outlined, size: 16),
              label: Text(_city.isEmpty ? 'Choose city' : _cityName),
            ),
            IconButton(
              tooltip: 'Favourites',
              onPressed: _openFavourites,
              icon: const Icon(
                Icons.favorite_border,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          onChanged: (value) {
            if (value.trim().isEmpty && _query.isNotEmpty) _search('');
          },
          decoration: InputDecoration(
            hintText: 'Search ${_kindLabel(_kind).toLowerCase()}...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final k in _Kind.values)
              ChoiceChip(
                label: Text(_kindLabel(k)),
                selected: _kind == k,
                selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                onSelected: (_) => setState(() {
                  if (_query.isNotEmpty) _lists.remove(_kind); // drop search results
                  _kind = k;
                  _query = '';
                  _searchController.clear();
                }),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_city.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Choose a country and city to see real attractions, restaurants and stays.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _changeCity,
                    icon: const Icon(Icons.place_outlined, size: 18),
                    label: const Text('Choose city'),
                  ),
                ],
              ),
            ),
          )
        else
          FutureBuilder<List<Object>>(
            future: _listFor(_kind),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data ?? const <Object>[];
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No ${_kindLabel(_kind).toLowerCase()} found in $_cityName.'
                          : 'No results found.',
                    ),
                  ),
                );
              }
              return Column(
                children: [for (final item in items) _tile(item)],
              );
            },
          ),
      ],
    );
  }

  String _kindLabel(_Kind k) => switch (k) {
        _Kind.attractions => 'Attractions',
        _Kind.restaurants => 'Restaurants',
        _Kind.stays => 'Stays',
      };

  Widget _tile(Object item) {
    final (title, subtitle, tags, trailing, image) = switch (item) {
      Attraction v => (v.title, v.location, v.tags, v.price, v.imageUrl),
      FoodOption v => (v.name, v.location, [v.cuisineType], v.price, v.imageUrl),
      HotelOption v =>
        (v.name, v.location, v.amenities, v.pricePerNightFormatted, v.imageUrl),
      _ => ('', '', <String>[], '', ''),
    };
    final favorite = _isFavorite(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetails(item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // a photo only when the place really has one
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
                        title,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final tag in tags.where((t) => t.trim().isNotEmpty).take(2))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(tag, style: const TextStyle(fontSize: 10)),
                            ),
                          if (trailing.isNotEmpty)
                            Text(
                              trailing,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    favorite ? Icons.favorite : Icons.favorite_border,
                    color: favorite ? Colors.red : Colors.grey,
                  ),
                  onPressed: () => _toggleFavorite(item),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isFavorite(Object item) =>
      _favorites.isFavorite(_favoriteKey(item)) ?? _modelFavorite(item);

  bool _modelFavorite(Object item) => switch (item) {
        Attraction v => v.isFavourite,
        FoodOption v => v.isFavourite,
        HotelOption v => v.isFavourite,
        _ => false,
      };

  String _favoriteKey(Object item) => switch (item) {
        Attraction v => 'attraction:${v.id}',
        FoodOption v => 'food:${v.id}',
        HotelOption v => 'hotel:${v.id}',
        _ => throw ArgumentError.value(item, 'item', 'Unsupported explore item'),
      };

  void _toggleFavorite(Object item) {
    final isFavorite = !_isFavorite(item);
    switch (item) {
      case Attraction v:
        v.isFavourite = isFavorite;
      case FoodOption v:
        v.isFavourite = isFavorite;
      case HotelOption v:
        v.isFavourite = isFavorite;
    }
    _favorites.setFavorite(
      _favoriteKey(item),
      isFavorite,
      snapshot: isFavorite ? _snapshot(item) : null,
    );
  }

  /// What the Favourites list needs to show this place later.
  Map<String, dynamic> _snapshot(Object item) {
    final city = _cityName;
    return switch (item) {
      Attraction v => {
          'kind': 'attraction', 'name': v.title, 'city': city, 'subtitle': v.location,
          'imageUrl': v.imageUrl, 'description': v.description,
          'facts': [if (v.price.isNotEmpty) v.price, ...v.tags, if (v.openingHours.isNotEmpty) v.openingHours],
        },
      FoodOption v => {
          'kind': 'food', 'name': v.name, 'city': city, 'subtitle': v.location,
          'imageUrl': v.imageUrl, 'description': v.description,
          'facts': [if (v.cuisineType.isNotEmpty) v.cuisineType, if (v.priceTier.isNotEmpty) v.priceTier, if (v.openingHours.isNotEmpty) v.openingHours],
        },
      HotelOption v => {
          'kind': 'hotel', 'name': v.name, 'city': city, 'subtitle': v.location,
          'imageUrl': v.imageUrl, 'description': '',
          'facts': [if (v.pricePerNightFormatted.isNotEmpty) v.pricePerNightFormatted, ...v.amenities],
        },
      _ => <String, dynamic>{},
    };
  }

  void _openDetails(Object item) {
    final city = _cityName;
    switch (item) {
      case Attraction v:
        showPlaceDetailSheet(
          context,
          name: v.title,
          city: city,
          kind: 'attraction',
          imageUrl: v.imageUrl,
          subtitle: v.location,
          facts: [
            if (v.price.isNotEmpty) v.price,
            ...v.tags,
            if (v.openingHours.isNotEmpty) v.openingHours,
          ],
          knownText: v.description,
        );
      case FoodOption v:
        showPlaceDetailSheet(
          context,
          name: v.name,
          city: city,
          kind: 'food',
          imageUrl: v.imageUrl,
          subtitle: v.location,
          facts: [
            if (v.cuisineType.isNotEmpty) v.cuisineType,
            if (v.priceTier.isNotEmpty) v.priceTier,
            if (v.openingHours.isNotEmpty) v.openingHours,
          ],
          knownText: v.description,
        );
      case HotelOption v:
        showPlaceDetailSheet(
          context,
          name: v.name,
          city: city,
          kind: 'hotel',
          imageUrl: v.imageUrl,
          subtitle: v.location,
          facts: [
            if (v.pricePerNightFormatted.isNotEmpty) v.pricePerNightFormatted,
            ...v.amenities,
          ],
        );
    }
  }
}
