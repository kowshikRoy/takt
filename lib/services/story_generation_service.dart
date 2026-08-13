import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article_model.dart';
import 'app_logger.dart';

/// A freshly generated reading passage, paired with its full body text (the
/// [Article] model itself has no content field — content is stored/looked up
/// separately, same as imported articles).
class GeneratedStory {
  final Article article;
  final String content;

  const GeneratedStory({required this.article, required this.content});
}

/// Client-side (BYOK) generator for diverse, level-tagged German reading
/// passages, replacing the app's old static mock story catalog. Uses the
/// user's own Gemini key so no server quota is spent — same pattern as
/// [GeminiTranscriptionService]'s YouTube transcription and cleanup pass.
class StoryGenerationService {
  StoryGenerationService._();

  static const _thumbnails = [
    'assets/images/story_desert.png',
    'assets/images/story_hair.png',
    'assets/images/story_soccer.png',
  ];

  // Flash-Lite first: generating a handful of short, level-constrained
  // reading passages is straightforward creative writing, not a task that
  // needs Flash's heavier reasoning budget, and Flash-Lite's higher
  // free-tier quota matters more here since a user may hit "Generate More"
  // repeatedly.
  static const _modelsToTry = [
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
    'gemini-2.0-flash',
  ];

  static const _topics = [
    'daily life', 'culture and traditions', 'food and cooking', 'travel',
    'nature and animals', 'technology', 'sports', 'history', 'music and art',
    'science', 'environment and climate', 'city life', 'friendship and family',
    'work and careers', 'hobbies',
  ];

  static String _buildPrompt({
    required int count,
    required List<String> levels,
    required List<String> avoidTitles,
    required List<String> focusWords,
  }) {
    final levelPlan = List.generate(count, (i) => levels[i % levels.length]).join(', ');
    final buffer = StringBuffer()
      ..writeln(
        'You are writing short German reading passages for language learners, spanning a mix '
        'of topics such as: ${_topics.join(", ")}. Write $count DISTINCT passages, one per '
        'CEFR level in this order: $levelPlan. Each passage must genuinely match its level:\n'
        '- A1/A2: very simple vocabulary, short sentences, present tense mostly.\n'
        '- B1/B2: everyday vocabulary, more varied tenses and clause structure.\n'
        '- C1: sophisticated vocabulary and sentence structure.\n'
        'Each passage should be 3-5 short paragraphs (separate paragraphs with a blank line). '
        'Pick a different topic for each passage so the set feels varied, not repetitive.',
      );
    if (avoidTitles.isNotEmpty) {
      buffer.writeln(
        'Do NOT reuse or closely resemble any of these existing titles/topics: '
        '${avoidTitles.join("; ")}.',
      );
    }
    if (focusWords.isNotEmpty) {
      buffer.writeln(
        'Where it fits naturally, try to include some of these German words the learner is '
        'practicing (do not force them if they do not fit a passage): ${focusWords.join(", ")}.',
      );
    }
    buffer.writeln(
      'Respond ONLY with a valid JSON object matching this exact schema:\n'
      '{\n'
      '  "stories": [\n'
      '    {\n'
      '      "title": "A short English title for the passage",\n'
      '      "level": "A2",\n'
      '      "description": "One short German teaser sentence",\n'
      '      "content": "Paragraph one.\\n\\nParagraph two.\\n\\nParagraph three."\n'
      '    }\n'
      '  ]\n'
      '}\n'
      'Return only the valid JSON, with exactly $count entries in "stories".',
    );
    return buffer.toString();
  }

  static Future<List<GeneratedStory>> generateStories({
    required String apiKey,
    List<String> levels = const ['A1', 'A2', 'B1', 'B2', 'C1'],
    int count = 3,
    List<String> avoidTitles = const [],
    List<String> focusWords = const [],
  }) async {
    final prompt = _buildPrompt(
      count: count,
      levels: levels,
      avoidTitles: avoidTitles,
      focusWords: focusWords,
    );

    for (final model in _modelsToTry) {
      try {
        final endpoint = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );
        final payload = {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {'responseMimeType': 'application/json'},
        };

        final res = await http
            .post(
              endpoint,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 60));

        if (res.statusCode != 200) {
          AppLogger.error(
            'Story generation ($model) returned status ${res.statusCode}: ${res.body}',
            tag: 'StoryGenerationService',
          );
          continue;
        }

        final resJson = jsonDecode(utf8.decode(res.bodyBytes));
        final candidates = (resJson['candidates'] as List?) ?? [];
        if (candidates.isEmpty) continue;

        var rawText =
            (((candidates.first['content']?['parts'] as List?)?.first
                        as Map<String, dynamic>?)?['text']
                    as String? ??
                '')
                .trim();
        if (rawText.startsWith('```json')) rawText = rawText.substring(7);
        if (rawText.startsWith('```')) rawText = rawText.substring(3);
        if (rawText.endsWith('```')) {
          rawText = rawText.substring(0, rawText.length - 3);
        }
        rawText = rawText.trim();

        final data = jsonDecode(rawText);
        final rawStories = (data is Map<String, dynamic>) ? (data['stories'] as List?) ?? [] : [];
        if (rawStories.isEmpty) continue;

        final results = <GeneratedStory>[];
        final baseId = DateTime.now().millisecondsSinceEpoch;
        for (var i = 0; i < rawStories.length; i++) {
          final item = rawStories[i];
          if (item is! Map) continue;
          final title = (item['title'] as String?)?.trim();
          final content = (item['content'] as String?)?.trim();
          if (title == null || title.isEmpty || content == null || content.isEmpty) continue;
          final level = (item['level'] as String?)?.trim().toUpperCase() ?? 'A2';
          final description = (item['description'] as String?)?.trim() ?? '';

          results.add(GeneratedStory(
            article: Article(
              id: 'gen_${baseId}_$i',
              title: title,
              description: description,
              level: level,
              date: DateTime.now(),
              imageUrl: _thumbnails[(baseId + i) % _thumbnails.length],
            ),
            content: content,
          ));
        }

        if (results.isNotEmpty) return results;
      } catch (e) {
        AppLogger.error(
          'Story generation ($model) error',
          error: e,
          tag: 'StoryGenerationService',
        );
      }
    }
    return [];
  }
}
