import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'main_navigation.dart';
import 'placeholder_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/itinerary/itinerary_overview_screen.dart';
import '../../features/chat/chat_main_screen.dart';
import '../../features/chat/group_chat_screen.dart';
import '../../features/account/account_screen.dart';
import '../../features/trips/trips_screen.dart';
import '../../features/trips/financial_summary_screen.dart';
import '../../features/trips/travel_checklist_screen.dart';
import '../../features/trips/trip_memories_screen.dart';
import '../../models/trip.dart';
import '../../services/account_service.dart';

GoRouter _buildRouter() => GoRouter(
  initialLocation: '/home',
  refreshListenable: AccountService.signedIn,
  // Nobody gets past the Account (login) page without signing in.
  redirect: (context, state) {
    final onLogin = state.matchedLocation == '/account';
    if (!AccountService.signedIn.value && !onLogin) return '/account';
    return null;
  },
  routes: [
    // Bottom Navigation Shell
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainNavigationWrapper(navigationShell: navigationShell);
      },
      branches: [
        // Tab 0: Home Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'details',
                  builder: (context, state) =>
                      const PlaceholderScreen(title: 'Home Details'),
                ),
                // Itinerary route under Home using state.extra
                GoRoute(
                  path: 'itinerary',
                  builder: (context, state) {
                    final itineraryId = state.extra as String? ?? '';
                    return ItineraryOverviewScreen(itineraryId: itineraryId);
                  },
                ),
              ],
            ),
          ],
        ),

        // Tab 1: Trips / Itinerary Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/trips',
              builder: (context, state) => const TripsScreen(),
              routes: [
                GoRoute(
                  path: ':tripId',
                  pageBuilder: (context, state) {
                    final tripId = state.pathParameters['tripId']!;
                    final trip = state.extra is Trip ? state.extra as Trip : null;
                    return NoTransitionPage<void>(
                      key: state.pageKey,
                      child: ItineraryOverviewScreen(
                        itineraryId: tripId,
                        initialTrip: trip,
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: ':tripId/checklist',
                  builder: (context, state) => TravelChecklistScreen(
                    tripId: state.pathParameters['tripId'] ?? '',
                  ),
                ),
                GoRoute(
                  path: ':tripId/financial-summary',
                  builder: (context, state) {
                    final tripId = state.pathParameters['tripId']!;
                    final trip = state.extra is Trip ? state.extra as Trip : null;
                    return FinancialSummaryEntryScreen(
                      tripId: tripId,
                      trip: trip,
                    );
                  },
                ),
                GoRoute(
                  path: ':tripId/memories',
                  builder: (context, state) {
                    final tripId = state.pathParameters['tripId']!;
                    final trip = state.extra is Trip ? state.extra as Trip : null;
                    return TripMemoriesScreen(
                      tripId: tripId,
                      initialTrip: trip,
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // Tab 2: Chat Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatMainScreen(),
              routes: [
                GoRoute(
                  path: ':groupId',
                  builder: (context, state) {
                    final groupId = state.pathParameters['groupId']!;
                    return GroupChatScreen(groupId: groupId);
                  },
                ),
              ],
            ),
          ],
        ),

        // Tab 3: Account Branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/account',
              builder: (context, state) => const AccountScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// The router for the current login session. Signing in or out builds a fresh
/// one, so pages left open by the previous account are not carried over.
GoRouter appRouter = _buildRouter();

/// Rebuilt whenever [appRouter] is replaced; the app listens to it.
final ValueNotifier<int> routerRevision = ValueNotifier(0);

void resetAppRouter() {
  appRouter = _buildRouter();
  routerRevision.value++;
}
