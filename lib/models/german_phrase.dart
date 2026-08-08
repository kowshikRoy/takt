/// Model representing an authentic German conversational phrase or idiom.
class GermanPhrase {
  final String id;
  final String german;
  final String english;
  final String literalTranslation;
  final String category;
  final String level; // A1, A2, B1, B2
  final String formality; // formal, informal, neutral
  final String situation;
  final String culturalNote;
  final PhraseDialogue? dialogue;
  final List<String> tags;
  final List<String> relatedPhrases;

  const GermanPhrase({
    required this.id,
    required this.german,
    required this.english,
    required this.literalTranslation,
    required this.category,
    required this.level,
    required this.formality,
    required this.situation,
    required this.culturalNote,
    this.dialogue,
    this.tags = const [],
    this.relatedPhrases = const [],
  });

  factory GermanPhrase.fromJson(Map<String, dynamic> json) {
    return GermanPhrase(
      id: json['id'] as String? ?? '',
      german: json['german'] as String? ?? '',
      english: json['english'] as String? ?? '',
      literalTranslation: json['literalTranslation'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      level: json['level'] as String? ?? 'A1',
      formality: json['formality'] as String? ?? 'neutral',
      situation: json['situation'] as String? ?? '',
      culturalNote: json['culturalNote'] as String? ?? '',
      dialogue: json['dialogue'] != null
          ? PhraseDialogue.fromJson(json['dialogue'] as Map<String, dynamic>)
          : null,
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      relatedPhrases: (json['relatedPhrases'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'german': german,
      'english': english,
      'literalTranslation': literalTranslation,
      'category': category,
      'level': level,
      'formality': formality,
      'situation': situation,
      'culturalNote': culturalNote,
      if (dialogue != null) 'dialogue': dialogue!.toJson(),
      'tags': tags,
      'relatedPhrases': relatedPhrases,
    };
  }

  GermanPhrase copyWith({
    String? id,
    String? german,
    String? english,
    String? literalTranslation,
    String? category,
    String? level,
    String? formality,
    String? situation,
    String? culturalNote,
    PhraseDialogue? dialogue,
    List<String>? tags,
    List<String>? relatedPhrases,
  }) {
    return GermanPhrase(
      id: id ?? this.id,
      german: german ?? this.german,
      english: english ?? this.english,
      literalTranslation: literalTranslation ?? this.literalTranslation,
      category: category ?? this.category,
      level: level ?? this.level,
      formality: formality ?? this.formality,
      situation: situation ?? this.situation,
      culturalNote: culturalNote ?? this.culturalNote,
      dialogue: dialogue ?? this.dialogue,
      tags: tags ?? this.tags,
      relatedPhrases: relatedPhrases ?? this.relatedPhrases,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GermanPhrase && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A short 2-line realistic mini dialogue demonstrating authentic usage.
class PhraseDialogue {
  final String speakerA;
  final String speakerB;
  final String englishA;
  final String englishB;

  const PhraseDialogue({
    required this.speakerA,
    required this.speakerB,
    required this.englishA,
    required this.englishB,
  });

  factory PhraseDialogue.fromJson(Map<String, dynamic> json) {
    return PhraseDialogue(
      speakerA: json['speakerA'] as String? ?? '',
      speakerB: json['speakerB'] as String? ?? '',
      englishA: json['englishA'] as String? ?? '',
      englishB: json['englishB'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speakerA': speakerA,
      'speakerB': speakerB,
      'englishA': englishA,
      'englishB': englishB,
    };
  }
}

/// Represents an interactive practice challenge item.
enum PhraseExerciseType {
  situationalChoice,
  dialogueCompletion,
  audioListening,
}

class PhraseExercise {
  final String id;
  final PhraseExerciseType type;
  final GermanPhrase targetPhrase;
  final String prompt;
  final String? speakerContext; // e.g. "Kellner: Das macht dann 18,50 Euro."
  final List<String> options;
  final String correctAnswer;
  final String explanation;

  const PhraseExercise({
    required this.id,
    required this.type,
    required this.targetPhrase,
    required this.prompt,
    this.speakerContext,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });
}
