import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takt/l10n/app_localizations.dart';
import 'package:takt/models/german_phrase.dart';
import 'package:takt/screens/phrases/phrase_practice_screen.dart';
import 'package:takt/services/phrase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  );

  const sampleExercise = PhraseExercise(
    id: 'ex_test_1',
    type: PhraseExerciseType.situationalChoice,
    targetPhrase: testPhrase,
    prompt: 'You want to tip your waiter and say keep the change:',
    options: ['Der Rest ist für Sie.', 'Guten Tag.', 'Auf Wiedersehen.'],
    correctAnswer: 'Der Rest ist für Sie.',
    explanation: '"Der Rest ist für Sie." means "Keep the change."',
  );

  testWidgets('PhrasePracticeScreen displays prompt and options', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final phraseService = PhraseService();

    await tester.pumpWidget(
      ChangeNotifierProvider<PhraseService>.value(
        value: phraseService,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: PhrasePracticeScreen(
            autoPlayAudio: false,
            initialExercises: [sampleExercise],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Phrasen-Trainer'), findsOneWidget);
    expect(find.textContaining('QUESTION 1 OF 1'), findsOneWidget);
    expect(find.text('You want to tip your waiter and say keep the change:'), findsOneWidget);
    expect(find.text('Der Rest ist für Sie.'), findsOneWidget);
  });
}
