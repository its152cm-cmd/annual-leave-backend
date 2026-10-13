import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../models/trip.dart';
import '../../models/destination_list.dart';
import '../../models/trip_customization.dart';
import '../../models/travel_preference.dart';
import '../../core/theme/app_theme.dart';
import '../../services/itinerary_service.dart';
import '../../services/preference_service.dart';
import '../../services/trip_service.dart';
import 'trip_planning_screen.dart'
    show DefaultPreferencesOverlay, TripCustomizationSwipeOverlay;
import 'widgets/preference_action_card.dart';
import 'widgets/swipe_instructions_modal.dart';
import '../../core/widgets/ai_working.dart';
import 'widgets/voice_input_card.dart';
import '../../services/voice_recorder.dart';
import '../../services/voice_service.dart';

class TravelPreferencesScreen extends StatefulWidget {
  const TravelPreferencesScreen({
    super.key,
    this.tripDraft,
    this.preferenceService,
    this.rearrange = false,
  });

  /// true = opened from a Top Pick itinerary: regenerate it, then go back to it.
  final bool rearrange;

  final Trip? tripDraft;
  final PreferenceService? preferenceService;

  @override
  State<TravelPreferencesScreen> createState() =>
      _TravelPreferencesScreenState();
}

class _TravelPreferencesScreenState extends State<TravelPreferencesScreen> {
  late final PreferenceService _preferenceService;
  final TextEditingController _transcriptController =
      TextEditingController();
  late TravelPreference _travelPreference;

  bool _isLoading = true;
  bool _isRecording = false;
  bool _isTranscribing = false;
  final VoiceRecorder _recorder = VoiceRecorder();
  bool _isGenerating = false;
  Trip? _savedTrip; // set after the first save so retries do not create copies
  bool _createdByThisScreen = false;
  final List<String> _liked = [];
  final List<String> _disliked = [];

  @override
  void initState() {
    super.initState();
    _preferenceService =
        widget.preferenceService ?? PreferenceService();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await _preferenceService.getPreferences();

    if (!mounted) return;

    setState(() {
      _travelPreference = prefs;
      _transcriptController.text = ''; // start empty: the saved sample text was not written by the user
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _recorder.cancel();
    _transcriptController.dispose();
    super.dispose();
  }

  void _append(String text) {
    final add = text.trim();
    if (add.isEmpty) return;
    final current = _transcriptController.text.trim();
    _transcriptController.text = current.isEmpty ? add : '$current $add';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleRecording() async {
    if (_isTranscribing) return;
    if (!_isRecording) {
      try {
        await _recorder.start();
        if (mounted) setState(() => _isRecording = true);
      } catch (e) {
        _snack('$e'.replaceFirst('Exception: ', ''));
      }
      return;
    }
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });
    try {
      final clip = await _recorder.stop();
      if (clip == null) {
        _snack('We did not catch any sound. Please try again.');
      } else {
        _append(await VoiceService().transcribe(clip.bytes, clip.mime));
      }
    } catch (e) {
      _snack(e is ApiException ? e.message : 'We could not turn your voice into text. Please type instead.');
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  void _openDefaultPreferencesOverlay() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DefaultPreferencesOverlay(),
    );
  }

  Future<void> _openTripCustomizationOverlay() async {
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (_) => const SwipeInstructionsModal(),
    );

    if (proceed != true || !mounted) return;

    final city = widget.tripDraft?.destination ?? 'Kyoto, Japan';
    final stops = splitDestination(city);
    if (stops.isEmpty) stops.add('Kyoto, Japan');
    // The same number of cards from every chosen city, mixed together.
    final perCity = (18 / stops.length).ceil().clamp(4, 16).toInt();
    // The AI can take a while: show a clear "working" message so it does not look frozen.
    showAiWorkingDialog(context, 'Preparing your cards...', 'Our AI is picking places for you. This can take up to a minute.');
    List<List<PreferenceCardItem>> decks;
    try {
      decks = await Future.wait([
        for (final stop in stops)
          _preferenceService.getSwipeCards(stop).catchError((_) => <PreferenceCardItem>[]),
      ]);
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    final cards = <PreferenceCardItem>[];
    for (var i = 0; i < perCity; i++) {
      for (final deck in decks) {
        if (i < deck.length) cards.add(deck[i]);
      }
    }

    if (!mounted) return;
    if (cards.isEmpty) {
      _snack('We could not load cards for $city right now. Please try again.');
      return;
    }
    _liked.clear();
    _disliked.clear();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TripCustomizationSwipeOverlay(
        cards: cards,
        city: city,
        onDecision: (card, decision) {
          _liked.remove(card.title);
          _disliked.remove(card.title);
          if (decision == 'like') _liked.add(card.title);
          if (decision == 'dislike') _disliked.add(card.title);
        },
      ),
    );
  }

  Future<void> _generateItinerary() async {
    final draftTrip =
        widget.tripDraft ??
        Trip(
          id: 'TRIP_${DateTime.now().millisecondsSinceEpoch}',
          destination: 'Kyoto, Japan',
          dateRange: '12 - 18 October 2026',
          duration: '6 days',
          budget: 'RM 3,000 budget',
          imageUrl:
              'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=1000&auto=format&fit=crop',
          status: 'draft',
          travellerCount: 4,
          plannedBudget: 3000,
        );

    setState(() => _isGenerating = true);

    try {
      // Save the draft first so the trip gets its real id from the backend.
      final trip = await TripService().saveDraft(_savedTrip ?? draftTrip);
      if (_savedTrip == null && trip.id != draftTrip.id) {
        _createdByThisScreen = true; // this screen made the draft on the backend
      }
      _savedTrip = trip;
      if (!mounted) return;

      final generatedItinerary =
          await _preferenceService.generateItinerary(
        trip: trip,
        preference: _travelPreference.copyWith(
          transcript: _transcriptController.text.trim(),
        ),
        liked: _liked,
        disliked: _disliked,
      );

      if (!mounted) return;

      if (generatedItinerary.overview.id != trip.id) {
        throw const FormatException(
          'The generated itinerary does not match the submitted trip.',
        );
      }

      ItineraryService.saveGeneratedItinerary(
        generatedItinerary,
      );

      final generatedTrip = await TripService().saveDraft(
        trip.copyWith(
          estimatedBudget: generatedItinerary.estimatedBudget,
          budgetBreakdown: generatedItinerary.budgetBreakdown,
        ),
      );

      if (!mounted) return;

      ItineraryService.unmarkTopPick(generatedTrip.id);
      if (widget.rearrange) {
        Navigator.of(context).pop(true);
        return;
      }
      context.go(
        '/trips/${generatedTrip.id}',
        extra: generatedTrip.copyWith(status: 'draft'),
      );
    } catch (error) {
      // Generation failed: remove the draft this screen created, so a failed
      // attempt does not leave an empty trip behind.
      final orphan = _savedTrip;
      if (orphan != null && _createdByThisScreen) {
        _savedTrip = null;
        _createdByThisScreen = false;
        try {
          await TripService().deleteDraft(orphan.id);
        } catch (_) {
          // ignore: the draft stays and can be deleted later
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to generate itinerary: $error',
            ),
          ),
        );
        if (context.canPop()) {
          context.pop();
          return;
        }
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryGreen,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Travel preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              VoiceInputCard(
                controller: _transcriptController,
                isRecording: _isRecording,
                onToggleRecording: _toggleRecording,
                isTranscribing: _isTranscribing,
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _isGenerating ? null : _generateItinerary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isGenerating)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      else ...[
                        const Icon(
                          Icons.star_rate_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'Generate my itinerary',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Center(
                child: Text(
                  'Not sure what to describe preferences? Let Annual Leave guide you!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              PreferenceActionCard(
                title: 'Set Default Travel Preferences',
                subtitle:
                    'Global pace, accessibility & default settings across all trips',
                icon: Icons.settings_outlined,
                onTap: _openDefaultPreferencesOverlay,
              ),

              const SizedBox(height: 12),

              PreferenceActionCard(
                title: 'Customize This Trip',
                subtitle:
                    'Swipe cards to like, dislike, or skip specific activity options',
                icon: Icons.swipe_outlined,
                onTap: _openTripCustomizationOverlay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
