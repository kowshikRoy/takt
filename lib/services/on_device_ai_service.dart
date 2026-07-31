import 'package:flutter/services.dart';
import '../models/subtitle_cue.dart';

class OnDeviceAIService {
  static const MethodChannel _channel =
      MethodChannel('com.example.fb_video_player/aicore');

  /// Checks if Gemini Nano / AICore is available on this device (e.g. Pixel 9).
  Future<bool> isAvailable() async {
    try {
      final bool available = await _channel.invokeMethod('isAvailable');
      return available;
    } catch (e) {
      return false;
    }
  }

  /// Summarizes a list of transcript cues using on-device Gemini Nano.
  Future<String> summarizeTranscript(List<SubtitleCue> cues) async {
    if (cues.isEmpty) return "No transcript content to summarize.";

    final fullText = cues.map((c) => c.translated.isNotEmpty ? c.translated : c.original).join(" ");
    
    try {
      final String summary = await _channel.invokeMethod('summarizeText', {
        'text': fullText,
      });
      return summary;
    } on PlatformException catch (e) {
      return "On-Device AI error: ${e.message}";
    } catch (e) {
      return "Unable to run on-device summary: $e";
    }
  }

  /// Explains a German word using on-device Gemini Nano.
  Future<String> explainWord(String word, String contextText) async {
    try {
      final String explanation = await _channel.invokeMethod('explainWord', {
        'word': word,
        'context': contextText,
      });
      return explanation;
    } catch (e) {
      return "Word explanation unavailable: $e";
    }
  }
}
