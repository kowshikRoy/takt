import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'dictionary_service.dart';
import '../models/subtitle_cue.dart';

class GrammarTokenAnalysis {
  final String word;
  final String lemma;
  final String partOfSpeech;
  final String translation;
  final String grammarNote;

  GrammarTokenAnalysis({
    required this.word,
    required this.lemma,
    required this.partOfSpeech,
    required this.translation,
    required this.grammarNote,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'lemma': lemma,
        'partOfSpeech': partOfSpeech,
        'translation': translation,
        'grammarNote': grammarNote,
      };
}

class SentenceAnalysisResult {
  final String originalSentence;
  final String translatedSentence;
  final String overallStructure;
  final List<GrammarTokenAnalysis> tokens;

  SentenceAnalysisResult({
    required this.originalSentence,
    required this.translatedSentence,
    required this.overallStructure,
    required this.tokens,
  });

  Map<String, dynamic> toJson() => {
        'originalSentence': originalSentence,
        'translatedSentence': translatedSentence,
        'overallStructure': overallStructure,
        'tokens': tokens.map((t) => t.toJson()).toList(),
      };
}

class OnDeviceAIService {
  final DictionaryService _dictionaryService = DictionaryService();
  OnDeviceTranslator? _translator;
  bool _isMlKitInitializing = false;

  Future<OnDeviceTranslator?> _getTranslator() async {
    if (kIsWeb) return null;
    if (_translator != null) return _translator;
    if (_isMlKitInitializing) return null;
    _isMlKitInitializing = true;
    try {
      final modelManager = OnDeviceTranslatorModelManager();
      final isDeDownloaded = await modelManager.isModelDownloaded(TranslateLanguage.german.bcpCode);
      final isEnDownloaded = await modelManager.isModelDownloaded(TranslateLanguage.english.bcpCode);

      if (!isDeDownloaded || !isEnDownloaded) {
        print("[OnDeviceAI] Downloading Google ML Kit German-English language models (~30MB)...");
        await modelManager.downloadModel(TranslateLanguage.german.bcpCode);
        await modelManager.downloadModel(TranslateLanguage.english.bcpCode);
      }

      _translator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.german,
        targetLanguage: TranslateLanguage.english,
      );
      print("[OnDeviceAI] Google ML Kit Translator initialized successfully!");
    } catch (e) {
      print("[OnDeviceAI] ML Kit init failed: $e");
    } finally {
      _isMlKitInitializing = false;
    }
    return _translator;
  }

  // Known German article, preposition & pronoun mappings for instant offline resolution
  static const Map<String, Map<String, String>> _knownWords = {
    'der': {'pos': 'Article', 'trans': 'the', 'note': 'Definite article (Masculine Nominative)'},
    'die': {'pos': 'Article', 'trans': 'the', 'note': 'Definite article (Feminine/Plural)'},
    'das': {'pos': 'Article', 'trans': 'the', 'note': 'Definite article (Neuter)'},
    'den': {'pos': 'Article', 'trans': 'the', 'note': 'Definite article (Accusative / Dative Plural)'},
    'dem': {'pos': 'Article', 'trans': 'the', 'note': 'Definite article (Dative Masculine/Neuter)'},
    'des': {'pos': 'Article', 'trans': 'of the', 'note': 'Definite article (Genitive Masculine/Neuter)'},
    'ein': {'pos': 'Article', 'trans': 'a / an', 'note': 'Indefinite article'},
    'eine': {'pos': 'Article', 'trans': 'a / an', 'note': 'Indefinite article (Feminine)'},
    'einem': {'pos': 'Article', 'trans': 'a / an', 'note': 'Indefinite article (Dative)'},
    'einer': {'pos': 'Article', 'trans': 'a / an', 'note': 'Indefinite article (Dative Feminine)'},
    'eines': {'pos': 'Article', 'trans': 'of a', 'note': 'Indefinite article (Genitive)'},
    'ich': {'pos': 'Pronoun', 'trans': 'I', 'note': 'Personal pronoun (1st person singular)'},
    'du': {'pos': 'Pronoun', 'trans': 'you', 'note': 'Personal pronoun (2nd person singular)'},
    'er': {'pos': 'Pronoun', 'trans': 'he', 'note': 'Personal pronoun (3rd person singular)'},
    'sie': {'pos': 'Pronoun', 'trans': 'she / they', 'note': 'Personal pronoun'},
    'es': {'pos': 'Pronoun', 'trans': 'it', 'note': 'Personal pronoun (neuter)'},
    'wir': {'pos': 'Pronoun', 'trans': 'we', 'note': 'Personal pronoun (1st person plural)'},
    'ihr': {'pos': 'Pronoun', 'trans': 'you all', 'note': 'Personal pronoun (2nd person plural)'},
    'ihrer': {'pos': 'Pronoun', 'trans': 'her / their', 'note': 'Possessive pronoun (Genitive/Dative)'},
    'ihre': {'pos': 'Pronoun', 'trans': 'her / their', 'note': 'Possessive pronoun'},
    'sein': {'pos': 'Pronoun', 'trans': 'his / its', 'note': 'Possessive pronoun'},
    'seine': {'pos': 'Pronoun', 'trans': 'his / its', 'note': 'Possessive pronoun'},
    'und': {'pos': 'Conjunction', 'trans': 'and', 'note': 'Coordinating conjunction'},
    'oder': {'pos': 'Conjunction', 'trans': 'or', 'note': 'Coordinating conjunction'},
    'aber': {'pos': 'Conjunction', 'trans': 'but', 'note': 'Coordinating conjunction'},
    'dass': {'pos': 'Conjunction', 'trans': 'that', 'note': 'Subordinating conjunction'},
    'weil': {'pos': 'Conjunction', 'trans': 'because', 'note': 'Subordinating conjunction'},
    'ist': {'pos': 'Verb', 'trans': 'is', 'note': 'Conjugated verb (sein, 3rd person singular)'},
    'sind': {'pos': 'Verb', 'trans': 'are', 'note': 'Conjugated verb (sein, 1st/3rd person plural)'},
    'war': {'pos': 'Verb', 'trans': 'was', 'note': 'Conjugated verb (sein, Präteritum 1st/3rd person singular)'},
    'waren': {'pos': 'Verb', 'trans': 'were', 'note': 'Conjugated verb (sein, Präteritum plural)'},
    'habe': {'pos': 'Verb', 'trans': 'have', 'note': 'Conjugated verb (haben, 1st person singular)'},
    'hat': {'pos': 'Verb', 'trans': 'has', 'note': 'Conjugated verb (haben, 3rd person singular)'},
    'hatte': {'pos': 'Verb', 'trans': 'had', 'note': 'Conjugated verb (haben, Präteritum)'},
    'im': {'pos': 'Preposition', 'trans': 'in the', 'note': 'Contraction of in + dem'},
    'am': {'pos': 'Preposition', 'trans': 'at the', 'note': 'Contraction of an + dem'},
    'zum': {'pos': 'Preposition', 'trans': 'to the', 'note': 'Contraction of zu + dem'},
    'zur': {'pos': 'Preposition', 'trans': 'to the', 'note': 'Contraction of zu + der'},
    'vor': {'pos': 'Preposition', 'trans': 'in front of / before', 'note': 'Preposition'},
    'nach': {'pos': 'Preposition', 'trans': 'to / after', 'note': 'Preposition'},
    'aus': {'pos': 'Preposition', 'trans': 'from / out of', 'note': 'Preposition'},
    'von': {'pos': 'Preposition', 'trans': 'of / from', 'note': 'Preposition'},
    'mit': {'pos': 'Preposition', 'trans': 'with', 'note': 'Preposition'},
    'auf': {'pos': 'Preposition', 'trans': 'on / upon', 'note': 'Preposition'},
    'in': {'pos': 'Preposition', 'trans': 'in / into', 'note': 'Preposition'},
    'nicht': {'pos': 'Adverb', 'trans': 'not', 'note': 'Negation particle'},
  };

  // In-memory lookup cache for 10x faster token analysis
  final Map<String, Map<String, String>> _lookupCache = {};

  void clearCache() {
    _lookupCache.clear();
  }

  /// On-Device Sentence Analysis & Grammar Breakdown (No Backend Call)
  Future<SentenceAnalysisResult> analyzeSentenceLocally(String sentence) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final rawTokens = sentence
        .replaceAll(RegExp(r'[^\w\säöüÄÖÜß]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final List<GrammarTokenAnalysis> tokenAnalyses = [];
    final List<String> translatedWords = [];

    for (int i = 0; i < rawTokens.length; i++) {
      final token = rawTokens[i];
      final lowerToken = token.toLowerCase();

      String pos = 'Unknown';
      String trans = token;
      String note = '';

      if (_knownWords.containsKey(lowerToken)) {
        pos = _knownWords[lowerToken]!['pos']!;
        trans = _knownWords[lowerToken]!['trans']!;
        note = _knownWords[lowerToken]!['note']!;
      } else if (_lookupCache.containsKey(lowerToken)) {
        pos = _lookupCache[lowerToken]!['pos']!;
        trans = _lookupCache[lowerToken]!['trans']!;
        note = _lookupCache[lowerToken]!['note']!;
      } else {
        try {
          // 1. Try exact ultra-fast dictionary lookup first (<1ms)
          final posResults = await _dictionaryService.lookupWordFast(lowerToken);
          if (posResults.isNotEmpty && posResults.first['definitions'] != null && (posResults.first['definitions'] as List).isNotEmpty) {
            final firstDef = (posResults.first['definitions'] as List).first.toString();
            pos = (posResults.first['pos'] as String?) ?? 'Word';
            trans = _cleanTranslation(token, firstDef);
            note = 'Lemma: ${posResults.first['word']} | POS: $pos';
          } else {
            // 2. Search fuzzy match
            final dbResults = await _dictionaryService.search(lowerToken);
            if (dbResults.isNotEmpty) {
              final match = dbResults.firstWhere(
                (r) => r['definition'] != null && r['definition'].toString().isNotEmpty,
                orElse: () => dbResults.first,
              );
              pos = (match['pos'] as String?) ?? 'Word';
              String rawDef = (match['definition'] as String?) ?? token;
              trans = _cleanTranslation(token, rawDef);
              if (rawDef.contains('inflection of') || rawDef.contains('genitive') || rawDef.contains('plural')) {
                String cleanLemma = rawDef.replaceAll(RegExp(r'inflection of|[:;]'), '').trim().split(' ').first;
                if (cleanLemma.isNotEmpty) {
                  final baseRes = await _dictionaryService.lookupWordFast(cleanLemma);
                  if (baseRes.isNotEmpty && baseRes.first['definitions'] != null && (baseRes.first['definitions'] as List).isNotEmpty) {
                    trans = _cleanTranslation(token, (baseRes.first['definitions'] as List).first.toString());
                  }
                }
              }
              note = 'Lemma: ${match['word']} | POS: $pos';
            }
          }
        } catch (e) {
          print("[OnDeviceAI] Lookup error for '$token': $e");
        }

        // Apply clean translation filter
        trans = _cleanTranslation(token, trans);

        // Fallback heuristic if dictionary query yields no translation
        if (trans == token) {
          if (token.isNotEmpty && token[0] == token[0].toUpperCase()) {
            pos = 'Noun';
            note = 'German Noun';
          } else if (lowerToken.endsWith('en') || lowerToken.endsWith('et') || lowerToken.endsWith('st') || lowerToken.endsWith('te')) {
            pos = 'Verb';
            note = 'Inflected Verb';
          } else {
            pos = 'General';
            note = 'Vocabulary Item';
          }
        }

        // Cache the lookup result
        _lookupCache[lowerToken] = {'pos': pos, 'trans': trans, 'note': note};
      }

      tokenAnalyses.add(GrammarTokenAnalysis(
        word: token,
        lemma: lowerToken,
        partOfSpeech: pos,
        translation: trans,
        grammarNote: note,
      ));

      translatedWords.add(trans);
    }

    // 1. Try fluent neural translation with Google ML Kit Translate
    String? mlKitTranslation;
    try {
      final translator = await _getTranslator();
      if (translator != null) {
        mlKitTranslation = await translator.translateText(sentence);
      }
    } catch (e) {
      print("[OnDeviceAI] ML Kit NMT error: $e");
    }

    final translatedSentence = (mlKitTranslation != null && mlKitTranslation.trim().isNotEmpty)
        ? mlKitTranslation.trim()
        : _formatSentence(translatedWords);

    String structure = 'Declarative Clause';
    if (sentence.trim().endsWith('?')) {
      structure = 'Interrogative Question';
    }

    stopwatch.stop();

    return SentenceAnalysisResult(
      originalSentence: sentence,
      translatedSentence: translatedSentence,
      overallStructure: structure,
      tokens: tokenAnalyses,
    );
  }

  String _cleanTranslation(String rawWord, String rawTrans) {
    String lowerWord = rawWord.toLowerCase();

    // Direct High-Frequency German -> English mappings
    const directMap = {
      'ein': 'a',
      'eine': 'a',
      'einen': 'a',
      'einem': 'a',
      'einer': 'a',
      'eines': 'a',
      'der': 'the',
      'die': 'the',
      'das': 'the',
      'den': 'the',
      'dem': 'the',
      'des': 'the',
      'auf': 'on',
      'in': 'in',
      'von': 'from',
      'mit': 'with',
      'aus': 'from',
      'zu': 'to',
      'zum': 'to the',
      'zur': 'to the',
      'sich': 'itself',
      'diese': 'this',
      'dieser': 'this',
      'dieses': 'this',
      'diesen': 'this',
      'diesem': 'this',
      'ist': 'is',
      'sind': 'are',
      'war': 'was',
      'waren': 'were',
      'und': 'and',
      'oder': 'or',
      'aber': 'but',
    };

    if (directMap.containsKey(lowerWord)) {
      return directMap[lowerWord]!;
    }

    // Strip Wiktionary meta-strings
    String clean = rawTrans
        .replaceAll(RegExp(r'^(inflection of|past participle of|present participle of|nominative|genitive|dative|accusative|singular|plural|feminine|masculine|neuter|reflexive pronoun)[^:]*:?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?\)', caseSensitive: false), '')
        .trim();

    if (clean.isEmpty || clean.startsWith('inflection of') || clean.startsWith('past participle')) {
      clean = rawWord;
    }

    // Take cleanest first slash alternative (e.g. "a / an" -> "a", "on / upon" -> "on")
    if (clean.contains(' / ')) {
      clean = clean.split(' / ').first.trim();
    }
    if (clean.contains('/')) {
      clean = clean.split('/').first.trim();
    }

    // Take first comma/semicolon meaning
    clean = clean.split(';').first.split(',').first.trim();

    return clean.isNotEmpty ? clean : rawWord;
  }

  Future<String> translateText(String germanText) async {
    if (germanText.trim().isEmpty) return '';
    try {
      final translator = await _getTranslator();
      if (translator != null) {
        final result = await translator.translateText(germanText);
        return result.trim();
      }
    } catch (e) {
      print("[OnDeviceAI] translateText failed: $e");
    }
    return germanText;
  }

  Future<List<SubtitleCue>> translateSubtitlesOnDevice(List<SubtitleCue> cues) async {
    if (cues.isEmpty) return cues;
    final List<SubtitleCue> updatedCues = [];
    for (final cue in cues) {
      if (cue.translated.isNotEmpty) {
        updatedCues.add(cue);
      } else {
        final translatedText = await translateText(cue.original);
        updatedCues.add(SubtitleCue(
          start: cue.start,
          end: cue.end,
          original: cue.original,
          translated: translatedText,
        ));
      }
    }
    return updatedCues;
  }

  String _formatSentence(List<String> words) {
    if (words.isEmpty) return '';
    String joined = words.join(' ');
    // Clean up double spaces & punctuation spacing
    joined = joined.replaceAll(RegExp(r'\s+'), ' ');
    joined = joined.replaceAll(RegExp(r'\s+([,.\?!;:])'), r'$1');
    if (joined.isNotEmpty) {
      joined = joined[0].toUpperCase() + joined.substring(1);
    }
    return joined;
  }
}
