import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/subtitle_cue.dart';
import 'app_logger.dart';
import 'gemini_api_key_store.dart';

class BackendService {
  final String baseUrl = Config.backendUrl;

  Future<Map<String, dynamic>?> importFromUrl(String url) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/import_url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'error': 'Failed with status ${response.statusCode}'};
    } catch (e) {
      AppLogger.error("importFromUrl error", error: e, tag: 'BackendService');
      return {'error': 'Connection timed out or failed: $e'};
    }
  }

  Future<Map<String, dynamic>?> submitMediaUrl(String url) async {
    try {
      final geminiKey = await GeminiApiKeyStore.getKey();
      final response = await http.post(
        Uri.parse('$baseUrl/submit-media'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url, 'client_can_transcribe': geminiKey != null}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'error': 'Server returned status ${response.statusCode}'};
    } catch (e) {
      AppLogger.error("submitMediaUrl error", error: e, tag: 'BackendService');
      return {'error': 'Connection timed out or failed: $e'};
    }
  }

  /// Resumes a task the backend paused with status `awaiting_client_transcription`,
  /// supplying subtitles the client transcribed itself via its own Gemini API key
  /// (or an empty list to have the backend fall back to server-side Whisper).
  Future<bool> resumeMediaTask(
    String taskId,
    List<SubtitleCue> subtitles, {
    String? title,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/resume-media'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task_id': taskId,
          'subtitles': subtitles.map((c) => c.toJson()).toList(),
          'title': title,
        }),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error("resumeMediaTask error", error: e, tag: 'BackendService');
      return false;
    }
  }

  /// Resumes a task the backend paused with status `awaiting_client_transcription`, supplying
  /// both the subtitles AND the studio dialogue audio the client generated itself via its own
  /// Gemini API key — so the server skips its own Gemini TTS call entirely and just aligns
  /// timestamps to the uploaded audio, letting the client's key cover both Gemini calls.
  Future<bool> resumeMediaTaskWithAudio(
    String taskId,
    List<SubtitleCue> subtitles,
    Uint8List audioBytes, {
    String? title,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/resume-media-with-audio'),
      )
        ..fields['task_id'] = taskId
        ..fields['subtitles'] = jsonEncode(subtitles.map((c) => c.toJson()).toList())
        ..files.add(http.MultipartFile.fromBytes('audio', audioBytes, filename: 'dialogue.wav'));
      if (title != null) request.fields['title'] = title;

      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      return streamedResponse.statusCode == 200;
    } catch (e) {
      AppLogger.error("resumeMediaTaskWithAudio error", error: e, tag: 'BackendService');
      return false;
    }
  }

  Future<Map<String, dynamic>?> checkMediaStatus(String taskId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/status/$taskId'),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {
        'error': 'Server returned status ${response.statusCode}',
        'status': response.statusCode == 404 ? 'not_found' : 'error',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      AppLogger.error("checkMediaStatus error", error: e, tag: 'BackendService');
      return {'error': e.toString(), 'status': 'error'};
    }
  }

  Stream<Map<String, dynamic>> processFullArticleStream(String text, {String lang = 'auto'}) async* {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/process_full_stream'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'lang': lang}),
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        yield jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception("Backend HTTP status ${response.statusCode}");
      }
    } catch (e) {
      AppLogger.error("processFullArticleStream error", error: e, tag: 'BackendService');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> processText(String text, {String lang = 'de'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/process_text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'lang': lang}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      AppLogger.error("processText error", error: e, tag: 'BackendService');
      return null;
    }
  }

  Stream<Map<String, dynamic>> streamLesson(String topic, String level) async* {
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/stream_lesson'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'topic': topic,
        'level': level,
      });

      final response = await client.send(request);

      if (response.statusCode != 200) {
        yield {'type': 'error', 'error': 'Server error: ${response.statusCode}'};
        return;
      }

      String buffer = '';
      await for (var chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        while (buffer.contains('\n\n')) {
          final endIndex = buffer.indexOf('\n\n');
          final message = buffer.substring(0, endIndex);
          buffer = buffer.substring(endIndex + 2);

          if (message.startsWith('data: ')) {
            final jsonStr = message.substring(6);
            try {
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;
              yield data;
            } catch (e) {
              AppLogger.error("Error parsing SSE message", error: e, tag: 'BackendService');
            }
          }
        }
      }
    } catch (e) {
      AppLogger.error("Stream error", error: e, tag: 'BackendService');
      yield {'type': 'error', 'error': 'Connection error: $e'};
    } finally {
      client.close();
    }
  }

  Future<String?> getFreshVideoUrl(String mediaUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/refresh-url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': mediaUrl}),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['video_url'] as String?;
      }
    } catch (e) {
      AppLogger.error("Error fetching fresh video url", error: e, tag: 'BackendService');
    }
    return null;
  }
}
