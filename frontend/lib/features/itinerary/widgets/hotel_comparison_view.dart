import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/hotel.dart';
import '../../../../models/itinerary.dart';
import '../../../../services/hotel_service.dart';
import 'place_detail_sheet.dart';

class HotelComparisonView extends StatefulWidget {
  final String destinationCity;
  final Future<List<HotelOption>> hotelsFuture;
  final ValueChanged<ItineraryDetailItem> onAddToTimeline;

  const HotelComparisonView({
    super.key,
    required this.destinationCity,
    required this.hotelsFuture,
    required this.onAddToTimeline,
  });

  @override
  State<HotelComparisonView> createState() => _HotelComparisonViewState();
}

class _HotelComparisonViewState extends State<HotelComparisonView> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  Future<List<HotelOption>>? _searchFuture; // null = the normal list

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _searchFuture = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _searchFuture = HotelService().searchHotels(
          widget.destinationCity,
          q: query,
        );
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
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
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<HotelOption>>(
            future: _searchFuture ?? widget.hotelsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                );
              }

              final hotels = snapshot.data ?? [];
              if (hotels.isEmpty) {
                return const Center(child: Text('No hotels found.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: hotels.length,
                itemBuilder: (context, index) {
                  final hotel = hotels[index];
                  final scheduleItem = ItineraryScheduleOption.hotel(hotel);
                  return Draggable<ItineraryDetailItem>(
                    data: scheduleItem,
                    feedback: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 260,
                        child: _HotelDragCard(hotel: hotel, isDragging: true),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: _HotelDragCard(hotel: hotel),
                    ),
                    child: GestureDetector(
                      onTap: () => showPlaceDetailSheet(
                        context,
                        name: hotel.name,
                        city: widget.destinationCity,
                        kind: 'hotel',
                        imageUrl: hotel.imageUrl,
                        subtitle: hotel.location,
                        facts: [
                          hotel.pricePerNightFormatted,
                          ...hotel.roomTypes,
                          if (hotel.checkInTime.isNotEmpty)
                            'Check-in ${hotel.checkInTime}',
                          if (hotel.checkOutTime.isNotEmpty)
                            'Check-out ${hotel.checkOutTime}',
                        ],
                      ),
                      child: _HotelDragCard(
                        hotel: hotel,
                        onAddToTimeline: () =>
                            widget.onAddToTimeline(scheduleItem),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HotelDragCard extends StatelessWidget {
  const _HotelDragCard({
    required this.hotel,
    this.isDragging = false,
    this.onAddToTimeline,
  });

  final HotelOption hotel;
  final bool isDragging;
  final VoidCallback? onAddToTimeline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isDragging ? const Color(0xFFE9F8EE) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4EAE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hotel_outlined,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  hotel.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(
                Icons.drag_indicator,
                size: 18,
                color: AppTheme.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            hotel.location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Spacer(),
              Text(
                hotel.pricePerNightFormatted,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (onAddToTimeline != null) ...[
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              height: 30,
              child: OutlinedButton(
                onPressed: onAddToTimeline,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Add to day', style: TextStyle(fontSize: 10)),
              ),
            ),
          ],
          const SizedBox(height: 3),
          const Center(
            child: Text(
              'Drag into the day timeline',
              style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
