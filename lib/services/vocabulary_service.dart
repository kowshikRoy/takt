import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
import 'home_screen_widget_service.dart';

class VocabularyService extends ChangeNotifier {
  static final VocabularyService _instance = VocabularyService._internal();
  static Database? _db;
  static Completer<Database>? _dbCompleter;
  static const String _legacyStorageKey = 'user_vocabulary_list';
  static const String _webStorageKey = 'user_vocabulary_json_v1';
  static const String _deletedStorageKey = 'takt_deleted_vocabulary_ids';

  final Map<String, SavedWord> _inMemoryWords = {};
  Set<String> _deletedWordIds = {};
  List<SavedWord> _cachedSavedWords = [];
  List<SavedWord> _cachedDueWords = [];

  List<SavedWord> get cachedSavedWords => _cachedSavedWords;
  List<SavedWord> get cachedDueWords => _cachedDueWords;
  int get cachedSavedCount => _cachedSavedWords.length;
  int get cachedDueCount => _cachedDueWords.length;

  List<String> getDeletedWordIdsForSync() => _deletedWordIds.toList();

  Future<void> clearDeletedWordIds() async {
    _deletedWordIds.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deletedStorageKey);
    } catch (_) {}
  }

  Future<void> _loadDeletedWordIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_deletedStorageKey) ?? [];
      _deletedWordIds = list.toSet();
    } catch (_) {}
  }

  Future<void> _persistDeletedWordIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_deletedStorageKey, _deletedWordIds.toList());
    } catch (_) {}
  }

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
    if (kIsWeb) {
      _instance._inMemoryWords.clear();
    } else {
      final db = await _instance.database;
      if (db != null && db.isOpen) {
        await db.delete('saved_words');
      }
    }
    _instance._inMemoryWords.clear();
    await _instance.refreshCache();
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
    await _loadDeletedWordIds();
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
      version: 5,
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
            createdAt TEXT,
            source TEXT DEFAULT 'dictionary_saved'
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE saved_words ADD COLUMN contextExamples TEXT');
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute("ALTER TABLE saved_words ADD COLUMN source TEXT DEFAULT 'dictionary_saved'");
          } catch (_) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute("UPDATE saved_words SET source = 'dictionary_saved' WHERE source = 'user_database' OR source = 'user_added' OR source IS NULL");
          } catch (_) {}
        }
        if (oldVersion < 5) {
          try {
            await db.execute('ALTER TABLE saved_words ADD COLUMN baseForm TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE saved_words ADD COLUMN pos TEXT');
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
    final cleanId = word.id.trim().toLowerCase();
    final cleanWord = word.word.trim().toLowerCase();
    if (_deletedWordIds.remove(word.id) ||
        _deletedWordIds.remove(cleanId) ||
        _deletedWordIds.remove(word.word) ||
        _deletedWordIds.remove(cleanWord)) {
      _persistDeletedWordIds();
    }

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

    if (existing == null && wordToSave.category != VocabCategory.ignored) {
      await ProfileService().recordActivityToday(wordSaved: true);
    }

    if (triggerSync) {
      _triggerCloudSync();
    }
    unawaited(HomeScreenWidgetService().updateWidgetData());
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

  /// Merges a word coming from the cloud into local storage.
  Future<void> mergeWordFromSync(Map<String, dynamic> jsonMap) async {
    final incoming = SavedWord.fromJson(jsonMap);
    final cleanId = incoming.id.trim().toLowerCase();
    final cleanWord = incoming.word.trim().toLowerCase();

    // Do not resurrect words marked as deleted locally
    if (_deletedWordIds.contains(incoming.id) ||
        _deletedWordIds.contains(cleanId) ||
        _deletedWordIds.contains(incoming.word) ||
        _deletedWordIds.contains(cleanWord)) {
      return;
    }

    final existing = await getSavedWord(incoming.id) ?? await getSavedWordByWord(incoming.word);
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

  Future<void> removeWord(String idOrWord) async {
    final clean = idOrWord.trim().toLowerCase();

    // 1. Remove from in-memory / web
    _inMemoryWords.remove(idOrWord);
    _inMemoryWords.remove(clean);
    _inMemoryWords.removeWhere((k, v) =>
        k.toLowerCase() == clean ||
        v.word.toLowerCase() == clean ||
        v.id.toLowerCase() == clean);

    if (kIsWeb) {
      await _saveWebWords();
    } else {
      // 2. Remove from local SQLite database (matching by ID or Word case-insensitively)
      final db = await database;
      if (db != null) {
        await db.delete(
          'saved_words',
          where: 'id = ? OR LOWER(id) = ? OR LOWER(word) = ?',
          whereArgs: [idOrWord, clean, clean],
        );
      }
    }

    // 3. Mark in persistent tombstone set for cloud sync
    _deletedWordIds.add(idOrWord);
    _deletedWordIds.add(clean);
    await _persistDeletedWordIds();

    await refreshCache();
    _triggerCloudSync();
    unawaited(HomeScreenWidgetService().updateWidgetData());
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

  /// Re-evaluates saved words against updated dictionary & OpenNLP POS contextual disambiguation.
  /// Fixes stale definitions, resolves lemmas, and updates incorrect POS tags (e.g. attributive adjectives).
  Future<int> refreshAndRepairSavedWords({bool forceAll = false}) async {
    final words = await getSavedWords();
    final dictionaryService = DictionaryService();
    int updatedCount = 0;

    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.source == 'user_edited') continue;

      final hasContext = word.contextSentence != null && word.contextSentence!.trim().isNotEmpty;

      try {
        List<Map<String, dynamic>> entries;
        if (hasContext) {
          entries = await dictionaryService.lookupContextualWord(
            word.word,
            contextSentence: word.contextSentence,
          );
        } else {
          entries = await dictionaryService.lookupWordAllPOS(word.word);
        }

        if (entries.isNotEmpty) {
          final best = entries.first;
          final bestPos = best['pos']?.toString();
          final bestGender = best['gender']?.toString();
          final bestBase = best['base_form']?.toString();
          final bestIpa = best['ipa']?.toString();
          final bestDefs = (best['definitions'] as List?)?.whereType<String>().where((d) => d.trim().isNotEmpty).toList() ?? [];
          final newPrimaryDef = bestDefs.isNotEmpty
              ? bestDefs.first
              : (best['definition']?.toString() ?? word.primaryDefinition);

          final posChanged = bestPos != null &&
              bestPos.isNotEmpty &&
              DictionaryService.normalizePos(bestPos) != DictionaryService.normalizePos(word.pos);
          final defsChanged = bestDefs.isNotEmpty &&
              (newPrimaryDef != word.primaryDefinition || bestDefs.length != word.definitions.length);
          final baseChanged = bestBase != null && bestBase.isNotEmpty && bestBase != word.baseForm;

          if (posChanged || defsChanged || baseChanged || forceAll) {
            final updated = SavedWord(
              id: word.id,
              word: word.word,
              baseForm: bestBase ?? word.baseForm,
              pos: (bestPos != null && bestPos.isNotEmpty) ? bestPos : word.pos,
              gender: (bestPos?.toLowerCase() == 'noun') ? bestGender : null,
              primaryDefinition: newPrimaryDef.isNotEmpty ? newPrimaryDef : word.primaryDefinition,
              definitions: bestDefs.isNotEmpty ? bestDefs : word.definitions,
              ipa: (bestIpa != null && bestIpa.isNotEmpty) ? bestIpa : word.ipa,
              contextSentence: word.contextSentence,
              sourceTitle: word.sourceTitle,
              contextExamples: word.contextExamples,
              category: word.category,
              interval: word.interval,
              easeFactor: word.easeFactor,
              repetitions: word.repetitions,
              dueDate: word.dueDate,
              lastReviewed: word.lastReviewed,
              createdAt: word.createdAt,
              source: word.source,
            );
            await upsertWord(
              updated,
              notify: false,
              triggerSync: i == words.length - 1,
            );
            updatedCount++;
          }
        }
      } catch (e) {
        AppLogger.error(
          "Failed to refresh metadata for '${word.word}'",
          error: e,
          tag: 'VocabularyService',
        );
      }
    }

    if (updatedCount > 0) {
      await refreshCache();
    }
    return updatedCount;
  }

  Future<int> repairStaleDefinitions() async {
    return refreshAndRepairSavedWords();
  }

  Future<List<SavedWord>> getDueWords() async {
    if (kIsWeb) {
      final now = DateTime.now();
      final due = _inMemoryWords.values.where((w) => w.category == VocabCategory.learning && now.isAfter(w.dueDate)).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return _shuffleWithinDueDateDayBuckets(due);
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
    final words = res.map((m) => SavedWord.fromMap(m)).toList();
    return _shuffleWithinDueDateDayBuckets(words);
  }

  /// Groups already dueDate-ASC-sorted [words] by the calendar day of their
  /// dueDate, then shuffles within each day. Words due on the same (or an
  /// equally overdue) day are effectively tied for review priority, so their
  /// relative order shouldn't be a fixed DB/insertion order that repeats
  /// identically every session — but days are still visited oldest-first,
  /// so the most-overdue words are still reviewed first overall.
  List<SavedWord> _shuffleWithinDueDateDayBuckets(List<SavedWord> words) {
    if (words.length <= 1) return words;
    final random = Random();
    final dayOrder = <DateTime>[];
    final buckets = <DateTime, List<SavedWord>>{};
    for (final w in words) {
      final day = DateTime(w.dueDate.year, w.dueDate.month, w.dueDate.day);
      final bucket = buckets.putIfAbsent(day, () {
        dayOrder.add(day);
        return <SavedWord>[];
      });
      bucket.add(w);
    }
    final result = <SavedWord>[];
    for (final day in dayOrder) {
      final bucket = buckets[day]!..shuffle(random);
      result.addAll(bucket);
    }
    return result;
  }

  Future<void> recordReview(String id, ReviewRating rating) async {
    final word = await getSavedWord(id) ?? await getSavedWordByWord(id);
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
