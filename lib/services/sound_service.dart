import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

/// Short correct/incorrect/level-up cues. Respects a persisted mute toggle
/// (settings), since the app has no sound today — see design doc §5.
class SoundService extends ChangeNotifier {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;

  SoundService._internal() {
    _init();
  }

  static const String _keySoundEnabled = 'sound_enabled_v1';

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_keySoundEnabled) ?? true;
      notifyListeners();
    } catch (e) {
      AppLogger.error("Error initializing", error: e, tag: 'SoundService');
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySoundEnabled, value);
    } catch (e) {
      AppLogger.error("Error saving setting", error: e, tag: 'SoundService');
    }
  }

  Future<void> _play(String assetPath) async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      AppLogger.error("Error playing $assetPath", error: e, tag: 'SoundService');
    }
  }

  Future<void> playCorrect() => _play('sounds/correct.wav');
  Future<void> playIncorrect() => _play('sounds/incorrect.wav');
  Future<void> playLevelUp() => _play('sounds/level_up.wav');
}
