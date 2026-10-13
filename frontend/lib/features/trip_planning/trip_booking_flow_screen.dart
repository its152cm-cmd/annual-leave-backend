import '../../services/trip_budget_service.dart';
import 'widgets/budget_lines_section.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../../models/attraction.dart';
import '../../../models/flight.dart';
import '../../../models/food_option.dart';
import '../../../models/hotel.dart';
import '../../../models/itinerary.dart';
import '../../../models/trip.dart';
import '../../../models/trip_booking.dart';
import '../../../services/trip_booking_service.dart';
import '../../../services/trip_service.dart';

class TripBookingFlowScreen extends StatefulWidget {
  const TripBookingFlowScreen({super.key, required this.trip});

  final Trip trip;

  @override
  State<TripBookingFlowScreen> createState() => _TripBookingFlowScreenState();
}

class _TripBookingFlowScreenState extends State<TripBookingFlowScreen> {
  final TripBookingService _bookingService = TripBookingService();
  final TextEditingController _searchController = TextEditingController();
  late final Future<TripBookingOptions> _optionsFuture;
  int _selectedCategory = 0;
  String _searchQuery = '';
  String? _flightId;
  String? _hotelId;
  final Set<String> _attractionIds = {};
  final Set<String> _foodIds = {};

  static const _categories = ['Flights', 'Hotels', 'Attractions', 'Food'];

  @override
  void initState() {
    super.initState();
    _optionsFuture = _bookingService.getOptions(widget.trip);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  TripBookingSelection _selection() => TripBookingSelection(
    flightId: _flightId,
    hotelId: _hotelId,
    attractionIds: _attractionIds.toList(),
    foodIds: _foodIds.toList(),
  );

  String get _pageTitle => switch (_selectedCategory) {
    0 => 'Compare Flights',
    1 => 'Compare Hotels',
    2 => '${widget.trip.destination.split(',').first} Attractions',
    _ => 'Recommended Eats',
  };

  void _continueToBudget(TripBookingOptions options) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TripBookingBudgetScreen(
          trip: widget.trip,
          options: options,
          selection: _selection(),
          bookingService: _bookingService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<TripBookingOptions>(
          future: _optionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Unable to load trip options: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final options = snapshot.data!;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'annual leave',
                              style: TextStyle(
                                color: AppTheme.primaryGreen,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _pageTitle,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.trip.destination} · ${widget.trip.dateRange}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final selected = _selectedCategory == index;
                            return ChoiceChip(
                              label: Text(_categories[index]),
                              selected: selected,
                              onSelected: (_) => setState(() {
                                _selectedCategory = index;
                                _searchController.clear();
                                _searchQuery = '';
                              }),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: selected
                                    ? Colors.white
                                    : AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                              selectedColor: AppTheme.primaryGreen,
                              backgroundColor: const Color(0xFFF2F2F6),
                              showCheckmark: false,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value.trim()),
                        decoration: InputDecoration(
                          hintText:
                              'Search ${widget.trip.destination.split(',').first}',
                          prefixIcon: const Icon(Icons.search, size: 19),
                          filled: true,
                          fillColor: const Color(0xFFF2F2F6),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                      if (_selectedCategory == 0) ...[
                        const SizedBox(height: 10),
                        _FlightRouteSummary(trip: widget.trip),
                      ],
                    ],
                  ),
                ),
                Expanded(child: _buildResults(options)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => _continueToBudget(options),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('Review estimated budget'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResults(TripBookingOptions options) {
    final children = switch (_selectedCategory) {
      0 => _flightCards(options.flights),
      1 => _hotelCards(options.hotels),
      2 => _attractionCards(options.attractions),
      _ => _foodCards(options.food),
    };
    if (children.isEmpty) {
      return const Center(child: Text('No options match your search.'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      children: children,
    );
  }

  List<Widget> _flightCards(List<FlightOption> flights) => [
    for (final flight in flights.where((item) => _matches(item.airlineName)))
      _OptionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flight_rounded,
                  color: AppTheme.primaryGreen,
                  size: 19,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    flight.airlineName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  flight.priceFormatted,
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    flight.departureTime,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  flight.duration,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
                Expanded(
                  child: Text(
                    flight.arrivalTime,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${flight.flightType} · ${flight.terminal}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
            const SizedBox(height: 10),
            _selectButton(
              selected: _flightId == flight.id,
              label: 'Select Flight',
              onPressed: () => setState(
                () => _flightId = _flightId == flight.id ? null : flight.id,
              ),
            ),
          ],
        ),
      ),
  ];

  List<Widget> _hotelCards(List<HotelOption> hotels) => [
    for (final hotel in hotels.where((item) => _matches(item.name)))
      _OptionCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NetworkImage(url: hotel.imageUrl, height: 130),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hotel.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        hotel.pricePerNightFormatted,
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hotel.location,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    children: [
                      for (final amenity in hotel.amenities)
                        _Tag(label: amenity),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _selectButton(
                    selected: _hotelId == hotel.id,
                    label: 'Select Hotel',
                    onPressed: () => setState(
                      () => _hotelId = _hotelId == hotel.id ? null : hotel.id,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
  ];

  List<Widget> _attractionCards(List<Attraction> attractions) => [
    for (final attraction in attractions.where((item) => _matches(item.title)))
      _OptionCard(
        padding: const EdgeInsets.all(9),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _NetworkImage(
                url: attraction.imageUrl,
                width: 62,
                height: 62,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final shouldAdd = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AttractionBookingDetailsScreen(
                        attraction: attraction,
                      ),
                    ),
                  );
                  if (shouldAdd == true && mounted) {
                    setState(() => _attractionIds.add(attraction.id));
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attraction.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      attraction.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      attraction.price,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _smallSelectButton(
              selected: _attractionIds.contains(attraction.id),
              onPressed: () => setState(() {
                if (!_attractionIds.add(attraction.id)) {
                  _attractionIds.remove(attraction.id);
                }
              }),
            ),
          ],
        ),
      ),
  ];

  List<Widget> _foodCards(List<FoodOption> food) => [
    for (final option in food.where((item) => _matches(item.name)))
      _OptionCard(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(15),
              ),
              child: _NetworkImage(
                url: option.imageUrl,
                width: 82,
                height: 104,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      option.cuisineType,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: _smallSelectButton(
                selected: _foodIds.contains(option.id),
                onPressed: () => setState(() {
                  if (!_foodIds.add(option.id)) _foodIds.remove(option.id);
                }),
              ),
            ),
          ],
        ),
      ),
  ];

  bool _matches(String value) =>
      _searchQuery.isEmpty ||
      value.toLowerCase().contains(_searchQuery.toLowerCase());

  Widget _selectButton({
    required bool selected,
    required String label,
    required VoidCallback onPressed,
  }) => SizedBox(
    width: double.infinity,
    height: 34,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppTheme.primaryGreen : Colors.white,
        foregroundColor: selected ? Colors.white : AppTheme.textDark,
        side: BorderSide(
          color: selected ? AppTheme.primaryGreen : const Color(0xFFE7E7EB),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(selected ? 'Selected' : label),
    ),
  );

  Widget _smallSelectButton({
    required bool selected,
    required VoidCallback onPressed,
  }) => SizedBox(
    width: 36,
    height: 30,
    child: IconButton.filled(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? const Color(0xFFE5F7EB)
            : AppTheme.primaryGreen,
        foregroundColor: selected ? AppTheme.primaryGreen : Colors.white,
      ),
      icon: Icon(selected ? Icons.check : Icons.add, size: 16),
    ),
  );
}

class AttractionBookingDetailsScreen extends StatelessWidget {
  const AttractionBookingDetailsScreen({super.key, required this.attraction});

  final Attraction attraction;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _NetworkImage(url: attraction.imageUrl, height: 220),
                ),
                const SizedBox(height: 14),
                Text(
                  attraction.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  attraction.location,
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${attraction.title} is one of the well-known highlights around ${attraction.location}. '
                  'Add it to your trip plan, then review the estimated cost before confirming.',
                  style: const TextStyle(
                    height: 1.5,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'From ${attraction.price} per person',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add to trip'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class TripBookingBudgetScreen extends StatefulWidget {
  const TripBookingBudgetScreen({
    super.key,
    required this.trip,
    required this.options,
    required this.selection,
    required this.bookingService,
    this.itineraryItems,
  });

  final Trip trip;
  final TripBookingOptions options;
  final TripBookingSelection selection;
  final TripBookingService bookingService;
  final List<ItineraryDetailItem>? itineraryItems;

  @override
  State<TripBookingBudgetScreen> createState() =>
      _TripBookingBudgetScreenState();
}

class _TripBookingBudgetScreenState extends State<TripBookingBudgetScreen> {
  bool _saving = false;
  late Set<String> _bookedItemIds;

  @override
  void initState() {
    super.initState();
    _bookedItemIds = widget.trip.bookedItemIds.toSet();
  }

  Future<void> _toggleBooked(ItineraryDetailItem item, bool isBooked) async {
    setState(() {
      if (isBooked) {
        _bookedItemIds.add(item.id);
      } else {
        _bookedItemIds.remove(item.id);
      }
    });
    await TripService().saveBookedItemIds(widget.trip, _bookedItemIds);
  }

  Future<void> _openBookingUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open booking website.')),
      );
    }
  }

  Map<String, double> _budgetAmounts(TripBookingQuote quote) {
    final stored = widget.trip.budgetBreakdown;
    if (stored != null && stored.isNotEmpty) return stored;
    return {for (final line in quote.lines) line.category: line.amount};
  }

  String? _bookingUrl(ItineraryDetailItem item) {
    final itemUrl = _usableBookingUrl(item.bookingUrl);
    if (itemUrl != null) return itemUrl;
    final flight = _findById(
      widget.options.flights,
      item.id,
      (option) => 'flight-${option.id}',
    );
    if (flight != null) return _usableBookingUrl(flight.bookingUrl);
    final hotel = _findById(
      widget.options.hotels,
      item.id,
      (option) => 'hotel-${option.id}',
    );
    return hotel == null ? null : _usableBookingUrl(hotel.bookingUrl);
  }

  String? _usableBookingUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return null;
    }
    return uri.toString();
  }

  String? _bookingPriceLabel(ItineraryDetailItem item) {
    final flight = _findById(
      widget.options.flights,
      item.id,
      (option) => 'flight-${option.id}',
    );
    if (flight != null && flight.priceFormatted.trim().isNotEmpty) {
      return flight.priceFormatted.trim();
    }
    final hotel = _findById(
      widget.options.hotels,
      item.id,
      (option) => 'hotel-${option.id}',
    );
    if (hotel != null && hotel.pricePerNightFormatted.trim().isNotEmpty) {
      return hotel.pricePerNightFormatted.trim();
    }
    final match = RegExp(
      r'(?:RM|MYR|USD|\$|¥)\s*[\d,]+(?:\.\d{1,2})?(?:\s*/\s*\w+)?',
      caseSensitive: false,
    ).firstMatch(item.subtitle);
    return match?.group(0)?.trim();
  }

  bool _isHotelItem(ItineraryDetailItem item) =>
      const {'hotel', 'accommodation'}.contains(item.type.toLowerCase()) ||
      const {'stay', 'hotel', 'accommodation'}.contains(
        item.mode.toLowerCase(),
      );

  List<ItineraryDetailItem> _uniqueBookableItems(
    List<ItineraryDetailItem> items,
  ) {
    final result = <ItineraryDetailItem>[];
    final seenHotelUrls = <String>{};
    for (final item in items) {
      final url = _bookingUrl(item);
      if (url == null) continue;
      if (_isHotelItem(item) && !seenHotelUrls.add(url)) continue;
      result.add(item);
    }
    return result;
  }

  String _bookingTitle(ItineraryDetailItem item) =>
      _isHotelItem(item) ? 'Hotel' : item.title;

  String _bookingDetails(ItineraryDetailItem item) {
    final details = <String>[];
    if (_isHotelItem(item)) {
      final hotelName = item.title
          .replaceFirst(
            RegExp(
              r'^Hotel\s+(?:check-in|check-out)\s*:?[\s]*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      if (hotelName.isNotEmpty && hotelName.toLowerCase() != 'hotel') {
        details.add(hotelName);
      }
    }
    final subtitle = item.subtitle
        .replaceFirst(
          RegExp(
            r'(?:RM|MYR|USD|\$|¥)\s*[\d,]+(?:\.\d{1,2})?(?:\s*/\s*\w+)?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(RegExp(r'[\s·,]+$'), '')
        .trim();
    if (subtitle.isNotEmpty) details.add(subtitle);
    return details.join(' · ');
  }

  List<MapEntry<String, double>> _orderedEstimatedAmounts(
    Map<String, double> amounts,
  ) {
    final grouped = <String, double>{};
    for (final entry in amounts.entries) {
      if (entry.value <= 0) continue;
      final category = switch (entry.key.trim().toLowerCase()) {
        'transport' || 'flights' => 'Transport',
        'accommodation' => 'Accommodation',
        'food' => 'Food',
        'activities' || 'activity' => 'Activities',
        'other expenses' || 'other' => 'Other Expenses',
        _ => entry.key,
      };
      grouped.update(
        category,
        (amount) => amount + entry.value,
        ifAbsent: () => entry.value,
      );
    }

    const order = [
      'Transport',
      'Accommodation',
      'Food',
      'Activities',
      'Other Expenses',
    ];
    final ordered = <MapEntry<String, double>>[
      for (final category in order)
        if (grouped.containsKey(category))
          MapEntry(category, grouped.remove(category)!),
      for (final entry in grouped.entries)
        MapEntry(entry.key, entry.value),
    ];
    return ordered;
  }

  T? _findById<T>(List<T> options, String id, String Function(T) getId) {
    for (final option in options) {
      if (getId(option) == id) return option;
    }
    return null;
  }

  Widget _buildBookingItem(ItineraryDetailItem item) {
    final bookingUrl = _bookingUrl(item);
    if (bookingUrl == null) return const SizedBox.shrink();
    final priceLabel = _bookingPriceLabel(item);
    final isBooked = _bookedItemIds.contains(item.id);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bookingTitle(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_bookingDetails(item).isNotEmpty)
                      Text(
                        _bookingDetails(item),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ),
              if (priceLabel != null)
                TextButton(
                  onPressed: () => _openBookingUrl(bookingUrl),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    backgroundColor: const Color(0xFFE8F5E9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    priceLabel,
                    style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                InkWell(
                  onTap: () => _openBookingUrl(bookingUrl),
                  child: const Text(
                    'Book',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              IconButton(
                tooltip: isBooked ? 'Mark as unbooked' : 'Mark as booked',
                onPressed: () => _toggleBooked(item, !isBooked),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                icon: Icon(
                  isBooked ? Icons.check_circle : Icons.circle_outlined,
                  color: isBooked
                      ? AppTheme.primaryGreen
                      : Colors.grey.shade500,
                  size: 20,
                ),
                  ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildEstimatedCategory(MapEntry<String, double> entry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            entry.key,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _money(entry.value),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      final quote = widget.bookingService.estimate(
        widget.trip,
        widget.options,
        widget.selection,
      );
      double amountFor(String category) =>
          quote.lines.firstWhere((line) => line.category == category).amount;
      final confirmedTrip = widget.trip.copyWith(
        estimatedBudget: quote.total,
        budgetBreakdown: {
          'Transport': amountFor('Flights') + amountFor('Transport'),
          'Accommodation': amountFor('Accommodation'),
          'Food': amountFor('Food'),
          'Activities': amountFor('Activities'),
          'Other expenses': 0,
        },
      );
      final savedTrip = await TripService().confirmTrip(confirmedTrip);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => TripConfirmedScreen(trip: savedTrip),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to confirm trip: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.bookingService.estimate(
      widget.trip,
      widget.options,
      widget.selection,
    );
    final budgetAmounts = widget.itineraryItems == null
      ? {for (final line in quote.lines) line.category: line.amount}
      : _budgetAmounts(quote);
    final bookingItems = widget.itineraryItems == null
      ? const <ItineraryDetailItem>[]
      : _uniqueBookableItems(widget.itineraryItems!);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Budget'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        children: [
          if (widget.itineraryItems != null &&
              TripBudgetService.isSaved(widget.trip.id)) ...[
            const Text(
              'Line items',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a line to set its status, add a booking document or open its booking website.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
            const SizedBox(height: 8),
            BudgetLinesSection(tripId: widget.trip.id),
          ] else if (widget.itineraryItems != null) ...[
            const Text(
              'Line of Items',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a green price to open its booking website.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
            const SizedBox(height: 8),
            if (bookingItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No items have direct booking links.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ),
            for (final item in bookingItems)
              _buildBookingItem(item),
            const SizedBox(height: 12),
            const Text(
              'Estimated',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            for (final entry in _orderedEstimatedAmounts(budgetAmounts))
              _buildEstimatedCategory(entry),
          ] else ...[
            const Text(
              'Line items',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final line in quote.lines)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F6),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.category,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            line.isSelected
                                ? 'Selected option'
                                : line.category == 'Flights' ||
                                      line.category == 'Accommodation'
                                ? 'Not yet booked'
                                : 'Estimated',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _money(line.amount),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 4),
          const Text(
            'Prices are estimates based on your selected options and trip details. Bookings are not purchased in this demo.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _saving ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class TripConfirmedScreen extends StatelessWidget {
  const TripConfirmedScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Your trip is confirmed!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Everything is ready for your journey to ${trip.destination.split(',').first}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        final router = GoRouter.of(context);
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                        router.go('/trips');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('View my trips'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: 'Close',
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).popUntil((route) => route.isFirst);
                router.go('/home');
              },
              icon: const Icon(Icons.close, color: AppTheme.textDark),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FlightRouteSummary extends StatelessWidget {
  const _FlightRouteSummary({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F8FA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${trip.originCity} (KUL)',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
        const Icon(Icons.arrow_forward, color: AppTheme.primaryGreen, size: 15),
        Expanded(
          child: Text(
            trip.destination.split(',').first == 'Kyoto'
                ? 'Osaka (KIX)'
                : trip.destination.split(',').first,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(
          Icons.calendar_month_outlined,
          color: AppTheme.primaryGreen,
          size: 17,
        ),
      ],
    ),
  );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE8E8EC)),
      borderRadius: BorderRadius.circular(15),
    ),
    child: child,
  );
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url, this.width, required this.height});

  final String url;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFE8EBE8),
        child: Icon(Icons.landscape_outlined, color: AppTheme.textMuted),
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F2F6),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 8, color: AppTheme.textMuted),
    ),
  );
}

String _money(double amount) => 'RM ${amount.round()}';
