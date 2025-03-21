import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alkitab_2_0/app.dart'; // Note the correct import path

void main() {
  testWidgets('Verify app initializes', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app initialized correctly
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}