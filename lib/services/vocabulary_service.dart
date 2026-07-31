import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_word.dart';
import 'sync_service.dart';
import 'auth_service.dart';

class VocabularyService extends ChangeNotifier {
  static final VocabularyService _instance = VocabularyService._internal();
  static Database? _db;
  static Completer<Database>? _dbCompleter;
  static const String _legacyStorageKey = 'user_vocabulary_list';
  static const String _webStorageKey = 'user_vocabulary_json_v1';

  final Map<String, SavedWord> _inMemoryWords = {};

  factory VocabularyService() => _instance;

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
        print("[VocabularyService] DB init notice: $e");
      }
    }

    // Auto-sync if user is authenticated
    if (AuthService().isAuthenticated) {
      SyncService().syncNow();
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
      print("[VocabularyService] Web load error: $e");
    }
  }

  Future<void> _saveWebWords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _inMemoryWords.values.map((w) => w.toJson()).toList();
      await prefs.setString(_webStorageKey, jsonEncode(list));
    } catch (e) {
      print("[VocabularyService] Web save error: $e");
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'user_vocabulary_v1.db');

    return await openDatabase(
      path,
      version: 1,
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
      print("[VocabularyService] Legacy migration notice: $e");
    }
  }

  Future<void> upsertWord(SavedWord word, {bool notify = true, bool triggerSync = true}) async {
    if (kIsWeb) {
      _inMemoryWords[word.id] = word;
      await _saveWebWords();
    } else {
      final db = await database;
      if (db != null) {
        await db.insert(
          'saved_words',
          word.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    if (notify) notifyListeners();

    if (triggerSync && AuthService().isAuthenticated) {
      SyncService().syncNow();
    }
  }

  Future<void> mergeWordFromSync(Map<String, dynamic> jsonMap) async {
    final word = SavedWord.fromJson(jsonMap);
    await upsertWord(word, notify: true, triggerSync: false);
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
    notifyListeners();

    if (AuthService().isAuthenticated) {
      SyncService().syncNow();
    }
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
