import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/attraction.dart';
import '../../../models/food_option.dart';
import '../../../models/flight.dart';
import '../../../models/destination_list.dart';
import '../../../models/group_trip_summary.dart';
import '../../../models/hotel.dart';
import '../../../services/food_service.dart';
import '../../../services/flight_service.dart';
import '../../../services/hotel_service.dart';
import '../../../services/recommendation_service.dart';
import '../../../services/favourites_service.dart';
import '../../../services/group_summary_service.dart';
import '../../../services/group_planning_service.dart';
import 'suggestion_detail.dart';

class SummarySuggestionsTab extends StatefulWidget {
  final List<GroupSuggestion> suggestions;
  final String destinationCity;
  final String groupId;
  final String tripId;
  final String initialCategory;
  final VoidCallback? onPlanningSelectionChanged;
  final bool showCategoryFilters;

  const SummarySuggestionsTab({
    super.key,
    required this.suggestions,
    required this.groupId,
    this.tripId = '',
    this.destinationCity = '',
    this.initialCategory = 'Favourites',
    this.onPlanningSelectionChanged,
    this.showCategoryFilters = true,
  });

  @override
  State<SummarySuggestionsTab> createState() => _SummarySuggestionsTabState();
}

class _SummarySuggestionsTabState extends State<SummarySuggestionsTab> {
  late String _selectedCategoryFilter = widget.initialCategory;
  List<Attraction> _attractions = [];
  List<FoodOption> _foods = [];
  List<HotelOption> _hotels = [];
  List<FlightOption> _flights = [];
  final SuggestionFavoritesService _favoritesService =
      SuggestionFavoritesService();
  final GroupSummaryService _summaryService = GroupSummaryService();
  bool _isLoadingItems = true;
  int _cityIndex = 0;
  // Hearts made in other cities of the same trip stay in the Favourites list.
  final Map<String, Object> _keptFavourites = {};
  List<String> _myFoodHabits = [];

  /// Every city of the trip, in order ("Tokyo, Japan", "Kyoto, Japan"...).
  List<String> get _stops {
    final stops = splitDestination(widget.destinationCity);
    return stops.isEmpty ? [widget.destinationCity] : stops;
  }

  /// The city whose places are shown now.
  String get _currentCity =>
      _stops[_cityIndex.clamp(0, _stops.length - 1).toInt()];

  String get _tripIdForOptions => _realTripId ?? '';
  final GroupPlanningService _planning = GroupPlanningService();
  String? get _realTripId => GroupPlanningService.tripIdFor(widget.groupId);

  @override
  void initState() {
    super.initState();
    SuggestionFavoritesService.favoritesRevision.addListener(
      _syncSharedFavorites,
    );
    _loadCategoryItems();
  }

  @override
  void dispose() {
    SuggestionFavoritesService.favoritesRevision.removeListener(
      _syncSharedFavorites,
    );
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SummarySuggestionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory) {
      _selectedCategoryFilter = widget.initialCategory;
    }
    if (oldWidget.destinationCity != widget.destinationCity) {
      _cityIndex = 0;
      _keptFavourites.clear();
      _loadCategoryItems();
    }
  }

  /// The group has not chosen where to go yet: nothing to suggest.
  bool get _hasDestination {
    final city = widget.destinationCity.trim().toLowerCase();
    return city.isNotEmpty && city != 'to be decided' && city != 'needs decision';
  }

  Future<void> _loadCategoryItems() async {
    if (!_hasDestination) {
      setState(() {
        _attractions = [];
        _foods = [];
        _hotels = [];
        _flights = [];
        _isLoadingItems = false;
      });
      return;
    }
    setState(() => _isLoadingItems = true);
    final city = _currentCity;
    _loadMyFoodHabits();
    final results = await Future.wait<dynamic>([
      RecommendationService().getAttractionsForCity(city),
      FoodService().getRecommendedEats(city, tripId: _tripIdForOptions),
      HotelService().searchHotels(city, tripId: _tripIdForOptions),
      widget.tripId.isEmpty
          ? Future.value(<FlightOption>[])
          : FlightService().searchFlightsByCity(
              _stops.first,
              tripId: widget.tripId,
            ),
    ]);
    // Real groups: hearts are personal. (The host's final choice lives in the
    // Overview tab.) Only sample groups preset hearts from their selections.
    final selections = _realTripId != null
        ? {'Accommodation': <String>[], 'Transport': <String>[]}
        : await _summaryService.getPlanningSelections(widget.groupId);
    if (!mounted) return;
    final attractions = results[0] as List<Attraction>;
    final foods = results[1] as List<FoodOption>;
    final hotels = results[2] as List<HotelOption>;
    final flights = results[3] as List<FlightOption>;
    for (final item in [...attractions, ...foods, ...hotels, ...flights]) {
      final key = _favouriteKey(item);
      final sharedFavorite = _favoritesService.isFavorite(key);
      if (sharedFavorite != null) {
        _setItemFavourite(item, sharedFavorite);
      } else if (item is HotelOption) {
        final selected = selections['Accommodation']!.contains(item.id);
        _setItemFavourite(item, selected);
        if (widget.groupId.isNotEmpty) {
          _favoritesService.setFavorite(key, selected, save: false);
        }
      } else if (item is FlightOption) {
        final selected = selections['Transport']!.contains(item.id);
        _setItemFavourite(item, selected);
        if (widget.groupId.isNotEmpty) {
          _favoritesService.setFavorite(key, selected, save: false);
        }
      } else {
        _favoritesService.setFavorite(key, _itemFavourite(item), save: false);
      }
    }
    setState(() {
      _attractions = attractions;
      _foods = foods;
      _hotels = hotels;
      _flights = flights;
      _isLoadingItems = false;
    });
  }

  void _syncSharedFavorites() {
    if (!mounted) return;
    setState(() {
      for (final item in [
        ..._attractions,
        ..._foods,
        ..._hotels,
        ..._flights,
      ]) {
        final favorite = _favoritesService.isFavorite(_favouriteKey(item));
        if (favorite != null) _setItemFavourite(item, favorite);
      }
    });
  }

  void _toggleAttractionSaved(Attraction attraction) =>
      _toggleItemFavourite(attraction);
  void _toggleFoodSaved(FoodOption food) => _toggleItemFavourite(food);
  void _toggleHotelSaved(HotelOption hotel) => _toggleItemFavourite(hotel);
  void _toggleFlightSaved(FlightOption flight) => _toggleItemFavourite(flight);

  String _favouriteKey(Object item) => switch (item) {
    Attraction value => 'attraction:${value.id}',
    FoodOption value => 'food:${value.id}',
    HotelOption value => 'hotel:${value.id}',
    FlightOption value => 'flight:${value.id}',
    _ => throw ArgumentError.value(item, 'item', 'Unsupported suggestion'),
  };

  bool _itemFavourite(Object item) => switch (item) {
    Attraction value => value.isFavourite,
    FoodOption value => value.isFavourite,
    HotelOption value => value.isFavourite,
    FlightOption value => value.isFavourite,
    _ => false,
  };

  void _setItemFavourite(Object item, bool isFavourite) {
    switch (item) {
      case Attraction value:
        value.isFavourite = isFavourite;
        break;
      case FoodOption value:
        value.isFavourite = isFavourite;
        break;
      case HotelOption value:
        value.isFavourite = isFavourite;
        break;
      case FlightOption value:
        value.isFavourite = isFavourite;
        break;
    }
  }

  Future<void> _toggleItemFavourite(Object item) async {
    final category = item is HotelOption
        ? 'Accommodation'
        : item is FlightOption
        ? 'Transport'
        : null;
    final isSaved = !_itemFavourite(item);
    final key = _favouriteKey(item);
    setState(() => _setItemFavourite(item, isSaved));
    final entry = _entryFor(item);
    _favoritesService.setFavorite(
      key,
      isSaved,
      snapshot: !isSaved
          ? null
          : {
              'kind': item is HotelOption
                  ? 'hotel'
                  : item is FlightOption
                  ? 'flight'
                  : item is FoodOption
                  ? 'food'
                  : 'attraction',
              'name': entry.title,
              'city': _currentCity.split(',').first.trim(),
              'subtitle': _subtitleFor(item),
              'imageUrl': entry.imageUrl,
              'description': '',
              'facts': <String>[],
            },
    );
    final tripId = _realTripId;
    if (!isSaved && tripId != null) {
      // Un-favouriting also takes your vote back from the group poll.
      try {
        await _planning.unshare(tripId, key);
      } catch (_) {}
    }
    if (category != null && _realTripId == null) {
      await _summaryService.setPlanningOptionSelected(
        groupId: widget.groupId,
        category: category,
        optionId: item is HotelOption ? item.id : (item as FlightOption).id,
        selected: isSaved,
      );
      widget.onPlanningSelectionChanged?.call();
    }
  }

  _SuggestionEntry _entryFor(Object item) => switch (item) {
    Attraction value => _SuggestionEntry(
      item: value,
      title: value.title,
      imageUrl: value.imageUrl,
      category: 'Attraction',
      details: [
        DetailField('Highlights', value.tags.join(' · ')),
        DetailField('Hours', value.openingHours),
        DetailField('Location', value.location),
        DetailField('Fee', value.price),
      ],
    ),
    FoodOption value => _SuggestionEntry(
      item: value,
      title: value.name,
      imageUrl: value.imageUrl,
      category: 'Restaurant',
      details: [
        DetailField('Cuisine', value.cuisineType),
        DetailField('Menu', value.menuItems.join(' · ')),
        DetailField('Price', value.price),
        DetailField('Hours', value.openingHours),
        DetailField('Location', value.location),
        DetailField('About', value.description),
      ],
    ),
    HotelOption value => _SuggestionEntry(
      item: value,
      title: value.name,
      imageUrl: value.imageUrl,
      category: 'Stay',
      details: [
        DetailField('Rooms', value.roomTypes.join(' · ')),
        DetailField('Amenities', value.amenities.join(' · ')),
        DetailField('Price', value.pricePerNightFormatted),
        DetailField('Check-in', value.checkInTime),
        DetailField('Check-out', value.checkOutTime),
        DetailField('Location', value.location),
      ],
    ),
    FlightOption value => _SuggestionEntry(
      item: value,
      title: value.airlineName,
      imageUrl: value.airlineLogoUrl,
      category: 'Flight',
      details: [
        DetailField('Airline', value.airlineName),
        DetailField('Route', value.route),
        DetailField('Times', '${value.departureTime} – ${value.arrivalTime}'),
        DetailField('Duration', value.duration),
        DetailField('Stops', value.stops),
        DetailField('Baggage', value.baggage),
        DetailField('Fare', value.priceFormatted),
      ],
    ),
    _ => throw ArgumentError.value(item, 'item', 'Unsupported suggestion'),
  };

  void _showItemDetail(_SuggestionEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SuggestionDetailPage(
          title: entry.title,
          imageUrl: entry.imageUrl,
          category: entry.category,
          details: entry.details,
          favouriteKey: _favouriteKey(entry.item),
          isFavourite: _itemFavourite(entry.item),
          onToggleFavourite: () => _toggleItemFavourite(entry.item),
          kind: switch (entry.item) {
            Attraction _ => 'attraction',
            FoodOption _ => 'food',
            HotelOption _ => 'hotel',
            _ => '',
          },
          city: _currentCity,
          knownText: entry.details
              .where((d) => d.label == 'Highlights' || d.label == 'Cuisine')
              .map((d) => d.value)
              .join('. '),
        ),
      ),
    );
  }

  Widget _tappableCard(Widget child, Object item) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => _showItemDetail(_entryFor(item)),
      borderRadius: BorderRadius.circular(16),
      child: child,
    ),
  );
  Widget _buildFavouriteButton({
    required bool isFavourite,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: isFavourite ? 'Saved' : 'Favourite',
      icon: Icon(isFavourite ? Icons.favorite : Icons.favorite_border),
      style: IconButton.styleFrom(
        foregroundColor: isFavourite ? Colors.white : AppTheme.primaryGreen,
        backgroundColor: isFavourite ? AppTheme.primaryGreen : Colors.white,
        side: const BorderSide(color: AppTheme.primaryGreen),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(10),
      ),
    );
  }

  Widget _buildAttractionCard(Attraction item) {
    final isSaved = item.isFavourite;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              item.imageUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 72,
                height: 72,
                color: Colors.grey[300],
                child: const Icon(Icons.place),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.location,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Text(
                  item.price,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildFavouriteButton(
            isFavourite: isSaved,
            onPressed: () => _toggleAttractionSaved(item),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodCard(FoodOption item) {
    final isSaved = item.isFavourite;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              item.imageUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 72,
                height: 72,
                color: Colors.grey[300],
                child: const Icon(Icons.restaurant),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.cuisineType} • ${item.priceTier}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          _buildFavouriteButton(
            isFavourite: isSaved,
            onPressed: () => _toggleFoodSaved(item),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelCard(HotelOption item) {
    final isSaved = item.isFavourite;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.hotel_outlined,
              color: AppTheme.primaryGreen,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.location,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Spacer(),
                    Text(
                      item.pricePerNightFormatted,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildFavouriteButton(
            isFavourite: isSaved,
            onPressed: () => _toggleHotelSaved(item),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightCard(FlightOption item) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            item.airlineLogoUrl,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 72,
              height: 72,
              color: const Color(0xFFE8F5E9),
              child: const Icon(Icons.flight, color: AppTheme.primaryGreen),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.airlineName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.route,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 6),
              Text(
                '${item.priceFormatted} · ${item.duration} · ${item.stops}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _buildFavouriteButton(
          isFavourite: item.isFavourite,
          onPressed: () => _toggleFlightSaved(item),
        ),
      ],
    ),
  );

  List<Object> get _allItems {
    final items = <Object>[..._attractions, ..._foods, ..._hotels, ..._flights];
    // Put group-curated picks first when they match a richer category model.
    for (final suggestion in widget.suggestions.reversed) {
      final index = items.indexWhere(
        (item) =>
            _entryFor(item).title.toLowerCase() ==
            suggestion.title.toLowerCase(),
      );
      if (index > 0) items.insert(0, items.removeAt(index));
    }
    return items;
  }

  Widget _buildAllSuggestionsList() => _buildItemList(_allItems);

  /// Places hearted in Explore (any screen) that belong to this trip's cities
  /// but are not in the loaded suggestions: built from their saved copy so
  /// they can be opened, shared to the group and un-hearted like any card.
  List<Object> _exploreFavouriteItems() {
    final cities = {for (final c in _stops) c.split(',').first.trim().toLowerCase()};
    final known = <String>{
      for (final i in _allItems) _favouriteKey(i),
      ..._keptFavourites.keys,
    };
    final out = <Object>[];
    for (final e in SuggestionFavoritesService.savedEntries()) {
      if (known.contains(e.key)) continue;
      final d = e.value;
      final kind = '${d['kind'] ?? 'attraction'}';
      if (kind == 'flight') continue;
      final city = '${d['city'] ?? ''}'.split(',').first.trim().toLowerCase();
      if (city.isNotEmpty && !cities.contains(city)) continue;
      final idx = e.key.indexOf(':');
      final id = idx < 0 ? e.key : e.key.substring(idx + 1);
      final name = '${d['name'] ?? ''}';
      final image = '${d['imageUrl'] ?? ''}';
      final subtitle = '${d['subtitle'] ?? ''}';
      final text = '${d['description'] ?? ''}';
      final facts = [for (final f in (d['facts'] as List? ?? const [])) '$f'];
      switch (kind) {
        case 'food':
          out.add(FoodOption(
            id: id, name: name, imageUrl: image, cuisineType: subtitle,
            priceTier: '', description: text, rating: 0, reviewCount: 0,
            location: '${d['city'] ?? ''}', isFavourite: true,
          ));
        case 'hotel':
          out.add(HotelOption(
            id: id, name: name, imageUrl: image,
            location: '${d['city'] ?? ''}', rating: 0,
            pricePerNightFormatted: subtitle, amenities: facts,
            bookingUrl: '', isFavourite: true,
          ));
        default:
          out.add(Attraction(
            id: id, title: name, location: subtitle.isEmpty ? '${d['city'] ?? ''}' : subtitle,
            imageUrl: image, description: text, tags: facts, isFavourite: true,
          ));
      }
    }
    return out;
  }

  Widget _buildCombinedFavouriteList() => _buildItemList(
    [
      ..._allItems.where(_itemFavourite),
      for (final entry in _keptFavourites.entries)
        if (_itemFavourite(entry.value) &&
            !_allItems.any((i) => _favouriteKey(i) == entry.key))
          entry.value,
      ..._exploreFavouriteItems(),
    ],
    emptyMessage: 'No favourite suggestions yet.',
    showShare: _realTripId != null,
  );

  String _sectionFor(Object item) => switch (item) {
    HotelOption _ => 'Accommodation',
    FlightOption _ => 'Flights',
    FoodOption _ => 'Food',
    _ => 'Activities',
  };

  String _subtitleFor(Object item) => switch (item) {
    HotelOption v => '${v.pricePerNightFormatted} · ${v.location}',
    FlightOption v => '${v.route} · ${v.priceFormatted} · ${v.duration}',
    FoodOption v => '${v.cuisineType} · ${v.priceTier}',
    Attraction v => v.location,
    _ => '',
  };

  String _itemIdOf(Object item) => switch (item) {
    HotelOption v => v.id,
    FlightOption v => v.id,
    _ => '',
  };

  Future<void> _shareToGroup(Object item) async {
    final tripId = _realTripId;
    if (tripId == null) return;
    final entry = _entryFor(item);
    final section = _sectionFor(item);
    try {
      await _planning.share(
        tripId,
        section: section,
        itemKey: _favouriteKey(item),
        title: entry.title,
        subtitle: _subtitleFor(item),
        imageUrl: entry.imageUrl,
        itemId: _itemIdOf(item),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shared to the group. Vote in the $section poll.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't share. Try again.")),
      );
    }
  }

  Widget _buildItemList(
    List<Object> items, {
    String emptyMessage = 'No suggestions available.',
    bool showShare = false,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(emptyMessage),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final item = items[index];
        final card = switch (item) {
          Attraction value => _buildAttractionCard(value),
          FoodOption value => _buildFoodCard(value),
          HotelOption value => _buildHotelCard(value),
          FlightOption value => _buildFlightCard(value),
          _ => const SizedBox.shrink(),
        };
        if (!showShare) return _tappableCard(card, item);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _tappableCard(card, item),
            TextButton.icon(
              onPressed: () => _shareToGroup(item),
              icon: const Icon(Icons.ios_share, size: 16),
              label: const Text('Share to group'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListFromCategory(String category) {
    if (!_hasDestination) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Choose a destination first (Overview tab), then places to visit, '
            'restaurants, stays and flights will appear here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_isLoadingItems) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return switch (category) {
      'Attractions' => _buildItemList(_attractions),
      'Restaurants' => _buildItemList(_foods),
      'Stays' => _buildItemList(_hotels),
      'Flights' => _buildItemList(_flights),
      'Favourites' => _buildCombinedFavouriteList(),
      _ => _buildAllSuggestionsList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String, IconData>{
      'Favourites': Icons.favorite,
      'Attractions': Icons.location_on,
      'Restaurants': Icons.restaurant,
      'Stays': Icons.bed,
      'Flights': Icons.flight,
    };

    return Column(
      children: [
        if (widget.showCategoryFilters) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: categories.entries.map((category) {
                final cat = category.key;
                final isSelected = _selectedCategoryFilter == cat;
                return Expanded(
                  child: Center(
                    child: ChoiceChip(
                      label: Icon(category.value, size: 18, semanticLabel: cat),
                      tooltip: cat,
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: AppTheme.primaryGreen,
                      backgroundColor: AppTheme.cardBackground,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textMuted,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedCategoryFilter = cat),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide.none,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_hasDestination && _stops.length > 1) _buildCityChips(),
        if (_hasDestination &&
            _selectedCategoryFilter == 'Restaurants' &&
            _myFoodHabits.isNotEmpty &&
            _realTripId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Picked for your food habits: ${_myFoodHabits.join(', ')}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
          ),
        if (_hasDestination &&
            _selectedCategoryFilter == 'Stays' &&
            _myHotelStars > 0 &&
            _realTripId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Picked for your hotel preference: $_myHotelStars-star',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
          ),
        Expanded(child: _buildListFromCategory(_selectedCategoryFilter)),
      ],
    );
  }

  int _myHotelStars = 0;

  /// This person's own food habits and hotel stars (everyone sees their own list).
  Future<void> _loadMyFoodHabits() async {
    final tripId = _realTripId;
    if (tripId == null) return;
    try {
      final t = await _planning.getTaste(tripId);
      final mine = (t['members'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) => m['isMe'] == true)
          .firstOrNull;
      if (!mounted || mine == null) return;
      setState(() {
        _myFoodHabits = List<String>.from(mine['dietary'] as List? ?? const []);
        _myHotelStars = (mine['hotel_stars'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  Widget _buildCityChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _stops.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == _cityIndex;
          return ChoiceChip(
            label: Text(_stops[i].split(',').first.trim()),
            selected: selected,
            showCheckmark: false,
            selectedColor: AppTheme.primaryGreen,
            backgroundColor: AppTheme.cardBackground,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppTheme.textDark,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            side: BorderSide.none,
            onSelected: (_) {
              if (selected) return;
              for (final item in _allItems) {
                if (_itemFavourite(item)) _keptFavourites[_favouriteKey(item)] = item;
              }
              setState(() => _cityIndex = i);
              _loadCategoryItems();
            },
          );
        },
      ),
    );
  }
}

class _SuggestionEntry {
  final Object item;
  final String title;
  final String imageUrl;
  final String category;
  final List<DetailField> details;

  const _SuggestionEntry({
    required this.item,
    required this.title,
    required this.imageUrl,
    required this.category,
    required this.details,
  });
}
