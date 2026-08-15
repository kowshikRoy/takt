import 'dart:math';
import '../models/saved_word.dart';
import 'vocabulary_service.dart';

class MatchingPairWord {
  final String german;
  final String english;

  const MatchingPairWord({required this.german, required this.english});
}

/// Builds boards for the "Match Up" practice screen: a handful of
/// German-word/English-meaning pairs, blending the user's own saved
/// vocabulary (struggling/due words first) with a curated fallback bank.
/// Unlike DailyChallengeService's vocab slice, there's no minimum-saved-words
/// gate — the board is always fully playable, even for a brand-new user with
/// nothing saved yet.
class MatchingPairsService {
  static const int pairsPerRound = 6;

  static const List<MatchingPairWord> _fallbackBank = [
    MatchingPairWord(german: 'Haus', english: 'house'),
    MatchingPairWord(german: 'Wasser', english: 'water'),
    MatchingPairWord(german: 'Hund', english: 'dog'),
    MatchingPairWord(german: 'Katze', english: 'cat'),
    MatchingPairWord(german: 'Buch', english: 'book'),
    MatchingPairWord(german: 'Freund', english: 'friend'),
    MatchingPairWord(german: 'Schule', english: 'school'),
    MatchingPairWord(german: 'Zeit', english: 'time'),
    MatchingPairWord(german: 'Familie', english: 'family'),
    MatchingPairWord(german: 'Auto', english: 'car'),
    MatchingPairWord(german: 'Sonne', english: 'sun'),
    MatchingPairWord(german: 'Nacht', english: 'night'),
    MatchingPairWord(german: 'Arbeit', english: 'work'),
    MatchingPairWord(german: 'Straße', english: 'street'),
    MatchingPairWord(german: 'Brot', english: 'bread'),
  ];

  final VocabularyService _vocabularyService;
  final Random _random;

  MatchingPairsService({VocabularyService? vocabularyService, Random? random})
      : _vocabularyService = vocabularyService ?? VocabularyService(),
        _random = random ?? Random();

  Future<List<MatchingPairWord>> buildRound({int count = pairsPerRound}) async {
    final due = await _vocabularyService.getDueWords();
    final all = await _vocabularyService.getSavedWords();

    // Struggling/due words first, then whatever else is saved.
    final candidates = <SavedWord>[
      ...List<SavedWord>.from(due)..sort((a, b) => a.masteryLevel.compareTo(b.masteryLevel)),
      ...all.where((w) => !due.any((d) => d.id == w.id)),
    ];

    final selected = <MatchingPairWord>[];
    final usedDefs = <String>{};
    final usedWords = <String>{};

    for (final w in candidates) {
      if (selected.length >= count) break;
      final def = w.primaryDefinition.trim();
      final german = w.word.trim();
      if (def.isEmpty || german.isEmpty) continue;
      // Pairwise-distinct guard — two tiles with the same text on either
      // side would make the match ambiguous.
      if (usedDefs.contains(def.toLowerCase()) || usedWords.contains(german.toLowerCase())) continue;
      usedDefs.add(def.toLowerCase());
      usedWords.add(german.toLowerCase());
      selected.add(MatchingPairWord(german: german, english: def));
    }

    if (selected.length < count) {
      final fallback = List<MatchingPairWord>.from(_fallbackBank)..shuffle(_random);
      for (final fb in fallback) {
        if (selected.length >= count) break;
        if (usedDefs.contains(fb.english.toLowerCase()) || usedWords.contains(fb.german.toLowerCase())) continue;
        usedDefs.add(fb.english.toLowerCase());
        usedWords.add(fb.german.toLowerCase());
        selected.add(fb);
      }
    }

    selected.shuffle(_random);
    return selected.take(count).toList();
  }
}
