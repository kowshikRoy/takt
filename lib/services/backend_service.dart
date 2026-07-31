import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

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
      print('importFromUrl error: $e');
      return {'error': 'Connection timed out or failed: $e'};
    }
  }

  Future<Map<String, dynamic>?> submitMediaUrl(String url) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/submit-media'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'error': 'Server returned status ${response.statusCode}'};
    } catch (e) {
      print('submitMediaUrl error: $e');
      return {'error': 'Connection timed out or failed: $e'};
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
      print('checkMediaStatus error: $e');
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
      print('processFullArticleStream error: $e');
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
      print('processText error: $e');
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
              print('Error parsing SSE message: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Stream error: $e');
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
      print('Error fetching fresh video url: $e');
    }
    return null;
  }
}
