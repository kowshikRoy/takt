import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/screens/dictionary_screen.dart';
import 'package:takt/services/auth_service.dart';
import 'package:takt/services/curriculum_service.dart';
import 'package:takt/services/gamification_service.dart';
import 'package:takt/services/media_library_service.dart';
import 'package:takt/services/notification_service.dart';
import 'package:takt/services/profile_service.dart';
import 'package:takt/services/sound_service.dart';
import 'package:takt/services/sync_service.dart';
import 'package:takt/services/vocabulary_service.dart';
import 'package:takt/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Widget buildTestWidget({required Map<String, dynamic> wordData}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ProfileService()),
        ChangeNotifierProvider(create: (_) => VocabularyService()),
        ChangeNotifierProvider(create: (_) => GamificationService()),
        ChangeNotifierProvider(create: (_) => CurriculumService()),
        ChangeNotifierProvider(create: (_) => MediaLibraryService()),
        ChangeNotifierProvider(create: (_) => SyncService()),
        ChangeNotifierProvider(create: (_) => SoundService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: MaterialApp(
        home: DictionaryScreen(
          initialWordData: wordData,
        ),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Dictionary Noun Declension Table', () {
    testWidgets('renders 4-case declension table for masculine noun', (tester) async {
      final masculineNoun = {
        'id': 101,
        'word': 'Hund',
        'pos': 'noun',
        'gender': 'm',
        'plural': 'Hunde',
        'meanings': ['dog'],
        'forms': ['Hund', 'Hunde'],
      };

      await tester.pumpWidget(buildTestWidget(wordData: masculineNoun));
      await tester.pumpAndSettle();

      final formsTab = find.text('Forms & Declension');
      expect(formsTab, findsOneWidget);
      await tester.tap(formsTab);
      await tester.pumpAndSettle();

      // Verify Noun Declension Table Header
      expect(find.text('NOUN DECLENSION TABLE'), findsOneWidget);
      expect(find.text('CASE'), findsOneWidget);
      expect(find.text('SINGULAR'), findsOneWidget);
      expect(find.text('PLURAL'), findsOneWidget);

      // Verify Cases
      expect(find.text('Nominativ'), findsOneWidget);
      expect(find.text('Akkusativ'), findsOneWidget);
      expect(find.text('Dativ'), findsOneWidget);
      expect(find.text('Genitiv'), findsOneWidget);

      // Verify Masculine Singular Articles and Forms
      expect(find.text('der Hund'), findsOneWidget);
      expect(find.text('den Hund'), findsOneWidget);
      expect(find.text('dem Hund'), findsOneWidget);
      expect(find.text('des Hund(e)s'), findsOneWidget);

      // Verify Plural Forms (with Dativ plural -en)
      expect(find.text('die Hunde'), findsNWidgets(2)); // Nominativ & Akkusativ
      expect(find.text('den Hunden'), findsOneWidget); // Dativ plural
      expect(find.text('der Hunde'), findsOneWidget); // Genitiv plural
    });

    testWidgets('renders 4-case declension table for feminine noun', (tester) async {
      final feminineNoun = {
        'id': 102,
        'word': 'Katze',
        'pos': 'noun',
        'gender': 'f',
        'plural': 'Katzen',
        'meanings': ['cat'],
        'forms': ['Katze', 'Katzen'],
      };

      await tester.pumpWidget(buildTestWidget(wordData: feminineNoun));
      await tester.pumpAndSettle();

      final formsTab = find.text('Forms & Declension');
      expect(formsTab, findsOneWidget);
      await tester.tap(formsTab);
      await tester.pumpAndSettle();

      expect(find.text('NOUN DECLENSION TABLE'), findsOneWidget);

      // Feminine Singular Articles: die, die, der, der
      expect(find.text('die Katze'), findsNWidgets(2));
      expect(find.text('der Katze'), findsNWidgets(2));

      // Feminine Plural Articles: die, die, den, der
      expect(find.text('die Katzen'), findsNWidgets(2));
      expect(find.text('den Katzen'), findsOneWidget);
      expect(find.text('der Katzen'), findsOneWidget);
    });

    testWidgets('renders 4-case declension table for neuter noun', (tester) async {
      final neuterNoun = {
        'id': 103,
        'word': 'Buch',
        'pos': 'noun',
        'gender': 'n',
        'plural': 'Bücher',
        'meanings': ['book'],
        'forms': ['Buch', 'Bücher'],
      };

      await tester.pumpWidget(buildTestWidget(wordData: neuterNoun));
      await tester.pumpAndSettle();

      final formsTab = find.text('Forms & Declension');
      expect(formsTab, findsOneWidget);
      await tester.tap(formsTab);
      await tester.pumpAndSettle();

      expect(find.text('NOUN DECLENSION TABLE'), findsOneWidget);

      // Neuter Singular Articles: das, das, dem, des
      expect(find.text('das Buch'), findsNWidgets(2));
      expect(find.text('dem Buch'), findsOneWidget);
      expect(find.text('des Buch(e)s'), findsOneWidget);

      // Neuter Plural: die, die, den, der
      expect(find.text('die Bücher'), findsNWidgets(2));
      expect(find.text('den Büchern'), findsOneWidget);
      expect(find.text('der Bücher'), findsOneWidget);
    });
  });
}
