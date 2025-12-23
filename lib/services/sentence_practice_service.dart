import '../models/sentence_exercise.dart';

class SentencePracticeService {
  List<SentenceExercise> getExercises() {
    return [
      SentenceExercise(
        id: '1',
        sentenceParts: ['Die', 'kleine', 'Katze', 'schläft', 'auf', 'dem', 'Sofa'],
        missingIndex: 5,
        options: ['der', 'die', 'den', 'dem'],
        correctAnswer: 'dem',
        translation: '"The small cat sleeps on the sofa."',
        tip: "Tip: 'auf' (location) requires Dative case.",
        targetCase: GrammaticalCase.dative,
      ),
      SentenceExercise(
        id: '2',
        sentenceParts: ['Ich', 'sehe', 'den', 'Hund'],
        missingIndex: 2,
        options: ['der', 'die', 'den', 'dem'],
        correctAnswer: 'den',
        translation: '"I see the dog."',
        tip: "Tip: Direct object takes Accusative case.",
        targetCase: GrammaticalCase.accusative,
      ),
      SentenceExercise(
        id: '3',
        sentenceParts: ['Der', 'Mann', 'gibt', 'der', 'Frau', 'ein', 'Buch'],
        missingIndex: 3,
        options: ['der', 'die', 'den', 'dem'],
        correctAnswer: 'der',
        translation: '"The man gives the woman a book."',
        tip: "Tip: Indirect object takes Dative case.",
        targetCase: GrammaticalCase.dative,
      ),
      SentenceExercise(
        id: '4',
        sentenceParts: ['Das', 'Auto', 'gehört', 'dem', 'Vater'],
        missingIndex: 3,
        options: ['der', 'die', 'den', 'dem'],
        correctAnswer: 'dem',
        translation: '"The car belongs to the father."',
        tip: "Tip: 'gehören' requires Dative case.",
        targetCase: GrammaticalCase.dative,
      ),
       SentenceExercise(
        id: '5',
        sentenceParts: ['Wir', 'essen', 'einen', 'Apfel'],
        missingIndex: 2,
        options: ['ein', 'eine', 'einen', 'einem'],
        correctAnswer: 'einen',
        translation: '"We are eating an apple."',
        tip: "Tip: 'einen Apfel' is the direct object (Accusative).",
        targetCase: GrammaticalCase.accusative,
      ),
    ];
  }
}
