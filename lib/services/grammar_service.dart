import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grammar_lesson.dart';
import '../models/xp_event.dart';
import 'gamification_service.dart';
import 'app_logger.dart';

class GrammarService extends ChangeNotifier {
  static final GrammarService _instance = GrammarService._internal();
  factory GrammarService() => _instance;
  GrammarService._internal();

  static const String _completedLessonsKey = 'takt_completed_grammar_lessons_v1';

  List<GrammarLesson>? _cachedLessons;
  Set<String> _completedLessonIds = {};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  Set<String> get completedLessonIds => Set.unmodifiable(_completedLessonIds);

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_completedLessonsKey) ?? [];
      _completedLessonIds = saved.toSet();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      AppLogger.error(
        "Failed to initialize GrammarService preferences",
        error: e,
        tag: 'GrammarService',
      );
    }
  }

  Future<List<GrammarLesson>> getLessons() async {
    if (!_isInitialized) {
      await init();
    }
    if (_cachedLessons != null) return _cachedLessons!;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/grammar/german_grammar_lessons.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      _cachedLessons = jsonList
          .map((e) => GrammarLesson.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error(
        "Error loading german_grammar_lessons.json",
        error: e,
        tag: 'GrammarService',
      );
      _cachedLessons = [];
    }
    return _cachedLessons!;
  }

  Future<GrammarLesson?> getLessonById(String id) async {
    final list = await getLessons();
    try {
      return list.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  bool isLessonCompleted(String lessonId) {
    return _completedLessonIds.contains(lessonId);
  }

  Future<bool> markLessonCompleted(String lessonId) async {
    await init();
    if (_completedLessonIds.contains(lessonId)) {
      return false; // Already completed
    }

    _completedLessonIds.add(lessonId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_completedLessonsKey, _completedLessonIds.toList());
      
      // Award XP for grammar lesson completion
      await GamificationService().awardXp(
        XpSource.lessonComplete,
      );
    } catch (e) {
      AppLogger.error(
        "Failed to save completed grammar lesson",
        error: e,
        tag: 'GrammarService',
      );
    }

    notifyListeners();
    return true;
  }

  Future<List<String>> getCategories() async {
    final lessons = await getLessons();
    final categories = <String>{};
    for (final l in lessons) {
      categories.add(l.category);
    }
    return categories.toList()..sort();
  }

  Future<List<String>> getLevels() async {
    final lessons = await getLessons();
    final levels = <String>{};
    for (final l in lessons) {
      levels.add(l.level);
    }
    return levels.toList()..sort();
  }
}
