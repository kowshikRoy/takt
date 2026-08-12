import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subtitle_cue.dart';
import 'app_logger.dart';

/// Client-side port of the backend's `transcribe_youtube_with_gemini` (backend/main.py).
/// Calls the Gemini API directly with the user's own API key so a YouTube video can be
/// transcribed without spending the app's shared server-side Gemini quota.
class GeminiTranscriptionResult {
  final List<SubtitleCue> subtitles;
  final String? title;

  const GeminiTranscriptionResult({required this.subtitles, this.title});

  static const empty = GeminiTranscriptionResult(subtitles: []);
}

class GeminiTranscriptionService {
  GeminiTranscriptionService._();

  static const _modelsToTry = [
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
    'gemini-2.0-flash',
  ];

  static const _prompt =
      'You are an expert German language transcription and learning system. '
      'Listen to this YouTube video and produce:\n'
      '1. A clear, descriptive title for this German lesson/video/conversation.\n'
      '2. A complete, verbatim timestamped transcription of all spoken German sentences with synchronized English translations.\n'
      'Respond ONLY with a valid JSON object matching this exact schema:\n'
      '{\n'
      '  "title": "Anna helps with German Homework",\n'
      '  "subtitles": [\n'
      '    {\n'
      '      "start": 0.0,\n'
      '      "end": 13.5,\n'
      '      "original": "Anna, könntest du mir bitte kurz helfen?",\n'
      '      "translated": "Anna, could you please help me for a moment?"\n'
      '    }\n'
      '  ]\n'
      '}\n'
      'Return only the valid JSON.';

  static Future<GeminiTranscriptionResult> transcribeYoutube(
    String url,
    String apiKey,
  ) async {
    var normalizedUrl = url;
    if (normalizedUrl.contains('youtu.be/')) {
      final afterHost = normalizedUrl.split('youtu.be/')[1];
      final vid = afterHost.split('?')[0].split('&')[0];
      normalizedUrl = 'https://www.youtube.com/watch?v=$vid';
    }

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
                  'file_data': {
                    'file_uri': normalizedUrl,
                    'mime_type': 'video/*',
                  },
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
            .timeout(const Duration(seconds: 240));

        if (res.statusCode != 200) {
          AppLogger.error(
            'Gemini ($model) returned status ${res.statusCode}: ${res.body}',
            tag: 'GeminiTranscriptionService',
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
        String? extractedTitle;
        List<dynamic> rawCues = [];
        if (data is Map<String, dynamic>) {
          extractedTitle = data['title'] as String?;
          rawCues = (data['subtitles'] as List?) ?? (data['cues'] as List?) ?? [];
        } else if (data is List) {
          rawCues = data;
        }

        final cues = <SubtitleCue>[];
        for (final item in rawCues) {
          if (item is! Map) continue;
          final start = _asDouble(item['start'] ?? item['start_time']) ?? 0.0;
          final end = _asDouble(item['end'] ?? item['end_time']) ?? (start + 3.0);
          final original =
              (item['original'] ?? item['text'] ?? item['german'] ?? '')
                  .toString()
                  .trim();
          final translated =
              (item['translated'] ?? item['translation'] ?? item['english'] ?? '')
                  .toString()
                  .trim();
          if (original.isNotEmpty) {
            cues.add(SubtitleCue(
              start: start,
              end: end,
              original: original,
              translated: translated,
            ));
          }
        }

        if (cues.isNotEmpty) {
          return GeminiTranscriptionResult(subtitles: cues, title: extractedTitle);
        }
      } catch (e) {
        AppLogger.error(
          'Gemini ($model) YouTube transcription error',
          error: e,
          tag: 'GeminiTranscriptionService',
        );
      }
    }
    return GeminiTranscriptionResult.empty;
  }

  // Flash-Lite first: this is a text-only grammar/context cleanup pass, not multimodal
  // transcription, so it doesn't need Flash's heavier reasoning budget — and Flash-Lite carries
  // a notably higher free-tier request quota, which matters since this runs per non-YouTube
  // video import using the user's own key.
  static const _cleanupModelsToTry = [
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
    'gemini-2.0-flash',
  ];

  static const _cleanupPrompt =
      'You are correcting a German speech-to-text transcript produced by an automatic speech '
      'recognition model. The ASR sometimes mishears words or produces grammatically odd '
      'phrasing because it only looks at a few seconds of audio at a time. You can see the '
      'whole transcript below, in order — use that full context to fix likely mishearings, '
      'grammatical errors, and word choice so the German reads naturally and makes sense as a '
      'continuous passage. Do NOT add, remove, or invent content beyond what is already there, '
      'and do NOT change the meaning. Keep the same number of entries, in the same order. For '
      'each entry, provide the corrected German text and an accurate English translation.\n'
      'Respond ONLY with a valid JSON object matching this exact schema:\n'
      '{\n'
      '  "cues": [\n'
      '    {"original": "corrected German text", "translated": "English translation"}\n'
      '  ]\n'
      '}\n'
      'Return only the valid JSON, with exactly one entry per input line, in the same order.';

  /// Runs a text-only Gemini pass over an already-transcribed subtitle list to fix
  /// grammar/word-choice using full-passage context, and to fill in translations. Only the
  /// `original`/`translated` text is touched — timestamps are reused as-is from [subtitles]
  /// since Gemini isn't re-listening to the audio here. Returns null if the cleanup fails or the
  /// model returns a mismatched number of entries (caller should keep the original subtitles).
  static Future<List<SubtitleCue>?> cleanupTranscript(
    List<SubtitleCue> subtitles,
    String apiKey,
  ) async {
    if (subtitles.isEmpty) return null;

    final inputLines = subtitles
        .map((c) => {'original': c.original, 'translated': c.translated})
        .toList();

    for (final model in _cleanupModelsToTry) {
      try {
        final endpoint = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );
        final payload = {
          'contents': [
            {
              'parts': [
                {'text': '$_cleanupPrompt\n\nInput:\n${jsonEncode(inputLines)}'},
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
            'Gemini cleanup ($model) returned status ${res.statusCode}: ${res.body}',
            tag: 'GeminiTranscriptionService',
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
        final rawCues = (data is Map<String, dynamic>) ? (data['cues'] as List?) ?? [] : [];

        if (rawCues.length != subtitles.length) {
          AppLogger.error(
            'Gemini cleanup ($model) returned ${rawCues.length} cues, expected ${subtitles.length} — discarding.',
            tag: 'GeminiTranscriptionService',
          );
          continue;
        }

        final cleaned = <SubtitleCue>[];
        for (var i = 0; i < subtitles.length; i++) {
          final item = rawCues[i];
          if (item is! Map) {
            cleaned.add(subtitles[i]);
            continue;
          }
          final original = (item['original'] as String?)?.trim();
          final translated = (item['translated'] as String?)?.trim();
          cleaned.add(SubtitleCue(
            start: subtitles[i].start,
            end: subtitles[i].end,
            original: (original != null && original.isNotEmpty) ? original : subtitles[i].original,
            translated: (translated != null && translated.isNotEmpty) ? translated : subtitles[i].translated,
          ));
        }
        return cleaned;
      } catch (e) {
        AppLogger.error(
          'Gemini cleanup ($model) error',
          error: e,
          tag: 'GeminiTranscriptionService',
        );
      }
    }
    return null;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
