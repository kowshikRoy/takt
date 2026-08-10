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

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
