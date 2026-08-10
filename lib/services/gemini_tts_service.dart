import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'app_logger.dart';

/// Client-side port of the backend's `generate_dialogue_audio_with_gemini` (backend/main.py).
/// Calls Gemini's Studio TTS directly with the user's own API key, so a BYOK user's key covers
/// both the transcription and the (more expensive) audio-synthesis Gemini calls, instead of the
/// synthesis step always falling back to the app's shared server-side Gemini quota.
class GeminiTtsService {
  GeminiTtsService._();

  static const _model = 'gemini-2.5-flash-preview-tts';
  static const _chunkSize = 30;
  static const _sampleRate = 24000;

  /// Synthesizes studio German dialogue audio for [dialogueLines] and returns a complete WAV
  /// file (24kHz 16-bit mono), or null if synthesis failed entirely (caller should fall back to
  /// the text-only resume path and let the server synthesize with its own shared key instead).
  static Future<Uint8List?> generateDialogueAudio(
    List<String> dialogueLines,
    String apiKey,
  ) async {
    if (dialogueLines.isEmpty) return null;

    final chunks = <List<String>>[];
    for (var i = 0; i < dialogueLines.length; i += _chunkSize) {
      final end = (i + _chunkSize < dialogueLines.length) ? i + _chunkSize : dialogueLines.length;
      chunks.add(dialogueLines.sublist(i, end));
    }

    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey',
    );
    final allPcmBytes = BytesBuilder();

    for (var chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
      final dialogueText = chunks[chunkIndex].join('\n');
      final prompt =
          'You are a professional native German voice actor. '
          'Perform the following German conversation with authentic native pronunciation, lively conversational cadence, '
          'expressive intonation, natural breathing pauses between sentences, and engaging warmth:\n\n'
          '$dialogueText';

      final payload = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
        },
      };

      Uint8List? chunkPcm;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final res = await http
              .post(
                endpoint,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 240));

          if (res.statusCode == 200) {
            final resJson = jsonDecode(utf8.decode(res.bodyBytes));
            final candidates = (resJson['candidates'] as List?) ?? [];
            if (candidates.isNotEmpty) {
              final parts = (candidates.first['content']?['parts'] as List?) ?? [];
              for (final part in parts) {
                final inlineData = (part as Map)['inlineData'] as Map<String, dynamic>?;
                if (inlineData?['data'] != null) {
                  chunkPcm = base64Decode(inlineData!['data'] as String);
                  break;
                }
              }
            }
            break;
          } else if (res.statusCode == 429) {
            AppLogger.debug(
              'Gemini TTS rate limited (429) on chunk ${chunkIndex + 1}/${chunks.length}, waiting 20s before retry (attempt ${attempt + 1}/3)...',
              tag: 'GeminiTtsService',
            );
            await Future.delayed(const Duration(seconds: 20));
            continue;
          } else {
            AppLogger.error(
              'Gemini TTS returned status ${res.statusCode} on chunk ${chunkIndex + 1}: ${res.body}',
              tag: 'GeminiTtsService',
            );
            break;
          }
        } catch (e) {
          AppLogger.error(
            'Gemini TTS generation error on chunk ${chunkIndex + 1} (attempt ${attempt + 1})',
            error: e,
            tag: 'GeminiTtsService',
          );
          await Future.delayed(const Duration(seconds: 5));
        }
      }

      if (chunkPcm == null) {
        AppLogger.error(
          'Gemini Studio TTS failed on chunk ${chunkIndex + 1}/${chunks.length}; using ${allPcmBytes.length} bytes generated so far.',
          tag: 'GeminiTtsService',
        );
        break;
      }
      allPcmBytes.add(chunkPcm);

      // Space out sequential requests to respect the TTS preview model's low per-minute rate limit.
      if (chunkIndex < chunks.length - 1) {
        await Future.delayed(const Duration(seconds: 20));
      }
    }

    final pcm = allPcmBytes.toBytes();
    if (pcm.isEmpty) return null;
    return _wrapPcmAsWav(pcm);
  }

  /// Wraps raw 16-bit mono PCM samples in a standard 44-byte WAV header.
  static Uint8List _wrapPcmAsWav(Uint8List pcm) {
    const numChannels = 1;
    const bitsPerSample = 16;
    final byteRate = _sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;

    final header = ByteData(44);
    void writeAscii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // PCM fmt chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);

    final wav = BytesBuilder();
    wav.add(header.buffer.asUint8List());
    wav.add(pcm);
    return wav.toBytes();
  }
}
