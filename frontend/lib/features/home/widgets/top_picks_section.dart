import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/recommendation.dart';
import '../../../services/itinerary_service.dart';
import '../../../services/preference_service.dart';
import '../../../core/api/api_client.dart';
import '../../../services/recommendation_service.dart';
import '../../../services/trip_service.dart';
import 'recommendation_card.dart';

/// Top Picks Section
class TopPicksSection extends StatefulWidget {
  const TopPicksSection({
    super.key,
    this.recommendationService,
    this.tripService,
    this.itineraryService,
  });

  final RecommendationService? recommendationService;
  final TripService? tripService;
  final ItineraryService? itineraryService;

  @override
  State<TopPicksSection> createState() => _TopPicksSectionState();
}

class _TopPicksSectionState extends State<TopPicksSection> {
  late final RecommendationService _recommendationService;
  late final TripService _tripService;
  late Future<List<Recommendation>> _topPicksFuture;

  @override
  void initState() {
    super.initState();
    _recommendationService =
        widget.recommendationService ?? RecommendationService();
    _tripService = widget.tripService ?? TripService();
    _topPicksFuture = _recommendationService.getTopPicks();
  }

  bool _opening = false;

  Future<void> _openRecommendation(Recommendation recommendation) async {
    if (_opening) return;
    _opening = true;
    var dialogOpen = false;
    try {
      final trip = await _tripService.getOrCreateTopPickTrip(recommendation);
      if (!ItineraryService.hasGenerated(trip.id)) {
        if (!mounted) return;
        dialogOpen = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              content: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Planning your ${recommendation.destination} trip...\nThis can take up to a minute.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final service = PreferenceService();
        final base = await service.getPreferences();
        final tags = recommendation.tags.join(', ');
        final generated = await service.generateItinerary(
          trip: trip,
          preference: base.copyWith(
            transcript: tags.isEmpty
                ? ''
                : 'I am interested in $tags for this trip to ${recommendation.destination}.',
          ),
        );
        if (generated.overview.id != trip.id) {
          throw const FormatException('The itinerary did not match the trip.');
        }
        ItineraryService.saveGeneratedItinerary(generated);
        ItineraryService.markTopPick(trip.id);
        if (mounted && dialogOpen) {
          Navigator.of(context, rootNavigator: true).pop();
          dialogOpen = false;
        }
      }
      if (!mounted) return;

      await context.push<void>(
        '/trips/${trip.id}',
        extra: trip,
      );
    } catch (error) {
      if (mounted && dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
      if (mounted) {
        final msg = error is ApiException ? error.message : 'Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to plan this trip. $msg')),
        );
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Recommendation>>(
      future: _topPicksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final topPicks = snapshot.data!;

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topPicks.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final pick = topPicks[index];
            return RecommendationCard.fromModel(
              key: ValueKey('top-pick-${pick.id}'),
              recommendation: pick,
              onTap: () => _openRecommendation(pick),
            );
          },
        );
      },
    );
  }
}