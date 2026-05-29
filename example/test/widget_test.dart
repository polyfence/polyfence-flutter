import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyfence_example/main.dart';
import 'package:polyfence_example/theme/app_theme.dart';

void main() {
  testWidgets('ApiKeyEmptyState renders the dart-define CTA',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: ApiKeyEmptyState(),
        ),
      ),
    );

    // Headline + the dart-define command should both be visible. If
    // either AppTheme-styled path regresses, this fails.
    expect(find.text('Connect Polyfence'), findsOneWidget);
    expect(
      find.text('flutter run --dart-define=POLYFENCE_API_KEY=pf_...'),
      findsOneWidget,
    );
  });
}
