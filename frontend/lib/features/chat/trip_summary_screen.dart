import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/group_trip_summary.dart';
import '../../models/itinerary.dart';
import '../../services/group_planning_service.dart';
import '../../services/group_summary_service.dart';
import '../../services/itinerary_service.dart';
import '../../services/trip_booking_service.dart';
import 'widgets/host_action_bar.dart';
import 'widgets/summary_overview_tab.dart';
import 'widgets/summary_segmented_control.dart';
import 'widgets/summary_suggestions_tab.dart';

class TripSummaryScreen extends StatefulWidget {
  final String groupId;

  const TripSummaryScreen({super.key, required this.groupId});

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  final GroupSummaryService _summaryService = GroupSummaryService();
  final ItineraryService _itineraryService = ItineraryService();
  final TripBookingService _tripBookingService = TripBookingService();

  int _selectedTabIndex = 0;
  GroupTripSummary? _tripSummary;
  List<GroupSuggestion> _suggestions = [];
  bool _isLoading = true;
  bool _isHost = true;
  bool _isGeneratingItinerary = false;
  String _selectedSuggestionCategory = 'Favourites';

  @override
  void initState() {
    super.initState();
    _loadSummaryData();
  }

  Future<void> _loadSummaryData() async {
    final summary = await _summaryService.getTripSummary(widget.groupId);
    final suggestions = await _summaryService.getGroupSuggestions(
      widget.groupId,
    );

    final isHost = await _summaryService.isHost(widget.groupId);
    if (!mounted) return;
    setState(() {
      _tripSummary = summary;
      _suggestions = suggestions;
      _isHost = isHost;
      _isLoading = false;
    });
  }

  Future<void> _handleConfirmedDetailUpdated(
    String key,
    String newValue,
  ) async {
    await _summaryService.updateConfirmedDetail(
      groupId: widget.groupId,
      key: key,
      value: newValue,
    );
    await _loadSummaryData();
  }

  Future<void> _refreshSummary() async {
    final summary = await _summaryService.getTripSummary(widget.groupId);
    if (mounted) setState(() => _tripSummary = summary);
  }

  void _openPlanningSuggestions(String parameter) {
    setState(() {
      _selectedSuggestionCategory = parameter == 'Accommodation'
          ? 'Stays'
          : 'Flights';
      _selectedTabIndex = 1;
    });
  }

  Future<void> _handleReadyPressed() async {
    final summary = _tripSummary;
    if (!mounted ||
        summary == null ||
        !summary.isReadyToPlan ||
        _isGeneratingItinerary) {
      return;
    }

    setState(() => _isGeneratingItinerary = true);
    try {
      final trip = await _summaryService.getOrCreatePlanningTrip(summary);
      final realTripId = GroupPlanningService.tripIdFor(widget.groupId);
      if (realTripId != null) {
        // Real group: Gemini merges everyone's preferences, the ticked
        // activities and the chosen hotel/flight.
        final json = await GroupPlanningService().generateGroupItinerary(
          realTripId,
        );
        ItineraryService.saveGeneratedItinerary(
          GeneratedItinerary.fromJson(json),
        );
        if (!mounted) return;
        context.go(
          '/trips/${trip.id}',
          extra: trip.copyWith(status: 'draft'),
        );
        return;
      }
      final selections = await _summaryService.getPlanningSelections(
        widget.groupId,
      );
      final options = await _tripBookingService.getOptions(trip);
      final selectedFlightId = selections['Transport']?.firstOrNull;
      final selectedHotelId = selections['Accommodation']?.firstOrNull;
      final selectedFlight = options.flights
          .where((flight) => flight.id == selectedFlightId)
          .firstOrNull;
      final selectedHotel = options.hotels
          .where((hotel) => hotel.id == selectedHotelId)
          .firstOrNull;

      _itineraryService.getOrCreateTopPickItinerary(
        trip,
        flightTime: selectedFlight?.duration ?? '',
        selectedFlight: selectedFlight,
        selectedHotel: selectedHotel,
        onlyConfirmedTravelOptions: true,
      );

      if (!mounted) return;
      context.go('/trips/${trip.id}', extra: trip.copyWith(status: 'draft'));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to generate itinerary: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingItinerary = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trip Summary',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  SummarySegmentedControl(
                    selectedIndex: _selectedTabIndex,
                    onTabChanged: (index) {
                      setState(() => _selectedTabIndex = index);
                      if (index == 0) _refreshSummary();
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _selectedTabIndex == 0
                        ? SummaryOverviewTab(
                            tripSummary: _tripSummary!,
                            onSelectPendingDecision: _openPlanningSuggestions,
                            onTagsUpdated: () => setState(() {}),
                            groupId: widget.groupId,
                            isHost: _isHost,
                            onNeedsRefresh: _loadSummaryData,
                            onConfirmedDetailUpdated:
                                _handleConfirmedDetailUpdated,
                          )
                        : SummarySuggestionsTab(
                            suggestions: _suggestions,
                            groupId: widget.groupId,
                            tripId: widget.groupId.startsWith('trip_')
                                ? widget.groupId.substring('trip_'.length)
                                : '',
                            destinationCity: _tripSummary?.destination ?? '',
                            initialCategory: _selectedSuggestionCategory,
                            onPlanningSelectionChanged: _refreshSummary,
                          ),
                  ),
                  if (_selectedTabIndex == 0 && _tripSummary != null)
                    HostActionBar(
                      tripSummary: _tripSummary!,
                      onReadyPressed: _handleReadyPressed,
                    ),
                ],
              ),
            ),
    );
  }
}
