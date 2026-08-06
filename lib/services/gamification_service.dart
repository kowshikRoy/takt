import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/xp_event.dart';
import 'auth_service.dart';
import 'app_logger.dart';

import 'vocabulary_service.dart';

/// Owns the XP event log and derived totals/level. Kept separate from
/// ProfileService to avoid overloading it further (see design doc §8).
class GamificationService extends ChangeNotifier {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;

  int _lastVocabLevel = 1;
  // VocabularyService fires its first notifyListeners() once it finishes
  // loading persisted data from disk on every app start, not just on a
  // live level-up. That initial notification must only calibrate
  // _lastVocabLevel to the real current level, not be compared against the
  // hardcoded default above — otherwise anyone above level 1 sees a false
  // "level up" celebration on every cold start.
  bool _hasSyncedInitialVocabLevel = false;

  GamificationService._internal() {
    _init();
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

  static const String _keyXpEvents = 'gamification_xp_events_v1';
  static const String _keyTotalXp = 'gamification_total_xp_v1';

  List<XpEvent> _events = [];
  int _totalXp = 0;
  bool _justLeveledUp = false;

  List<XpEvent> get events => List.unmodifiable(_events);
  int get totalXp => _totalXp;

  /// User level is based on Vocabulary Mastery (New, Learning, Familiar, Proficient, Mastered)
  int get level => VocabularyService().vocabLevel;
  int get vocabMasteryScore => VocabularyService().vocabMasteryScore;

  /// True once, right after level crosses into a new level. Call
  /// [acknowledgeLevelUp] after showing the celebration.
  bool get justLeveledUp => _justLeveledUp;

  void acknowledgeLevelUp() {
    _justLeveledUp = false;
    notifyListeners();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyXpEvents);
      if (raw != null) {
        final List<dynamic> decoded = jsonDecode(raw);
        _events = decoded
            .map((e) => XpEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      _totalXp =
          prefs.getInt(_keyTotalXp) ??
          _events.fold<int>(0, (sum, e) => sum + e.amount);
      notifyListeners();
    } catch (e) {
      AppLogger.error("Error initializing", error: e, tag: 'GamificationService');
    }
  }

  Future<void> awardXp(XpSource source, {int? amountOverride}) async {
    final amount = amountOverride ?? source.defaultAmount;
    final event = XpEvent(
      id: 'xp_${DateTime.now().microsecondsSinceEpoch}',
      userId: AuthService().userId,
      source: source,
      amount: amount,
      timestamp: DateTime.now(),
    );

    final levelBefore = level;
    _events.add(event);
    _totalXp += amount;
    if (level > levelBefore) {
      _justLeveledUp = true;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyXpEvents,
        jsonEncode(_events.map((e) => e.toJson()).toList()),
      );
      await prefs.setInt(_keyTotalXp, _totalXp);
    } catch (e) {
      AppLogger.error("Error saving XP event", error: e, tag: 'GamificationService');
    }
  }

  /// Unions remote XP events into the local log by id and recomputes
  /// totalXp from the deduped set — never adds remote's amount on top of
  /// the local total, which would double-count events synced previously.
  /// Doesn't trigger the level-up celebration; that's reserved for XP
  /// earned live via [awardXp], not passively merged in from another device.
  Future<void> mergeRemoteEvents(List<dynamic> remoteEventsJson) async {
    final merged = {for (final e in _events) e.id: e};
    for (final raw in remoteEventsJson) {
      if (raw is Map<String, dynamic>) {
        try {
          final event = XpEvent.fromJson(raw);
          merged[event.id] = event;
        } catch (_) {}
      }
    }

    if (merged.length == _events.length) return;

    _events = merged.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _totalXp = _events.fold<int>(0, (sum, e) => sum + e.amount);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyXpEvents,
        jsonEncode(_events.map((e) => e.toJson()).toList()),
      );
      await prefs.setInt(_keyTotalXp, _totalXp);
    } catch (e) {
      AppLogger.error("Error saving merged XP events", error: e, tag: 'GamificationService');
    }
  }
}
