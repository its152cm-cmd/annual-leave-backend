import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/trip.dart';
import '../../../services/trip_service.dart';

class UpcomingTripCard extends StatefulWidget {
  const UpcomingTripCard({super.key, this.tripService});

  final TripService? tripService;

  @override
  State<UpcomingTripCard> createState() => _UpcomingTripCardState();
}

class _UpcomingTripCardState extends State<UpcomingTripCard> {
  late final TripService _tripService;
  final PageController _pageController = PageController();
  late Future<List<Trip>> _tripsFuture;
  Timer? _autoScrollTimer;
  int _tripCount = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _tripService = widget.tripService ?? TripService();
    _tripsFuture = _loadEligibleTrips();
    TripService.tripListRevision.addListener(_reloadTrips);
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    TripService.tripListRevision.removeListener(_reloadTrips);
    _pageController.dispose();
    super.dispose();
  }

  Future<List<Trip>> _loadEligibleTrips() async {
    final trips = await _tripService.getTrips();
    final eligibleTrips = trips.where((trip) {
      final status = trip.status.trim().toLowerCase();
      return status == 'upcoming' || status == 'draft';
    }).toList();
    _tripCount = eligibleTrips.length;

    if (_tripCount > 1) {
      _autoScrollTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_pageController.hasClients) return;
        final nextPage = (_currentPage + 1) % _tripCount;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      });
    } else {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
    }

    return eligibleTrips;
  }

  void _reloadTrips() {
    if (!mounted) return;
    if (_pageController.hasClients) _pageController.jumpToPage(0);
    setState(() {
      _currentPage = 0;
      _tripsFuture = _loadEligibleTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Trip>>(
      future: _tripsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final trips = snapshot.data!;
        return SizedBox(
          height: 220,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: trips.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildTripPage(
                    context,
                    trips[index],
                    showIndicators: trips.length > 1,
                  ),
                ),
              ),
              if (trips.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 0; index < trips.length; index++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: AnimatedContainer(
                            key: ValueKey('upcoming-trip-dot-$index'),
                            duration: const Duration(milliseconds: 180),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: index == _currentPage ? 1 : 0.4,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripPage(
    BuildContext context,
    Trip trip, {
    required bool showIndicators,
  }) {
    final status = trip.status.trim().toLowerCase();
    final budgetLabel = trip.budget.trim().isNotEmpty
        ? trip.budget
        : trip.plannedBudget > 0
        ? 'RM ${trip.plannedBudget.round()} budget'
        : '';

    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('upcoming-trip-card-${trip.id}'),
        onTap: () => context.push<void>('/trips/${trip.id}', extra: trip),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              trip.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: Color(0xFF46525A)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                showIndicators ? 36 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status == 'draft' ? 'Draft Trip' : 'Upcoming Trip',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    trip.destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${trip.dateRange} • ${trip.duration}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TripInfoChip(label: trip.duration),
                      if (budgetLabel.isNotEmpty)
                        _TripInfoChip(label: budgetLabel),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripInfoChip extends StatelessWidget {
  const _TripInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
