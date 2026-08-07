import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_word.dart';
import 'dictionary_service.dart';
import 'vocabulary_service.dart';
import 'profile_service.dart';
import 'app_logger.dart';

class DiscoveryService extends ChangeNotifier {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;

  DiscoveryService._internal() {
    _init();
  }

  static const String _prefKeyPool = 'daily_discovery_pool_v2';
  static const String _prefKeyDate = 'daily_discovery_pool_date_v2';
  static const String _prefKeySavedToday = 'daily_discovery_saved_today_v2';

  List<Map<String, dynamic>> _pool = [];
  bool _isLoading = false;
  int _savedTodayCount = 0;

  List<Map<String, dynamic>> get pool => List.unmodifiable(_pool);
  bool get isLoading => _isLoading;
  int get savedTodayCount => _savedTodayCount;

  Future<void> _init() async {
    await loadPool();
  }

  Future<void> loadPool({bool forceRefresh = false}) async {
    if (_pool.isNotEmpty && !forceRefresh && !_isLoading) {
      await _filterSavedWords();
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final savedDate = prefs.getString(_prefKeyDate);
      final savedJson = prefs.getString(_prefKeyPool);

      if (savedDate == todayStr) {
        _savedTodayCount = prefs.getInt(_prefKeySavedToday) ?? ProfileService().todayWordsSaved;
      } else {
        _savedTodayCount = 0;
        await prefs.setInt(_prefKeySavedToday, 0);
      }

      if (!forceRefresh && savedDate == todayStr && savedJson != null) {
        final List<dynamic> list = jsonDecode(savedJson);
        _pool = list.cast<Map<String, dynamic>>();
        await _filterSavedWords();
        _isLoading = false;
        notifyListeners();
        return;
      }

      await discoverMore(limit: 20, clearExisting: true);
    } catch (e) {
      AppLogger.error("Error loading discovery pool", error: e, tag: 'DiscoveryService');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> discoverMore({int limit = 20, bool clearExisting = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final savedWords = await VocabularyService().getSavedWords();
      final learnedCount = savedWords.length;

      final fetched = await DictionaryService().getHighFrequencyWords(
        pos: 'all',
        limit: limit * 3,
        learnedCount: learnedCount,
      );

      final newWords = <Map<String, dynamic>>[];
      final existingWords = clearExisting
          ? <String>{}
          : _pool.map((e) => (e['word'] as String).toLowerCase()).toSet();

      for (final entry in fetched) {
        final wordStr = entry['word'] as String?;
        if (wordStr == null || wordStr.trim().isEmpty) continue;
        final cleanWord = wordStr.trim();
        final lower = cleanWord.toLowerCase();

        if (existingWords.contains(lower)) continue;
        final isSaved = await VocabularyService().isWordSaved(cleanWord);
        if (isSaved) continue;

        newWords.add(entry);
        existingWords.add(lower);

        if (newWords.length >= limit) break;
      }

      if (clearExisting) {
        _pool = newWords;
      } else {
        _pool = [..._pool, ...newWords];
      }

      await _saveToPrefs();
    } catch (e) {
      AppLogger.error("Error discovering more words", error: e, tag: 'DiscoveryService');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveWordFromDiscovery(Map<String, dynamic> entry) async {
    final wordStr = entry['word'] as String?;
    if (wordStr == null || wordStr.isEmpty) return;

    final newWord = SavedWord(
      id: 'disc_${DateTime.now().millisecondsSinceEpoch}',
      word: wordStr,
      gender: entry['gender'] as String?,
      pos: entry['pos'] as String?,
      ipa: entry['ipa'] as String?,
      primaryDefinition: (entry['definition'] as String?)?.trim().isNotEmpty == true
          ? entry['definition'] as String
          : 'No definition available',
    );

    await VocabularyService().upsertWord(newWord);
    await ProfileService().recordActivityToday(wordSaved: true);

    _pool.removeWhere((e) => (e['word'] as String?)?.toLowerCase() == wordStr.toLowerCase());
    _savedTodayCount++;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> _filterSavedWords() async {
    final filtered = <Map<String, dynamic>>[];
    for (final item in _pool) {
      final wordStr = item['word'] as String?;
      if (wordStr != null && !await VocabularyService().isWordSaved(wordStr)) {
        filtered.add(item);
      }
    }
    if (filtered.length != _pool.length) {
      _pool = filtered;
      await _saveToPrefs();
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      await prefs.setString(_prefKeyDate, todayStr);
      await prefs.setString(_prefKeyPool, jsonEncode(_pool));
      await prefs.setInt(_prefKeySavedToday, _savedTodayCount);
    } catch (_) {}
  }
}
