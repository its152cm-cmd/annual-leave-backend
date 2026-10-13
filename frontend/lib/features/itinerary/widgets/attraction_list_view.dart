import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../models/attraction.dart';
import '../../../../models/itinerary.dart';
import '../../../../services/recommendation_service.dart';
import '../../../../core/widgets/ai_working.dart';
import 'attraction_card.dart';

class AttractionListView extends StatefulWidget {
  final List<Attraction> attractions;
  final String destinationCity;
  final ValueChanged<ItineraryDetailItem> onAddToTimeline;
  final bool loading; // the list is still being fetched (it can take a while)

  const AttractionListView({
    super.key,
    this.loading = false,
    required this.attractions,
    required this.onAddToTimeline,
    this.destinationCity = 'Kyoto',
  });

  @override
  State<AttractionListView> createState() => _AttractionListViewState();
}

class _AttractionListViewState extends State<AttractionListView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  List<Attraction>? _found; // results of a search, null = show the normal list
  bool _searching = false;
  int _searchId = 0;

  void _onQueryChanged(String value) {
    setState(() => _searchQuery = value);
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _searchId++;
      setState(() {
        _found = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final id = ++_searchId;
    setState(() => _searching = true);
    final results = await RecommendationService()
        .getAttractionsForCity(widget.destinationCity, q: query);
    if (!mounted || id != _searchId) return; // a newer search replaced this one
    setState(() {
      _found = results;
      _searching = false;
    });
  }

  @override
  void didUpdateWidget(covariant AttractionListView old) {
    super.didUpdateWidget(old);
    if (old.destinationCity != widget.destinationCity) {
      _searchController.clear();
      _found = null;
      _searching = false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter list based on search query
    final filteredList = _found ?? widget.attractions;

    return Column(
      children: [
        // Pill-shaped Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: _onQueryChanged,
            onSubmitted: (value) {
              _debounce?.cancel();
              if (value.trim().isNotEmpty) _runSearch(value.trim());
            },
            decoration: InputDecoration(
              hintText: 'Search ${widget.destinationCity}',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.grey,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
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

        // Filtered Attractions Cards List
        Expanded(
          child: _searching || (widget.loading && filteredList.isEmpty)
              ? const Center(
                  child: AiWorkingBox(
                    title: 'Finding attractions...',
                    message: 'This can take up to a minute.',
                  ),
                )
              : filteredList.isEmpty
              ? Center(
                  child: Text(
                    'No attractions found.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    return AttractionCard(
                      attraction: filteredList[index],
                      destinationCity: widget.destinationCity,
                      onAddToTimeline: widget.onAddToTimeline,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
