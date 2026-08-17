import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grammar_drill.dart';

class GrammarDrillService {
  static const _scoreKeyPrefix = 'grammar_drill_score_';

  List<GrammarDrillTopic> _topics = [
    const GrammarDrillTopic(
      id: GrammarDrillTopicId.tensesMoods,
      title: 'Tenses & Moods',
      description: 'Fill in the correct Perfekt-tense (past-tense) verb forms.',
      sheets: [
        GrammarDrillSheet(
          id: 'tensesMoods_1',
          title: 'Sheet 1: Perfekt Tense',
          questions: [
            GrammarDrillQuestion(
              id: 'tm_1',
              prompt: 'Ich ___ gestern Pizza ___.',
              blanks: [
                GrammarDrillBlank(correctAnswer: 'habe', hint: 'haben'),
                GrammarDrillBlank(correctAnswer: 'gegessen', hint: 'essen'),
              ],
            ),
            GrammarDrillQuestion(
              id: 'tm_2',
              prompt: 'Er ___ nach Berlin ___.',
              blanks: [
                GrammarDrillBlank(correctAnswer: 'ist', hint: 'sein'),
                GrammarDrillBlank(correctAnswer: 'gefahren', hint: 'fahren'),
              ],
            ),
          ],
        ),
      ],
    ),
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
      id: GrammarDrillTopicId.nounsArticles,
      title: 'Nouns & Articles',
      description: 'Pick the article that matches each noun\'s gender, case, or plural form.',
      sheets: [
        GrammarDrillSheet(
          id: 'nounsArticles_1',
          title: 'Sheet 1: Articles & Plurals',
          questions: [
            GrammarDrillQuestion(
              id: 'na_1',
              prompt: '___ Hund ist braun.',
              blanks: [GrammarDrillBlank(correctAnswer: 'Der', options: ['Der', 'Die', 'Das', 'Den'])],
            ),
            GrammarDrillQuestion(
              id: 'na_2',
              prompt: 'Der Plural von \'Buch\' ist \'___\'.',
              blanks: [GrammarDrillBlank(correctAnswer: 'Bücher', options: ['Bücher', 'Buche', 'Buchs', 'Buchen'])],
            ),
          ],
        ),
      ],
    ),
    const GrammarDrillTopic(
      id: GrammarDrillTopicId.adjectives,
      title: 'Adjectives',
      description: 'Choose the correct adjective ending, comparative, or superlative form.',
      sheets: [
        GrammarDrillSheet(
          id: 'adjectives_1',
          title: 'Sheet 1: Endings & Comparison',
          questions: [
            GrammarDrillQuestion(
              id: 'adj_1',
              prompt: 'Das ist ein ___ Auto.',
              blanks: [GrammarDrillBlank(correctAnswer: 'schnelles', options: ['schnelles', 'schneller', 'schnelle', 'schnellen'])],
            ),
            GrammarDrillQuestion(
              id: 'adj_2',
              prompt: 'Berlin ist ___ als München.',
              blanks: [GrammarDrillBlank(correctAnswer: 'größer', options: ['größer', 'größter', 'groß', 'am größten'])],
            ),
          ],
        ),
      ],
    ),
    const GrammarDrillTopic(
      id: GrammarDrillTopicId.numbers,
      title: 'Numbers',
      description: 'Spell out the German word for each number.',
      sheets: [
        GrammarDrillSheet(
          id: 'numbers_1',
          title: 'Sheet 1: Cardinal Numbers',
          questions: [
            GrammarDrillQuestion(
              id: 'num_1',
              prompt: 'Schreibe die Zahl: 5',
              blanks: [GrammarDrillBlank(correctAnswer: 'fünf')],
            ),
            GrammarDrillQuestion(
              id: 'num_2',
              prompt: 'Schreibe die Zahl: 12',
              blanks: [GrammarDrillBlank(correctAnswer: 'zwölf')],
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
    const GrammarDrillTopic(
      id: GrammarDrillTopicId.adverbs,
      title: 'Adverbs',
      description: 'Pick the temporal, local, causal, or modal adverb that fits.',
      sheets: [
        GrammarDrillSheet(
          id: 'adverbs_1',
          title: 'Sheet 1: Adverb Choice',
          questions: [
            GrammarDrillQuestion(
              id: 'adv_1',
              prompt: 'Ich gehe ___ ins Kino.',
              blanks: [GrammarDrillBlank(correctAnswer: 'heute', options: ['heute', 'hier', 'deshalb', 'langsam'])],
            ),
            GrammarDrillQuestion(
              id: 'adv_2',
              prompt: 'Es regnet, ___ bleibe ich zu Hause.',
              blanks: [GrammarDrillBlank(correctAnswer: 'deshalb', options: ['deshalb', 'heute', 'hier', 'gern'])],
            ),
          ],
        ),
      ],
    ),
    const GrammarDrillTopic(
      id: GrammarDrillTopicId.conjunctions,
      title: 'Conjunctions',
      description: 'Choose the conjunction that correctly links the clauses.',
      sheets: [
        GrammarDrillSheet(
          id: 'conjunctions_1',
          title: 'Sheet 1: Coordinating & Subordinating',
          questions: [
            GrammarDrillQuestion(
              id: 'conj_1',
              prompt: 'Ich bleibe zu Hause, ___ ich krank bin.',
              blanks: [GrammarDrillBlank(correctAnswer: 'weil', options: ['weil', 'aber', 'und', 'oder'])],
            ),
            GrammarDrillQuestion(
              id: 'conj_2',
              prompt: 'Ich weiß, ___ er müde ist.',
              blanks: [GrammarDrillBlank(correctAnswer: 'dass', options: ['dass', 'weil', 'ob', 'aber'])],
            ),
          ],
        ),
      ],
    ),
    const GrammarDrillTopic(
      id: GrammarDrillTopicId.sentenceConstruction,
      title: 'Sentence Construction',
      description: 'Practice word order — verb position, negation, and questions.',
      sheets: [
        GrammarDrillSheet(
          id: 'sentenceConstruction_1',
          title: 'Sheet 1: Word Order & Negation',
          questions: [
            GrammarDrillQuestion(
              id: 'sc_1',
              prompt: 'Ich habe ___ Zeit.',
              blanks: [GrammarDrillBlank(correctAnswer: 'keine', options: ['keine', 'nicht', 'kein', 'nichts'])],
            ),
            GrammarDrillQuestion(
              id: 'sc_2',
              prompt: '___ gehe ich ins Kino.',
              blanks: [GrammarDrillBlank(correctAnswer: 'Heute', options: ['Heute', 'Ich heute', 'Heute ich', 'Gehe heute'])],
            ),
          ],
        ),
      ],
    ),
    const GrammarDrillTopic(
      id: GrammarDrillTopicId.passiveVoice,
      title: 'Passive Voice',
      description: 'Fill in the werden-conjugation and past participle for present passive.',
      sheets: [
        GrammarDrillSheet(
          id: 'passiveVoice_1',
          title: 'Sheet 1: Present Passive',
          questions: [
            GrammarDrillQuestion(
              id: 'pv_1',
              prompt: 'Das Auto ___ ___.',
              blanks: [
                GrammarDrillBlank(correctAnswer: 'wird', hint: 'werden'),
                GrammarDrillBlank(correctAnswer: 'repariert', hint: 'reparieren'),
              ],
            ),
            GrammarDrillQuestion(
              id: 'pv_2',
              prompt: 'Die Fenster ___ ___.',
              blanks: [
                GrammarDrillBlank(correctAnswer: 'werden', hint: 'werden'),
                GrammarDrillBlank(correctAnswer: 'geöffnet', hint: 'öffnen'),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  bool _isLoaded = false;

  static GrammarDrillTopicId? _topicIdFromKey(String? key) {
    switch (key) {
      case 'tensesMoods':
        return GrammarDrillTopicId.tensesMoods;
      case 'verbConjugation':
        return GrammarDrillTopicId.verbConjugation;
      case 'casesPrepositions':
        return GrammarDrillTopicId.casesPrepositions;
      case 'nounsArticles':
        return GrammarDrillTopicId.nounsArticles;
      case 'adjectives':
        return GrammarDrillTopicId.adjectives;
      case 'numbers':
        return GrammarDrillTopicId.numbers;
      case 'pronouns':
        return GrammarDrillTopicId.pronouns;
      case 'adverbs':
        return GrammarDrillTopicId.adverbs;
      case 'conjunctions':
        return GrammarDrillTopicId.conjunctions;
      case 'sentenceConstruction':
        return GrammarDrillTopicId.sentenceConstruction;
      case 'passiveVoice':
        return GrammarDrillTopicId.passiveVoice;
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
