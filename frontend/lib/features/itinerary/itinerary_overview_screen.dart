import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/attraction.dart';
import '../../models/destination_list.dart';
import '../../models/itinerary.dart';
import '../../models/trip.dart';
import '../../models/trip_booking.dart';
import '../../services/itinerary_service.dart';
import '../../services/route_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/trip_service.dart';
import '../../services/trip_booking_service.dart';
import '../../services/chat_list_service.dart';
import '../../services/group_chat_service.dart';
import '../../services/group_summary_service.dart';
import '../../models/collaborator.dart';
import '../trip_planning/trip_booking_flow_screen.dart';
import '../trip_planning/trip_collaborators_screen.dart';
import 'widgets/itinerary_daycards.dart';
import 'widgets/place_detail_sheet.dart';
import 'widgets/day_map_view.dart';
import 'widgets/itinerary_side_panel.dart';
import 'widgets/itinerary_calendar_view.dart';
import 'widgets/panel_state.dart';
import 'replan_issue_screen.dart';
import '../trip_planning/travel_preferences.dart';
import '../trip_planning/trip_budget_lines_screen.dart';
import 'widgets/group_review_day_list.dart';
import '../../services/itinerary_review_service.dart';

class ItineraryOverviewScreen extends StatefulWidget {
  final String itineraryId;
  final int initialDayIndex;
  final Trip? initialTrip;
  final GeneratedItinerary? generatedItinerary;

  const ItineraryOverviewScreen({
    super.key,
    required this.itineraryId,
    this.initialDayIndex = 0,
    this.initialTrip,
    this.generatedItinerary,
  });

  @override
  State<ItineraryOverviewScreen> createState() =>
      _ItineraryOverviewScreenState();
}

class _ItineraryOverviewScreenState extends State<ItineraryOverviewScreen> {
  final ItineraryService _itineraryService = ItineraryService();
  final RecommendationService _recommendationService = RecommendationService();
  final TripBookingService _bookingService = TripBookingService();
  bool _openingBudget = false;
  final ItineraryReviewService _reviewService = ItineraryReviewService();
  ItineraryReview? _review;
  bool _showFeedback = false; // host: look at the group's feedback instead of editing

  /// Only the host edits a group itinerary; everyone else reviews it.
  bool get _canEdit {
    final review = _review;
    if (review != null) return review.canEdit;
    final trip = widget.initialTrip;
    final looksGroup = trip != null &&
        (trip.travellerCount > 1 || trip.collaborators.isNotEmpty);
    return !looksGroup;
  }

  Future<void> _loadReview() async {
    final review = await _reviewService.load(widget.itineraryId);
    if (mounted && review != null) setState(() => _review = review);
  }

  late Future<ItineraryOverview> _itineraryFuture;
  late Future<List<ItineraryDetailItem>> _dayItemsFuture;
  late Future<List<({String date, ItineraryDetailItem item})>>
  _allTripItemsFuture;
  late Future<List<Attraction>> _attractionsFuture;

  int _selectedTabIndex = 0;
  final RouteService _routeService = RouteService();
  Map<String, TransferLeg> _legs = {};
  String _legSignature = '';
  String _dayCity = '';

  /// Tapping a stop opens the AI summary and the Google Maps link.
  void _openItemDetail(ItineraryDetailItem item) {
    final type = item.type.toLowerCase();
    if (const {'flight', 'transit', 'transport'}.contains(type)) return;
    final kind = const {'hotel', 'accommodation'}.contains(type)
        ? 'hotel'
        : const {'food', 'meal', 'restaurant', 'dining'}.contains(type)
            ? 'food'
            : 'attraction';
    final name = item.title
        .replaceFirst(
          RegExp(r'^(check[- ]?in|check[- ]?out|lunch|dinner|breakfast|brunch)\s*(at|:|-)?\s*',
              caseSensitive: false),
          '',
        )
        .trim();
    final city = item.city.isNotEmpty
        ? item.city
        : (_dayCity.isNotEmpty ? _dayCity : (widget.initialTrip?.destination ?? ''));
    showPlaceDetailSheet(
      context,
      name: name.isEmpty ? item.title : name,
      city: city,
      kind: kind,
      subtitle: item.subtitle,
    );
  }

  bool _showMap = false;

  /// The city the open day is in (a multi-city trip changes city from day to day).
  Future<String> _resolveDayCity() async {
    final overview = await _itineraryService.getItineraryOverview(
      widget.itineraryId,
      trip: widget.initialTrip,
    );
    var city = overview.destinationCity ?? overview.destination;
    final cities = tripCities(overview.destination);
    for (final d in overview.days) {
      if (d.dayNumber == _selectedTabIndex) {
        final loc = d.location.toLowerCase();
        for (final c in cities) {
          if (loc.contains(c.toLowerCase())) city = c;
        }
      }
    }
    return city;
  }

  /// Looks up the real walking / taxi time between the stops of the open day.
  Future<void> _loadLegs(List<ItineraryDetailItem> items) async {
    final signature =
        '$_selectedTabIndex|${items.map((i) => '${i.id}:${i.title}').join(',')}';
    if (signature == _legSignature) return;
    _legSignature = signature;
    if (items.length < 2) {
      if (_legs.isNotEmpty && mounted) setState(() => _legs = {});
      return;
    }
    try {
      final city = await _resolveDayCity();
      _dayCity = city;
      final legs = await _routeService.legs(city, items);
      if (!mounted || signature != _legSignature) return;
      setState(() => _legs = legs);
    } catch (_) {
      if (mounted && signature == _legSignature) setState(() => _legs = {});
    }
  }
  PanelState _panelState = PanelState.hidden;
  String _selectedCategory = 'Attractions';

  @override
  void initState() {
    super.initState();

    _selectedTabIndex = widget.initialDayIndex;
    _loadReview();
    if (widget.generatedItinerary == null) ItineraryService.forget(widget.itineraryId);
    _panelState = widget.initialDayIndex > 0
        ? PanelState.peek
        : PanelState.hidden;

    _itineraryFuture = widget.generatedItinerary == null
        ? _itineraryService.getItineraryOverview(
            widget.itineraryId,
            trip: widget.initialTrip,
          )
        : Future.value(widget.generatedItinerary!.overview);

    if (widget.generatedItinerary != null) {
      ItineraryService.saveGeneratedItinerary(widget.generatedItinerary!);
    }

    _dayItemsFuture = _loadDayItems(
      widget.initialDayIndex > 0 ? widget.initialDayIndex : 1,
    );
    _allTripItemsFuture = _loadAllTripItems();

    _attractionsFuture = _itineraryFuture.then(
      (data) => _recommendationService.getAttractionsForCity(
        data.destinationCity ?? data.destination,
      ),
    );
  }

  void _onTabSelected(int index) {
    if (_selectedTabIndex == index) return;

    setState(() {
      _selectedTabIndex = index;

      if (index > 0) {
        _dayItemsFuture = _loadDayItems(index);
        _panelState = PanelState.peek;
      } else {
        _panelState = PanelState.hidden;
      }
    });
  }

  Future<List<ItineraryDetailItem>> _loadDayItems(int dayNumber) {
    return _itineraryService.getDayDetailItems(widget.itineraryId, dayNumber);
  }

  Future<List<({String date, ItineraryDetailItem item})>>
  _loadAllTripItems() async {
    final overview = await _itineraryService.getItineraryOverview(
      widget.itineraryId,
      trip: widget.initialTrip,
    );
    final itemsByDay = await Future.wait(
      overview.days.map(
        (day) => _itineraryService.getDayDetailItems(
          widget.itineraryId,
          day.dayNumber,
        ),
      ),
    );
    return [
      for (var index = 0; index < overview.days.length; index++)
        for (final item in itemsByDay[index])
          (date: overview.days[index].dateString, item: item),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tripStatus = widget.initialTrip?.status.trim().toLowerCase();
    final isUpcomingTrip = tripStatus == 'upcoming';

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: SafeArea(
        child: FutureBuilder<ItineraryOverview>(
          future: _itineraryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                child: Text(
                  'Failed to load itinerary.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              );
            }

            final data = snapshot.data!;

            return LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(data),
                      const SizedBox(height: 16),
                      _buildFilterTabs(data.durationDays),
                      const SizedBox(height: 12),
                      _buildTripActions(),
                      const SizedBox(height: 8),
                      if (isUpcomingTrip)
                        FutureBuilder<
                          List<({String date, ItineraryDetailItem item})>
                        >(
                          future: _allTripItemsFuture,
                          builder: (context, tripItemsSnapshot) =>
                              _buildStickyTripInfo(
                                data,
                                tripItemsSnapshot.data ?? const [],
                              ),
                        ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _selectedTabIndex == 0
                            ? _buildOverviewList(data)
                            : _buildDayTimelineView(),
                      ),
                    ],
                  ),
                  if (_canEdit &&
                      !_showFeedback &&
                      _selectedTabIndex > 0 &&
                      _panelState != PanelState.hidden)
                    FutureBuilder<List<Attraction>>(
                      future: _attractionsFuture,
                      builder: (context, attractionSnapshot) {
                        return ItinerarySidePanel(
                          panelState: _panelState,
                          availableHeight: constraints.maxHeight,
                          attractions: attractionSnapshot.data ?? [],
                          attractionsLoading: attractionSnapshot.connectionState != ConnectionState.done,
                          categories: [
                            ...(data.categories ??
                                ['Flights', 'Hotels', 'Attractions', 'Food']),
                            if (!(data.categories ?? const <String>[]).contains('Saved'))
                              'Saved',
                          ],
                          selectedCategory: _selectedCategory,
                          originCode: data.originCode ?? '',
                          destinationCode: data.destinationCode ?? '',
                          originCity: data.originCity ?? '',
                          destinationCity:
                              data.destinationCity ?? data.destination,
                          tripId: widget.itineraryId,
                          cities: tripCities(data.destination),
                          onPanelStateChanged: (state) =>
                              setState(() => _panelState = state),
                          onCategorySelected: (category) => setState(() {
                            _selectedCategory = category;
                            _panelState = PanelState.expanded;
                          }),
                          onAddToTimeline: _addScheduleItem,
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(ItineraryOverview data) {
    final headerTitle = data.title;
    final headerSubtitle =
        '${data.destination} · ${data.dateRange} · ${data.durationDays} days';
    // "Add members" only makes sense for a group trip, not a solo one.
    final initialTrip = widget.initialTrip;
    final isGroupTrip =
        initialTrip != null &&
        (initialTrip.travellerCount > 1 || initialTrip.collaborators.isNotEmpty);
    final canAddMembers =
        isGroupTrip &&
        initialTrip.status.trim().toLowerCase() == 'draft' &&
        !initialTrip.generatedFromGroupChat;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headerTitle,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/trips/${widget.itineraryId}/checklist'),
                    icon: const Icon(Icons.check_box_outlined, size: 16),
                    label: const Text('Checklist'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      side: const BorderSide(color: AppTheme.primaryGreen),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 7,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  if (canAddMembers) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Add members',
                      onPressed: _openAddMembersFlow,
                      style: IconButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.person_add_alt_1_outlined,
                        color: AppTheme.primaryGreen,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              headerSubtitle,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripActions() {
    final tripStatus = widget.initialTrip?.status.trim().toLowerCase();
    final showBudgetAction = tripStatus != 'upcoming' && _canEdit;
    final t = widget.initialTrip;
    // Splitting bills only makes sense with other people; hide it for a solo trip.
    final isGroup = t == null ||
        t.travellerCount > 1 ||
        t.collaborators.isNotEmpty ||
        t.generatedFromGroupChat;
    final showFinancialSummary = tripStatus != 'draft' && isGroup;

    return Column(children: [
      if (_showRearrange) _buildRearrangeCard(),
      Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (tripStatus == 'upcoming' && _canEdit) ...[
            Expanded(
              child: SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => ReplanIssueScreen(
                          itineraryId: widget.itineraryId,
                          trip: widget.initialTrip!,
                        ),
                      ),
                    );
                    if (changed == true && mounted) {
                      setState(() {
                        _itineraryFuture = _itineraryService.getItineraryOverview(
                          widget.itineraryId,
                          trip: widget.initialTrip,
                        );
                        if (_selectedTabIndex > 0) {
                          _dayItemsFuture = _loadDayItems(_selectedTabIndex);
                        }
                        _allTripItemsFuture = _loadAllTripItems();
                      });
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 17),
                  label: const Text(
                    'Replan Trip',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1010),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (showBudgetAction) ...[
            Expanded(
              child: SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _openingBudget ? null : _proceedToBudget,
                  icon: _openingBudget
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 17,
                        ),
                  label: const Text('Proceed to budget'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (tripStatus == 'upcoming') ...[
            const SizedBox(width: 10),
            Material(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(14),
              child: IconButton(
                tooltip: 'Trip budget and bookings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TripBudgetLinesScreen(tripId: widget.itineraryId),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 19),
                constraints: const BoxConstraints.tightFor(width: 42, height: 42),
              ),
            ),
          ],
          if (showFinancialSummary) ...[
            const SizedBox(width: 10),
            Material(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(14),
              child: IconButton(
                tooltip: 'Financial summary',
                onPressed: () => context.push(
                  '/trips/${widget.itineraryId}/financial-summary',
                  extra: widget.initialTrip,
                ),
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 19,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 42,
                  height: 42,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    ),
    ]);
  }

  bool get _showRearrange =>
      _canEdit &&
      widget.initialTrip != null &&
      ItineraryService.isTopPick(widget.itineraryId) &&
      (widget.initialTrip!.status.trim().toLowerCase() == 'draft');

  Widget _buildRearrangeCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Want this to fit you better?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Set your preferences and we will rearrange this itinerary around them.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _rearrangeByPreferences,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Rearrange based on my preferences'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
                side: const BorderSide(color: AppTheme.primaryGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rearrangeByPreferences() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TravelPreferencesScreen(
          tripDraft: widget.initialTrip,
          rearrange: true,
        ),
      ),
    );
    if (changed == true && mounted) {
      setState(() {
        _itineraryFuture = _itineraryService.getItineraryOverview(
          widget.itineraryId,
          trip: widget.initialTrip,
        );
        if (_selectedTabIndex > 0) {
          _dayItemsFuture = _loadDayItems(_selectedTabIndex);
        }
        _allTripItemsFuture = _loadAllTripItems();
      });
    }
  }

  Widget _buildStickyTripInfo(
    ItineraryOverview data,
    List<({String date, ItineraryDetailItem item})> tripItems,
  ) {
    final flightEntries = tripItems
        .where((entry) => entry.item.type == 'flight')
        .toList();
    final destinationCode = (data.destinationCode ?? '').trim();
    final originCity = data.originCity ?? 'Home';
    final destinationCity = data.destinationCity ?? data.destination;
    final outboundFlightEntry = flightEntries.where((entry) {
      final text = '${entry.item.title} ${entry.item.subtitle}'.toLowerCase();
      final isReturnFlight = text.contains('return') ||
          text.contains('kuala lumpur') ||
          text.contains('home');
      if (isReturnFlight) return false;
      if (destinationCode.isNotEmpty) {
        return text.contains(destinationCode.toLowerCase());
      }
      return text.contains(data.destination.toLowerCase()) ||
          text.contains(destinationCity.toLowerCase());
    }).firstOrNull ??
        flightEntries.firstOrNull;

    final hotelEntries = tripItems
        .where((entry) => entry.item.type == 'hotel')
        .toList();
    final currentStayHotelEntry = hotelEntries
            .where(
              (entry) => !entry.item.title.toLowerCase().contains('check-out'),
            )
            .firstOrNull ??
        hotelEntries.firstOrNull;
    final checkIn = hotelEntries
        .where((entry) => entry.item.title.toLowerCase().contains('check-in'))
        .firstOrNull;
    final checkOut = hotelEntries
        .where((entry) => entry.item.title.toLowerCase().contains('check-out'))
        .firstOrNull;
    final hotelName = currentStayHotelEntry == null
        ? ''
        : currentStayHotelEntry.item.subtitle.split('·').first.trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildStickyInfoRow(
            icon: Icons.flight_outlined,
            color: const Color(0xFF3D78B5),
            label: 'Flight',
            value: outboundFlightEntry == null
                ? 'No flight added'
                : '$originCity → ${destinationCity.split(',').first.trim()} · ${outboundFlightEntry.date} ${outboundFlightEntry.item.timeStart}',
          ),
          const Divider(height: 12),
          _buildStickyInfoRow(
            icon: Icons.hotel_outlined,
            color: const Color(0xFF8054A5),
            label: 'Hotel',
            value: currentStayHotelEntry == null
                ? 'No hotel added'
                : [
                    hotelName.isEmpty ? currentStayHotelEntry.item.title : hotelName,
                    if (checkIn != null)
                      'Check-in ${checkIn.date} ${checkIn.item.timeStart}',
                    if (checkOut != null)
                      'Check-out ${checkOut.date} ${checkOut.item.timeStart}',
                  ].join(' · '),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyInfoRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Future<void> _openAddMembersFlow() async {
    final trip =
        widget.initialTrip ?? await TripService().getTrip(widget.itineraryId);
    if (!mounted) return;
    if (trip.status.trim().toLowerCase() != 'draft' ||
        trip.generatedFromGroupChat) {
      return;
    }

    final groupId = 'trip_${trip.id}';
    final storedMembers = [
      ...await GroupChatService().getGroupMembers(groupId),
      ...?GroupSummaryService.pendingByGroup[groupId],
    ];
    final selectedCollaborators = storedMembers.isEmpty
        ? trip.collaborators
        : storedMembers
              .where((member) => !member.isMe)
              .map(
                (member) => Collaborator(
                  id: member.id,
                  name: member.name,
                  email: '',
                  avatarUrl: member.avatarUrl,
                  isAdded: true,
                ),
              )
              .toList();
    final existingCollaboratorIds = selectedCollaborators
        .map((collaborator) => collaborator.id)
        .toSet();

    final selectedMembers = await Navigator.of(context).push<List<Collaborator>>(
      MaterialPageRoute<List<Collaborator>>(
        builder: (_) => TripCollaboratorsScreen(
          startWithNoMembers: true,
          returnSelectedMembers: true,
          existingCollaboratorIds: existingCollaboratorIds,
          initialCollaborators: selectedCollaborators,
          screenTitle: 'Add trip members',
        ),
      ),
    );
    if (!mounted || selectedMembers == null || selectedMembers.isEmpty) return;

    final createdGroupId = await ChatListService().createTripGroupChat(trip);

    // save the group and the invitations for real (expenses use these people)
    try {
      await TripService().createGroupChat(
        trip.id,
        selectedMembers.map((member) => member.id).toList(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("The chat was created, but the invitations couldn't be saved."),
          ),
        );
      }
    }

    // Invited people show in the chat only after they accept.
    await GroupSummaryService().syncMembers(createdGroupId);
    if (!mounted) return;
    context.go('/chat/$createdGroupId');
  }

  Future<Trip> _resolveTripForBudget() async {
    if (widget.initialTrip != null) return widget.initialTrip!;

    final overview = await _itineraryFuture;
    final durationDays = overview.durationDays > 0 ? overview.durationDays : 1;
    final plannedBudget = 2400.0 + (durationDays * 450.0);

    return Trip(
      id: widget.itineraryId,
      destination: overview.destination,
      dateRange: overview.dateRange,
      duration: '$durationDays days',
      budget: 'RM ${plannedBudget.round()} budget',
      imageUrl: '',
      status: 'draft',
      travellerCount: 2,
      plannedBudget: plannedBudget,
      estimatedBudget: plannedBudget,
      minimumBudget: plannedBudget * 0.7,
      originCity: overview.originCity ?? 'Kuala Lumpur',
      budgetBreakdown: {
        'Transport': plannedBudget * 0.28,
        'Accommodation': plannedBudget * 0.32,
        'Food': plannedBudget * 0.16,
        'Activities': plannedBudget * 0.16,
        'Other expenses': plannedBudget * 0.08,
      },
    );
  }

  Future<void> _proceedToBudget() async {
    if (_openingBudget) return;

    setState(() => _openingBudget = true);

    try {
      final trip = await _resolveTripForBudget();

      if (!mounted) return;

      final options = await _bookingService.getOptions(trip);
      final tripItems = await _allTripItemsFuture;

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TripBookingBudgetScreen(
            trip: trip,
            options: options,
            selection: const TripBookingSelection(),
            bookingService: _bookingService,
            itineraryItems: tripItems.map((entry) => entry.item).toList(),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open trip budget: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _openingBudget = false);
      }
    }
  }

  Widget _buildFilterTabs(int totalDays) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: totalDays + 1,
        itemBuilder: (context, index) {
          final isSelected = _selectedTabIndex == index;
          final label = index == 0 ? 'Overview' : 'Day $index';

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textDark,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.primaryColor,
              backgroundColor: Colors.grey[200],
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide.none,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              onSelected: (selected) {
                if (selected) {
                  _onTabSelected(index);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewList(ItineraryOverview data) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: data.days.length,
      itemBuilder: (context, index) {
        return DayOverviewCard(
          dayData: data.days[index],
          onTap: () => _onTabSelected(data.days[index].dayNumber),
        );
      },
    );
  }

  Widget _buildDayTimelineView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Timeline'), icon: Icon(Icons.view_timeline_outlined, size: 16)),
              ButtonSegment(value: true, label: Text('Map'), icon: Icon(Icons.map_outlined, size: 16)),
            ],
            selected: {_showMap},
            onSelectionChanged: (v) => setState(() => _showMap = v.first),
          ),
        ),
        Expanded(child: _showMap ? _buildDayMap() : _buildDayTimelineContent()),
      ],
    );
  }

  Widget _buildDayMap() {
    return FutureBuilder<List<ItineraryDetailItem>>(
      future: _dayItemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        final items = [...?snapshot.data]
          ..sort((a, b) => _minutesAfterMidnight(a.timeStart).compareTo(_minutesAfterMidnight(b.timeStart)));
        return FutureBuilder<String>(
          future: _resolveDayCity(),
          builder: (context, citySnap) {
            if (!citySnap.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }
            return DayMapView(
              key: ValueKey('map-$_selectedTabIndex-${items.map((i) => '${i.id}:${i.title}').join(',')}'),
              city: citySnap.data!,
              items: items,
              onOpen: _openItemDetail,
            );
          },
        );
      },
    );
  }

  Widget _buildDayTimelineContent() {
    return FutureBuilder<List<ItineraryDetailItem>>(
      future: _dayItemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        final items = [...?snapshot.data]
          ..sort(
            (first, second) =>
                _minutesAfterMidnight(first.timeStart)
                    .compareTo(_minutesAfterMidnight(second.timeStart)),
          );

        WidgetsBinding.instance.addPostFrameCallback((_) => _loadLegs(items));
        final review = _review;
        if (review == null && !_canEdit) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        if (review != null && review.isGroup && (!review.isHost || _showFeedback)) {
          return Column(
            children: [
              if (review.isHost) _feedbackToggle(),
              Expanded(
                child: GroupReviewDayList(
                  tripId: widget.itineraryId,
                  items: items,
                  review: review,
                  legs: _legs,
                  onOpen: _openItemDetail,
                  onChanged: _loadReview,
                ),
              ),
            ],
          );
        }

        final calendar = ItineraryCalendarView(
          items: items,
          legs: _legs,
          onOpen: _openItemDetail,
          onDrop: (item, y) => _scheduleItemAt(item, y),
          onDelete: _deleteScheduleItem,
          onLongPressDelete: _confirmDeleteScheduleItem,
          onAdjustDuration: _adjustAttractionDuration,
        );
        if (review != null && review.isGroup && review.isHost) {
          return Column(children: [_feedbackToggle(), Expanded(child: calendar)]);
        }
        return calendar;
      },
    );
  }

  Widget _feedbackToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('Edit'), icon: Icon(Icons.edit_outlined, size: 16)),
          ButtonSegment(value: true, label: Text('Group feedback'), icon: Icon(Icons.forum_outlined, size: 16)),
        ],
        selected: {_showFeedback},
        onSelectionChanged: (v) {
          setState(() => _showFeedback = v.first);
          if (v.first) _loadReview();
        },
      ),
    );
  }

  /// The "Add to day" button. Flights and hotels keep their own time; anything
  /// else goes into the first free slot of the day, and can then be dragged to
  /// the time the user prefers.
  Future<void> _addScheduleItem(ItineraryDetailItem item) async {
    if (item.isFixed) {
      final initialMinute = _minutesAfterMidnight(item.timeStart);
      await _scheduleItemAt(
        item,
        ((initialMinute - 6 * 60) / 60 * 72),
        showConfirmation: false,
      );
    } else {
      final dayItems = await _itineraryService.getDayDetailItems(
        widget.itineraryId,
        _selectedTabIndex,
      );
      if (!mounted) return;
      final start = _firstFreeStart(
        dayItems,
        _itemDurationMinutes(item),
        excludingId: item.id,
      );
      if (start == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No free time left on this day. Remove an event first, or drag this one onto the calendar.',
            ),
          ),
        );
        return;
      }
      await _scheduleItemAt(
        item,
        (start - 6 * 60) / 60 * 72,
        showConfirmation: true,
      );
    }

    if (mounted) setState(() => _panelState = PanelState.peek);
  }

  /// Earliest start (in minutes after midnight) with no clash, looking at
  /// 8:00 AM - 10:00 PM first, then the rest of the calendar. null = no room.
  int? _firstFreeStart(
    List<ItineraryDetailItem> items,
    int durationMinutes, {
    required String excludingId,
  }) {
    bool isFree(int start) => !_hasScheduleOverlap(
      items,
      start,
      start + durationMinutes,
      excludingId: excludingId,
    );

    for (var start = 8 * 60; start + durationMinutes <= 22 * 60; start += 30) {
      if (isFree(start)) return start;
    }
    for (var start = 6 * 60; start + durationMinutes <= 24 * 60; start += 30) {
      if (isFree(start)) return start;
    }
    return null;
  }

  /// On a multi-city trip, a place must be in the same city as the day it is added to.
  /// Returns the message to show, or null when it is fine.
  Future<String?> _cityMismatch(ItineraryDetailItem item, int dayNumber) async {
    final itemCity = item.city.trim().toLowerCase();
    if (itemCity.isEmpty) return null;
    try {
      final overview = await _itineraryService.getItineraryOverview(
        widget.itineraryId,
        trip: widget.initialTrip,
      );
      final cities = tripCities(overview.destination);
      if (cities.length < 2) return null;
      final day = overview.days.where((d) => d.dayNumber == dayNumber);
      if (day.isEmpty) return null;
      final dayLocation = day.first.location.toLowerCase();
      final dayCity = cities.where((c) => dayLocation.contains(c.toLowerCase()));
      if (dayCity.isEmpty) return null;
      final dayName = dayCity.first;
      if (itemCity.contains(dayName.toLowerCase()) ||
          dayName.toLowerCase().contains(itemCity)) {
        return null;
      }
      return '"${item.title}" is in ${item.city}, but Day $dayNumber is in $dayName. '
          'Please choose a place in $dayName, or open a day that is in ${item.city}.';
    } catch (_) {
      return null;
    }
  }

  Future<void> _scheduleItemAt(
    ItineraryDetailItem item,
    double canvasY, {
    bool showConfirmation = true,
  }) async {
    final dayNumber = _selectedTabIndex;
    var currentItems = await _itineraryService.getDayDetailItems(
      widget.itineraryId,
      dayNumber,
    );
    if (!mounted) return;
    final alreadyScheduled = currentItems.any((entry) => entry.id == item.id);
    var flightDaysToReplace = <int>[];

    if (!alreadyScheduled && item.type != 'flight') {
      final wrongCity = await _cityMismatch(item, dayNumber);
      if (wrongCity != null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(wrongCity)));
        }
        return;
      }
    }

    if (item.type == 'flight' && !alreadyScheduled) {
      final itinerary = await _itineraryService.getItineraryOverview(
        widget.itineraryId,
        trip: widget.initialTrip,
      );
      final flightDays = <int>[];
      for (final day in itinerary.days) {
        final dayItems = await _itineraryService.getDayDetailItems(
          widget.itineraryId,
          day.dayNumber,
        );
        if (dayItems.any((entry) => entry.type == 'flight')) {
          flightDays.add(day.dayNumber);
        }
      }
      if (!mounted) return;

      if (flightDays.isNotEmpty) {
        final replaceFlight = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Replace existing flight?'),
            content: const Text(
              'Adding this flight will replace your current flight.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Replace Flight'),
              ),
            ],
          ),
        );
        if (replaceFlight != true || !mounted) return;
        flightDaysToReplace = flightDays;
        currentItems = currentItems
            .where((entry) => entry.type != 'flight')
            .toList();
      }
    }

    if (!mounted) return;
    if (item.isFixed && alreadyScheduled) return;
    final startMinute = item.isFixed
        ? _minutesAfterMidnight(item.timeStart)
        : (6 * 60 + (canvasY / 72 * 60 / 30).round() * 30)
              .clamp(6 * 60, 23 * 60)
              .toInt();
    final endMinute = item.isFixed
        ? _minutesAfterMidnight(item.timeEnd)
        : (startMinute + _itemDurationMinutes(item))
              .clamp(startMinute + 30, 24 * 60)
              .toInt();

    if (_hasScheduleOverlap(
      currentItems,
      startMinute,
      endMinute,
      excludingId: item.id,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This time overlaps another event.')),
      );
      return;
    }

    for (final flightDay in flightDaysToReplace) {
      final dayItems = await _itineraryService.getDayDetailItems(
        widget.itineraryId,
        flightDay,
      );
      await _itineraryService.saveDayDetailItems(
        widget.itineraryId,
        flightDay,
        dayItems.where((entry) => entry.type != 'flight').toList(),
      );
    }

    final scheduledItem = item.copyWith(
      timeStart: _formatScheduleTime(startMinute),
      timeEnd: _formatScheduleTime(endMinute),
    );
    final updatedItems =
        [...currentItems.where((entry) => entry.id != item.id), scheduledItem]
          ..sort(
            (first, second) =>
                _minutesAfterMidnight(first.timeStart)
                    .compareTo(_minutesAfterMidnight(second.timeStart)),
          );
    await _itineraryService.saveDayDetailItems(
      widget.itineraryId,
      dayNumber,
      updatedItems,
    );
    if (!mounted) return;
    setState(() {
      _panelState = PanelState.peek;
      _dayItemsFuture = Future.value(updatedItems);
      _allTripItemsFuture = _loadAllTripItems();
    });

    if (showConfirmation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          content: Text(
            '${item.title} scheduled for ${scheduledItem.timeStart}.',
          ),
        ),
      );
    }
  }

  int _itemDurationMinutes(ItineraryDetailItem item) {
    final durationMatch = RegExp(
      r'(?:(\d+)\s*(?:h|hr|hour)s?)?\s*(?:(\d+)\s*(?:m|min|minute)s?)?',
      caseSensitive: false,
    ).firstMatch(item.duration);

    if (durationMatch != null &&
        (durationMatch.group(1) != null || durationMatch.group(2) != null)) {
      final hours = int.tryParse(durationMatch.group(1) ?? '') ?? 0;

      final minutes = int.tryParse(durationMatch.group(2) ?? '') ?? 0;

      return (hours * 60 + minutes).clamp(30, 24 * 60).toInt();
    }

    return 60;
  }

  bool _hasScheduleOverlap(
    List<ItineraryDetailItem> items,
    int startMinute,
    int endMinute, {
    required String excludingId,
  }) => items.any((entry) {
    if (entry.id == excludingId) return false;
    final existingStart = _minutesAfterMidnight(entry.timeStart);
    final existingEnd = _minutesAfterMidnight(entry.timeEnd);
    return startMinute < existingEnd && endMinute > existingStart;
  });

  Future<void> _deleteScheduleItem(ItineraryDetailItem item) async {
    final dayNumber = _selectedTabIndex;
    final currentItems = await _itineraryService.getDayDetailItems(
      widget.itineraryId,
      dayNumber,
    );
    final updatedItems = currentItems
        .where((entry) => entry.id != item.id)
        .toList();
    if (updatedItems.length == currentItems.length) return;

    await _itineraryService.saveDayDetailItems(
      widget.itineraryId,
      dayNumber,
      updatedItems,
    );
    if (!mounted) return;
    setState(() {
      _dayItemsFuture = Future.value(updatedItems);
      _allTripItemsFuture = _loadAllTripItems();
    });
  }

  Future<void> _confirmDeleteScheduleItem(ItineraryDetailItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete itinerary item?'),
        content: Text('Remove "${item.title}" from this day?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) await _deleteScheduleItem(item);
  }

  Future<void> _adjustAttractionDuration(ItineraryDetailItem item) async {
    if (item.isFixed) return;
    final dayNumber = _selectedTabIndex;
    final items = await _itineraryService.getDayDetailItems(
      widget.itineraryId,
      dayNumber,
    );
    final startMinute = _minutesAfterMidnight(item.timeStart);
    final minimumMinutes = _itemDurationMinutes(
      item.copyWith(duration: item.minimumDuration),
    );
    final nextStart = items
        .where((entry) => entry.id != item.id)
        .map((entry) => _minutesAfterMidnight(entry.timeStart))
        .where((minute) => minute > startMinute)
        .fold<int>(
          24 * 60,
          (nearest, minute) => minute < nearest ? minute : nearest,
        );
    final maximumMinutes = nextStart - startMinute;

    if (!mounted) return;
    if (maximumMinutes <= minimumMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No additional time is available here.')),
      );
      return;
    }

    var selectedMinutes = _itemDurationMinutes(item)
        .clamp(minimumMinutes, maximumMinutes)
        .toInt();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adjust activity duration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_formatDuration(selectedMinutes)),
              Slider(
                value: selectedMinutes.toDouble(),
                min: minimumMinutes.toDouble(),
                max: maximumMinutes.toDouble(),
                divisions: ((maximumMinutes - minimumMinutes) ~/ 15).clamp(
                  1,
                  100,
                ),
                label: _formatDuration(selectedMinutes),
                onChanged: (value) =>
                    setDialogState(() => selectedMinutes = value.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selectedMinutes),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;

    final updatedItem = item.copyWith(
      duration: _formatDuration(result),
      timeEnd: _formatScheduleTime(startMinute + result),
    );
    if (_hasScheduleOverlap(
      items,
      startMinute,
      startMinute + result,
      excludingId: item.id,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This time overlaps another event.')),
      );
      return;
    }
    final updatedItems = items
        .map((entry) => entry.id == item.id ? updatedItem : entry)
        .toList();
    await _itineraryService.saveDayDetailItems(
      widget.itineraryId,
      dayNumber,
      updatedItems,
    );
    if (!mounted) return;
    setState(() {
      _dayItemsFuture = Future.value(updatedItems);
      _allTripItemsFuture = _loadAllTripItems();
    });
  }

  String _formatDuration(int durationMinutes) {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours hr';
    return '$hours hr $minutes min';
  }

  int _minutesAfterMidnight(String time) {
    final match = RegExp(
      r'^\s*(\d{1,2}):(\d{2})\s*(AM|PM)\s*$',
      caseSensitive: false,
    ).firstMatch(time);

    if (match == null) return 6 * 60;

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);

    if (hour == 12) {
      hour = 0;
    }

    if (match.group(3)!.toUpperCase() == 'PM') {
      hour += 12;
    }

    return hour * 60 + minute;
  }

  String _formatScheduleTime(int minuteOfDay) {
    final hour = minuteOfDay ~/ 60;
    final minute = minuteOfDay % 60;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final meridiem = hour < 12 ? 'AM' : 'PM';

    return '$displayHour:${minute.toString().padLeft(2, '0')} $meridiem';
  }
}
