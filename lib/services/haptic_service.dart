import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized Haptic Feedback Service providing rich, nuanced tactile response
/// across Takt (card flips, word lookups, quiz ratings, category toggles, navigation).
class HapticService extends ChangeNotifier {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;

  HapticService._internal() {
    _init();
  }

  static const String _keyHapticsEnabled = 'haptics_enabled_v1';
  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_keyHapticsEnabled) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHapticsEnabled, value);
    } catch (_) {}
  }

  /// Light tap for buttons, chips, audio buttons, small UI actions.
  static void light() {
    if (!_instance._enabled || kIsWeb) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Selection click for word lookups, tab switching, sliders, segmented controls.
  static void selection() {
    if (!_instance._enabled || kIsWeb) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Medium impact for card flips, quiz choices, status toggles, recording start/stop.
  static void medium() {
    if (!_instance._enabled || kIsWeb) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy impact for completing a lesson, finishing SRS review, level ups.
  static void heavy() {
    if (!_instance._enabled || kIsWeb) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Success tactile cue for correct answers and milestone achievements.
  static void success() {
    if (!_instance._enabled || kIsWeb) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Error tactile cue for wrong answers or validation failures.
  static void error() {
    if (!_instance._enabled || kIsWeb) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}

/// Alias for concise call sites: AppHaptics.light(), AppHaptics.selection(), etc.
typedef AppHaptics = HapticService;
