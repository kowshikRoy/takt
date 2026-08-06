import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/xp_event.dart';
import 'auth_service.dart';
import 'gamification_service.dart';
import 'analytics_service.dart';
import 'app_logger.dart';

class ProfileService extends ChangeNotifier {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;

  ProfileService._internal() {
    _init();
    AuthService().addListener(_syncAuthDisplayName);
  }

  void _syncAuthDisplayName() {
    final authName = AuthService().username;
    final authPhoto = AuthService().photoUrl;
    bool updated = false;

    if (authName != null && authName.isNotEmpty && _displayName != authName) {
      _displayName = authName;
      updated = true;
    }
    if (authPhoto != null && authPhoto.isNotEmpty && _photoUrl != authPhoto) {
      _photoUrl = authPhoto;
      updated = true;
    }

    if (updated) {
      notifyListeners();
      SharedPreferences.getInstance().then((prefs) {
        if (authName != null) prefs.setString(_keyDisplayName, authName);
        if (authPhoto != null) prefs.setString(_keyPhotoUrl, authPhoto);
      }).catchError((_) {});
    }
  }

  static const String _keyDisplayName = 'profile_display_name_v1';
  static const String _keyPhotoUrl = 'profile_photo_url_v1';
  static const String _keyJoinDate = 'profile_join_date_iso_v1';
  static const String _keyActivityDates = 'profile_activity_dates_v1';
  static const String _keyBestStreak = 'profile_best_streak_v1';
  static const String _keyTodayDate = 'profile_today_date_v1';
  static const String _keyTodayReviews = 'profile_today_reviews_v1';
  static const String _keyTodayStory = 'profile_today_story_v1';
  static const String _keyTodaySaved = 'profile_today_saved_v1';
  static const String _keyStreakFreezes = 'profile_streak_freezes_v1';
  static const String _keyLastFreezeMilestone =
      'profile_last_freeze_milestone_v1';
  static const String _keyStreakXpMilestones =
      'profile_streak_xp_milestones_v1';
  static const String _keyLastDailyGoalAwardDate =
      'profile_last_daily_goal_award_date_v1';
  static const String _keyDailyWordGoalCount =
      'profile_daily_word_goal_count_v1';

  static const int _maxStreakFreezes = 2;
  static const int _freezeMilestoneIntervalDays = 10;
  static const List<int> _streakXpMilestoneDays = [7, 30, 100];
  static const int defaultDailyWordGoalCount = 5;

  String _displayName = 'Learner';
  String? _photoUrl;
  String _joinDateFormatted = 'Joined August 2026';
  Set<String> _activityDates = {};
  int _bestStreak = 0;

  int _todayReviewsCount = 0;
  bool _todayStoryRead = false;
  int _todayWordsSaved = 0;

  int _streakFreezes = 1;
  int _lastFreezeMilestone = 0;
  Set<int> _streakXpMilestonesAwarded = {};
  String _lastDailyGoalAwardDate = '';
  bool _justUsedStreakFreeze = false;
  bool _justHitStreakXpMilestone = false;
  int _dailyWordGoalCount = defaultDailyWordGoalCount;

  String get displayName => _displayName;
  String? get photoUrl => _photoUrl ?? AuthService().photoUrl;
  String get joinDateFormatted => _joinDateFormatted;
  Set<String> get activityDates => _activityDates;
  int get bestStreak => _bestStreak;
  int get todayReviewsCount => _todayReviewsCount;
  bool get todayStoryRead => _todayStoryRead;
  int get todayWordsSaved => _todayWordsSaved;
  int get streakFreezes => _streakFreezes;
  int get dailyWordGoalCount => _dailyWordGoalCount;

  /// True once, right after a missed day was auto-repaired with a streak
  /// freeze. Call [acknowledgeStreakFreezeUsed] after showing the banner.
  bool get justUsedStreakFreeze => _justUsedStreakFreeze;

  /// True once, right after hitting a 7/30/100-day streak milestone.
  /// Call [acknowledgeStreakMilestone] after showing the celebration.
  bool get justHitStreakXpMilestone => _justHitStreakXpMilestone;

  void acknowledgeStreakFreezeUsed() {
    _justUsedStreakFreeze = false;
    notifyListeners();
  }

  void acknowledgeStreakMilestone() {
    _justHitStreakXpMilestone = false;
    notifyListeners();
  }

  Future<void> setDailyWordGoalCount(int count) async {
    _dailyWordGoalCount = count;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyDailyWordGoalCount, count);
    } catch (e) {
      AppLogger.error(
        "Error saving daily word goal count",
        error: e,
        tag: 'ProfileService',
      );
    }
  }

  /// Takes the max of local and remote so a device that hasn't pushed a
  /// locally-earned freeze yet can't have it clobbered by an older remote
  /// value on GET (the merged value is then what gets POSTed back).
  Future<void> mergeRemoteStreakFreezes(int remoteValue) async {
    final merged = remoteValue > _streakFreezes ? remoteValue : _streakFreezes;
    final clamped = merged > _maxStreakFreezes ? _maxStreakFreezes : merged;
    if (clamped == _streakFreezes) return;

    _streakFreezes = clamped;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyStreakFreezes, _streakFreezes);
    } catch (e) {
      AppLogger.error(
        "Error saving merged streak freezes",
        error: e,
        tag: 'ProfileService',
      );
    }
  }

  String _getIsoDateString(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int get currentStreak {
    if (_activityDates.isEmpty) return 0;

    final now = DateTime.now();
    final todayStr = _getIsoDateString(now);
    final yesterdayStr = _getIsoDateString(
      now.subtract(const Duration(days: 1)),
    );

    // If neither today nor yesterday has activity, current streak is 0
    if (!_activityDates.contains(todayStr) &&
        !_activityDates.contains(yesterdayStr)) {
      return 0;
    }

    // Start checking backward from today (or yesterday if today not yet active)
    DateTime checkDate = _activityDates.contains(todayStr)
        ? now
        : now.subtract(const Duration(days: 1));

    int streak = 0;
    while (true) {
      final str = _getIsoDateString(checkDate);
      if (_activityDates.contains(str)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  int get dailyTasksCompleted {
    int count = 0;
    // Task 1: SRS review or active check
    if (_todayReviewsCount > 0 ||
        _activityDates.contains(_getIsoDateString(DateTime.now()))) {
      count++;
    }
    // Task 2: Story Read
    if (_todayStoryRead) {
      count++;
    }
    // Task 3: Words Saved
    if (_todayWordsSaved > 0) {
      count++;
    }
    return count;
  }

  bool get isDailyGoalAchieved => dailyTasksCompleted >= 3;

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(_keyDisplayName);
      final authName = AuthService().username;
      if (savedName != null && savedName != 'Alex Deutsch') {
        _displayName = savedName;
      } else if (authName != null && authName.isNotEmpty) {
        _displayName = authName;
      } else {
        _displayName = 'Learner';
      }
      _photoUrl = prefs.getString(_keyPhotoUrl) ?? AuthService().photoUrl;

      final joinIso = prefs.getString(_keyJoinDate);
      if (joinIso == null) {
        final now = DateTime.now();
        const months = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        _joinDateFormatted = 'Joined ${months[now.month - 1]} ${now.year}';
        await prefs.setString(_keyJoinDate, _joinDateFormatted);
      } else {
        _joinDateFormatted = joinIso;
      }

      final datesList = prefs.getStringList(_keyActivityDates) ?? [];
      _activityDates = datesList.toSet();
      _bestStreak = prefs.getInt(_keyBestStreak) ?? 0;
      _streakFreezes = prefs.getInt(_keyStreakFreezes) ?? 1;
      _lastFreezeMilestone = prefs.getInt(_keyLastFreezeMilestone) ?? 0;
      _streakXpMilestonesAwarded =
          (prefs.getStringList(_keyStreakXpMilestones) ?? [])
              .map((s) => int.tryParse(s))
              .whereType<int>()
              .toSet();
      _lastDailyGoalAwardDate =
          prefs.getString(_keyLastDailyGoalAwardDate) ?? '';
      _dailyWordGoalCount =
          prefs.getInt(_keyDailyWordGoalCount) ?? defaultDailyWordGoalCount;

      final now = DateTime.now();
      final todayStr = _getIsoDateString(now);
      final yesterdayStr = _getIsoDateString(
        now.subtract(const Duration(days: 1)),
      );
      final dayBeforeStr = _getIsoDateString(
        now.subtract(const Duration(days: 2)),
      );

      // A single missed day (yesterday) with an unbroken streak before it,
      // and a freeze in inventory: auto-repair the chain instead of letting
      // the streak reset to 0.
      final missedExactlyOneDay =
          !_activityDates.contains(todayStr) &&
          !_activityDates.contains(yesterdayStr) &&
          _activityDates.contains(dayBeforeStr);
      if (missedExactlyOneDay && _streakFreezes > 0) {
        _activityDates.add(yesterdayStr);
        _streakFreezes--;
        _justUsedStreakFreeze = true;
        await prefs.setInt(_keyStreakFreezes, _streakFreezes);
      }

      // Ensure today is at least in activity dates if user opens the app
      _activityDates.add(todayStr);
      await prefs.setStringList(_keyActivityDates, _activityDates.toList());

      // Daily session state reset for new day
      final storedToday = prefs.getString(_keyTodayDate) ?? '';
      if (storedToday != todayStr) {
        _todayReviewsCount = 0;
        _todayStoryRead = false;
        _todayWordsSaved = 0;
        await prefs.setString(_keyTodayDate, todayStr);
        await prefs.setInt(_keyTodayReviews, 0);
        await prefs.setBool(_keyTodayStory, false);
        await prefs.setInt(_keyTodaySaved, 0);
      } else {
        _todayReviewsCount = prefs.getInt(_keyTodayReviews) ?? 0;
        _todayStoryRead = prefs.getBool(_keyTodayStory) ?? false;
        _todayWordsSaved = prefs.getInt(_keyTodaySaved) ?? 0;
      }

      _updateBestStreak();
      await _checkStreakMilestones(prefs);
      await _checkDailyGoalXp(prefs);
      notifyListeners();
    } catch (e) {
      AppLogger.error(
        "Error initializing profile",
        error: e,
        tag: 'ProfileService',
      );
    }
  }

  /// Earns a streak freeze every [_freezeMilestoneIntervalDays] (capped at
  /// [_maxStreakFreezes]) and awards streak_milestone XP at 7/30/100 days,
  /// each exactly once. Called after any change that could move the streak.
  Future<void> _checkStreakMilestones(SharedPreferences prefs) async {
    final streak = currentStreak;
    if (streak <= 0) return;

    if (streak % _freezeMilestoneIntervalDays == 0 &&
        streak > _lastFreezeMilestone &&
        _streakFreezes < _maxStreakFreezes) {
      _streakFreezes++;
      _lastFreezeMilestone = streak;
      await prefs.setInt(_keyStreakFreezes, _streakFreezes);
      await prefs.setInt(_keyLastFreezeMilestone, _lastFreezeMilestone);
    }

    if (_streakXpMilestoneDays.contains(streak) &&
        !_streakXpMilestonesAwarded.contains(streak)) {
      _streakXpMilestonesAwarded.add(streak);
      await prefs.setStringList(
        _keyStreakXpMilestones,
        _streakXpMilestonesAwarded.map((e) => e.toString()).toList(),
      );
      _justHitStreakXpMilestone = true;
      unawaited(GamificationService().awardXp(XpSource.streakMilestone));
      AnalyticsService.logEvent('streak_milestone', params: {'days': streak});
    }
  }

  /// Awards daily_goal_met XP the first time the daily goal is reached on a
  /// given day. Called after any change that could complete the daily goal.
  Future<void> _checkDailyGoalXp(SharedPreferences prefs) async {
    final todayStr = _getIsoDateString(DateTime.now());
    if (isDailyGoalAchieved && _lastDailyGoalAwardDate != todayStr) {
      _lastDailyGoalAwardDate = todayStr;
      await prefs.setString(_keyLastDailyGoalAwardDate, todayStr);
      unawaited(GamificationService().awardXp(XpSource.dailyGoalMet));
      AnalyticsService.logEvent('daily_goal_met');
    }
  }

  void _updateBestStreak() {
    final cur = currentStreak;
    if (cur > _bestStreak) {
      _bestStreak = cur;
      SharedPreferences.getInstance().then(
        (p) => p.setInt(_keyBestStreak, _bestStreak),
      );
    }
  }

  Future<void> recordActivityToday({
    bool review = false,
    bool story = false,
    bool wordSaved = false,
  }) async {
    final todayStr = _getIsoDateString(DateTime.now());
    _activityDates.add(todayStr);

    if (review) _todayReviewsCount++;
    if (story) _todayStoryRead = true;
    if (wordSaved) _todayWordsSaved++;

    _updateBestStreak();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyActivityDates, _activityDates.toList());
      await prefs.setInt(_keyTodayReviews, _todayReviewsCount);
      await prefs.setBool(_keyTodayStory, _todayStoryRead);
      await prefs.setInt(_keyTodaySaved, _todayWordsSaved);
      await _checkStreakMilestones(prefs);
      await _checkDailyGoalXp(prefs);
    } catch (e) {
      AppLogger.error("Error saving activity", error: e, tag: 'ProfileService');
    }
  }

  Future<void> updateDisplayName(String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) return;
    _displayName = clean;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDisplayName, clean);
      await AuthService().updateDisplayName(clean);
    } catch (e) {
      AppLogger.error(
        "Error updating display name",
        error: e,
        tag: 'ProfileService',
      );
    }
  }
}
