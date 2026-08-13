import 'compound_word.dart';
import 'connector_exercise.dart';
import 'noun_question.dart';
import 'saved_word.dart';
import 'sentence_exercise.dart';

/// One question in a Daily Challenge session. Wraps whichever existing per-module
/// model (SavedWord, NounQuestion, CompoundWord, SentenceExercise, ConnectorExercise)
/// the question came from, rather than flattening everything into a generic
/// prompt/options shape — the quiz screen switches on the concrete type to render
/// each one with its module's own visual treatment and to dispatch the right
/// SRS/scoring side effect on answer.
sealed class DailyChallengeQuestion {
  final String id;
  const DailyChallengeQuestion({required this.id});
}

/// "Which definition matches this German word?" — built from a due (or newly-added)
/// SavedWord plus distractor definitions sampled from the user's other saved words.
class VocabDefinitionQuestion extends DailyChallengeQuestion {
  final SavedWord word;
  final List<String> options;
  final String correctOption;

  const VocabDefinitionQuestion({
    required super.id,
    required this.word,
    required this.options,
    required this.correctOption,
  });
}

/// der/die/das question, reusing the gender-practice module's own question shape.
class GenderQuestion extends DailyChallengeQuestion {
  final NounQuestion noun;

  const GenderQuestion({required super.id, required this.noun});
}

/// "What does this compound word mean?" multiple choice, reusing CompoundWord as-is.
class CompoundQuestion extends DailyChallengeQuestion {
  final CompoundWord compound;
  final List<String> options;

  const CompoundQuestion({
    required super.id,
    required this.compound,
    required this.options,
  });
}

/// Fill-in-the-blank grammatical-case exercise, reusing SentenceExercise as-is.
class SentenceCaseQuestion extends DailyChallengeQuestion {
  final SentenceExercise exercise;

  const SentenceCaseQuestion({required super.id, required this.exercise});
}

/// "Pick the correct German sentence" connector/word-order exercise, reusing
/// ConnectorExercise as-is.
class ConnectorQuestion extends DailyChallengeQuestion {
  final ConnectorExercise exercise;

  const ConnectorQuestion({required super.id, required this.exercise});
}
