import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/image_extraction_result.dart';
import 'app_logger.dart';

/// Client-side (BYOK) analysis of a photo/screenshot of German study material —
/// a vocabulary list, flashcards, a grammar table, a textbook page, a dialogue,
/// a sign/menu, or handwritten notes. The format is unknown in advance, so the
/// prompt asks Gemini to adaptively extract whatever is present. Same
/// direct-to-Gemini pattern as [GeminiTranscriptionService]/[StoryGenerationService]
/// — no OmniScribe backend involved, runs entirely on the user's own key.
class GeminiVisionService {
  GeminiVisionService._();

  static const _modelsToTry = [
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
    'gemini-2.0-flash',
  ];

  static const _prompt =
      'You are an expert German-language learning assistant analyzing a photograph or '
      'screenshot of study material. The image could be ANY of: a vocabulary list, '
      'flashcards, a grammar table/conjugation chart, a textbook page, a dialogue or '
      'story excerpt, a sign/menu/label with German text, or handwritten notes. The '
      'format is unknown in advance — infer it from the image itself.\n\n'
      'Extract BOTH of the following whenever present (an image often contains both):\n'
      '1. Individual vocabulary items (words/phrases worth adding to a flashcard deck), '
      'each with its German form, gender (if a noun), part of speech, an English '
      'translation, and — if the image shows one — an example sentence.\n'
      '2. Any continuous German prose (a dialogue, story, paragraph, sign text, or '
      'caption) that could stand alone as reading practice, transcribed verbatim '
      'preserving line breaks/paragraph structure where meaningful.\n\n'
      'If the image contains only one of the two (e.g. a bare word list with no '
      'prose, or a story with no vocabulary called out), leave the other field an '
      'empty array / null — do not invent content that is not in the image.\n\n'
      'If the image contains no legible German text at all, return '
      '{"content_type": "none", "vocabulary": [], "lesson_text": null, "notes": "..."}\n\n'
      'Respond ONLY with valid JSON matching this exact schema:\n'
      '{\n'
      '  "content_type": "vocab_list" | "flashcards" | "grammar_table" | "textbook_page"\n'
      '                   | "dialogue" | "sign_or_menu" | "handwritten_notes" | "mixed" | "none",\n'
      '  "title": "A short descriptive title for this content",\n'
      '  "vocabulary": [\n'
      '    {\n'
      '      "word": "Tisch",\n'
      '      "gender": "m",\n'
      '      "pos": "noun",\n'
      '      "translation": "table",\n'
      '      "example_sentence": "Der Tisch steht im Wohnzimmer."\n'
      '    }\n'
      '  ],\n'
      '  "lesson_text": "Continuous German passage text here, or null if none present.",\n'
      '  "notes": "Optional short note about ambiguity, illegible portions, or format."\n'
      '}\n'
      'Return only the valid JSON.';

  /// Downloads image bytes for the URL-input path. Runs client-side (not via the
  /// backend), so a cross-origin image on Flutter web may fail with a CORS error —
  /// acceptable here since the primary target is the native app.
  static Future<(Uint8List, String)> fetchImageBytes(String url) async {
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Could not fetch image URL (status ${res.statusCode})');
    }
    final contentType = res.headers['content-type'] ?? '';
    if (!contentType.startsWith('image/')) {
      throw Exception('URL did not return an image');
    }
    if (res.bodyBytes.length > 15000000) {
      throw Exception('Image is too large (max 15MB)');
    }
    return (res.bodyBytes, contentType.split(';').first.trim());
  }

  static Future<ImageExtractionResult?> analyzeImage({
    required Uint8List imageBytes,
    required String mimeType,
    required String apiKey,
  }) async {
    final b64Data = base64Encode(imageBytes);

    for (final model in _modelsToTry) {
      try {
        final endpoint = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );
        final payload = {
          'contents': [
            {
              'parts': [
                {
                  'inline_data': {'mime_type': mimeType, 'data': b64Data},
                },
                {'text': _prompt},
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
            .timeout(const Duration(seconds: 90));

        if (res.statusCode != 200) {
          AppLogger.error(
            'Gemini image analysis ($model) returned status ${res.statusCode}: ${res.body}',
            tag: 'GeminiVisionService',
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
        if (data is! Map<String, dynamic>) continue;

        final normalized = _normalize(data);
        final result = ImageExtractionResult.fromJson(normalized);
        if (result.vocabulary.isNotEmpty || (result.lessonText?.isNotEmpty ?? false)) {
          return result;
        }
      } catch (e) {
        AppLogger.error(
          'Gemini image analysis ($model) error',
          error: e,
          tag: 'GeminiVisionService',
        );
      }
    }
    return null;
  }

  /// Tolerates key-name drift in Gemini's response, same defensive normalization
  /// used elsewhere in the app's Gemini-parsing code.
  static Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final rawVocab = (data['vocabulary'] as List?) ?? [];
    final vocabulary = <Map<String, dynamic>>[];
    for (final v in rawVocab) {
      if (v is! Map) continue;
      final word = (v['word'] ?? v['german'] ?? '').toString().trim();
      if (word.isEmpty) continue;
      vocabulary.add({
        'word': word,
        'gender': v['gender'],
        'pos': v['pos'],
        'translation': (v['translation'] ?? v['english'] ?? '').toString().trim(),
        'example_sentence': v['example_sentence'] ?? v['example'],
      });
    }

    final lessonText =
        (data['lesson_text'] ?? data['story'] ?? data['passage'] ?? '').toString().trim();

    return {
      'content_type': data['content_type'] ?? 'unknown',
      'title': data['title'] ?? 'Extracted from Image',
      'vocabulary': vocabulary,
      'lesson_text': lessonText.isEmpty ? null : lessonText,
      'notes': data['notes'],
    };
  }
}
