class BookGuide {
  final String id;
  final String title;
  final String subtitle;
  final String cefrLevel;
  final String coverImage;
  final int totalChapters;
  final List<ChapterSummary> chapters;

  BookGuide({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.cefrLevel,
    required this.coverImage,
    required this.totalChapters,
    required this.chapters,
  });

  factory BookGuide.fromJson(Map<String, dynamic> json) {
    return BookGuide(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      cefrLevel: json['cefrLevel'] as String? ?? 'A1',
      coverImage: json['coverImage'] as String? ?? 'assets/images/story_desert.png',
      totalChapters: json['totalChapters'] as int? ?? 0,
      chapters: (json['chapters'] as List<dynamic>? ?? [])
          .map((e) => ChapterSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChapterSummary {
  final int chapterNumber;
  final String title;
  final String topic;
  final String jsonAssetPath;
  final int wordCount;
  final int audioCount;

  ChapterSummary({
    required this.chapterNumber,
    required this.title,
    required this.topic,
    required this.jsonAssetPath,
    required this.wordCount,
    required this.audioCount,
  });

  factory ChapterSummary.fromJson(Map<String, dynamic> json) {
    return ChapterSummary(
      chapterNumber: json['chapterNumber'] as int? ?? 1,
      title: json['title'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      jsonAssetPath: json['jsonAssetPath'] as String? ?? '',
      wordCount: json['wordCount'] as int? ?? 0,
      audioCount: json['audioCount'] as int? ?? 0,
    );
  }
}

class ChapterGuide {
  final String id;
  final String bookId;
  final int chapterNumber;
  final String title;
  final String topic;
  final String summary;
  final String cefrLevel;
  final List<VocabularyGuideItem> vocabulary;
  final List<DialogueGuideItem> dialogues;
  final List<RedemittelGroup> redemittel;

  ChapterGuide({
    required this.id,
    required this.bookId,
    required this.chapterNumber,
    required this.title,
    required this.topic,
    required this.summary,
    required this.cefrLevel,
    required this.vocabulary,
    required this.dialogues,
    required this.redemittel,
  });

  factory ChapterGuide.fromJson(Map<String, dynamic> json) {
    return ChapterGuide(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      chapterNumber: json['chapterNumber'] as int? ?? 1,
      title: json['title'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      cefrLevel: json['cefrLevel'] as String? ?? 'A1',
      vocabulary: (json['vocabulary'] as List<dynamic>? ?? [])
          .map((e) => VocabularyGuideItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      dialogues: (json['dialogues'] as List<dynamic>? ?? [])
          .map((e) => DialogueGuideItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      redemittel: (json['redemittel'] as List<dynamic>? ?? [])
          .map((e) => RedemittelGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class VocabularyGuideItem {
  final String id;
  final String section;
  final String word;
  final String article;
  final String exampleSentence;

  VocabularyGuideItem({
    required this.id,
    required this.section,
    required this.word,
    required this.article,
    required this.exampleSentence,
  });

  factory VocabularyGuideItem.fromJson(Map<String, dynamic> json) {
    return VocabularyGuideItem(
      id: json['id'] as String? ?? '',
      section: json['section'] as String? ?? '',
      word: json['word'] as String? ?? '',
      article: json['article'] as String? ?? '',
      exampleSentence: json['exampleSentence'] as String? ?? '',
    );
  }
}

class DialogueGuideItem {
  final String trackNumber;
  final String title;
  final String audioAssetPath;
  final String transcript;

  DialogueGuideItem({
    required this.trackNumber,
    required this.title,
    required this.audioAssetPath,
    required this.transcript,
  });

  factory DialogueGuideItem.fromJson(Map<String, dynamic> json) {
    return DialogueGuideItem(
      trackNumber: json['trackNumber'] as String? ?? '',
      title: json['title'] as String? ?? '',
      audioAssetPath: json['audioAssetPath'] as String? ?? '',
      transcript: json['transcript'] as String? ?? '',
    );
  }
}

class RedemittelGroup {
  final String title;
  final List<String> phrases;

  RedemittelGroup({
    required this.title,
    required this.phrases,
  });

  factory RedemittelGroup.fromJson(Map<String, dynamic> json) {
    return RedemittelGroup(
      title: json['title'] as String? ?? '',
      phrases: (json['phrases'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
