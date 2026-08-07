import 'package:flutter/foundation.dart';
import 'vocabulary_service.dart';

/// Manages User Mastery Level derived directly from Vocabulary Mastery score.
class GamificationService extends ChangeNotifier {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;

  int _lastVocabLevel = 1;
  bool _hasSyncedInitialVocabLevel = false;
  bool _justLeveledUp = false;

  GamificationService._internal() {
    VocabularyService().addListener(_onVocabChanged);
  }

  void _onVocabChanged() {
    final currentLevel = level;
    if (!_hasSyncedInitialVocabLevel) {
      _hasSyncedInitialVocabLevel = true;
      _lastVocabLevel = currentLevel;
      notifyListeners();
      return;
    }
    if (currentLevel > _lastVocabLevel) {
      _justLeveledUp = true;
    }
    _lastVocabLevel = currentLevel;
    notifyListeners();
  }

  /// User level is based on Vocabulary Mastery (New, Learning, Familiar, Proficient, Mastered)
  int get level => VocabularyService().vocabLevel;
  int get vocabMasteryScore => VocabularyService().vocabMasteryScore;

  /// True once, right after level crosses into a new level.
  bool get justLeveledUp => _justLeveledUp;

  void acknowledgeLevelUp() {
    _justLeveledUp = false;
    notifyListeners();
  }
}
