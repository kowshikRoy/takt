import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grammar_drill.dart';

class GrammarDrillService {
  static const _scoreKeyPrefix = 'grammar_drill_score_';

  List<GrammarDrillTopic> _topics = [
    const GrammarDrillTopic(
      id: GrammarDrillTopicId.verbConjugation,
      title: 'Verb Conjugation',
      description: 'Fill in the correctly conjugated present-tense form of each verb.',
      sheets: [
        GrammarDrillSheet(
          id: 'verbConjugation_1',
          title: 'Sheet 1: Present Tense',
          questions: [
            GrammarDrillQuestion(
              id: 'vc_1',
              prompt: 'Ich ___ jeden Morgen Kaffee.',
              blanks: [GrammarDrillBlank(correctAnswer: 'trinke', hint: 'trinken')],
            ),
            GrammarDrillQuestion(
              id: 'vc_2',
              prompt: 'Du ___ sehr schnell.',
              blanks: [GrammarDrillBlank(correctAnswer: 'läufst', hint: 'laufen')],
            ),
            GrammarDrillQuestion(
              id: 'vc_3',
              prompt: 'Er ___ in Berlin.',
              blanks: [GrammarDrillBlank(correctAnswer: 'wohnt', hint: 'wohnen')],
            ),
          ],
        ),
      ],
    ),
    const GrammarDrillTopic(
      id: GrammarDrillTopicId.casesPrepositions,
      title: 'Cases & Prepositions',
      description: 'Choose the article or preposition that correctly completes each sentence.',
      sheets: [
        GrammarDrillSheet(
          id: 'casesPrepositions_1',
          title: 'Sheet 1: Articles & Prepositions',
          questions: [
            GrammarDrillQuestion(
              id: 'cp_1',
              prompt: 'Ich sehe ___ Mann.',
              blanks: [GrammarDrillBlank(correctAnswer: 'den', options: ['den', 'dem', 'der', 'die'])],
            ),
            GrammarDrillQuestion(
              id: 'cp_2',
              prompt: 'Wir fahren mit ___ Zug.',
              blanks: [GrammarDrillBlank(correctAnswer: 'dem', options: ['dem', 'den', 'der', 'des'])],
            ),
          ],
        ),
      ],
    ),
    const GrammarDrillTopic(
      id: GrammarDrillTopicId.pronouns,
      title: 'Pronouns',
      description: 'Pick the pronoun that correctly completes each sentence.',
      sheets: [
        GrammarDrillSheet(
          id: 'pronouns_1',
          title: 'Sheet 1: Personal Pronouns',
          questions: [
            GrammarDrillQuestion(
              id: 'pr_1',
              prompt: '___ bin müde.',
              blanks: [GrammarDrillBlank(correctAnswer: 'Ich', options: ['Ich', 'Du', 'Er', 'Wir'])],
            ),
            GrammarDrillQuestion(
              id: 'pr_2',
              prompt: 'Kannst ___ mir helfen?',
              blanks: [GrammarDrillBlank(correctAnswer: 'du', options: ['du', 'ihr', 'er', 'sie'])],
            ),
          ],
        ),
      ],
    ),
  ];

  bool _isLoaded = false;

  static GrammarDrillTopicId? _topicIdFromKey(String? key) {
    switch (key) {
      case 'verbConjugation':
        return GrammarDrillTopicId.verbConjugation;
      case 'casesPrepositions':
        return GrammarDrillTopicId.casesPrepositions;
      case 'pronouns':
        return GrammarDrillTopicId.pronouns;
      default:
        return null;
    }
  }

  static GrammarDrillBlank? _parseBlank(dynamic raw) {
    if (raw is! Map) return null;
    final correctAnswer = raw['correctAnswer'] as String?;
    if (correctAnswer == null || correctAnswer.isEmpty) return null;
    final options = (raw['options'] as List?)?.whereType<String>().toList();
    if (options != null && (options.length < 2 || !options.contains(correctAnswer))) return null;
    return GrammarDrillBlank(
      correctAnswer: correctAnswer,
      options: options,
      hint: raw['hint'] as String?,
    );
  }

  static GrammarDrillQuestion? _parseQuestion(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'] as String?;
    final prompt = raw['prompt'] as String?;
    if (id == null || prompt == null) return null;
    final blanksRaw = (raw['blanks'] as List?) ?? [];
    final blanks = blanksRaw.map(_parseBlank).whereType<GrammarDrillBlank>().toList();
    if (blanks.isEmpty) return null;
    return GrammarDrillQuestion(id: id, prompt: prompt, blanks: blanks);
  }

  static GrammarDrillSheet? _parseSheet(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'] as String?;
    final title = raw['title'] as String?;
    if (id == null || title == null) return null;
    final questionsRaw = (raw['questions'] as List?) ?? [];
    final questions = questionsRaw.map(_parseQuestion).whereType<GrammarDrillQuestion>().toList();
    if (questions.isEmpty) return null;
    return GrammarDrillSheet(id: id, title: title, questions: questions);
  }

  static GrammarDrillTopic? _parseTopic(dynamic raw) {
    if (raw is! Map) return null;
    final id = _topicIdFromKey(raw['id'] as String?);
    if (id == null) return null;
    final title = raw['title'] as String?;
    final description = raw['description'] as String?;
    if (title == null || description == null) return null;
    final sheetsRaw = (raw['sheets'] as List?) ?? [];
    final sheets = sheetsRaw.map(_parseSheet).whereType<GrammarDrillSheet>().toList();
    if (sheets.isEmpty) return null;
    return GrammarDrillTopic(id: id, title: title, description: description, sheets: sheets);
  }

  /// Loads the curated grammar-drill content from assets/grammar_drills.json,
  /// falling back to the small hardcoded set above on any load/parse failure
  /// (same defensive pattern as ConnectorService.loadAssetConnectors).
  Future<void> loadAssetTopics() async {
    if (_isLoaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/grammar_drills.json');
      final List data = json.decode(jsonStr);
      final loaded = data.map(_parseTopic).whereType<GrammarDrillTopic>().toList();
      if (loaded.isNotEmpty) {
        _topics = loaded;
      }
      _isLoaded = true;
    } catch (_) {}
  }

  List<GrammarDrillTopic> getTopics() {
    return List.unmodifiable(_topics);
  }

  Future<double?> getBestScore(String sheetId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_scoreKeyPrefix$sheetId');
  }

  Future<void> saveBestScore(String sheetId, double score) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getDouble('$_scoreKeyPrefix$sheetId');
    if (existing == null || score > existing) {
      await prefs.setDouble('$_scoreKeyPrefix$sheetId', score);
    }
  }
}
