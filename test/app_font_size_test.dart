import 'package:flutter_test/flutter_test.dart';
import 'package:takt/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppFontSize Design Token Scale', () {
    test('enforces accessibility floor (micro >= 10.0)', () {
      expect(AppFontSize.micro, greaterThanOrEqualTo(10.0));
    });

    test('maintains strict monotonic scale ordering', () {
      expect(AppFontSize.micro, lessThan(AppFontSize.label));
      expect(AppFontSize.label, lessThan(AppFontSize.meta));
      expect(AppFontSize.meta, lessThan(AppFontSize.body));
      expect(AppFontSize.body, lessThan(AppFontSize.emphasized));
      expect(AppFontSize.emphasized, lessThan(AppFontSize.heading));
      expect(AppFontSize.heading, lessThan(AppFontSize.screenTitle));
      expect(AppFontSize.screenTitle, lessThan(AppFontSize.large));
      expect(AppFontSize.large, lessThan(AppFontSize.display));
    });

    test('verifies exact constant scale values', () {
      expect(AppFontSize.micro, 10.0);
      expect(AppFontSize.label, 11.0);
      expect(AppFontSize.meta, 12.0);
      expect(AppFontSize.body, 13.0);
      expect(AppFontSize.emphasized, 14.0);
      expect(AppFontSize.heading, 16.0);
      expect(AppFontSize.screenTitle, 18.0);
      expect(AppFontSize.large, 22.0);
      expect(AppFontSize.display, 28.0);
    });

    test('maps AppFontSize correctly into Light ThemeData TextTheme', () {
      final theme = AppTheme.lightTheme('Spline Sans', AppColorTheme.classic);
      final textTheme = theme.textTheme;

      expect(textTheme.labelSmall?.fontSize, AppFontSize.micro);
      expect(textTheme.labelMedium?.fontSize, AppFontSize.label);
      expect(textTheme.bodySmall?.fontSize, AppFontSize.meta);
      expect(textTheme.bodyMedium?.fontSize, AppFontSize.body);
      expect(textTheme.titleSmall?.fontSize, AppFontSize.emphasized);
      expect(textTheme.titleMedium?.fontSize, AppFontSize.heading);
      expect(textTheme.titleLarge?.fontSize, AppFontSize.screenTitle);
      expect(textTheme.headlineSmall?.fontSize, AppFontSize.large);
    });

    test('maps AppFontSize correctly into Dark ThemeData TextTheme', () {
      final theme = AppTheme.darkTheme('Spline Sans', AppColorTheme.classic);
      final textTheme = theme.textTheme;

      expect(textTheme.labelSmall?.fontSize, AppFontSize.micro);
      expect(textTheme.labelMedium?.fontSize, AppFontSize.label);
      expect(textTheme.bodySmall?.fontSize, AppFontSize.meta);
      expect(textTheme.bodyMedium?.fontSize, AppFontSize.body);
      expect(textTheme.titleSmall?.fontSize, AppFontSize.emphasized);
      expect(textTheme.titleMedium?.fontSize, AppFontSize.heading);
      expect(textTheme.titleLarge?.fontSize, AppFontSize.screenTitle);
      expect(textTheme.headlineSmall?.fontSize, AppFontSize.large);
    });
  });
}
