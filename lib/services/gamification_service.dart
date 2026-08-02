import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/xp_event.dart';
import 'auth_service.dart';
import 'app_logger.dart';

/// Owns the XP event log and derived totals/level. Kept separate from
/// ProfileService to avoid overloading it further (see design doc §8).
class GamificationService extends ChangeNotifier {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;

  GamificationService._internal() {
    _init();
  }

  static const String _keyXpEvents = 'gamification_xp_events_v1';
  static const String _keyTotalXp = 'gamification_total_xp_v1';

  List<XpEvent> _events = [];
  int _totalXp = 0;
  bool _justLeveledUp = false;

  List<XpEvent> get events => List.unmodifiable(_events);
  int get totalXp => _totalXp;

  /// level = floor(sqrt(totalXp / 100)), per §3.1.
  int get level => sqrt(_totalXp / 100).floor();

  int get _xpAtLevelStart => level * level * 100;
  int get _xpAtNextLevel => (level + 1) * (level + 1) * 100;
  int get xpIntoCurrentLevel => _totalXp - _xpAtLevelStart;
  int get xpNeededForNextLevel => _xpAtNextLevel - _xpAtLevelStart;

  /// True once, right after totalXp crosses into a new level. Call
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
