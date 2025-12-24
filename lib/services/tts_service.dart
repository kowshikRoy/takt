import 'dart:async';
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

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("de-DE");
    await _flutterTts.setSpeechRate(0.5); // Slightly slower for learners
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

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
    await _flutterTts.setLanguage(lang);
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _progressController.add(null);
  }

  Future<void> setLanguage(String lang) async {
    await _flutterTts.setLanguage(lang);
  }

  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }
}
