import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsProgress {
  final String text;
  final int start;
  final int end;
  final String word;

  TtsProgress(this.text, this.start, this.end, this.word);
}

class TtsService {
  static final TtsService _instance = TtsService._internal();
  final FlutterTts _flutterTts = FlutterTts();
  
  final _progressController = StreamController<TtsProgress?>.broadcast();
  Stream<TtsProgress?> get progressStream => _progressController.stream;

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
      await _ensureWebVoicesLoaded();
      await _flutterTts.setLanguage("de-DE");
      // Rate scales differ by platform: web is 0–10 with 1.0 as normal speed,
      // while Android/iOS are 0–1 with 0.5 as normal. Using 0.5 on web would
      // play at half speed.
      await _flutterTts.setSpeechRate(kIsWeb ? 0.9 : 0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      if (!kIsWeb) {
        await _flutterTts.awaitSpeakCompletion(true);
      }
    } catch (_) {}

    _flutterTts.setProgressHandler((text, start, end, word) {
      _progressController.add(TtsProgress(text, start, end, word));
    });

    _flutterTts.setCompletionHandler(() {
      _progressController.add(null);
    });

    _flutterTts.setCancelHandler(() {
      _progressController.add(null);
    });

    _flutterTts.setErrorHandler((msg) {
      _progressController.add(null);
    });
  }

  Future<void> speak(String text, {String lang = "de-DE"}) async {
    // Guards against the first tap being spoken in the wrong voice if the
    // browser hasn't finished loading its voice list yet.
    await _ensureWebVoicesLoaded();
    await _flutterTts.setLanguage(lang);
    await _flutterTts.speak(text);
  }

  Future<void> speakAndWait(String text, {String lang = "de-DE"}) async {
    await _ensureWebVoicesLoaded();
    await _flutterTts.setLanguage(lang);
    if (!kIsWeb) {
      await _flutterTts.awaitSpeakCompletion(true);
    }
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _progressController.add(null);
  }

  Future<void> setLanguage(String lang) async {
    await _ensureWebVoicesLoaded();
    await _flutterTts.setLanguage(lang);
  }

  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }
}
