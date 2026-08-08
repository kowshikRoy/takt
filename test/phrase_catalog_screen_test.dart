import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:takt/l10n/app_localizations.dart';
import 'package:takt/models/german_phrase.dart';
import 'package:takt/screens/phrases/phrase_catalog_screen.dart';
import 'package:takt/screens/phrases/phrase_practice_screen.dart';
import 'package:takt/services/phrase_service.dart';
import 'package:takt/services/profile_service.dart';
import 'package:takt/services/sound_service.dart';
import 'package:takt/services/tts_service.dart';
import 'package:takt/widgets/phrase_card.dart';
import 'package:takt/widgets/phrase_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
            (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getVoices':
          return [];
        case 'getLanguages':
          return ['de-DE'];
        case 'setSpeechRate':
        case 'setVolume':
        case 'setPitch':
        case 'setLanguage':
        case 'awaitSpeakCompletion':
        case 'speak':
        case 'stop':
          return 1;
        default:
          return 1;
      }
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  const testPhrase = GermanPhrase(
    id: 'phr_test_1',
    german: 'Der Rest ist für Sie.',
    english: 'Keep the change.',
    literalTranslation: 'The rest is for you.',
    category: 'Restaurant & Dining',
    level: 'A1',
    formality: 'formal',
    situation: 'When paying at a restaurant.',
    culturalNote: 'Tipping is direct.',
    dialogue: PhraseDialogue(
      speakerA: 'Das macht 18 Euro.',
      speakerB: 'Der Rest ist für Sie!',
      englishA: 'That is 18 euros.',
      englishB: 'Keep the change!',
    ),
    tags: ['restaurant', 'tipping'],
    relatedPhrases: ['Stimmt so!'],
  );

  Widget createWrapper(Widget child, PhraseService phraseService) {
    return ChangeNotifierProvider<PhraseService>.value(
      value: phraseService,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  group('Phrase Widgets Tests', () {
    testWidgets('PhraseCard renders German phrase, English translation, and badges', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final phraseService = PhraseService();

      await tester.pumpWidget(createWrapper(const PhraseCard(phrase: testPhrase), phraseService));
      await tester.pump();

      expect(find.text('Der Rest ist für Sie.'), findsOneWidget);
      expect(find.text('Keep the change.'), findsOneWidget);
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('Sie'), findsOneWidget);
      expect(find.text('Restaurant & Dining'), findsOneWidget);
    });

    testWidgets('PhraseDetailSheet renders full breakdown, dialogue and cultural note', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final phraseService = PhraseService();

      await tester.pumpWidget(createWrapper(const PhraseDetailSheet(phrase: testPhrase), phraseService));
      await tester.pump();

      expect(find.text('ENGLISH MEANING'), findsOneWidget);
      expect(find.text('Keep the change.'), findsOneWidget);
      expect(find.text('CONVERSATION EXAMPLE'), findsOneWidget);
      expect(find.text('Das macht 18 Euro.'), findsOneWidget);
      expect(find.text('CULTURAL INSIGHT'), findsOneWidget);
      expect(find.text('Tipping is direct.'), findsOneWidget);
    });

    testWidgets('PhraseCatalogScreen renders title and search bar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final phraseService = PhraseService();
      await phraseService.init();

      await tester.pumpWidget(createWrapper(const PhraseCatalogScreen(), phraseService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ALLTAGSSPRACHE'), findsOneWidget);
      expect(find.text('Phrasen & Redemittel'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.pumpWidget(Container());
    });
  });
}
