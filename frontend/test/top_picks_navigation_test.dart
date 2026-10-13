import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homempage/features/home/widgets/top_picks_section.dart';
import 'package:homempage/features/itinerary/itinerary_overview_screen.dart';
import 'package:homempage/models/recommendation.dart';
import 'package:homempage/models/trip.dart';
import 'package:homempage/services/itinerary_service.dart';
import 'package:homempage/services/recommendation_service.dart';
import 'package:homempage/services/trip_service.dart';

void main() {
  testWidgets('top pick opens and reuses its trip-specific itinerary', (
    tester,
  ) async {
    final recommendation = Recommendation(
      id: 'PICK_FLOW_TEST',
      destination: 'Langkawi',
      flightTime: '1h 15m flight',
      cost: 'RM 1,850/person',
      imageUrl: '',
      matchPercentage: '94% match',
      tags: const ['Nature', 'Relaxed'],
    );
    final tripService = TripService();
    final itineraryService = ItineraryService();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: TopPicksSection(
              recommendationService: _StubRecommendationService(
                [recommendation],
              ),
              tripService: tripService,
              itineraryService: itineraryService,
            ),
          ),
        ),
        GoRoute(
          path: '/trips/:tripId',
          builder: (context, state) => ItineraryOverviewScreen(
            itineraryId: state.pathParameters['tripId']!,
            initialTrip: state.extra as Trip?,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('top-pick-PICK_FLOW_TEST')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Langkawi Itinerary'), findsOneWidget);
    expect(find.text('Flight to Langkawi'), findsOneWidget);
    expect(find.text('Hotel check-in'), findsOneWidget);

    final savedTrip = await tripService.getTrip('TRIP_PICK_FLOW_TEST');
    expect(savedTrip.status, 'draft');
    expect(savedTrip.estimatedBudget, greaterThan(0));
    expect(savedTrip.budgetBreakdown, isNotNull);

    final savedItinerary = itineraryService.getOrCreateTopPickItinerary(
      savedTrip,
      flightTime: 'a different flight time',
    );
    expect(savedItinerary.overview.title, 'Langkawi Itinerary');
    expect(savedItinerary.dayDetails.length, 6);
    expect(savedItinerary.dayDetails[1]!.first.subtitle, contains('1h 15m'));
  });
}

class _StubRecommendationService extends RecommendationService {
  _StubRecommendationService(this.recommendations);

  final List<Recommendation> recommendations;

  @override
  Future<List<Recommendation>> getTopPicks() async => recommendations;
}
