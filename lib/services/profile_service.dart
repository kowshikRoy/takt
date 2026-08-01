import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class ProfileService extends ChangeNotifier {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;

  ProfileService._internal() {
    _init();
  }

  static const String _keyDisplayName = 'profile_display_name_v1';
  static const String _keyJoinDate = 'profile_join_date_iso_v1';
  static const String _keyActivityDates = 'profile_activity_dates_v1';
  static const String _keyBestStreak = 'profile_best_streak_v1';
  static const String _keyTodayDate = 'profile_today_date_v1';
  static const String _keyTodayReviews = 'profile_today_reviews_v1';
  static const String _keyTodayStory = 'profile_today_story_v1';
  static const String _keyTodaySaved = 'profile_today_saved_v1';

  String _displayName = 'Alex Deutsch';
  String _joinDateFormatted = 'Joined August 2026';
  Set<String> _activityDates = {};
  int _bestStreak = 0;
  
  int _todayReviewsCount = 0;
  bool _todayStoryRead = false;
  int _todayWordsSaved = 0;

  String get displayName => _displayName;
  String get joinDateFormatted => _joinDateFormatted;
  Set<String> get activityDates => _activityDates;
  int get bestStreak => _bestStreak;
  int get todayReviewsCount => _todayReviewsCount;
  bool get todayStoryRead => _todayStoryRead;
  int get todayWordsSaved => _todayWordsSaved;

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
    final yesterdayStr = _getIsoDateString(now.subtract(const Duration(days: 1)));

    // If neither today nor yesterday has activity, current streak is 0
    if (!_activityDates.contains(todayStr) && !_activityDates.contains(yesterdayStr)) {
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
    if (_todayReviewsCount > 0 || _activityDates.contains(_getIsoDateString(DateTime.now()))) {
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

  int calculateTotalXp(int totalSavedWords) {
    return 150 + (currentStreak * 50) + (totalSavedWords * 25) + (_activityDates.length * 40) + (_todayReviewsCount * 10);
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _displayName = prefs.getString(_keyDisplayName) ?? AuthService().username ?? 'Alex Deutsch';
      
      final joinIso = prefs.getString(_keyJoinDate);
      if (joinIso == null) {
        final now = DateTime.now();
        const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        _joinDateFormatted = 'Joined ${months[now.month - 1]} ${now.year}';
        await prefs.setString(_keyJoinDate, _joinDateFormatted);
      } else {
        _joinDateFormatted = joinIso;
      }

      final datesList = prefs.getStringList(_keyActivityDates) ?? [];
      _activityDates = datesList.toSet();
      _bestStreak = prefs.getInt(_keyBestStreak) ?? 0;

      // Ensure today is at least in activity dates if user opens the app
      final todayStr = _getIsoDateString(DateTime.now());
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
      notifyListeners();
    } catch (e) {
      print("[ProfileService] Error initializing profile: $e");
    }
  }

  void _updateBestStreak() {
    final cur = currentStreak;
    if (cur > _bestStreak) {
      _bestStreak = cur;
      SharedPreferences.getInstance().then((p) => p.setInt(_keyBestStreak, _bestStreak));
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
    } catch (e) {
      print("[ProfileService] Error saving activity: $e");
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
    } catch (e) {
      print("[ProfileService] Error updating display name: $e");
    }
  }
}
