import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homempage/features/home/widgets/upcoming_trip_card.dart';
import 'package:homempage/models/trip.dart';
import 'package:homempage/services/trip_service.dart';

void main() {
  testWidgets('carousel filters inactive trips and opens the selected trip', (
    tester,
  ) async {
    final upcomingTrip = _trip(
      id: 'TRIP_KYOTO',
      destination: 'Kyoto, Japan',
      status: 'upcoming',
    );
    final draftTrip = _trip(
      id: 'TRIP_PENANG',
      destination: 'Penang, Malaysia',
      status: 'draft',
    );
    final router = _router([
      upcomingTrip,
      draftTrip,
      _trip(
        id: 'TRIP_BALI',
        destination: 'Bali, Indonesia',
        status: 'completed',
      ),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Upcoming Trip'), findsOneWidget);
    expect(find.text('Bali, Indonesia'), findsNothing);
    expect(find.byKey(const ValueKey('upcoming-trip-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('upcoming-trip-dot-1')), findsOneWidget);
    final pageViewSize = tester.getSize(find.byType(PageView));
    final firstCardSize = tester.getSize(
      find.byKey(const ValueKey('upcoming-trip-card-TRIP_KYOTO')),
    );
    expect(firstCardSize.width, pageViewSize.width - 16);

    await tester.fling(find.byType(PageView), const Offset(-1000, 0), 1000);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Penang, Malaysia'));
    await tester.pumpAndSettle();
    expect(find.text('Draft Trip'), findsOneWidget);
    expect(find.text('Penang, Malaysia'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('upcoming-trip-card-TRIP_PENANG')),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRIP_PENANG:draft'), findsOneWidget);
  });

  testWidgets('single eligible trip has no pagination indicators', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpcomingTripCard(
            tripService: _StubTripService([
              _trip(
                id: 'TRIP_PENANG',
                destination: 'Penang, Malaysia',
                status: 'draft',
              ),
              _trip(
                id: 'TRIP_BALI',
                destination: 'Bali, Indonesia',
                status: 'completed',
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Penang, Malaysia'), findsOneWidget);
    expect(find.byKey(const ValueKey('upcoming-trip-dot-0')), findsNothing);
  });


  testWidgets('carousel automatically advances and updates the active dot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpcomingTripCard(
            tripService: _StubTripService([
              _trip(
                id: 'TRIP_KYOTO',
                destination: 'Kyoto, Japan',
                status: 'upcoming',
              ),
              _trip(
                id: 'TRIP_PENANG',
                destination: 'Penang, Malaysia',
                status: 'draft',
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller!.page, 1);
    final activeDot = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('upcoming-trip-dot-1')),
    );
    expect((activeDot.decoration! as BoxDecoration).color!.a, 1);
  });
}

GoRouter _router(List<Trip> trips) => GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => Scaffold(
        body: UpcomingTripCard(tripService: _StubTripService(trips)),
      ),
    ),
    GoRoute(
      path: '/trips/:tripId',
      builder: (context, state) {
        final trip = state.extra as Trip;
        return Scaffold(body: Text('${trip.id}:${trip.status}'));
      },
    ),
  ],
);

Trip _trip({
  required String id,
  required String destination,
  required String status,
}) => Trip(
  id: id,
  destination: destination,
  dateRange: '12 - 18 December 2026',
  duration: '6 days',
  budget: 'RM 3,000 budget',
  imageUrl: '',
  status: status,
  plannedBudget: 3000,
);

class _StubTripService extends TripService {
  _StubTripService(this.trips);

  final List<Trip> trips;

  @override
  Future<List<Trip>> getTrips() async => trips;
}
