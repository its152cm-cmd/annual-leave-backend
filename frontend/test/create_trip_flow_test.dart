import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homempage/features/trip_planning/create_trip_screen.dart';
import 'package:homempage/features/trip_planning/travel_preferences.dart';

void main() {
  testWidgets('Group Plan First returns to the form with traveller count', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateTripScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Number of travellers'), findsNothing);
    await tester.tap(find.text('Group'));
    await tester.pumpAndSettle();
    final planFirst = find.textContaining('Plan first', findRichText: true);
    await tester.ensureVisible(planFirst);
    await tester.tap(planFirst);
    await tester.pumpAndSettle();

    expect(find.text('Create your trip'), findsOneWidget);
    expect(find.text('Number of travellers'), findsOneWidget);
    expect(find.text('4 People'), findsOneWidget);
  });

  testWidgets('budget input values reach the Solo trip draft', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateTripScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(RangeSlider), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('budget-min-input')),
      '1200',
    );
    await tester.enterText(
      find.byKey(const ValueKey('budget-max-input')),
      '4500',
    );
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final preferencesScreen = tester.widget<TravelPreferencesScreen>(
      find.byType(TravelPreferencesScreen),
    );
    expect(preferencesScreen.tripDraft?.minimumBudget, 1200);
    expect(preferencesScreen.tripDraft?.plannedBudget, 4500);
    expect(preferencesScreen.tripDraft?.budget, 'RM 1200 - RM 4500 budget');
  });
}
