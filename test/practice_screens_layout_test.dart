import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takt/screens/practice/sentence_practice_screen.dart';
import 'package:takt/services/auth_service.dart';
import 'package:takt/services/curriculum_service.dart';
import 'package:takt/services/gamification_service.dart';
import 'package:takt/services/profile_service.dart';
import 'package:takt/services/vocabulary_service.dart';
import 'package:takt/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Practice Screens Responsive Layout Tests', () {
    testWidgets('SentencePracticeScreen caps card height on tall viewport', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AuthService()),
            ChangeNotifierProvider(create: (_) => ProfileService()),
            ChangeNotifierProvider(create: (_) => VocabularyService()),
            ChangeNotifierProvider(create: (_) => GamificationService()),
            ChangeNotifierProvider(create: (_) => CurriculumService()),
          ],
          child: const MaterialApp(
            home: SentencePracticeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final constrainedBoxFinder = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxHeight == 640,
      );
      expect(constrainedBoxFinder, findsOneWidget);
    });
  });
}
