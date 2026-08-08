import 'dart:io';
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

  static const Map<String, String> availablePacks = {
    'marimba': 'Marimba (Duolingo Style)',
    'bell': 'Bell (Crystalline Chime)',
    'harp': 'Harp (Acoustic Pluck)',
    'pop': 'Pop (Minimalist UI)',
    'retro': 'Retro (8-Bit Arcade)',
  };

  static const String _keySoundEnabled = 'sound_enabled_v1';
  static const String _keySoundPack = 'sound_pack_v1';

  AudioPlayer? _player;
  AudioPlayer get _audioPlayer => _player ??= AudioPlayer();
  bool _enabled = true;
  String _soundPack = 'marimba';

  bool get enabled => _enabled;
  String get soundPack => _soundPack;

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_keySoundEnabled) ?? true;
      final savedPack = prefs.getString(_keySoundPack);
      if (savedPack != null && availablePacks.containsKey(savedPack)) {
        _soundPack = savedPack;
      }
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

  Future<void> setSoundPack(String value, {bool preview = true}) async {
    if (!availablePacks.containsKey(value)) return;
    _soundPack = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySoundPack, value);
      if (preview && _enabled) {
        await playCorrect();
      }
    } catch (e) {
      AppLogger.error("Error saving sound pack setting", error: e, tag: 'SoundService');
    }
  }

  Future<void> _play(String assetPath) async {
    if (!_enabled) return;
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      _audioPlayer.stop().catchError((_) {});
      _audioPlayer.play(AssetSource(assetPath)).catchError((_) {});
    } catch (e) {
      AppLogger.error("Error playing $assetPath", error: e, tag: 'SoundService');
    }
  }

  Future<void> playCorrect() => _play('sounds/correct_$_soundPack.wav');
  Future<void> playIncorrect() => _play('sounds/incorrect_$_soundPack.wav');
  Future<void> playLevelUp() => _play('sounds/level_up.wav');

  Future<void> previewSoundPack(String pack, {bool correct = true}) async {
    if (!availablePacks.containsKey(pack)) return;
    final prefix = correct ? 'correct' : 'incorrect';
    await _play('sounds/${prefix}_$pack.wav');
  }
}
