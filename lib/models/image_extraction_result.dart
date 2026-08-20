class ExtractedVocabItem {
  final String word;
  final String? gender; // 'm' | 'f' | 'n' | null
  final String? pos;
  final String translation;
  final String? exampleSentence;
  bool selected;

  ExtractedVocabItem({
    required this.word,
    this.gender,
    this.pos,
    required this.translation,
    this.exampleSentence,
    this.selected = true,
  });

  factory ExtractedVocabItem.fromJson(Map<String, dynamic> json) => ExtractedVocabItem(
        word: json['word']?.toString() ?? '',
        gender: json['gender']?.toString(),
        pos: json['pos']?.toString(),
        translation: json['translation']?.toString() ?? '',
        exampleSentence: json['example_sentence']?.toString(),
      );
}

class ExtractedExerciseStatement {
  final String id;
  final String text; // sentence with blank '...' or '___'
  final String answer; // correct answer option
  final String? explanation; // explanation why this answer is correct

  ExtractedExerciseStatement({
    required this.id,
    required this.text,
    required this.answer,
    this.explanation,
  });

  factory ExtractedExerciseStatement.fromJson(Map<String, dynamic> json) =>
      ExtractedExerciseStatement(
        id: json['id']?.toString() ?? '1',
        text: json['text']?.toString() ?? '',
        answer: json['answer']?.toString() ?? '',
        explanation: json['explanation']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'answer': answer,
        if (explanation != null) 'explanation': explanation,
      };
}

class ExtractedExercise {
  final String title;
  final String instruction;
  final List<String> options;
  final List<ExtractedExerciseStatement> statements;

  ExtractedExercise({
    required this.title,
    required this.instruction,
    required this.options,
    required this.statements,
  });

  factory ExtractedExercise.fromJson(Map<String, dynamic> json) {
    final rawStatements = (json['statements'] as List? ?? []);
    final statements = rawStatements
        .map((s) => ExtractedExerciseStatement.fromJson(Map<String, dynamic>.from(s as Map)))
        .where((s) => s.text.isNotEmpty && s.answer.isNotEmpty)
        .toList();

    final rawOptions = (json['options'] as List? ?? []).map((o) => o.toString().trim()).toList();

    return ExtractedExercise(
      title: json['title']?.toString() ?? 'Exercise',
      instruction: json['instruction']?.toString() ?? 'Fill in the blanks.',
      options: rawOptions.isNotEmpty
          ? rawOptions
          : statements.map((s) => s.answer).toSet().toList(),
      statements: statements,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'instruction': instruction,
        'options': options,
        'statements': statements.map((s) => s.toJson()).toList(),
      };
}

class ImageExtractionResult {
  final String contentType;
  final String title;
  final List<ExtractedVocabItem> vocabulary;
  final String? lessonText;
  final ExtractedExercise? exercise;
  final String? notes;
  bool saveLessonText;

  ImageExtractionResult({
    required this.contentType,
    required this.title,
    required this.vocabulary,
    this.lessonText,
    this.exercise,
    this.notes,
  }) : saveLessonText = lessonText != null && lessonText.isNotEmpty;

  bool get hasExercise => exercise != null && exercise!.statements.isNotEmpty;

  factory ImageExtractionResult.fromJson(Map<String, dynamic> json) => ImageExtractionResult(
        contentType: json['content_type']?.toString() ?? 'unknown',
        title: json['title']?.toString() ?? 'Extracted from Image',
        vocabulary: (json['vocabulary'] as List? ?? [])
            .map((v) => ExtractedVocabItem.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList(),
        lessonText: json['lesson_text']?.toString(),
        exercise: json['exercise'] != null && json['exercise'] is Map
            ? ExtractedExercise.fromJson(Map<String, dynamic>.from(json['exercise'] as Map))
            : null,
        notes: json['notes']?.toString(),
      );
}
