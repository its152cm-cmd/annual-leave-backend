import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/trip.dart';
import '../../services/chat_list_service.dart';
import '../../services/trip_service.dart';
import '../trip_planning/create_trip_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final TripService _tripService = TripService();
  late Future<List<Trip>> _tripsFuture;

  @override
  void initState() {
    super.initState();
    _tripsFuture = _tripService.getTrips();
    TripService.tripListRevision.addListener(_reloadTrips);
  }

  @override
  void dispose() {
    TripService.tripListRevision.removeListener(_reloadTrips);
    super.dispose();
  }

  void _reloadTrips() {
    setState(() {
      _tripsFuture = _tripService.getTrips();
    });
  }

  /// Swipe left on a trip: asks first, then removes it for everyone.
  /// Only the host can; anyone else sees why it did not happen.
  Future<bool> _confirmDelete(Trip trip) async {
    final name = trip.destination.isEmpty ? 'this trip' : trip.destination;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $name?'),
        content: const Text(
          'This deletes the trip for everyone: its group chat, polls, votes, '
          'budget, expenses and itinerary. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true) return false;
    try {
      await _tripService.deleteDraft(trip.id);
      ChatListService.conversationsRevision.value++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $name.')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        final text = '$e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              text.contains('Only the host')
                  ? 'Only the host can delete this trip.'
                  : text.contains('completed')
                  ? 'A completed trip is kept for its memories.'
                  : "Couldn't delete the trip. Try again.",
            ),
          ),
        );
      }
      return false;
    }
  }

  void _createTrip() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CreateTripScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Trip>>(
      future: _tripsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load trips: ${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          );
        }

        final trips = snapshot.data ?? const <Trip>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Trips',
                    style: TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Create a trip',
                  child: IconButton(
                    onPressed: _createTrip,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final trip in trips)
              Dismissible(
                key: ValueKey('trip-${trip.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(trip),
                background: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                child: _TripListTile(trip: trip),
              ),
          ],
        );
      },
    );
  }
}

class _TripListTile extends StatelessWidget {
  const _TripListTile({required this.trip});

  final Trip trip;

  Color get _statusColor {
    switch (trip.status.toLowerCase()) {
      case 'upcoming':
        return AppTheme.primaryGreen;
      case 'draft':
        return const Color(0xFFFFB23F);
      case 'completed':
        return const Color(0xFFA5A5AD);
      default:
        return AppTheme.textMuted;
    }
  }

  String get _statusLabel {
    switch (trip.status.toLowerCase()) {
      case 'upcoming':
        return 'Upcoming';
      case 'draft':
        return 'Draft';
      case 'completed':
        return 'Completed';
      default:
        return trip.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              trip.imageUrl,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 54,
                height: 54,
                child: ColoredBox(
                  color: Color(0xFFE0E4E6),
                  child: Icon(
                    Icons.landscape_rounded,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.destination.isEmpty ? 'New group trip' : trip.destination,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trip.destination.isEmpty
                      ? 'Destination and dates to be decided in the chat'
                      : '${trip.dateRange} • ${trip.duration}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              _statusLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (trip.status.toLowerCase() == 'completed') {
      return Semantics(
        button: true,
        label: 'Open ${trip.destination} trip memories',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/trips/${trip.id}/memories', extra: trip),
          child: content,
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Open ${trip.destination} itinerary',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // A group trip whose destination is not chosen yet is planned in its chat.
        onTap: () => trip.destination.isEmpty
            ? context.go('/chat/trip_${trip.id}')
            : context.push('/trips/${trip.id}', extra: trip),
        child: content,
      ),
    );
  }
}
