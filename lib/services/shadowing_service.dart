import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/shadowing_sentence.dart';
import 'app_logger.dart';

/// Loads the curated shadowing-practice sentence bank and hands out
/// sentences one at a time. No SRS/scheduling — mirrors the simplicity of
/// SentencePracticeService, since this is a v1 standalone practice tool.
class ShadowingService {
  static final ShadowingService _instance = ShadowingService._internal();
  factory ShadowingService() => _instance;
  ShadowingService._internal();

  List<ShadowingSentence>? _sentences;
  final Random _random = Random();

  Future<List<ShadowingSentence>> getSentences() async {
    if (_sentences != null) return _sentences!;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/speaking/shadowing_sentences.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      _sentences = jsonList
          .map((e) => ShadowingSentence.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error(
        "Error loading shadowing_sentences.json",
        error: e,
        tag: 'ShadowingService',
      );
      _sentences = [];
    }
    return _sentences!;
  }

  Future<ShadowingSentence?> randomSentence({String? excludeId}) async {
    final sentences = await getSentences();
    if (sentences.isEmpty) return null;
    if (sentences.length == 1) return sentences.first;

    ShadowingSentence next;
    do {
      next = sentences[_random.nextInt(sentences.length)];
    } while (next.id == excludeId);
    return next;
  }
}
