enum GrammaticalCase {
  nominative,
  accusative,
  dative,
  genitive,
}

class SentenceExercise {
  final String id;
  final List<String> sentenceParts;
  final int missingIndex;
  final List<String> options;
  final String correctAnswer;
  final String translation;
  final String tip;
  final GrammaticalCase targetCase;

  SentenceExercise({
    required this.id,
    required this.sentenceParts,
    required this.missingIndex,
    required this.options,
    required this.correctAnswer,
    required this.translation,
    required this.tip,
    required this.targetCase,
  });
}
