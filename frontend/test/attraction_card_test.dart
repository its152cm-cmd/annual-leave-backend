import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homempage/features/home/widgets/attraction_card.dart';

void main() {
  testWidgets('favorite heart has no white circular background', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AttractionCard(
            title: 'Temple',
            location: 'Kyoto',
            imageUrl: '',
            price: 'Free',
            tags: [],
            rating: 4.8,
            isFavorite: false,
            onFavorite: _noop,
          ),
        ),
      ),
    );

    final heartBackground = tester.widget<Material>(
      find.byWidgetPredicate(
        (widget) => widget is Material && widget.shape is CircleBorder,
      ),
    );
    expect(heartBackground.color, Colors.transparent);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });
}

void _noop() {}
