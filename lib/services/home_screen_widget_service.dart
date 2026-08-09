import 'dart:async';
import 'dart:convert';
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

      // Helper to resolve rich multi-definitions for each card
      Future<String> resolveRichDefinitions({
        required String word,
        String? primary,
        List<String>? existingDefs,
      }) async {
        final List<String> defs = [];
        if (existingDefs != null && existingDefs.isNotEmpty) {
          defs.addAll(existingDefs.map((d) => d.trim()).where((d) => d.isNotEmpty));
        }
        if (primary != null && primary.trim().isNotEmpty && !defs.any((d) => d.toLowerCase() == primary.trim().toLowerCase())) {
          defs.insert(0, primary.trim());
        }

        // If we only have 0 or 1 definition, lookup offline database for additional senses
        if (defs.length <= 1) {
          try {
            final dbEntries = await dict.lookupWordFast(word);
            for (final entry in dbEntries) {
              final entryDefs = entry['definitions'];
              if (entryDefs is List) {
                for (final d in entryDefs) {
                  final s = d?.toString().trim() ?? '';
                  if (s.isNotEmpty && !defs.any((existing) => existing.toLowerCase() == s.toLowerCase())) {
                    defs.add(s);
                  }
                }
              }
            }
          } catch (_) {}
        }

        if (defs.isEmpty) return 'word, term';
        if (defs.length == 1) return defs.first;

        // Formats multiple definitions as numbered lines:
        // 1. primary definition
        // 2. secondary definition
        return defs.take(4).toList().asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');
      }

      // Build a swipeable deck of words (due words + saved words + curated fallbacks)
      final List<Map<String, String>> deck = [];
      final Set<String> seenWords = {};

      void addCard({
        required String word,
        required String definition,
        required String cefr,
        String? article,
      }) {
        final cleanWord = word.trim();
        if (cleanWord.isEmpty || seenWords.contains(cleanWord.toLowerCase())) return;
        seenWords.add(cleanWord.toLowerCase());

        String displayWord = cleanWord;
        final isNoun = cleanWord.isNotEmpty && cleanWord[0].toUpperCase() == cleanWord[0] && cleanWord[0].toLowerCase() != cleanWord[0];
        if (isNoun && article != null && article.isNotEmpty && !cleanWord.toLowerCase().startsWith(RegExp(r'^(der|die|das)\s+'))) {
          displayWord = '$article $cleanWord';
        }

        deck.add({
          'word': displayWord,
          'definition': definition.isNotEmpty ? definition : 'word, term',
          'cefr': cefr.isNotEmpty ? cefr : 'B1',
          'streak': streakText,
          'deepLink': 'takt://word?term=${Uri.encodeComponent(cleanWord)}',
        });
      }

      // Add featured or first word
      final featuredRichDef = await resolveRichDefinitions(
        word: wordStr,
        primary: definition,
        existingDefs: featuredWord?.definitions,
      );
      addCard(word: wordStr, definition: featuredRichDef, cefr: cefr, article: article);

      // Add due review words
      for (final due in dueWords.take(5)) {
        final dueRichDef = await resolveRichDefinitions(
          word: due.word,
          primary: due.primaryDefinition,
          existingDefs: due.definitions,
        );
        addCard(
          word: due.word,
          definition: dueRichDef,
          cefr: 'B1',
          article: due.article,
        );
      }

      // Add saved vocabulary words
      final allSaved = await vocab.getSavedWords();
      for (final saved in allSaved.take(8)) {
        final savedRichDef = await resolveRichDefinitions(
          word: saved.word,
          primary: saved.primaryDefinition,
          existingDefs: saved.definitions,
        );
        addCard(
          word: saved.word,
          definition: savedRichDef,
          cefr: 'B1',
          article: saved.article,
        );
      }

      // Fallback curated words if deck is small
      final curated = [
        {'word': 'die Uhr', 'def': '1. clock, watch\n2. o\'clock (time)', 'cefr': 'A1'},
        {'word': 'das Ziel', 'def': '1. goal, objective\n2. destination, target', 'cefr': 'B1'},
        {'word': 'die Entscheidung', 'def': '1. decision, choice\n2. determination, ruling', 'cefr': 'B2'},
        {'word': 'die Entwicklung', 'def': '1. development, evolution\n2. progress, advance', 'cefr': 'B1'},
        {'word': 'der Erfolg', 'def': '1. success, achievement\n2. hit, victory', 'cefr': 'A2'},
      ];
      for (final item in curated) {
        if (deck.length >= 8) break;
        addCard(
          word: item['word']!,
          definition: item['def']!,
          cefr: item['cefr']!,
        );
      }

      final deepLink = 'takt://word?term=${Uri.encodeComponent(wordStr)}';
      final deckJson = jsonEncode(deck);

      // 2. Save serialized fields to platform shared storage
      await Future.wait([
        HomeWidget.saveWidgetData<String>('widget_word', fullWord),
        HomeWidget.saveWidgetData<String>('widget_definition', definition),
        HomeWidget.saveWidgetData<String>('widget_cefr', cefr),
        HomeWidget.saveWidgetData<String>('widget_streak', streakText),
        HomeWidget.saveWidgetData<String>('widget_due_count', dueCountText),
        HomeWidget.saveWidgetData<String>('widget_example_de', exampleDe),
        HomeWidget.saveWidgetData<String>('widget_example_en', exampleEn),
        HomeWidget.saveWidgetData<String>('widget_deep_link', deepLink),
        HomeWidget.saveWidgetData<String>('widget_words_json', deckJson),
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

      debugPrint('[HomeScreenWidgetService] Home Screen Widgets successfully updated with ${deck.length} swipeable cards ($fullWord, $streakText, $dueCountText)');
    } catch (e) {
      debugPrint('[HomeScreenWidgetService] Error updating widgets: $e');
    }
  }

  void dispose() {
    _widgetClickController.close();
  }
}
