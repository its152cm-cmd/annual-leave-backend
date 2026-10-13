import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'widgets/widgets.dart';
import 'leave_optimizer/leave_optimizer_screen.dart';
import '../trip_planning/create_trip_screen.dart';

/// Main Home Screen Implementation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Navigation to Create Trip Screen
  void _navigateToCreateTrip() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTripScreen()),
    );
  }

  void _openLeaveOptimizerPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LeaveOptimizerScreen()),
    );
  }

  Widget _createTripButton() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _navigateToCreateTrip,
        icon: const Icon(Icons.add, size: 22),
        label: const Text(
          'Create a new trip',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: AppTheme.backgroundWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }

  Widget _tripOptimizerButton() {
    return Tooltip(
      message: 'Trip Optimizer',
      child: SizedBox(
        width: 56,
        height: 56,
        child: IconButton(
          onPressed: _openLeaveOptimizerPage,
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 3,
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.calendar_today_rounded, size: 24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Eligible upcoming and draft trips
          const UpcomingTripCard(),
          const SizedBox(height: 20),

          // 2. Trip planning actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _createTripButton()),
              const SizedBox(width: 14),
              _tripOptimizerButton(),
            ],
          ),
          const SizedBox(height: 28),

          // 3. Top Picks For You Section
          const Text(
            'Top Picks for You',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 14),
          const TopPicksSection(),
          const SizedBox(height: 28),

          // 4. Explore
          const RecommendedAttractionsSection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
