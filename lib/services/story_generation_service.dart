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

        if (results.isNotEmpty) {
          return _withGeneratedThumbnails(results, apiKey);
        }
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

  // Flash Image ("Nano Banana") first, with older preview/2.0 image-capable
  // models as fallbacks in case a key's project doesn't yet have access to
  // the newer one — same defensive fallback-chain pattern used everywhere
  // else Gemini is called in this app.
  static const _imageModelsToTry = [
    'gemini-2.5-flash-image',
    'gemini-2.5-flash-image-preview',
    'gemini-2.0-flash-preview-image-generation',
  ];

  /// Best-effort: generates one AI illustration per story in parallel and
  /// swaps it in for the cycling static-asset placeholder. Any story whose
  /// image call fails (rate limit, no image access on this key, etc.) simply
  /// keeps its placeholder — a missing thumbnail should never fail the whole
  /// batch of otherwise-good generated text.
  static Future<List<GeneratedStory>> _withGeneratedThumbnails(
    List<GeneratedStory> stories,
    String apiKey,
  ) async {
    final withImages = await Future.wait(stories.map((story) async {
      final dataUri = await _generateThumbnailDataUri(
        apiKey: apiKey,
        title: story.article.title,
        description: story.article.description,
      );
      if (dataUri == null) return story;
      return GeneratedStory(
        article: Article(
          id: story.article.id,
          title: story.article.title,
          description: story.article.description,
          level: story.article.level,
          date: story.article.date,
          imageUrl: dataUri,
        ),
        content: story.content,
      );
    }));
    return withImages;
  }

  static Future<String?> _generateThumbnailDataUri({
    required String apiKey,
    required String title,
    required String description,
  }) async {
    final prompt =
        'Create a simple, friendly, flat-illustration style cover image (no text, no words, no '
        'letters, no captions anywhere in the image) representing the theme of this short German '
        'reading passage for language learners. Title: "$title". Summary: "$description". Wide '
        'landscape composition, warm and appealing colors, clean and uncluttered, suitable as a '
        'small article thumbnail.';

    for (final model in _imageModelsToTry) {
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
          'generationConfig': {
            'responseModalities': ['IMAGE'],
          },
        };

        final res = await http
            .post(
              endpoint,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 45));

        if (res.statusCode != 200) {
          AppLogger.error(
            'Thumbnail generation ($model) returned status ${res.statusCode}: ${res.body}',
            tag: 'StoryGenerationService',
          );
          continue;
        }

        final resJson = jsonDecode(utf8.decode(res.bodyBytes));
        final candidates = (resJson['candidates'] as List?) ?? [];
        if (candidates.isEmpty) continue;

        final parts = (candidates.first['content']?['parts'] as List?) ?? [];
        for (final part in parts) {
          if (part is! Map) continue;
          final inline = part['inlineData'];
          if (inline is! Map) continue;
          final mimeType = (inline['mimeType'] as String?) ?? 'image/png';
          final data = inline['data'] as String?;
          if (data != null && data.isNotEmpty) {
            return 'data:$mimeType;base64,$data';
          }
        }
      } catch (e) {
        AppLogger.error(
          'Thumbnail generation ($model) error',
          error: e,
          tag: 'StoryGenerationService',
        );
      }
    }
    return null;
  }
}
