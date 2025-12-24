import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class BackendService {
  // Singleton pattern
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  final String baseUrl = Config.backendUrl;
  
  // Cache storage: key="$lang:$text" -> value=Response Map
  final Map<String, Map<String, dynamic>> _cache = {};

  Future<Map<String, dynamic>?> processText(String text, {String? lang}) async {
    // 1. Check cache
    String cacheKey = '${lang ?? "auto"}:$text';
    if (_cache.containsKey(cacheKey)) {
      print('DEBUG: Cache hit for translation');
      return _cache[cacheKey];
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/process'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          if (lang != null) 'lang': lang,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        
        // 2. Save to cache
        _cache[cacheKey] = data;
        
        return data;
      } else {
        print('Backend error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Backend connection error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> processFullArticle(String fullText, {String? lang}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/process_full'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': fullText,
          if (lang != null) 'lang': lang,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print('Backend error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Batch process error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> analyzeWord(String word, String sentence) async {
    // We can use the analyze endpoint for purely POS tagging of a specific word
    // Or we can use process() and find the word. 
    // Let's use /analyze which is specific for "word in context"
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sentence': sentence,
          'word': word,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      print('Correction error: $e');
      return null;
    }
  }
}
