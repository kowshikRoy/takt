import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'app_logger.dart';
import 'dictionary_service.dart';

class NativeNlpService {
  static final NativeNlpService _instance = NativeNlpService._internal();
  factory NativeNlpService() => _instance;
  NativeNlpService._internal();

  static const MethodChannel _platform = MethodChannel('com.example.takt/pos_tagger');

  OnDeviceTranslator? _translator;
  bool _isTranslatorReady = false;

  OnDeviceTranslator get translator {
    if (_translator == null) {
      _translator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.german,
        targetLanguage: TranslateLanguage.english,
      );
      _isTranslatorReady = true;
    }
    return _translator!;
  }

  /// Concurrently performs on-device sentence translation (ML Kit) and
  /// native POS tagging via Platform Channel / NLTagger (<20ms).
  Future<Map<String, dynamic>> processGermanText(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return {
        'translation': '',
        'tokens': <Map<String, String>>[],
      };
    }

    try {
      final results = await Future.wait([
        translateText(cleanText),
        getTaggedTokens(cleanText),
      ]);

      return {
        'translation': results[0] as String,
        'tokens': results[1] as List<Map<String, String>>,
      };
    } catch (e) {
      AppLogger.error('processGermanText error', error: e, tag: 'NativeNlpService');
      final fallbackTokens = await getTaggedTokens(cleanText);
      return {
        'translation': '',
        'tokens': fallbackTokens,
      };
    }
  }

  /// Translates a sentence using Google ML Kit on-device NMT model
  Future<String> translateText(String text) async {
    if (kIsWeb) return '';
    try {
      final translated = await translator.translateText(text);
      return translated.trim();
    } catch (e) {
      AppLogger.error('On-Device ML Kit translation error', error: e, tag: 'NativeNlpService');
      return '';
    }
  }

  /// Calls native OS POS tagger (Kotlin GermanPosTagger on Android, Swift NLTagger on iOS)
  Future<List<Map<String, String>>> getTaggedTokens(String text) async {
    if (kIsWeb) {
      return _dartFallbackTokenTagging(text);
    }

    try {
      final List<dynamic>? rawResult = await _platform.invokeMethod<List<dynamic>>(
        'tagPOS',
        {'text': text},
      );

      if (rawResult != null && rawResult.isNotEmpty) {
        return rawResult.map((item) {
          if (item is Map) {
            return Map<String, String>.from(item.map((k, v) => MapEntry(k.toString(), v.toString())));
          }
          return <String, String>{};
        }).where((m) => m.isNotEmpty).toList();
      }
    } on MissingPluginException {
      // Platform channel not supported on this platform/test runner
      AppLogger.info('MethodChannel pos_tagger missing, using Dart fallback', tag: 'NativeNlpService');
    } on PlatformException catch (e) {
      AppLogger.error('Platform tagPOS error', error: e, tag: 'NativeNlpService');
    } catch (e) {
      AppLogger.error('Native tagPOS error', error: e, tag: 'NativeNlpService');
    }

    return _dartFallbackTokenTagging(text);
  }

  /// Fallback morphological tagger in pure Dart
  List<Map<String, String>> _dartFallbackTokenTagging(String text) {
    final tokens = text
        .replaceAll(RegExp(r'[^\w\säöüÄÖÜß.]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final List<Map<String, String>> results = [];
    const articles = {
      'der', 'die', 'das', 'den', 'dem', 'des',
      'ein', 'eine', 'einen', 'einem', 'einer', 'eines',
      'kein', 'keine', 'keinen', 'keinem', 'keiner', 'keines',
      'mein', 'meine', 'dein', 'sein', 'ihr', 'unser', 'euer'
    };
    const prepositions = {
      'in', 'an', 'auf', 'aus', 'bei', 'mit', 'nach', 'von', 'zu',
      'über', 'unter', 'vor', 'hinter', 'für', 'gegen', 'ohne', 'um',
      'am', 'im', 'ans', 'ins', 'beim', 'vom', 'zum', 'zur'
    };

    for (int i = 0; i < tokens.length; i++) {
      final raw = tokens[i];
      final clean = raw.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '');
      if (clean.isEmpty) continue;

      final lower = clean.toLowerCase();
      final prev = i > 0 ? tokens[i - 1].replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '').toLowerCase() : '';
      final isCapitalized = clean[0] == clean[0].toUpperCase() && clean[0] != clean[0].toLowerCase();
      final isFirst = i == 0 || (i > 0 && tokens[i - 1].endsWith('.'));

      String pos = 'unknown';
      String gender = '';

      if (articles.contains(lower)) {
        pos = 'art';
      } else if (prepositions.contains(lower)) {
        pos = 'prep';
      } else if (isCapitalized) {
        pos = 'noun';
      } else if (articles.contains(prev) && !isCapitalized) {
        pos = 'adj';
      }

      if (pos == 'noun') {
        if (prev == 'der' || prev == 'den' || prev == 'dem' || prev == 'des') {
          gender = 'm';
        } else if (prev == 'die') {
          gender = 'f';
        } else if (prev == 'das') {
          gender = 'n';
        } else {
          gender = DictionaryService.inferGender(clean);
        }
      }

      results.add({
        'token': clean,
        'pos': pos,
        'lemma': clean,
        if (gender.isNotEmpty) 'gender': gender,
      });
    }

    return results;
  }

  void dispose() {
    if (_isTranslatorReady) {
      _translator?.close();
      _translator = null;
      _isTranslatorReady = false;
    }
  }
}
