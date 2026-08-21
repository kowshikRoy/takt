import '../services/dictionary_service.dart';

/// Represents a key vocabulary item extracted from context (e.g. video subtitles,
/// story reader paragraphs, textbook units, or OCR/image extraction).
class ContextualVocabItem {
  final String word;
  final String? baseForm;
  final String? pos;
  final String? gender;
  final String primaryDefinition;
  final String? ipa;
  final int sourceIndex; // paragraphIndex or cueIndex
  final double sourceStartTime; // cueStartTime (in seconds)
  final String sourceOriginal; // paragraphOriginal or cueOriginal
  final String sourceTranslated; // paragraphTranslated or cueTranslated
  final int? freqRank;
  final String difficultyLabel;
  final int occurrences;
  final int relevanceScore;

  ContextualVocabItem({
    required this.word,
    this.baseForm,
    this.pos,
    this.gender,
    required this.primaryDefinition,
    this.ipa,
    int? sourceIndex,
    int? paragraphIndex,
    int? cueIndex,
    double? sourceStartTime,
    double? cueStartTime,
    String? sourceOriginal,
    String? paragraphOriginal,
    String? cueOriginal,
    String? sourceTranslated,
    String? paragraphTranslated,
    String? cueTranslated,
    this.freqRank,
    String? difficultyLabel,
    this.occurrences = 1,
    this.relevanceScore = 50,
  })  : sourceIndex = sourceIndex ?? paragraphIndex ?? cueIndex ?? 0,
        sourceStartTime = sourceStartTime ?? cueStartTime ?? 0.0,
        sourceOriginal = sourceOriginal ?? paragraphOriginal ?? cueOriginal ?? '',
        sourceTranslated = sourceTranslated ?? paragraphTranslated ?? cueTranslated ?? '',
        difficultyLabel = difficultyLabel ??
            DictionaryService.getCefrLevel(
              freqRank,
              fallback: word.length > 8
                  ? 'B2'
                  : (word.length > 6
                      ? 'B1'
                      : (word.length > 4 ? 'A2' : 'A1')),
            );

  // Aliases for video/story backwards compatibility
  int get cueIndex => sourceIndex;
  int get paragraphIndex => sourceIndex;
  double get cueStartTime => sourceStartTime;
  String get cueOriginal => sourceOriginal;
  String get paragraphOriginal => sourceOriginal;
  String get cueTranslated => sourceTranslated;
  String get paragraphTranslated => sourceTranslated;

  String get article {
    final g = (gender ?? '').toLowerCase().trim();
    if (g == 'm' || g == 'masc' || g == 'masculine' || g == 'der') return 'der';
    if (g == 'f' || g == 'fem' || g == 'feminine' || g == 'die') return 'die';
    if (g == 'n' || g == 'neu' || g == 'neuter' || g == 'das') return 'das';
    return '';
  }

  String get fullWordWithArticle => article.isNotEmpty ? '$article $word' : word;
}

typedef KeyMediaVocab = ContextualVocabItem;
typedef KeyStoryVocab = ContextualVocabItem;
