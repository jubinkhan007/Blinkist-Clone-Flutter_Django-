import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flutter environment smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Blinkist Clone'),
          ),
        ),
      ),
    );

    expect(find.text('Blinkist Clone'), findsOneWidget);
  });
}
