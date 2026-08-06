import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config.dart';
import 'app_logger.dart';

/// Result of scoring a shadowing recording against a target sentence.
class ShadowingResult {
  final String transcript;
  final int score;
  final List<ShadowingWordResult> targetWords;
  final List<String> extraWords;

  ShadowingResult({
    required this.transcript,
    required this.score,
    required this.targetWords,
    required this.extraWords,
  });

  factory ShadowingResult.fromJson(Map<String, dynamic> json) {
    return ShadowingResult(
      transcript: json['transcript'] as String? ?? '',
      score: json['score'] as int? ?? 0,
      targetWords: (json['target_words'] as List<dynamic>? ?? [])
          .map((e) => ShadowingWordResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      extraWords: (json['extra_words'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class ShadowingWordResult {
  final String word;
  final String status; // correct | substituted | missing

  ShadowingWordResult({required this.word, required this.status});

  factory ShadowingWordResult.fromJson(Map<String, dynamic> json) {
    return ShadowingWordResult(
      word: json['word'] as String? ?? '',
      status: json['status'] as String? ?? 'missing',
    );
  }
}

/// Thin wrapper around the `record` package for the shadowing exercise:
/// captures a short recording of the user reading a target sentence aloud,
/// then uploads it to the OmniScribe backend's /api/speaking/score endpoint
/// for Whisper-based transcription + word-level scoring.
class SpeakingRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    final String path;
    if (kIsWeb) {
      // Ignored by record_web internally (it hands back a blob URL from
      // stop() instead), but the API still requires a path argument.
      path = 'shadowing_recording.webm';
    } else {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/shadowing_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }
    await _recorder.start(const RecordConfig(), path: path);
  }

  /// Stops recording and returns the raw audio bytes + a filename suitable
  /// for the multipart upload.
  Future<(Uint8List bytes, String filename)?> stop() async {
    final result = await _recorder.stop();
    if (result == null) return null;

    if (kIsWeb) {
      // On web, `result` is a blob: URL created by record_web — fetch it to
      // get the actual bytes.
      final response = await http.get(Uri.parse(result));
      return (response.bodyBytes, 'recording.webm');
    }

    final bytes = await File(result).readAsBytes();
    return (bytes, 'recording.m4a');
  }

  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } catch (e) {
      AppLogger.error("Error cancelling recording", error: e, tag: 'SpeakingRecordingService');
    }
  }

  Future<ShadowingResult> uploadForScoring({
    required Uint8List bytes,
    required String filename,
    required String targetText,
  }) async {
    final uri = Uri.parse('${Config.taktBackendUrl}/api/speaking/score');
    final request = http.MultipartRequest('POST', uri)
      ..fields['target_text'] = targetText
      ..files.add(http.MultipartFile.fromBytes('audio', bytes, filename: filename));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Speaking score request failed (${response.statusCode})');
    }

    return ShadowingResult.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  void dispose() {
    _recorder.dispose();
  }
}
