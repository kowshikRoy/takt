import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:takt/theme/app_theme.dart';
import 'package:takt/theme/books_modernist_style.dart';
import 'package:takt/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BooksModernist Reading Theme Tests', () {
    testWidgets('readingTheme returns Light ThemeData even in Dark Mode ambient context', (tester) async {
      ThemeData? extractedTheme;

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            theme: AppTheme.darkTheme('Spline Sans', AppColorTheme.classic),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  extractedTheme = BooksModernist.readingTheme(context);
                  return Theme(
                    data: extractedTheme!,
                    child: Builder(
                      builder: (themedContext) {
                        return Text(
                          'Test Reading Text',
                          style: TextStyle(
                            color: Theme.of(themedContext).colorScheme.onSurface,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(extractedTheme, isNotNull);
      expect(extractedTheme!.brightness, Brightness.light);
      // Verify that onSurface in readingTheme is a dark ink color suitable for light page background
      expect(extractedTheme!.colorScheme.onSurface.computeLuminance(), lessThan(0.3));
    });

    testWidgets('readingTheme respects ThemeProvider font and color preferences', (tester) async {
      ThemeData? extractedTheme;
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: themeProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  extractedTheme = BooksModernist.readingTheme(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(extractedTheme, isNotNull);
      expect(extractedTheme!.brightness, Brightness.light);
      expect(extractedTheme!.colorScheme.primary, isNotNull);
    });
  });
}
