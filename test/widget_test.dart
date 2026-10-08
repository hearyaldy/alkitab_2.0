import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alkitab_2_0/config/theme.dart';

// The full app needs Firebase, so this smoke test only checks that the
// app's light and dark themes build and render without errors.
void main() {
  for (final entry in {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    testWidgets('App ${entry.key} theme renders', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: Scaffold(
            appBar: AppBar(title: const Text('Alkitab 2.0')),
            body: const Center(child: Text('Hello')),
          ),
        ),
      );

      expect(find.text('Alkitab 2.0'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
