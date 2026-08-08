import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/saved_word.dart';
import 'profile_service.dart';
import 'vocabulary_service.dart';
import 'dictionary_service.dart';

/// Service responsible for keeping native Android & iOS Home Screen Widgets
/// synchronized with the user's daily word of the day, streak, due review count,
/// and target CEFR level.
class HomeScreenWidgetService {
  static final HomeScreenWidgetService _instance = HomeScreenWidgetService._internal();
  factory HomeScreenWidgetService() => _instance;
  HomeScreenWidgetService._internal();

  static const String appGroupId = 'group.com.example.takt';
  static const String mediumWidgetProvider = 'WordOfTheDayWidgetProvider';
  static const String smallWidgetProvider = 'WordOfTheDaySmallWidgetProvider';

  final StreamController<Uri> _widgetClickController = StreamController<Uri>.broadcast();
  Stream<Uri> get onWidgetClicked => _widgetClickController.stream;

  Uri? _initialUri;
  Uri? get initialUri => _initialUri;

  bool _initialized = false;

  /// Initializes HomeWidget listeners and performs the initial widget sync.
  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    try {
      HomeWidget.setAppGroupId(appGroupId);

      // Listen for background / foreground widget clicks
      HomeWidget.widgetClicked.listen((Uri? uri) {
        if (uri != null) {
          _widgetClickController.add(uri);
        }
      });

      // Check if app was initially opened from home screen widget click
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (uri != null) {
        _initialUri = uri;
        _widgetClickController.add(uri);
      }

      // Sync fresh widget data
      await updateWidgetData();
    } catch (e) {
      debugPrint('[HomeScreenWidgetService] Error during init: $e');
    }
  }

  /// Refreshes all Home Screen widgets with current Word of the Day, streak, and SRS stats.
  Future<void> updateWidgetData({SavedWord? featuredWord}) async {
    if (kIsWeb) return;

    try {
      final profile = ProfileService();
      final vocab = VocabularyService();
      final dict = DictionaryService();

      final streak = profile.currentStreak;
      final streakText = '🔥 $streak';

      final dueWords = await vocab.getDueWords();
      final dueCountText = '⚡ ${dueWords.length}';

      // 1. Determine featured Word of the Day
      String wordStr = 'Entwicklung';
      String article = 'die';
      String fullWord = 'die Entwicklung';
      String ipa = '/ɛntˈvɪklʊŋ/';
      String definition = 'development, progress';
      String cefr = 'B1';
      String exampleDe = 'Die Entwicklung der App macht große Fortschritte.';
      String exampleEn = 'The development of the app is making great progress.';

      if (featuredWord != null) {
        wordStr = featuredWord.word;
        fullWord = featuredWord.fullWordWithArticle;
        ipa = featuredWord.ipa ?? '';
        definition = featuredWord.primaryDefinition;
        if (featuredWord.contextExamples.isNotEmpty) {
          exampleDe = featuredWord.contextExamples.first.sentence;
          exampleEn = featuredWord.contextExamples.first.translation ?? '';
        } else if (featuredWord.contextSentence != null && featuredWord.contextSentence!.isNotEmpty) {
          exampleDe = featuredWord.contextSentence!;
          exampleEn = '';
        }
      } else if (dueWords.isNotEmpty) {
        // Prioritize first due word
        final due = dueWords.first;
        wordStr = due.word;
        fullWord = due.fullWordWithArticle;
        ipa = due.ipa ?? '';
        definition = due.primaryDefinition;
        if (due.contextExamples.isNotEmpty) {
          exampleDe = due.contextExamples.first.sentence;
          exampleEn = due.contextExamples.first.translation ?? '';
        } else if (due.contextSentence != null && due.contextSentence!.isNotEmpty) {
          exampleDe = due.contextSentence!;
          exampleEn = '';
        }
      } else {
        // Fetch from saved words or fallback dictionary lookup
        final savedWords = await vocab.getSavedWords();
        if (savedWords.isNotEmpty) {
          // Stable daily rotation based on day of year
          final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
          final picked = savedWords[dayOfYear % savedWords.length];
          wordStr = picked.word;
          fullWord = picked.fullWordWithArticle;
          ipa = picked.ipa ?? '';
          definition = picked.primaryDefinition;
          if (picked.contextExamples.isNotEmpty) {
            exampleDe = picked.contextExamples.first.sentence;
            exampleEn = picked.contextExamples.first.translation ?? '';
          } else if (picked.contextSentence != null && picked.contextSentence!.isNotEmpty) {
            exampleDe = picked.contextSentence!;
            exampleEn = '';
          }
        }
      }

      // Enrich metadata (IPA, examples, CEFR) via fast offline dictionary lookup if available
      try {
        final entries = await dict.lookupWordFast(wordStr);
        if (entries.isNotEmpty) {
          final entry = entries.first;
          final freqRank = entry['freq_rank'] is int ? entry['freq_rank'] as int : null;
          cefr = DictionaryService.getCefrLevel(freqRank, fallback: cefr);
          if (ipa.isEmpty && entry['ipa'] != null) {
            ipa = entry['ipa'].toString();
          }
          final g = entry['gender']?.toString().toLowerCase();
          String detectedArticle = '';
          if (g == 'm' || g == 'masc' || g == 'masculine') detectedArticle = 'der';
          if (g == 'f' || g == 'fem' || g == 'feminine') detectedArticle = 'die';
          if (g == 'n' || g == 'neu' || g == 'neuter') detectedArticle = 'das';
          if (detectedArticle.isNotEmpty && !wordStr.toLowerCase().startsWith(RegExp(r'^(der|die|das)\s+'))) {
            fullWord = '$detectedArticle $wordStr';
          }
        }
      } catch (_) {}

      // Fallback example sentence enrichment if empty
      if (exampleDe.isEmpty) {
        try {
          final fullResult = await dict.lookupWord(wordStr);
          final examples = fullResult?['examples'];
          if (examples is List && examples.isNotEmpty) {
            final firstEx = examples.first;
            if (firstEx is Map) {
              exampleDe = firstEx['german']?.toString() ?? firstEx['sentence']?.toString() ?? '';
              exampleEn = firstEx['english']?.toString() ?? firstEx['translation']?.toString() ?? '';
            }
          }
        } catch (_) {}
      }

      final deepLink = 'takt://word?term=${Uri.encodeComponent(wordStr)}';

      // 2. Save serialized fields to platform shared storage
      await Future.wait([
        HomeWidget.saveWidgetData<String>('widget_word', fullWord),
        HomeWidget.saveWidgetData<String>('widget_ipa', ipa),
        HomeWidget.saveWidgetData<String>('widget_definition', definition),
        HomeWidget.saveWidgetData<String>('widget_cefr', cefr),
        HomeWidget.saveWidgetData<String>('widget_streak', streakText),
        HomeWidget.saveWidgetData<String>('widget_due_count', dueCountText),
        HomeWidget.saveWidgetData<String>('widget_example_de', exampleDe),
        HomeWidget.saveWidgetData<String>('widget_example_en', exampleEn),
        HomeWidget.saveWidgetData<String>('widget_deep_link', deepLink),
      ]);

      // 3. Trigger native widget updates for Medium and Small widgets
      await HomeWidget.updateWidget(
        name: mediumWidgetProvider,
        androidName: mediumWidgetProvider,
      );
      await HomeWidget.updateWidget(
        name: smallWidgetProvider,
        androidName: smallWidgetProvider,
      );

      debugPrint('[HomeScreenWidgetService] Home Screen Widgets successfully updated with "$fullWord" ($cefr, $streakText, $dueCountText)');
    } catch (e) {
      debugPrint('[HomeScreenWidgetService] Error updating widgets: $e');
    }
  }

  void dispose() {
    _widgetClickController.close();
  }
}
