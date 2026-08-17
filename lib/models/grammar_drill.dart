enum GrammarDrillTopicId {
  verbConjugation,
  casesPrepositions,
  pronouns,
}

class GrammarDrillBlank {
  final String correctAnswer;
  final List<String>? options; // null => typed input; non-null => multiple choice
  final String? hint; // e.g. infinitive "regnen" shown next to the blank

  const GrammarDrillBlank({
    required this.correctAnswer,
    this.options,
    this.hint,
  });

  bool get isMultipleChoice => options != null;
}

class GrammarDrillQuestion {
  final String id;
  final String prompt; // "___ ist 22 Jahre alt." — blanks shown literally as "___"
  final List<GrammarDrillBlank> blanks;

  const GrammarDrillQuestion({
    required this.id,
    required this.prompt,
    required this.blanks,
  });
}

class GrammarDrillSheet {
  final String id;
  final String title;
  final List<GrammarDrillQuestion> questions;

  const GrammarDrillSheet({
    required this.id,
    required this.title,
    required this.questions,
  });

  int get blankCount => questions.fold(0, (sum, q) => sum + q.blanks.length);
}

class GrammarDrillTopic {
  final GrammarDrillTopicId id;
  final String title;
  final String description;
  final List<GrammarDrillSheet> sheets;

  const GrammarDrillTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.sheets,
  });
}
