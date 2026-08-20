import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/image_extraction_result.dart';
import 'app_logger.dart';

/// Client-side (BYOK) analysis of a photo/screenshot of German study material —
/// a vocabulary list, flashcards, a grammar table, a textbook exercise, a dialogue,
/// a sign/menu, or handwritten notes. The format is unknown in advance, so the
/// prompt asks Gemini to adaptively extract whatever is present in a single API call.
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
      'flashcards, a grammar table/conjugation chart, a textbook page/exercise, a dialogue or '
      'story excerpt, a sign/menu/label with German text, or handwritten notes. The '
      'format is unknown in advance — infer it from the image itself.\n\n'
      'Extract ALL of the following whenever present (an image often contains several):\n'
      '1. Individual vocabulary items (words/phrases worth adding to a flashcard deck), '
      'each with its German form (dictionary/infinitive form, e.g., "helfen" rather than "Ich helfe"), '
      'gender (if a noun: "m", "f", or "n"), part of speech, English translation, and example sentence.\n'
      '2. Fill-in-the-blank or grammar exercise items if the image contains an exercise '
      '(e.g. numbered sentences with blanks like "Ich helfe _____ Mann.", multiple-choice questions, case drills). '
      'For each sentence item in the exercise, extract:\n'
      '   - "id": item number or identifier (e.g. "1", "2")\n'
      '   - "text": sentence with "_____" or "..." representing the blank\n'
      '   - "answer": the correct German word/article/conjugation that fills the blank (e.g. "dem", "den")\n'
      '   - "explanation": a clear, helpful 1-2 sentence explanation in English of why this answer is correct (e.g. "helfen requires the dative case. Mann is masculine, so the definite article is dem.")\n'
      '   Also extract all possible options/pool choices in "options" (e.g. ["dem", "den", "das", "die", "der"]).\n'
      '3. Any continuous German prose (a dialogue, story, paragraph, sign text, or caption) that could stand alone as reading practice.\n\n'
      'If the image contains no legible German text at all, return '
      '{"content_type": "none", "vocabulary": [], "exercise": null, "lesson_text": null, "notes": "..."}\n\n'
      'Respond ONLY with valid JSON matching this exact schema:\n'
      '{\n'
      '  "content_type": "exercise" | "vocab_list" | "flashcards" | "grammar_table" | "textbook_page"\n'
      '                   | "dialogue" | "sign_or_menu" | "handwritten_notes" | "mixed" | "none",\n'
      '  "title": "A short descriptive title for this content (e.g. Akkusativ oder Dativ)",\n'
      '  "vocabulary": [\n'
      '    {\n'
      '      "word": "helfen",\n'
      '      "gender": null,\n'
      '      "pos": "verb",\n'
      '      "translation": "to help",\n'
      '      "example_sentence": "Ich helfe dem Mann."\n'
      '    }\n'
      '  ],\n'
      '  "exercise": {\n'
      '    "title": "Exercise Title",\n'
      '    "instruction": "Short instruction (e.g. Wählen Sie die richtige Form)",\n'
      '    "options": ["den", "dem", "das", "die", "der"],\n'
      '    "statements": [\n'
      '      {\n'
      '        "id": "1",\n'
      '        "text": "Ich helfe _____ Mann.",\n'
      '        "answer": "dem",\n'
      '        "explanation": "helfen always takes the dative case. Mann is masculine, and the masculine dative definite article is dem."\n'
      '      }\n'
      '    ]\n'
      '  },\n'
      '  "lesson_text": "Continuous German passage text here, or null if none present.",\n'
      '  "notes": "Optional short note summarizing the exercise topic or content."\n'
      '}\n'
      'Return only the valid JSON.';

  /// Downloads image bytes for the URL-input path.
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
        if (result.vocabulary.isNotEmpty ||
            result.hasExercise ||
            (result.lessonText?.isNotEmpty ?? false)) {
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

  /// Tolerates key-name drift in Gemini's response, defensive normalization
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

    Map<String, dynamic>? exerciseMap;
    if (data['exercise'] is Map) {
      final rawEx = data['exercise'] as Map<String, dynamic>;
      final rawStatements = (rawEx['statements'] ?? rawEx['questions'] ?? rawEx['items']) as List? ?? [];
      final statements = <Map<String, dynamic>>[];
      for (var i = 0; i < rawStatements.length; i++) {
        final s = rawStatements[i];
        if (s is! Map) continue;
        final text = (s['text'] ?? s['sentence'] ?? s['question'] ?? '').toString().trim();
        final answer = (s['answer'] ?? s['correct_answer'] ?? s['solution'] ?? '').toString().trim();
        final explanation = (s['explanation'] ?? s['reason'] ?? s['note'] ?? '').toString().trim();
        if (text.isEmpty && answer.isEmpty) continue;
        statements.add({
          'id': s['id']?.toString() ?? '${i + 1}',
          'text': text,
          'answer': answer,
          if (explanation.isNotEmpty) 'explanation': explanation,
        });
      }

      final rawOptions = (rawEx['options'] ?? rawEx['pool'] ?? rawEx['choices']) as List? ?? [];
      final options = rawOptions.map((o) => o.toString().trim()).where((o) => o.isNotEmpty).toList();

      if (statements.isNotEmpty) {
        exerciseMap = {
          'title': rawEx['title'] ?? data['title'] ?? 'Exercise',
          'instruction': rawEx['instruction'] ?? 'Fill in the blanks.',
          'options': options.isNotEmpty
              ? options
              : statements.map((s) => s['answer'] as String).toSet().toList(),
          'statements': statements,
        };
      }
    }

    return {
      'content_type': data['content_type'] ?? (exerciseMap != null ? 'exercise' : 'unknown'),
      'title': data['title'] ?? 'Extracted from Image',
      'vocabulary': vocabulary,
      'exercise': exerciseMap,
      'lesson_text': lessonText.isEmpty ? null : lessonText,
      'notes': data['notes'],
    };
  }
}
