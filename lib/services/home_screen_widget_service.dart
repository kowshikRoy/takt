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
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialUri != null) {
        _widgetClickController.add(initialUri);
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
      String wordStr = 'Wort';
      String article = 'das';
      String fullWord = 'das Wort';
      String ipa = '/vɔʁt/';
      String definition = 'word, term';
      String cefr = 'A1';
      String exampleDe = 'Ein Bild sagt mehr als tausend Worte.';
      String exampleEn = 'A picture is worth a thousand words.';

      if (featuredWord != null) {
        wordStr = featuredWord.word;
        fullWord = featuredWord.fullWordWithArticle;
        ipa = featuredWord.ipa ?? '';
        definition = featuredWord.primaryDefinition;
        cefr = 'B1';
      } else if (dueWords.isNotEmpty) {
        // Prioritize first due word
        final due = dueWords.first;
        wordStr = due.word;
        fullWord = due.fullWordWithArticle;
        ipa = due.ipa ?? '';
        definition = due.primaryDefinition;
        cefr = 'B1';
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
          cefr = 'B1';
        } else {
          // Curated fallback for brand new users
          wordStr = 'Entwicklung';
          article = 'die';
          fullWord = 'die Entwicklung';
          ipa = '/ɛntˈvɪklʊŋ/';
          definition = 'development, progress';
          cefr = 'B1';
          exampleDe = 'Die Entwicklung der App macht große Fortschritte.';
          exampleEn = 'The development of the app is making great progress.';
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
          if (g == 'm') article = 'der';
          if (g == 'f') article = 'die';
          if (g == 'n') article = 'das';
          if (article.isNotEmpty && !wordStr.startsWith(RegExp(r'^(der|die|das)\s+', caseSensitive: false))) {
            fullWord = '$article $wordStr';
          }
        }
      } catch (_) {}

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
