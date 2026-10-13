import 'dart:async';

import 'package:flutter/material.dart';

import 'package:homempage/core/theme/app_theme.dart';

import '../../../models/food_option.dart';
import '../../../models/itinerary.dart';
import '../../../services/food_service.dart';
import 'place_detail_sheet.dart';

class RecommendedEatsScreen extends StatefulWidget {
  final String destinationCity;
  final String subtitle;
  final Future<List<FoodOption>>? foodFuture;
  final ValueChanged<ItineraryDetailItem>? onAddToTimeline;

  const RecommendedEatsScreen({
    super.key,
    required this.destinationCity,
    this.subtitle = 'Top dining choices',
    this.foodFuture,
    this.onAddToTimeline,
  });

  @override
  State<RecommendedEatsScreen> createState() => _RecommendedEatsScreenState();
}

class _RecommendedEatsScreenState extends State<RecommendedEatsScreen> {
  late Future<List<FoodOption>> _foodFuture;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(_loadFoodData);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _foodFuture = FoodService().getRecommendedEats(
          widget.destinationCity,
          q: query,
        );
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFoodData();
  }

  @override
  void didUpdateWidget(covariant RecommendedEatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foodFuture != widget.foodFuture ||
        oldWidget.destinationCity != widget.destinationCity) {
      _loadFoodData();
    }
  }

  void _loadFoodData() {
    _foodFuture =
        widget.foodFuture ??
        FoodService().getRecommendedEats(widget.destinationCity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Search Bar Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search ${widget.destinationCity}',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Main Dining List View
            Expanded(
              child: FutureBuilder<List<FoodOption>>(
                future: _foodFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    );
                  }

                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        'No recommended dining spots found.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  final foodItems = snapshot.data!;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: foodItems.length,
                    itemBuilder: (context, index) {
                      final item = foodItems[index];
                      final scheduleItem = ItineraryScheduleOption.food(item);
                      final foodCard = Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Thumbnail Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                item.imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.restaurant,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Item Info Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Cuisine Tag & Price Tier Badges
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 2,
                                    children: [
                                      if (item.cuisineType.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            item.cuisineType,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      if (item.priceTier.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            item.priceTier,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Subtitle / Short Description
                                  Text(
                                    item.location.isNotEmpty ? item.location : item.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Add Button
                            ElevatedButton(
                              onPressed: widget.onAddToTimeline == null
                                  ? null
                                  : () => widget.onAddToTimeline!(scheduleItem),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Add to day',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      final tappableCard = GestureDetector(
                        onTap: () => showPlaceDetailSheet(
                          context,
                          name: item.name,
                          city: widget.destinationCity,
                          kind: 'food',
                          imageUrl: item.imageUrl,
                          subtitle: item.location,
                          facts: [
                            if (item.cuisineType.isNotEmpty) item.cuisineType,
                            if (item.priceTier.isNotEmpty) item.priceTier,
                            if (item.openingHours.isNotEmpty) item.openingHours,
                          ],
                          knownText: item.description,
                        ),
                        child: foodCard,
                      );
                      if (widget.onAddToTimeline == null) return tappableCard;
                      return Draggable<ItineraryDetailItem>(
                        data: scheduleItem,
                        feedback: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(width: 330, child: foodCard),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: foodCard,
                        ),
                        child: tappableCard,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
