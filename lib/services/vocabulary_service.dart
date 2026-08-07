import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_word.dart';
import 'sync_service.dart';
import 'auth_service.dart';
import 'app_logger.dart';
import 'dictionary_service.dart';
import 'profile_service.dart';

class VocabularyService extends ChangeNotifier {
  static final VocabularyService _instance = VocabularyService._internal();
  static Database? _db;
  static Completer<Database>? _dbCompleter;
  static const String _legacyStorageKey = 'user_vocabulary_list';
  static const String _webStorageKey = 'user_vocabulary_json_v1';

  final Map<String, SavedWord> _inMemoryWords = {};
  List<SavedWord> _cachedSavedWords = [];
  List<SavedWord> _cachedDueWords = [];

  List<SavedWord> get cachedSavedWords => _cachedSavedWords;
  List<SavedWord> get cachedDueWords => _cachedDueWords;
  int get cachedSavedCount => _cachedSavedWords.length;
  int get cachedDueCount => _cachedDueWords.length;

  /// Vocabulary Mastery Score calculated from stage of each saved word:
  /// Level 0 (New): 1 pt
  /// Level 1 (Apprentice): 2 pts
  /// Level 2 (Familiar): 3 pts
  /// Level 3 (Proficient): 4 pts
  /// Level 4 (Mastered): 5 pts
  int get vocabMasteryScore {
    int points = 0;
    for (final w in _cachedSavedWords) {
      points += (w.masteryLevel + 1);
    }
    return points;
  }

  /// Calculates user level based on vocabulary mastery points
  int get vocabLevel {
    final pts = vocabMasteryScore;
    if (pts < 15) return 1;
    if (pts < 35) return 2;
    if (pts < 70) return 3;
    if (pts < 120) return 4;
    if (pts < 200) return 5;
    return 6 + ((pts - 200) ~/ 100);
  }

  int get masteredCount {
    return _cachedSavedWords.where((w) => w.category == VocabCategory.mastered || w.masteryLevel >= 4).length;
  }

  Future<void> refreshCache() async {
    _cachedSavedWords = await getSavedWords();
    _cachedDueWords = await getDueWords();
    notifyListeners();
  }

  factory VocabularyService() => _instance;

  @visibleForTesting
  static Future<void> resetForTesting() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
    _dbCompleter = null;
  }

  VocabularyService._internal() {
    _init();
  }

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_db != null) return _db!;
    if (_dbCompleter == null || _dbCompleter!.isCompleted) {
      _dbCompleter = Completer<Database>();
      _initDatabase().then((db) {
        _db = db;
        _dbCompleter!.complete(db);
      }).catchError((e) {
        _dbCompleter!.completeError(e);
      });
    }
    return _dbCompleter!.future;
  }

  Future<void> _init() async {
    if (kIsWeb) {
      await _loadWebWords();
    } else {
      try {
        await database;
        await _migrateLegacyPreferences();
      } catch (e) {
        AppLogger.error("DB init notice", error: e, tag: 'VocabularyService');
      }
    }

    await refreshCache();

    // Auto-sync if user is authenticated
    _triggerCloudSync();
  }

  /// Kicks off a cloud sync when the user is authenticated. Cloud sync is a
  /// nice-to-have on top of local persistence, so any failure here (e.g.
  /// Firebase not initialized, no network, auth plugin not ready yet) must
  /// never propagate and abort the caller's local save — that would leave
  /// the review UI stuck without advancing even though the local write
  /// already succeeded.
  void _triggerCloudSync() {
    try {
      if (AuthService().isAuthenticated) {
        SyncService().syncNow();
      }
    } catch (e) {
      AppLogger.error("Cloud sync trigger skipped", error: e, tag: 'VocabularyService');
    }
  }

  Future<void> _loadWebWords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_webStorageKey);
      if (jsonStr != null) {
        final List list = jsonDecode(jsonStr);
        _inMemoryWords.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final w = SavedWord.fromJson(item);
            _inMemoryWords[w.id] = w;
          }
        }
      }
    } catch (e) {
      AppLogger.error("Web load error", error: e, tag: 'VocabularyService');
    }
  }

  Future<void> _saveWebWords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _inMemoryWords.values.map((w) => w.toJson()).toList();
      await prefs.setString(_webStorageKey, jsonEncode(list));
    } catch (e) {
      AppLogger.error("Web save error", error: e, tag: 'VocabularyService');
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'user_vocabulary_v1.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE saved_words (
            id TEXT PRIMARY KEY,
            word TEXT NOT NULL,
            baseForm TEXT,
            pos TEXT,
            gender TEXT,
            primaryDefinition TEXT,
            definitions TEXT,
            ipa TEXT,
            contextSentence TEXT,
            sourceTitle TEXT,
            contextExamples TEXT,
            category TEXT,
            interval INTEGER,
            easeFactor REAL,
            repetitions INTEGER,
            dueDate TEXT,
            lastReviewed TEXT,
            createdAt TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE saved_words ADD COLUMN contextExamples TEXT');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _migrateLegacyPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? legacyList = prefs.getStringList(_legacyStorageKey);
      if (legacyList != null && legacyList.isNotEmpty) {
        for (final word in legacyList) {
          final existing = await getSavedWordByWord(word);
          if (existing == null) {
            final newWord = SavedWord(
              id: word.toLowerCase().trim(),
              word: word,
              primaryDefinition: word,
              category: VocabCategory.learning,
            );
            await upsertWord(newWord, notify: false);
          }
        }
        await prefs.remove(_legacyStorageKey);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error("Legacy migration notice", error: e, tag: 'VocabularyService');
    }
  }

  Future<void> upsertWord(SavedWord word, {bool notify = true, bool triggerSync = true}) async {
    SavedWord wordToSave = word;
    final existing = await getSavedWord(word.id) ?? await getSavedWordByWord(word.word);
    if (existing != null) {
      final merged = List<WordContextExample>.from(existing.contextExamples);
      for (final newEx in word.contextExamples) {
        if (!merged.any((e) => e.sentence.trim().toLowerCase() == newEx.sentence.trim().toLowerCase())) {
          merged.add(newEx);
        }
      }
      final bool hasReviewUpdate = word.lastReviewed != null &&
          (existing.lastReviewed == null || !word.lastReviewed!.isBefore(existing.lastReviewed!));
      final bool hasExplicitSrs = word.repetitions > 0 || word.interval > 0;
      final bool preserveNewSrs = hasReviewUpdate || hasExplicitSrs;

      wordToSave = SavedWord(
        id: existing.id,
        word: word.word,
        baseForm: word.baseForm ?? existing.baseForm,
        pos: word.pos ?? existing.pos,
        gender: word.gender ?? existing.gender,
        primaryDefinition: word.primaryDefinition.isNotEmpty ? word.primaryDefinition : existing.primaryDefinition,
        definitions: word.definitions.isNotEmpty ? word.definitions : existing.definitions,
        ipa: word.ipa ?? existing.ipa,
        contextSentence: word.contextSentence ?? existing.contextSentence,
        sourceTitle: word.sourceTitle ?? existing.sourceTitle,
        contextExamples: merged,
        category: word.category,
        interval: preserveNewSrs ? word.interval : existing.interval,
        easeFactor: preserveNewSrs ? word.easeFactor : existing.easeFactor,
        repetitions: preserveNewSrs ? word.repetitions : existing.repetitions,
        dueDate: preserveNewSrs ? word.dueDate : existing.dueDate,
        lastReviewed: preserveNewSrs ? word.lastReviewed : existing.lastReviewed,
        createdAt: existing.createdAt,
      );
    }

    if (kIsWeb) {
      _inMemoryWords[wordToSave.id] = wordToSave;
      await _saveWebWords();
    } else {
      final db = await database;
      if (db != null) {
        await db.insert(
          'saved_words',
          wordToSave.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    if (notify) {
      await refreshCache();
    }

    if (triggerSync) {
      _triggerCloudSync();
    }
  }

  Future<void> recordEncounterExample(String word, WordContextExample example) async {
    final wordId = word.toLowerCase().trim();
    final existing = await getSavedWord(wordId) ?? await getSavedWordByWord(word);
    if (existing != null) {
      final merged = List<WordContextExample>.from(existing.contextExamples);
      if (!merged.any((e) => e.sentence.trim().toLowerCase() == example.sentence.trim().toLowerCase())) {
        merged.add(example);
        final updated = SavedWord(
          id: existing.id,
          word: existing.word,
          baseForm: existing.baseForm,
          pos: existing.pos,
          gender: existing.gender,
          primaryDefinition: existing.primaryDefinition,
          definitions: existing.definitions,
          ipa: existing.ipa,
          contextSentence: existing.contextSentence ?? example.sentence,
          sourceTitle: existing.sourceTitle ?? example.sourceTitle,
          contextExamples: merged,
          category: existing.category,
          interval: existing.interval,
          easeFactor: existing.easeFactor,
          repetitions: existing.repetitions,
          dueDate: existing.dueDate,
          lastReviewed: existing.lastReviewed,
          createdAt: existing.createdAt,
        );
        await upsertWord(updated);
      }
    }
  }

  /// Merges a word coming from the cloud into local storage. Cloud sync can
  /// lag behind (a previous push failed, another device hasn't synced yet,
  /// etc.), so a remote copy is not necessarily newer than what's on this
  /// device. Blindly overwriting local rows with remote ones on every sync
  /// (which runs automatically on every app launch) would silently revert
  /// review progress made since the cloud was last updated — keep whichever
  /// side actually has more review progress instead of trusting remote by
  /// default.
  Future<void> mergeWordFromSync(Map<String, dynamic> jsonMap) async {
    final incoming = SavedWord.fromJson(jsonMap);
    final existing = await getSavedWord(incoming.id);
    if (existing != null && _isAtLeastAsAdvanced(existing, incoming)) {
      return;
    }
    await upsertWord(incoming, notify: true, triggerSync: false);
  }

  /// True if [local]'s review progress is at or ahead of [remote]'s, based
  /// on whichever was reviewed more recently, falling back to repetition
  /// count when neither side has been reviewed yet.
  bool _isAtLeastAsAdvanced(SavedWord local, SavedWord remote) {
    final localReviewed = local.lastReviewed;
    final remoteReviewed = remote.lastReviewed;
    if (localReviewed == null && remoteReviewed == null) {
      return local.repetitions >= remote.repetitions;
    }
    if (localReviewed == null) return false;
    if (remoteReviewed == null) return true;
    return !localReviewed.isBefore(remoteReviewed);
  }

  Future<void> removeWord(String id) async {
    if (kIsWeb) {
      _inMemoryWords.remove(id);
      await _saveWebWords();
    } else {
      final db = await database;
      if (db != null) {
        await db.delete('saved_words', where: 'id = ?', whereArgs: [id]);
      }
    }
    await refreshCache();

    _triggerCloudSync();
  }

  Future<SavedWord?> getSavedWord(String id) async {
    if (kIsWeb) return _inMemoryWords[id];
    final db = await database;
    if (db == null) return _inMemoryWords[id];
    final res = await db.query('saved_words', where: 'id = ?', whereArgs: [id], limit: 1);
    if (res.isEmpty) return null;
    return SavedWord.fromMap(res.first);
  }

  Future<SavedWord?> getSavedWordByWord(String wordStr) async {
    final clean = wordStr.trim().toLowerCase();
    if (kIsWeb) {
      for (final w in _inMemoryWords.values) {
        if (w.word.trim().toLowerCase() == clean) return w;
      }
      return null;
    }
    final db = await database;
    if (db == null) return null;
    final res = await db.query('saved_words', where: 'LOWER(word) = ?', whereArgs: [clean], limit: 1);
    if (res.isEmpty) return null;
    return SavedWord.fromMap(res.first);
  }

  Future<bool> isWordSaved(String wordStr) async {
    final word = await getSavedWordByWord(wordStr);
    return word != null && word.category != VocabCategory.ignored;
  }

  Future<List<SavedWord>> getAllSavedWords() async {
    return getSavedWords();
  }

  Future<List<SavedWord>> getSavedWords({VocabCategory? category}) async {
    if (kIsWeb) {
      final list = _inMemoryWords.values.toList();
      if (category != null) {
        return list.where((w) => w.category == category).toList();
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
    final db = await database;
    if (db == null) return _inMemoryWords.values.toList();
    List<Map<String, dynamic>> res;
    if (category != null) {
      res = await db.query(
        'saved_words',
        where: 'category = ?',
        whereArgs: [category.name],
        orderBy: 'createdAt DESC',
      );
    } else {
      res = await db.query('saved_words', orderBy: 'createdAt DESC');
    }
    return res.map((m) => SavedWord.fromMap(m)).toList();
  }

  /// Older builds of the Key Vocabulary save flow had a bug where a missing
  /// dictionary definition fell back to saving the German word itself as
  /// its own "definition" (see story_reader_screen.dart's fix). Those
  /// entries are indistinguishable from a legitimately-empty lookup except
  /// by the fact that the "definition" equals the word — re-resolve those
  /// through the same fallback chain the Dictionary page uses and persist
  /// the fix. Cheap to call on every load: only words matching that exact
  /// signature trigger a re-lookup.
  Future<int> repairStaleDefinitions() async {
    final words = await getSavedWords();
    final dictionaryService = DictionaryService();
    int fixedCount = 0;

    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      final looksStale =
          word.primaryDefinition.trim().isEmpty ||
          word.primaryDefinition.trim().toLowerCase() ==
              word.word.trim().toLowerCase();
      if (!looksStale) continue;

      String? newDef;
      try {
        final fastEntries = await dictionaryService.lookupWordFast(
          word.word,
        );
        if (fastEntries.isNotEmpty) {
          final defs = (fastEntries.first['definitions'] as List?) ?? [];
          if (defs.isNotEmpty) newDef = defs.first.toString();
        }
        if (newDef == null || newDef.isEmpty) {
          final fullEntry = await dictionaryService.lookupWord(word.word);
          final onlineDefs = (fullEntry?['definitions'] as List?) ?? [];
          if (onlineDefs.isNotEmpty) newDef = onlineDefs.first.toString();
        }
      } catch (e) {
        AppLogger.error(
          "Failed to repair definition for '${word.word}'",
          error: e,
          tag: 'VocabularyService',
        );
      }

      if (newDef == null || newDef.isEmpty) continue;

      final repaired = SavedWord(
        id: word.id,
        word: word.word,
        baseForm: word.baseForm,
        pos: word.pos,
        gender: word.gender,
        primaryDefinition: newDef,
        definitions: [newDef],
        ipa: word.ipa,
        contextSentence: word.contextSentence,
        sourceTitle: word.sourceTitle,
        category: word.category,
        interval: word.interval,
        easeFactor: word.easeFactor,
        repetitions: word.repetitions,
        dueDate: word.dueDate,
        lastReviewed: word.lastReviewed,
        createdAt: word.createdAt,
      );
      await upsertWord(
        repaired,
        notify: false,
        triggerSync: i == words.length - 1,
      );
      fixedCount++;
    }

    if (fixedCount > 0) {
      await refreshCache();
    }
    return fixedCount;
  }

  Future<List<SavedWord>> getDueWords() async {
    if (kIsWeb) {
      final now = DateTime.now();
      return _inMemoryWords.values.where((w) => w.category == VocabCategory.learning && now.isAfter(w.dueDate)).toList();
    }
    final db = await database;
    if (db == null) return [];
    final nowIso = DateTime.now().toIso8601String();
    final res = await db.query(
      'saved_words',
      where: 'category = ? AND dueDate <= ?',
      whereArgs: [VocabCategory.learning.name, nowIso],
      orderBy: 'dueDate ASC',
    );
    return res.map((m) => SavedWord.fromMap(m)).toList();
  }

  Future<void> recordReview(String id, ReviewRating rating) async {
    final word = await getSavedWord(id);
    if (word != null) {
      final updated = word.calculateNextReview(rating);
      await upsertWord(updated);
      await ProfileService().recordActivityToday(review: true);
    }
  }

  Future<Map<String, int>> getCategoryCounts() async {
    final all = await getSavedWords();
    final now = DateTime.now();

    int learning = 0;
    int mastered = 0;
    int reviewLater = 0;
    int dueToday = 0;

    for (final w in all) {
      if (w.category == VocabCategory.learning) {
        learning++;
        if (now.isAfter(w.dueDate)) {
          dueToday++;
        }
      } else if (w.category == VocabCategory.mastered) {
        mastered++;
      } else if (w.category == VocabCategory.reviewLater) {
        reviewLater++;
      }
    }

    return {
      'learning': learning,
      'mastered': mastered,
      'reviewLater': reviewLater,
      'dueToday': dueToday,
    };
  }

  Future<List<String>> getSavedWordsLegacy() async {
    final words = await getSavedWords();
    return words.map((w) => w.word).toList();
  }

  Future<void> saveWord(String wordStr) async {
    final word = SavedWord(
      id: wordStr.trim().toLowerCase(),
      word: wordStr,
      primaryDefinition: wordStr,
      category: VocabCategory.learning,
    );
    await upsertWord(word);
  }
}
