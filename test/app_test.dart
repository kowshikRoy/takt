import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:takt/main.dart';
import 'package:takt/theme/theme_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We need to wrap MyApp in the provider it expects
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      )
    );

    // Verify that the welcome screen is shown
    expect(find.text('DeutschApp'), findsOneWidget);
    expect(find.text('Los geht’s (Get Started)'), findsOneWidget);
  });
}
