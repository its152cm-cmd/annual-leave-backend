import 'package:flutter/material.dart';
import 'package:homempage/core/theme/app_theme.dart';
import 'package:homempage/features/trip_planning/travel_preferences.dart';
import 'package:homempage/features/trip_planning/trip_collaborators_screen.dart';
import 'package:homempage/models/trip.dart';

import 'widgets/budget_range_slider.dart';
import 'widgets/location_dropdown_field.dart';
import 'widgets/multi_city_field.dart';
import 'widgets/travellers_counter_card.dart';
import 'widgets/trip_date_picker_card.dart';
import 'widgets/trip_style_selector.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  bool _isSoloSelected = true;
  String? _selectedFrom;
  String? _selectedTo;
  int _numberOfTravellers = 4;
  RangeValues _budgetRange = const RangeValues(500, 3000);
  // The two boxes are independent while typing, so read them in the right order.
  double get _lowBudget => _budgetRange.start < _budgetRange.end ? _budgetRange.start : _budgetRange.end;
  double get _highBudget => _budgetRange.start < _budgetRange.end ? _budgetRange.end : _budgetRange.start;
  // Nothing is pre-filled: the person has to choose the dates.
  DateTimeRange? _selectedDates;

  /// From, To and the dates are required before moving on.
  bool get _ready =>
      (_selectedFrom ?? '').trim().isNotEmpty &&
      (_selectedTo ?? '').trim().isNotEmpty &&
      _selectedDates != null;

  /// [undecided]: a group trip, where the group chooses the destination,
  /// dates and budget together later, so nothing is filled in yet.
  Trip _createTripDraft({bool undecided = false}) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final picked = _selectedDates ??
        DateTimeRange(
          start: DateTime.now(),
          end: DateTime.now().add(const Duration(days: 1)),
        );
    final start = picked.start;
    final end = picked.end;
    final dateRange =
        '${start.day} ${months[start.month - 1]} - '
        '${end.day} ${months[end.month - 1]} ${end.year}';

    return Trip(
      id: 'TRIP_${DateTime.now().millisecondsSinceEpoch}',
      destination: undecided ? '' : (_selectedTo ?? 'Kyoto, Japan'),
      dateRange: undecided ? '' : dateRange,
      duration: undecided ? '' : '${picked.duration.inDays} days',
      budget: undecided
          ? ''
          : 'RM ${_lowBudget.round()} - RM ${_highBudget.round()} budget',
      imageUrl: '',
      status: 'draft',
      travellerCount: _isSoloSelected ? 1 : _numberOfTravellers,
      minimumBudget: undecided ? 0 : _lowBudget,
      plannedBudget: undecided ? 0 : _highBudget,
      originCity: _selectedFrom ?? 'Kuala Lumpur',
    );
  }

  Future<void> _handleGroupSelected() async {
    setState(() => _isSoloSelected = false);

    final returnToGroupTripForm = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TripCollaboratorsScreen(
              tripDraft: _createTripDraft(undecided: true),
            ),
      ),
    );

    if (mounted) {
      setState(
        () => _isSoloSelected = returnToGroupTripForm == true ? false : true,
      );
    }
  }

  void _handleNext() {
    if (_isSoloSelected) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TravelPreferencesScreen(tripDraft: _createTripDraft()),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TripCollaboratorsScreen(
              tripDraft: _createTripDraft(undecided: true),
            ),
        ),
      );
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
          'Create your trip',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Style Selector
                  TripStyleSelector(
                    isSoloSelected: _isSoloSelected,
                    onSelectSolo: () => setState(() => _isSoloSelected = true),
                    onSelectGroup: _handleGroupSelected,
                  ),
                  const SizedBox(height: 24),

                  // 2. Location Fields
                  const Text(
                    'Destination',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LocationDropdownField(
                    hint: 'From',
                    value: _selectedFrom,
                    onChanged: (val) => setState(() => _selectedFrom = val),
                  ),
                  const SizedBox(height: 12),
                  MultiCityField(
                    hint: 'To',
                    value: _selectedTo,
                    onChanged: (val) => setState(() => _selectedTo = val),
                  ),
                  const SizedBox(height: 24),

                  if (!_isSoloSelected) ...[
                    TravellersCounterCard(
                      count: _numberOfTravellers,
                      onIncrement: () => setState(() => _numberOfTravellers++),
                      onDecrement: () => setState(() => _numberOfTravellers--),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 4. Date Picker
                  TripDatePickerCard(
                    selectedDates: _selectedDates,
                    onDatesSelected: (dates) =>
                        setState(() => _selectedDates = dates),
                  ),
                  const SizedBox(height: 24),

                  // 5. Budget Slider
                  BudgetRangeSlider(
                    range: _budgetRange,
                    onChanged: (values) =>
                        setState(() => _budgetRange = values),
                  ),
                  const SizedBox(height: 32),

                  // 6. Next Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _ready ? _handleNext : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        disabledBackgroundColor: Colors.grey.shade300,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.backgroundWhite,
                        ),
                      ),
                    ),
                  ),
                  if (!_ready) ...[
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'Please fill in where from, where to and your dates to continue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
