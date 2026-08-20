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

class ImageExtractionResult {
  final String contentType;
  final String title;
  final List<ExtractedVocabItem> vocabulary;
  final String? lessonText;
  final String? notes;
  bool saveLessonText;

  ImageExtractionResult({
    required this.contentType,
    required this.title,
    required this.vocabulary,
    this.lessonText,
    this.notes,
  }) : saveLessonText = lessonText != null && lessonText.isNotEmpty;

  factory ImageExtractionResult.fromJson(Map<String, dynamic> json) => ImageExtractionResult(
        contentType: json['content_type']?.toString() ?? 'unknown',
        title: json['title']?.toString() ?? 'Extracted from Image',
        vocabulary: (json['vocabulary'] as List? ?? [])
            .map((v) => ExtractedVocabItem.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList(),
        lessonText: json['lesson_text']?.toString(),
        notes: json['notes']?.toString(),
      );
}
