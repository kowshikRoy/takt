import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

class TtsProgress {
  final String text;
  final int start;
  final int end;
  final String word;

  TtsProgress(this.text, this.start, this.end, this.word);
}

class TtsVoice {
  final String name;
  final String locale;
  final String? gender;
  final String? quality;

  const TtsVoice({
    required this.name,
    required this.locale,
    this.gender,
    this.quality,
  });

  /// User-friendly display title for the voice.
  String get label {
    // If name is Android style e.g. "de-de-x-deg-local" or "de-de-x-deb-network"
    if (name.contains('-x-') || name.startsWith('de-') || name.startsWith('de_')) {
      final isLocal = name.toLowerCase().endsWith('-local');
      final isNetwork = name.toLowerCase().endsWith('-network');
      final tag = isLocal ? ' (Offline)' : (isNetwork ? ' (HQ)' : '');

      final parts = name.split('-');
      if (parts.length >= 4 && parts[2] == 'x') {
        final code = parts[3]
            .replaceAll('-local', '')
            .replaceAll('-network', '')
            .toUpperCase();
        return 'German Voice $code$tag';
      }
      return '$name$tag';
    }

    // Clean Microsoft web voice names e.g. "Microsoft Katja Online (Natural) - German (Germany)" -> "Katja (Natural)"
    if (name.startsWith('Microsoft ') && name.contains(' - ')) {
      final sub = name
          .substring('Microsoft '.length, name.indexOf(' - '))
          .replaceAll(' Online', '');
      return sub;
    }

    return name;
  }

  /// Region / locale subtitle, e.g. "Germany (de-DE)", "Austria (de-AT)", "Switzerland (de-CH)"
  String get regionLabel {
    final cleanLocale = locale.replaceAll('_', '-');
    final upper = cleanLocale.toUpperCase();
    if (upper.contains('DE-AT') || upper.endsWith('-AT') || upper == 'AT') {
      return 'Austria ($cleanLocale)';
    }
    if (upper.contains('DE-CH') || upper.endsWith('-CH') || upper == 'CH') {
      return 'Switzerland ($cleanLocale)';
    }
    if (upper.contains('DE-BE') || upper.endsWith('-BE')) {
      return 'Belgium ($cleanLocale)';
    }
    if (upper.contains('DE-LI') || upper.endsWith('-LI')) {
      return 'Liechtenstein ($cleanLocale)';
    }
    if (upper.contains('DE-LU') || upper.endsWith('-LU')) {
      return 'Luxembourg ($cleanLocale)';
    }
    if (upper.contains('DE-DE') || upper.endsWith('-DE')) {
      return 'Germany ($cleanLocale)';
    }
    return 'German ($cleanLocale)';
  }

  /// Detailed subtitle or badges (e.g. "Germany (de-DE) • Female • Enhanced")
  String get details {
    final List<String> detailsList = [regionLabel];
    if (gender != null && gender!.isNotEmpty && gender != 'unspecified') {
      detailsList.add(
        gender![0].toUpperCase() + gender!.substring(1).toLowerCase(),
      );
    }
    if (quality != null && quality!.isNotEmpty) {
      detailsList.add(quality!);
    }
    return detailsList.join(' • ');
  }

  Map<String, String> toMap() {
    return {
      'name': name,
      'locale': locale,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsVoice &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          locale == other.locale;

  @override
  int get hashCode => name.hashCode ^ locale.hashCode;
}

class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._internal();
  final FlutterTts _flutterTts = FlutterTts();

  static const String _keyVoiceName = 'tts_voice_name_v1';
  static const String _keyVoiceLocale = 'tts_voice_locale_v1';
  static const String _keySpeechRate = 'tts_speech_rate_v1';

  final _progressController = StreamController<TtsProgress?>.broadcast();
  Stream<TtsProgress?> get progressStream => _progressController.stream;

  TtsVoice? _selectedVoice;
  TtsVoice? get selectedVoice => _selectedVoice;

  List<TtsVoice> _availableVoices = [];
  List<TtsVoice> get availableVoices => List.unmodifiable(_availableVoices);

  bool _isLoadingVoices = false;
  bool get isLoadingVoices => _isLoadingVoices;

  bool _isPlayingPreview = false;
  bool get isPlayingPreview => _isPlayingPreview;

  String? _previewingVoiceKey;
  String? get previewingVoiceKey => _previewingVoiceKey;

  double _speechRate = kIsWeb ? 0.9 : 0.5;
  double get speechRate => _speechRate;

  String? _savedVoiceName;
  String? _savedVoiceLocale;

  factory TtsService() => _instance;

  TtsService._internal() {
    _initTts();
  }

  bool _webVoicesReady = false;

  /// On web, `speechSynthesis.getVoices()` returns an empty list on the first
  /// call and populates asynchronously. flutter_tts's `setLanguage` silently
  /// does nothing when that list is empty, leaving the utterance on the
  /// browser's default voice — so German text gets read aloud by an English
  /// voice. Poll until the voice list is actually populated.
  Future<void> _ensureWebVoicesLoaded() async {
    if (!kIsWeb || _webVoicesReady) return;
    for (var attempt = 0; attempt < 25; attempt++) {
      try {
        final voices = await _flutterTts.getVoices;
        if (voices is List && voices.isNotEmpty) {
          _webVoicesReady = true;
          return;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _initTts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedVoiceName = prefs.getString(_keyVoiceName);
      _savedVoiceLocale = prefs.getString(_keyVoiceLocale);
      final savedRate = prefs.getDouble(_keySpeechRate);
      if (savedRate != null && savedRate > 0) {
        _speechRate = savedRate;
      }

      await _ensureWebVoicesLoaded();

      if (_savedVoiceName != null && _savedVoiceName!.isNotEmpty) {
        _selectedVoice = TtsVoice(
          name: _savedVoiceName!,
          locale: _savedVoiceLocale ?? 'de-DE',
        );
        await _applyVoice();
      } else {
        await _flutterTts.setLanguage("de-DE");
      }

      // Rate scales differ by platform: web is 0–10 with 1.0 as normal speed,
      // while Android/iOS are 0–1 with 0.5 as normal.
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      if (!kIsWeb) {
        await _flutterTts.awaitSpeakCompletion(true);
      }
    } catch (e) {
      AppLogger.error("Error initializing TTS", error: e, tag: 'TtsService');
    }

    _flutterTts.setProgressHandler((text, start, end, word) {
      _progressController.add(TtsProgress(text, start, end, word));
    });

    _flutterTts.setCompletionHandler(() {
      _progressController.add(null);
      if (_isPlayingPreview) {
        _isPlayingPreview = false;
        _previewingVoiceKey = null;
        notifyListeners();
      }
    });

    _flutterTts.setCancelHandler(() {
      _progressController.add(null);
      if (_isPlayingPreview) {
        _isPlayingPreview = false;
        _previewingVoiceKey = null;
        notifyListeners();
      }
    });

    _flutterTts.setErrorHandler((msg) {
      _progressController.add(null);
      if (_isPlayingPreview) {
        _isPlayingPreview = false;
        _previewingVoiceKey = null;
        notifyListeners();
      }
    });

    // Populate voices in background
    getGermanVoices();
  }

  /// Fetches and caches all German voices supported by the current platform / TTS engine.
  Future<List<TtsVoice>> getGermanVoices({bool forceRefresh = false}) async {
    if (_availableVoices.isNotEmpty && !forceRefresh) {
      return _availableVoices;
    }

    _isLoadingVoices = true;
    notifyListeners();

    try {
      await _ensureWebVoicesLoaded();
      final rawVoices = await _flutterTts.getVoices;
      final List<TtsVoice> germanVoices = [];
      final Set<String> seenNames = {};

      if (rawVoices is List) {
        for (final v in rawVoices) {
          if (v is Map) {
            final name = (v['name'] ?? '').toString().trim();
            final locale = (v['locale'] ?? v['lang'] ?? '').toString().trim();
            final gender = v['gender']?.toString();
            final quality = v['quality']?.toString();

            if (name.isEmpty) continue;

            final locLower = locale.toLowerCase();
            final nameLower = name.toLowerCase();

            final isGerman = locLower.startsWith('de') ||
                locLower.contains('de-') ||
                locLower.contains('de_') ||
                nameLower.contains('deutsch') ||
                nameLower.contains('german') ||
                nameLower.startsWith('de-') ||
                nameLower.startsWith('de_');

            if (isGerman && !seenNames.contains(name)) {
              seenNames.add(name);
              germanVoices.add(TtsVoice(
                name: name,
                locale: locale.isNotEmpty ? locale : 'de-DE',
                gender: gender,
                quality: quality,
              ));
            }
          }
        }
      }

      // Sort voices: Germany (de-DE) first, then Austria, Switzerland, etc., then alphabetically by label
      germanVoices.sort((a, b) {
        final aLoc = a.locale.replaceAll('_', '-').toUpperCase();
        final bLoc = b.locale.replaceAll('_', '-').toUpperCase();

        int rank(String loc) {
          if (loc.contains('DE-DE')) return 1;
          if (loc.contains('DE-AT')) return 2;
          if (loc.contains('DE-CH')) return 3;
          if (loc.startsWith('DE')) return 4;
          return 5;
        }

        final rankA = rank(aLoc);
        final rankB = rank(bLoc);
        if (rankA != rankB) return rankA.compareTo(rankB);

        return a.label.compareTo(b.label);
      });

      _availableVoices = germanVoices;

      // Re-link selectedVoice with the richer object from availableVoices if available
      if (_savedVoiceName != null && _savedVoiceName!.isNotEmpty) {
        final matching = _availableVoices.where((v) => v.name == _savedVoiceName);
        if (matching.isNotEmpty) {
          _selectedVoice = matching.first;
        }
      }
    } catch (e) {
      AppLogger.error("Failed to load TTS voices", error: e, tag: 'TtsService');
    } finally {
      _isLoadingVoices = false;
      notifyListeners();
    }

    return _availableVoices;
  }

  /// Sets the selected German voice. Pass `null` to use the System Default voice.
  Future<void> setVoice(TtsVoice? voice) async {
    _selectedVoice = voice;
    _savedVoiceName = voice?.name;
    _savedVoiceLocale = voice?.locale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (voice == null) {
        await prefs.remove(_keyVoiceName);
        await prefs.remove(_keyVoiceLocale);
      } else {
        await prefs.setString(_keyVoiceName, voice.name);
        await prefs.setString(_keyVoiceLocale, voice.locale);
      }
      await _applyVoice();
    } catch (e) {
      AppLogger.error("Failed to save selected TTS voice", error: e, tag: 'TtsService');
    }
  }

  Future<void> _applyVoice() async {
    try {
      await _ensureWebVoicesLoaded();
      if (_selectedVoice != null) {
        await _flutterTts.setLanguage(_selectedVoice!.locale);
        await _flutterTts.setVoice({
          "name": _selectedVoice!.name,
          "locale": _selectedVoice!.locale,
        });
      } else {
        await _flutterTts.setLanguage("de-DE");
      }
    } catch (e) {
      AppLogger.error("Failed to apply TTS voice", error: e, tag: 'TtsService');
    }
  }

  /// Plays a preview sample with [voice] (or system default if `voice == null`).
  Future<void> previewVoice(
    TtsVoice? voice, {
    String sampleText = "Hallo! Willkommen bei Takt.",
  }) async {
    _isPlayingPreview = true;
    _previewingVoiceKey = voice?.name ?? '__system_default__';
    notifyListeners();

    try {
      await _ensureWebVoicesLoaded();
      await _flutterTts.stop();

      if (voice != null) {
        await _flutterTts.setLanguage(voice.locale);
        await _flutterTts.setVoice({
          "name": voice.name,
          "locale": voice.locale,
        });
      } else {
        await _flutterTts.setLanguage("de-DE");
      }

      await _flutterTts.speak(sampleText);
    } catch (e) {
      _isPlayingPreview = false;
      _previewingVoiceKey = null;
      notifyListeners();
      AppLogger.error("Failed to preview voice", error: e, tag: 'TtsService');
    }
  }

  Future<void> speak(String text, {String lang = "de-DE"}) async {
    await _ensureWebVoicesLoaded();
    await _flutterTts.stop();
    final isGerman = lang.toLowerCase().startsWith('de');
    if (isGerman && _selectedVoice != null) {
      await _applyVoice();
    } else {
      await _flutterTts.setLanguage(lang);
    }
    await _flutterTts.speak(text);
  }

  Future<void> speakAndWait(String text, {String lang = "de-DE"}) async {
    await _ensureWebVoicesLoaded();
    await _flutterTts.stop();
    final isGerman = lang.toLowerCase().startsWith('de');
    if (isGerman && _selectedVoice != null) {
      await _applyVoice();
    } else {
      await _flutterTts.setLanguage(lang);
    }
    if (!kIsWeb) {
      await _flutterTts.awaitSpeakCompletion(true);
    }
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    _isPlayingPreview = false;
    _previewingVoiceKey = null;
    await _flutterTts.stop();
    _progressController.add(null);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    await _ensureWebVoicesLoaded();
    await _flutterTts.setLanguage(lang);
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keySpeechRate, rate);
      await _flutterTts.setSpeechRate(rate);
    } catch (e) {
      AppLogger.error("Failed to save speech rate", error: e, tag: 'TtsService');
    }
  }
}
