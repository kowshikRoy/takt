import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/dictionary_service.dart';
import '../services/vocabulary_service.dart';
import '../services/media_library_service.dart';
import '../services/tts_service.dart';
import '../services/ondevice_ai_service.dart';
import '../services/profile_service.dart';
import 'package:takt/l10n/app_localizations.dart';
import '../models/article_model.dart';
import '../models/saved_word.dart';
import '../widgets/glance_word_sheet.dart';
import '../theme/books_modernist_style.dart';
import '../widgets/capped_width.dart';
import '../models/contextual_vocab_item.dart';
export '../models/contextual_vocab_item.dart' show KeyStoryVocab, ContextualVocabItem;

class _TappedWordData {
  final String word;
  final int paragraphIndex;
  _TappedWordData(this.word, this.paragraphIndex);
}

class StoryReaderScreen extends StatefulWidget {
  final Article? article;
  final String? customContent;

  const StoryReaderScreen({super.key, this.article, this.customContent});

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> with WidgetsBindingObserver {
  final DictionaryService _dictionaryService = DictionaryService();
  final VocabularyService _vocabularyService = VocabularyService();
  final TtsService _ttsService = TtsService();
  final OnDeviceAIService _onDeviceAI = OnDeviceAIService();
  final ScrollController _scrollController = ScrollController();

  final Map<String, String> _wordGenders = {};
  Map<int, Map<String, dynamic>> _paragraphAnalysisData = {};
  bool _isLoadingAnalysis = false;
  String? _loadedContent;
  TtsProgress? _currentTtsProgress;
  StreamSubscription? _ttsSubscription;
  final Set<int> _visibleParagraphTranslations = {};
  final Set<int> _activeActionParagraphs = {};

  int _activeViewIndex = 0; // 0: Full Story, 1: Key Vocabulary
  List<KeyStoryVocab> _keyVocabList = [];
  Set<String> _savedVocabIds = {};
  bool _isLoadingVocab = false;

  static final RegExp _wordTokenRegex = RegExp(r'^([^\wäöüÄÖÜß]*)([\wäöüÄÖÜß]+)([^\wäöüÄÖÜß]*)$');

  // Reader Settings State
  final ValueNotifier<double> _scrollProgressNotifier = ValueNotifier<double>(0.0);
  double _fontSize = 14.0;
  double _speechRate = 0.5; // 0.5 is flutter_tts default (~1.0x)
  String _fontFamily = 'Sans'; // 'Serif', 'Sans', 'Mono'
  double _lineHeight = 1.6; // 1.4, 1.6, 1.9
  bool _isSepiaMode = false;
  bool _showGenderHighlighting = true;
  bool _autoScrollWithTts = true;
  bool _isPlayingTts = false;
  final ValueNotifier<_TappedWordData?> _tappedWordNotifier = ValueNotifier<_TappedWordData?>(null);
  int? _currentlySpokenParagraphIndex;

  final Map<int, GlobalKey> _paragraphKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_updateScrollProgress);
    _loadContent();
    ProfileService().recordActivityToday(story: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _ttsService.stop();
      if (mounted) setState(() => _isPlayingTts = false);
    }
  }

  @override
  void deactivate() {
    _ttsService.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_updateScrollProgress);
    _scrollController.dispose();
    _ttsSubscription?.cancel();
    _ttsService.stop();
    super.dispose();
  }

  void _updateScrollProgress() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      _scrollProgressNotifier.value = 0.0;
      return;
    }
    final currentScroll = _scrollController.position.pixels;
    final progress = (currentScroll / maxScroll).clamp(0.0, 1.0);
    if ((progress - _scrollProgressNotifier.value).abs() > 0.01) {
      _scrollProgressNotifier.value = progress;
    }
  }

  Future<void> _loadContent() async {
    if (widget.customContent != null) {
      _loadedContent = widget.customContent;
    } else if (widget.article != null) {
      final mediaLibraryService = Provider.of<MediaLibraryService>(context, listen: false);
      final customData = await mediaLibraryService.getCustomContent(widget.article!.id);
      if (customData != null && customData.isNotEmpty) {
        _loadedContent = customData;
      }
    }

    if (mounted) setState(() {});

    _loadWordGenders();
    _fetchContextualAnalysis();

    _ttsSubscription = _ttsService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _currentTtsProgress = progress;
          _isPlayingTts = progress != null;
        });

        if (_autoScrollWithTts && progress != null) {
          _handleTtsAutoScroll(progress);
        }
      }
    });
  }

  void _handleTtsAutoScroll(TtsProgress progress) {
    List<String> paragraphs = _getParagraphList();
    for (int i = 0; i < paragraphs.length; i++) {
      if (paragraphs[i].contains(progress.word) || progress.text.contains(paragraphs[i])) {
        if (_currentlySpokenParagraphIndex != i) {
          _currentlySpokenParagraphIndex = i;
          _scrollToParagraph(i);
        }
        break;
      }
    }
  }

  void _scrollToParagraph(int index) {
    final key = _paragraphKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  List<String> _getParagraphList() {
    if (_loadedContent != null && _loadedContent!.isNotEmpty) {
      return _loadedContent!.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).toList();
    }
    return const ['Content is not available for this story.'];
  }

  Future<void> _fetchContextualAnalysis() async {
    setState(() {
      _isLoadingAnalysis = true;
      _paragraphAnalysisData = {};
    });

    final storyId = widget.article?.id ?? 'default_story';
    final mediaLibraryService = Provider.of<MediaLibraryService>(context, listen: false);

    // 1. Check persistent disk cache first (0ms instantaneous load)
    final cached = await mediaLibraryService.getCachedAnalysis(storyId);
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _paragraphAnalysisData = cached;
        _isLoadingAnalysis = false;
      });
      _loadWordGenders();
      _extractKeyVocabulary();
      return;
    }

    List<String> paragraphs = _getParagraphList();

    try {
      for (int i = 0; i < paragraphs.length; i++) {
        if (!mounted) break;
        final para = paragraphs[i].trim();
        final localResult = await _onDeviceAI.analyzeSentenceLocally(para);

        setState(() {
          _paragraphAnalysisData[i] = {
            'german_analysis': localResult.tokens.map((t) => {
              'word': t.word,
              'lemma': t.lemma,
              'pos': t.partOfSpeech,
              'translation': t.translation,
              'note': t.grammarNote,
            }).toList(),
            'german_text': para,
            'original_text': para,
            'english_translation': localResult.translatedSentence,
            'source_lang': 'de',
            'is_on_device': true,
          };
        });
      }

      await mediaLibraryService.saveCachedAnalysis(storyId, _paragraphAnalysisData);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAnalysis = false;
        });
        _loadWordGenders(); // Query DB for any newly parsed lemmas
        _extractKeyVocabulary();
      }
    }
  }

  Future<void> _loadWordGenders() async {
    List<String> textChunks = _getParagraphList();
    Set<String> queryWords = {};

    for (var chunk in textChunks) {
      chunk.split(RegExp(r'[^\wäöüÄÖÜß]+')).forEach((w) {
        if (w.isNotEmpty) {
          queryWords.add(w);
          queryWords.add(w.toLowerCase());

          // Common singularization candidates for SQLite DB lookup
          if (w.endsWith('en') && w.length > 3) {
            queryWords.add(w.substring(0, w.length - 2));
            queryWords.add('${w.substring(0, w.length - 2)}e');
          } else if (w.endsWith('n') && w.length > 3) {
            queryWords.add(w.substring(0, w.length - 1));
          } else if (w.endsWith('e') && w.length > 3) {
            queryWords.add(w.substring(0, w.length - 1));
          }
        }
      });
    }

    // Add words and lemmas parsed from token analysis
    for (var pData in _paragraphAnalysisData.values) {
      final tokens = (pData['german_analysis'] as List<dynamic>?) ?? [];
      for (var t in tokens) {
        if (t['word'] != null && t['word'].toString().isNotEmpty) {
          queryWords.add(t['word'].toString());
          queryWords.add(t['word'].toString().toLowerCase());
        }
        if (t['lemma'] != null && t['lemma'].toString().isNotEmpty) {
          queryWords.add(t['lemma'].toString());
          queryWords.add(t['lemma'].toString().toLowerCase());
        }
      }
    }

    final genders = await _dictionaryService.getGendersForWords(queryWords.toList());

    if (mounted && genders.isNotEmpty) {
      setState(() {
        _wordGenders.addAll(genders);
      });
    }
  }

  /// Determines gender for a German noun using DB lookup + morphological suffix fallback
  String? _getNounGender(String word, String? contextGender, String? lemma) {
    if (contextGender != null && contextGender.isNotEmpty) {
      final cg = contextGender.toLowerCase().trim();
      if (cg == 'm' || cg == 'masc' || cg == 'masculine' || cg == 'der' ||
          cg == 'f' || cg == 'fem' || cg == 'feminine' || cg == 'die' ||
          cg == 'n' || cg == 'neu' || cg == 'neuter' || cg == 'das') {
        return cg;
      }
    }

    final lower = word.toLowerCase();
    if (_wordGenders.containsKey(word)) return _wordGenders[word];
    if (_wordGenders.containsKey(lower)) return _wordGenders[lower];
    if (lemma != null && _wordGenders.containsKey(lemma.toLowerCase())) {
      return _wordGenders[lemma.toLowerCase()];
    }

    // High-precision German Noun Suffix Fallbacks (e.g. -ung -> die/f)
    if (lower.endsWith('ung') || lower.endsWith('heit') || lower.endsWith('keit') ||
        lower.endsWith('schaft') || lower.endsWith('ion') || lower.endsWith('tät') ||
        lower.endsWith('ik') || lower.endsWith('ur') || lower.endsWith('lage')) {
      return 'f'; // die (Feminine / Red)
    }
    if (lower.endsWith('ismus') || lower.endsWith('ling') || lower.endsWith('ant') || lower.endsWith('or')) {
      return 'm'; // der (Masculine / Blue)
    }
    if (lower.endsWith('ment') || lower.endsWith('tum') || lower.endsWith('lein') ||
        lower.endsWith('chen') || lower.endsWith('um')) {
      return 'n'; // das (Neuter / Green)
    }

    return null;
  }

  void _togglePlayAllTts() {
    if (_isPlayingTts) {
      _ttsService.stop();
      setState(() => _isPlayingTts = false);
    } else {
      List<String> paragraphs = _getParagraphList();
      _ttsService.setSpeechRate(_speechRate);
      _ttsService.speak(paragraphs.join(' '));
      setState(() => _isPlayingTts = true);
    }
  }

  void _speakParagraph(String text, int index) {
    HapticFeedback.selectionClick();
    if (_isPlayingTts && _currentTtsProgress?.text == text) {
      _ttsService.stop();
      setState(() => _isPlayingTts = false);
      return;
    }
    _ttsService.stop();
    _ttsService.setSpeechRate(_speechRate);
    _ttsService.speak(text);
    setState(() => _isPlayingTts = true);
  }

  void _changeSpeed(double rate) {
    setState(() {
      _speechRate = rate;
    });
    _ttsService.setSpeechRate(rate);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color scaffoldBg = BooksModernist.bg;
    if (_isSepiaMode) {
      scaffoldBg = isDark ? const Color(0xFF262220) : const Color(0xFFF6F0E6);
    }

    return Theme(
      data: BooksModernist.readingTheme(context),
      child: PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _ttsService.stop();
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _activeViewIndex == 1
                    ? _buildKeyVocabularyView(context)
                    : Column(
                        children: [
                          // 1. Sharp Bordered Textbook Page Card Container (Identical to TextbookUnitScreen)
                          Expanded(
                            child: CappedWidth(
                              maxWidth: 760,
                              child: Container(
                              margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                              decoration: BoxDecoration(
                                color: _isSepiaMode
                                    ? (isDark ? const Color(0xFF322C28) : const Color(0xFFEBE0D0))
                                    : BooksModernist.surface,
                                border: Border.all(color: BooksModernist.divider, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () {
                                  if (_activeActionParagraphs.isNotEmpty) {
                                    setState(() {
                                      _activeActionParagraphs.clear();
                                    });
                                  }
                                },
                                child: SingleChildScrollView(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildStoryContent(context),
                                    ],
                                  ),
                                ),
                              ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildDesktopReaderSidebar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reader Preferences Card
          Card(
            elevation: 0,
            color: _isSepiaMode
                ? (isDark ? const Color(0xFF322C28) : const Color(0xFFEBE0D0))
                : Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Reader Typography',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Font Family Selector
                  const Text('Font Family', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      {'id': 'Sans', 'label': 'Sans'},
                      {'id': 'Serif', 'label': 'Serif'},
                      {'id': 'Mono', 'label': 'Mono'},
                    ].map((f) {
                      final isSelected = _fontFamily == f['id'];
                      return ChoiceChip(
                        label: Text(f['label']!, style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          setState(() => _fontFamily = f['id']!);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Line Spacing Selector
                  const Text('Line Spacing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      {'val': 1.4, 'label': '1.4x'},
                      {'val': 1.6, 'label': '1.6x'},
                      {'val': 1.9, 'label': '1.9x'},
                    ].map((h) {
                      final isSelected = (_lineHeight - (h['val'] as double)).abs() < 0.05;
                      return ChoiceChip(
                        label: Text(h['label'] as String, style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          setState(() => _lineHeight = h['val'] as double);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Font Size Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Font Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('${_fontSize.round()} px', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _fontSize,
                    min: 14.0,
                    max: 26.0,
                    divisions: 6,
                    onChanged: (val) => setState(() => _fontSize = val),
                  ),
                  
                  // Sepia & Highlighting Switches
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sepia Warm Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    value: _isSepiaMode,
                    onChanged: (val) => setState(() => _isSepiaMode = val),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Gender Highlighting', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    value: _showGenderHighlighting,
                    onChanged: (val) => setState(() => _showGenderHighlighting = val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Audio Player & Controls Card
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.headset_rounded, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Audio Narration',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _togglePlayAllTts,
                        icon: Icon(_isPlayingTts ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(_isPlayingTts ? 'Pause' : 'Play Full Story'),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 4,
                        children: [0.75, 1.0, 1.25].map((speed) {
                          final ttsRate = 0.5 * speed;
                          final isSelected = (_speechRate - ttsRate).abs() < 0.05;
                          return ChoiceChip(
                            label: Text('${speed}x', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            selected: isSelected,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => _changeSpeed(ttsRate),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _extractKeyVocabulary() async {
    if (_paragraphAnalysisData.isEmpty) return;

    setState(() {
      _isLoadingVocab = true;
      _keyVocabList.clear();
    });

    final Map<String, KeyStoryVocab> uniqueMap = {};
    final paragraphs = _getParagraphList();

    const stopWords = {
      'der', 'die', 'das', 'dem', 'den', 'des', 'ein', 'eine', 'einen', 'einem',
      'einer', 'eines', 'und', 'oder', 'aber', 'ist', 'sind', 'war', 'waren',
      'in', 'im', 'zu', 'zum', 'zur', 'mit', 'von', 'aus', 'bei', 'nach',
      'über', 'unter', 'vor', 'hinter', 'neben', 'auf', 'an', 'für', 'um',
      'durch', 'gegen', 'ohne', 'nicht', 'ja', 'nein', 'so', 'dass', 'daß',
      'wie', 'als', 'auch', 'noch', 'nur', 'schon', 'mehr', 'sehr', 'viel',
      'ich', 'du', 'er', 'sie', 'es', 'wir', 'ihr', 'mich', 'dich',
      'ihn', 'uns', 'euch', 'ihnen', 'mein', 'dein', 'sein', 'unser',
      'euer', 'sich', 'was', 'wer', 'wo', 'wann', 'warum', 'dies',
      'diese', 'dieser', 'dieses', 'diesen', 'diesem', 'alle', 'alles', 'man'
    };

    for (int pIdx = 0; pIdx < paragraphs.length; pIdx++) {
      final pData = _paragraphAnalysisData[pIdx];
      if (pData == null) continue;

      final tokens = (pData['german_analysis'] as List<dynamic>?) ?? [];
      final engTranslation = pData['english_translation']?.toString() ?? '';

      for (var token in tokens) {
        final rawWord = token['word']?.toString().trim() ?? '';
        final lemma = token['lemma']?.toString().trim();
        final pos = token['pos']?.toString().trim();
        final translation = token['translation']?.toString().trim();

        if (rawWord.length < 3) continue;
        if (stopWords.contains(rawWord.toLowerCase())) continue;

        final isCapitalized = rawWord[0] == rawWord[0].toUpperCase() && rawWord[0].contains(RegExp(r'[A-ZÄÖÜ]'));
        final isNoun = isCapitalized || (pos != null && (pos.contains('NOUN') || pos.contains('N') || pos.contains('subst')));
        final isVerb = pos != null && (pos.contains('VERB') || pos.contains('V'));
        final isAdj = pos != null && (pos.contains('ADJ') || pos.contains('ADJECTIVE'));

        if (!isNoun && !isVerb && !isAdj) continue;

        final key = (lemma != null && lemma.isNotEmpty) ? lemma : rawWord;
        final keyLower = key.toLowerCase();

        if (uniqueMap.containsKey(keyLower)) continue;

        final gender = isNoun ? _getNounGender(rawWord, null, lemma) : null;
        String def = (translation != null && translation.isNotEmpty) ? translation : '';
        int? freqRank;
        String? fastIpa;

        final entryList = await _dictionaryService.lookupWordFast(key);
        if (entryList.isNotEmpty) {
          final first = entryList.first;
          final fastDefs = (first['definitions'] as List?) ?? [];
          if (def.isEmpty && fastDefs.isNotEmpty) def = fastDefs.first.toString();
          if (first['ipa'] != null) fastIpa = first['ipa'].toString();
          if (first['freq_rank'] is int) freqRank = first['freq_rank'] as int;
        }

        if (def.isEmpty) {
          // Local DB missed this word entirely — fall back to the same
          // Wiktionary API / Google Translate chain the Dictionary page
          // uses, so saved vocab doesn't end up with the word as its own
          // "definition" just because the offline DB lacks this entry.
          final fullEntry = await _dictionaryService.lookupWord(key);
          final onlineDefs = (fullEntry?['definitions'] as List?) ?? [];
          if (onlineDefs.isNotEmpty) def = onlineDefs.first.toString();
          if (fastIpa == null && fullEntry?['ipa'] != null) {
            fastIpa = fullEntry!['ipa'].toString();
          }
        }

        if (def.isEmpty) def = key;

        uniqueMap[keyLower] = KeyStoryVocab(
          word: key,
          baseForm: lemma,
          pos: isNoun ? 'NOUN' : (isVerb ? 'VERB' : 'ADJ'),
          gender: gender,
          primaryDefinition: def,
          ipa: fastIpa,
          paragraphIndex: pIdx,
          paragraphOriginal: paragraphs[pIdx],
          paragraphTranslated: engTranslation,
          freqRank: freqRank,
        );
      }
    }

    final savedWords = await _vocabularyService.getSavedWords();
    final savedSet = savedWords.map((w) => w.word.toLowerCase().trim()).toSet();

    if (mounted) {
      setState(() {
        _keyVocabList = uniqueMap.values.toList();
        _savedVocabIds = savedSet;
        _isLoadingVocab = false;
      });
    }
  }

  Future<void> _addAllVocabToLearning() async {
    if (_keyVocabList.isEmpty) return;

    int addedCount = 0;
    final storyTitle = widget.article?.title ?? 'Story Lesson';

    for (final vocab in _keyVocabList) {
      final wordId = vocab.word.toLowerCase().trim();
      if (!_savedVocabIds.contains(wordId)) {
        final saved = SavedWord(
          id: wordId,
          word: vocab.word,
          baseForm: vocab.baseForm,
          pos: vocab.pos,
          gender: vocab.gender,
          primaryDefinition: vocab.primaryDefinition,
          definitions: [vocab.primaryDefinition],
          ipa: vocab.ipa,
          contextSentence: vocab.paragraphOriginal,
          sourceTitle: storyTitle,
          category: VocabCategory.learning,
        );
        await _vocabularyService.upsertWord(saved);
        _savedVocabIds.add(wordId);
        addedCount++;
      }
    }

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $addedCount German terms to Learning Deck! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _startStoryVocabPracticeSheet() {
    if (_keyVocabList.isEmpty) return;
    int practiceIndex = 0;
    bool showAnswer = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final colorScheme = Theme.of(context).colorScheme;
          final item = _keyVocabList[practiceIndex];
          final isSaved = _savedVocabIds.contains(item.word.toLowerCase().trim());

          Color genderColor = colorScheme.primary;
          if (item.gender == 'm' || item.gender == 'masculine') genderColor = AppTheme.genderMasc;
          if (item.gender == 'f' || item.gender == 'feminine') genderColor = AppTheme.genderFem;
          if (item.gender == 'n' || item.gender == 'neuter') genderColor = AppTheme.genderNeu;

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6.0)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology_rounded, color: colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Practice Story Deck',
                          style: BooksModernist.heading(size: 18, color: colorScheme.onSurface, context: context),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: LinearProgressIndicator(
                    value: (practiceIndex + 1) / _keyVocabList.length,
                    minHeight: 6,
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Word ${practiceIndex + 1} of ${_keyVocabList.length}',
                  style: BooksModernist.body(size: 12, color: colorScheme.onSurfaceVariant, context: context),
                ),
                const Spacer(),

                GestureDetector(
                  onTap: () => setSheetState(() => showAnswer = !showAnswer),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.article.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: genderColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              item.article,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: genderColor),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          item.word,
                          style: BooksModernist.heading(size: 26, color: colorScheme.onSurface, context: context),
                        ),
                        const SizedBox(height: 16),
                        if (!showAnswer)
                          Text(
                            'Tap card to reveal definition',
                            style: BooksModernist.body(size: 13, color: colorScheme.onSurfaceVariant, context: context),
                          )
                        else ...[
                          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            item.primaryDefinition,
                            textAlign: TextAlign.center,
                            style: BooksModernist.body(size: 18, weight: FontWeight.w600, color: colorScheme.primary, context: context),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '"${item.paragraphOriginal}"',
                            textAlign: TextAlign.center,
                            style: BooksModernist.body(size: 12, color: colorScheme.onSurfaceVariant, context: context),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        setSheetState(() {
                          showAnswer = false;
                          practiceIndex = (practiceIndex - 1 + _keyVocabList.length) % _keyVocabList.length;
                        });
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Prev', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(_savedVocabIds.contains(item.word.toLowerCase().trim()) ? Icons.style_rounded : Icons.style_outlined),
                      tooltip: isSaved ? 'In Study Deck' : 'Add to Study Deck',
                      color: colorScheme.primary,
                      onPressed: () async {
                        final wordId = item.word.toLowerCase().trim();
                        if (isSaved) {
                          await _vocabularyService.removeWord(wordId);
                          _savedVocabIds.remove(wordId);
                        } else {
                          final saved = SavedWord(
                            id: wordId,
                            word: item.word,
                            baseForm: item.baseForm,
                            pos: item.pos,
                            gender: item.gender,
                            primaryDefinition: item.primaryDefinition,
                            definitions: [item.primaryDefinition],
                            contextSentence: item.paragraphOriginal,
                            sourceTitle: widget.article?.title ?? 'Story Lesson',
                            category: VocabCategory.learning,
                          );
                          await _vocabularyService.upsertWord(saved);
                          _savedVocabIds.add(wordId);
                        }
                        setSheetState(() {});
                        setState(() {});
                      },
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        setSheetState(() {
                          showAnswer = false;
                          if (practiceIndex < _keyVocabList.length - 1) {
                            practiceIndex++;
                          } else {
                            Navigator.pop(context);
                          }
                        });
                      },
                      icon: Icon(practiceIndex < _keyVocabList.length - 1 ? Icons.arrow_forward_rounded : Icons.check_circle_rounded, size: 16),
                      label: Text(practiceIndex < _keyVocabList.length - 1 ? 'Next' : 'Finish', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKeyVocabularyView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoadingVocab) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)?.msgExtractingVocab ?? 'Extracting key vocabulary...',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_keyVocabList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)?.msgNoVocab ?? 'No key vocabulary extracted yet.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _extractKeyVocabulary,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context)?.actionRefresh ?? 'Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
        // Header Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${AppLocalizations.of(context)?.titleKeyVocab ?? "Key Vocabulary"} (${_keyVocabList.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context)?.subtitleKeyVocab ?? 'Important German vocabulary from story',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addAllVocabToLearning,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        AppLocalizations.of(context)?.actionAddAllToLearning ?? 'Add all to Learning',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                        side: BorderSide(color: colorScheme.primary),
                        foregroundColor: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _startStoryVocabPracticeSheet,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                      side: BorderSide(color: colorScheme.outlineVariant),
                      foregroundColor: colorScheme.onSurface,
                    ),
                    child: Text(
                      AppLocalizations.of(context)?.actionPractice ?? 'Practice',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Vocab Items
        ..._keyVocabList.map((vocab) {
          Color genderColor = colorScheme.primary;
          if (vocab.gender == 'm' || vocab.gender == 'masculine') genderColor = AppTheme.genderMasc;
          if (vocab.gender == 'f' || vocab.gender == 'feminine') genderColor = AppTheme.genderFem;
          if (vocab.gender == 'n' || vocab.gender == 'neuter') genderColor = AppTheme.genderNeu;

          return Container(
            margin: const EdgeInsets.only(bottom: 12.0),
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (vocab.article.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: genderColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          vocab.article,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: genderColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        vocab.word,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (vocab.pos != null && vocab.pos!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          vocab.pos!.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Builder(
                      builder: (context) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        final cefrColors = AppTheme.getCefrColors(vocab.difficultyLabel, isDark: isDark);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cefrColors.background,
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(color: cefrColors.border, width: 0.8),
                          ),
                          child: Text(
                            vocab.difficultyLabel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cefrColors.foreground),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  vocab.primaryDefinition,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vocab.paragraphOriginal,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                      ),
                      if (vocab.paragraphTranslated.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          vocab.paragraphTranslated,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _ttsService.speak(vocab.fullWordWithArticle, lang: 'de-DE'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.volume_up_rounded, size: 14, color: colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)?.actionListen ?? 'Listen',
                              style: TextStyle(fontSize: 11, color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => GlanceWordSheet.show(
                        context,
                        word: vocab.word,
                        contextSentence: vocab.paragraphOriginal,
                        sourceTitle: widget.article?.title ?? 'Story Lesson',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.menu_book_rounded, size: 14, color: colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)?.actionGrammarForms ?? 'Grammar & Forms',
                              style: TextStyle(fontSize: 11, color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHeader() {
    List<String> paragraphs = _getParagraphList();
    final isAnyTranslationVisible = _visibleParagraphTranslations.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  _ttsService.stop();
                  Navigator.of(context).pop();
                },
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: BooksModernist.text,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.article?.title ?? 'Lesetext',
                  style: BooksModernist.heading(size: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (_isLoadingAnalysis) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BooksModernist.accent,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: Icon(
                  _activeViewIndex == 1 ? Icons.menu_book_rounded : Icons.menu_book_outlined,
                  size: 20,
                  color: _activeViewIndex == 1 ? BooksModernist.accent : BooksModernist.accentDark,
                ),
                tooltip: AppLocalizations.of(context)?.titleKeyVocab ?? 'Key Vocabulary',
                onPressed: () {
                  setState(() {
                    _activeViewIndex = _activeViewIndex == 1 ? 0 : 1;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  _isPlayingTts ? Icons.pause_rounded : Icons.volume_up_rounded,
                  size: 20,
                  color: _isPlayingTts ? BooksModernist.accent : BooksModernist.accentDark,
                ),
                tooltip: _isPlayingTts ? 'Pause' : 'Read aloud',
                onPressed: _togglePlayAllTts,
              ),
              IconButton(
                icon: Icon(
                  isAnyTranslationVisible ? Icons.translate_rounded : Icons.g_translate_rounded,
                  size: 20,
                  color: isAnyTranslationVisible ? BooksModernist.accent : BooksModernist.accentDark,
                ),
                tooltip: 'Übersetzung umschalten',
                onPressed: () {
                  setState(() {
                    if (_visibleParagraphTranslations.isNotEmpty) {
                      _visibleParagraphTranslations.clear();
                    } else {
                      for (int i = 0; i < paragraphs.length; i++) {
                        _visibleParagraphTranslations.add(i);
                      }
                    }
                  });
                },
              ),
            ],
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: _scrollProgressNotifier,
          builder: (context, progress, _) {
            return ModernistProgressBar(
              progress: progress,
              height: 3,
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: BooksModernist.surface,
          border: Border.all(color: BooksModernist.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: BooksModernist.accentDark),
            const SizedBox(width: 4),
            Text(
              label,
              style: BooksModernist.body(
                size: 11,
                weight: FontWeight.w700,
                color: BooksModernist.accentDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPageSlider() {
    List<String> paragraphs = _getParagraphList();
    if (paragraphs.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: List.generate(paragraphs.length, (index) {
              final isSelected = index == (_currentlySpokenParagraphIndex ?? 0);

              return Expanded(
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: isSelected ? 1.0 : 0.0,
                    child: Text(
                      'S. ${index + 1}',
                      style: BooksModernist.body(
                        size: 10.5,
                        weight: FontWeight.w800,
                        color: BooksModernist.accentDark,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 2),
          Row(
            children: List.generate(paragraphs.length, (index) {
              final isSelected = index == (_currentlySpokenParagraphIndex ?? 0);

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _currentlySpokenParagraphIndex = index;
                    });
                    _scrollToParagraph(index);
                  },
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < paragraphs.length - 1 ? 6.0 : 0.0,
                      top: 2.0,
                      bottom: 4.0,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? BooksModernist.accent
                            : BooksModernist.divider.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderLegend(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: BooksModernist.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: BooksModernist.dividerThin,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendChip(context, 'der (M)', isDark ? AppTheme.genderMascDark : AppTheme.genderMasc),
          _buildLegendChip(context, 'die (F)', isDark ? AppTheme.genderFemDark : AppTheme.genderFem),
          _buildLegendChip(context, 'das (N)', isDark ? AppTheme.genderNeuDark : AppTheme.genderNeu),
        ],
      ),
    );
  }

  Widget _buildLegendChip(BuildContext context, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: BooksModernist.body(
            size: 12,
            weight: FontWeight.w600,
            color: BooksModernist.text.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    final rawTitle = widget.article?.title ?? 'Der verlorene Schlüssel';
    String mainHeadline = rawTitle;
    String? sourceTag;

    if (rawTitle.contains(' - ')) {
      final parts = rawTitle.split(' - ');
      if (parts.last.contains('.')) {
        sourceTag = parts.last;
        mainHeadline = parts.sublist(0, parts.length - 1).join(' - ');
      }
    }

    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: BooksModernist.accent,
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ModernistTag(widget.article?.level ?? 'LESETEXT', accent: true),
              const SizedBox(width: 10),
              Text(
                'KAPITEL ${widget.article?.id ?? '1'}',
                style: BooksModernist.body(
                  size: 11.5,
                  weight: FontWeight.w700,
                  color: BooksModernist.text.withValues(alpha: 0.6),
                ),
              ),
              if (sourceTag != null) ...[
                const SizedBox(width: 8),
                ModernistTag(sourceTag),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            mainHeadline,
            style: BooksModernist.heading(size: 18, height: 1.25),
          ),
          if (widget.article == null) ...[
            const SizedBox(height: 4),
            Text(
              'The Lost Key',
              style: BooksModernist.body(
                size: 13,
                color: BooksModernist.text.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStoryContent(BuildContext context) {
    List<String> paragraphs = _getParagraphList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(paragraphs.length, (index) {
        _paragraphKeys.putIfAbsent(index, () => GlobalKey());

        final germanText = _paragraphAnalysisData[index]?['german_text'] as String? ?? paragraphs[index];

        return Padding(
          key: _paragraphKeys[index],
          padding: const EdgeInsets.only(bottom: 18.0),
          child: _buildInteractiveParagraph(context, germanText, index),
        );
      }),
    );
  }

  TextStyle _getReaderTextStyle(BuildContext context) {
    final baseColor = _isSepiaMode
        ? const Color(0xFF322720)
        : BooksModernist.text;

    if (_fontFamily == 'Serif') {
      return GoogleFonts.lora(fontSize: _fontSize, height: _lineHeight, color: baseColor);
    } else if (_fontFamily == 'Mono') {
      return GoogleFonts.robotoMono(fontSize: _fontSize, height: _lineHeight, color: baseColor);
    } else {
      return BooksModernist.font(context, size: _fontSize, height: _lineHeight, color: baseColor);
    }
  }

  Widget _buildInteractiveParagraph(BuildContext context, String text, int index) {
    final englishTranslation = _paragraphAnalysisData[index]?['english_translation'] as String?;
    final isTranslationVisible = _visibleParagraphTranslations.contains(index);
    final isActionsVisible = _activeActionParagraphs.contains(index);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () => _speakParagraph(text, index),
      onLongPress: () {
        setState(() {
          if (_activeActionParagraphs.contains(index)) {
            _activeActionParagraphs.remove(index);
          } else {
            _activeActionParagraphs.add(index);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _isSepiaMode
              ? (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF322C28)
                  : const Color(0xFFEBE0D0))
              : BooksModernist.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActionsVisible ? BooksModernist.accent : BooksModernist.dividerThin,
            width: isActionsVisible ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<_TappedWordData?>(
              valueListenable: _tappedWordNotifier,
              builder: (context, tappedData, _) {
                return RichText(
                  text: TextSpan(
                    style: _getReaderTextStyle(context),
                    children: _buildParagraphSpans(context, text, index),
                  ),
                );
              },
            ),
            if (isActionsVisible) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BooksModernist.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: BooksModernist.dividerThin),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _speakParagraph(text, index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              (_isPlayingTts && _currentTtsProgress?.text == text)
                                  ? Icons.pause_rounded
                                  : Icons.volume_up_rounded,
                              size: 14,
                              color: BooksModernist.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Speak',
                              style: BooksModernist.body(size: 11, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(height: 12, width: 1, color: BooksModernist.dividerThin),
                    InkWell(
                      onTap: () => _showAiGrammarExplainer(context, text, index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 14, color: BooksModernist.accent),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)?.actionGrammar ?? 'Grammar',
                              style: BooksModernist.body(size: 11, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(height: 12, width: 1, color: BooksModernist.dividerThin),
                    InkWell(
                      onTap: () => _editParagraph(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_rounded, size: 14, color: BooksModernist.accentDark),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)?.actionEdit ?? 'Edit',
                              style: BooksModernist.body(size: 11, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(height: 12, width: 1, color: BooksModernist.dividerThin),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _activeActionParagraphs.remove(index);
                        });
                        _deleteParagraph(index);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)?.actionDelete ?? 'Delete',
                              style: BooksModernist.body(
                                size: 11,
                                weight: FontWeight.w600,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isTranslationVisible && englishTranslation != null && englishTranslation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: BooksModernist.accent100,
                  borderRadius: BorderRadius.circular(6),
                  border: const Border(
                    left: BorderSide(
                      color: BooksModernist.accentDark,
                      width: 3.5,
                    ),
                  ),
                ),
                child: Text(
                  englishTranslation,
                  style: BooksModernist.body(
                    size: 12,
                    color: BooksModernist.accentDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _buildParagraphSpans(BuildContext context, String text, int paragraphIndex) {
    List<String> rawTokens = text.split(' ');
    List<InlineSpan> spans = [];
    int currentCharacterOffset = 0;

    final paragraphData = _paragraphAnalysisData[paragraphIndex];
    final paragraphTokens = (paragraphData?['german_analysis'] as List<dynamic>?) ?? [];
    int tokenSearchIndex = 0;

    for (int i = 0; i < rawTokens.length; i++) {
      String token = rawTokens[i];
      final match = _wordTokenRegex.firstMatch(token);

      if (match != null) {
        String prefix = match.group(1) ?? '';
        String word = match.group(2) ?? '';
        String suffix = match.group(3) ?? '';

        if (prefix.isNotEmpty) {
          spans.add(TextSpan(text: prefix));
        }

        Color wordColor = Theme.of(context).colorScheme.onSurface;
        FontWeight wordWeight = FontWeight.normal;

        String? contextGender;
        String? contextPos;
        String? lemma;

        // Contextual word alignment
        while (tokenSearchIndex < paragraphTokens.length) {
          final aToken = paragraphTokens[tokenSearchIndex];
          if (aToken['word'].toString().toLowerCase() == word.toLowerCase()) {
            contextGender = aToken['gender'];
            contextPos = aToken['pos'];
            lemma = aToken['lemma'];
            tokenSearchIndex++;
            break;
          } else {
            tokenSearchIndex++;
            if (tokenSearchIndex >= paragraphTokens.length) break;
            if (paragraphTokens[tokenSearchIndex]['word'].toString().toLowerCase() == word.toLowerCase()) {
              contextGender = paragraphTokens[tokenSearchIndex]['gender'];
              contextPos = paragraphTokens[tokenSearchIndex]['pos'];
              lemma = paragraphTokens[tokenSearchIndex]['lemma'];
              tokenSearchIndex++;
              break;
            }
          }
        }

        // TTS word highlighting (Supports both single paragraph and full story playback)
        bool isHighlighted = false;
        if (_currentTtsProgress != null) {
          int wordStart = currentCharacterOffset + prefix.length;
          int wordEnd = wordStart + word.length;

          if (_currentTtsProgress!.text == text) {
            // Paragraph-level TTS
            if (wordStart >= _currentTtsProgress!.start && wordEnd <= _currentTtsProgress!.end) {
              isHighlighted = true;
            }
          } else if (_currentTtsProgress!.text.contains(text)) {
            // Full story TTS
            int paraOffsetInFullText = _currentTtsProgress!.text.indexOf(text);
            if (paraOffsetInFullText != -1) {
              int relStart = _currentTtsProgress!.start - paraOffsetInFullText;
              int relEnd = _currentTtsProgress!.end - paraOffsetInFullText;

              if (relStart >= 0 && wordStart >= relStart - 1 && wordEnd <= relEnd + 2) {
                isHighlighted = true;
              } else if (relStart >= 0 &&
                  word.toLowerCase() == _currentTtsProgress!.word.toLowerCase() &&
                  wordStart >= relStart - 8 &&
                  wordStart <= relEnd + 8) {
                isHighlighted = true;
              }
            }
          }
        }

        // German Noun Gender Coloring (der / die / das)
        final isCapitalizedNoun = word.isNotEmpty && word[0] == word[0].toUpperCase();
        final isNounInDb = _wordGenders.containsKey(word) || _wordGenders.containsKey(word.toLowerCase());
        if (_showGenderHighlighting && (contextPos?.toLowerCase() == 'noun' || isCapitalizedNoun || isNounInDb)) {
          final gender = _getNounGender(word, contextGender, lemma);

          if (gender != null && gender.isNotEmpty) {
            wordWeight = FontWeight.w600;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final g = gender.toLowerCase().trim();

            if (g == 'm' || g == 'masc' || g == 'masculine' || g == 'der') {
              wordColor = isDark ? AppTheme.genderMascDark : AppTheme.genderMasc;
            } else if (g == 'f' || g == 'fem' || g == 'feminine' || g == 'die') {
              wordColor = isDark ? AppTheme.genderFemDark : AppTheme.genderFem;
            } else if (g == 'n' || g == 'neu' || g == 'neuter' || g == 'das') {
              wordColor = isDark ? AppTheme.genderNeuDark : AppTheme.genderNeu;
            }
          }
        } else if (_showGenderHighlighting && contextPos != null) {
          // Part-of-speech coloring for other content words (verb/adjective/adverb) —
          // same toggle as noun-gender coloring, just applied to the categories the
          // ML POS tagger (NativeNlpService / GermanPosTagger.kt) returns beyond noun.
          final posColor = AppTheme.colorForPos(contextPos, isDark: Theme.of(context).brightness == Brightness.dark);
          if (posColor != null) {
            wordColor = posColor;
          }
        }

        final tappedData = _tappedWordNotifier.value;
        final isTappedWord = tappedData != null &&
            tappedData.paragraphIndex == paragraphIndex &&
            word.toLowerCase() == tappedData.word.toLowerCase();

        Color? backgroundColor;
        Color? textColor = wordColor;

        if (isTappedWord) {
          backgroundColor = Theme.of(context).colorScheme.primaryContainer;
          textColor = Theme.of(context).colorScheme.onPrimaryContainer;
        } else if (isHighlighted) {
          backgroundColor = Theme.of(context).colorScheme.primaryContainer;
          textColor = Theme.of(context).colorScheme.primary;
        }

        spans.add(
          TextSpan(
            text: word,
            style: TextStyle(
              color: textColor,
              fontWeight: isTappedWord ? FontWeight.bold : wordWeight,
              backgroundColor: backgroundColor,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _handleWordTap(word, text, paragraphIndex);
              },
          ),
        );

        if (suffix.isNotEmpty) {
          spans.add(TextSpan(text: suffix));
        }
      } else {
        spans.add(TextSpan(text: token));
      }

      currentCharacterOffset += token.length;

      if (i < rawTokens.length - 1) {
        spans.add(const TextSpan(text: ' '));
        currentCharacterOffset += 1;
      }
    }
    return spans;
  }

  void _handleWordTap(String word, String contextText, int paragraphIndex) {
    final cleanWord = word.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '').trim();
    if (cleanWord.isEmpty) return;

    if (_isPlayingTts) {
      _ttsService.stop();
      setState(() => _isPlayingTts = false);
    }

    _tappedWordNotifier.value = _TappedWordData(cleanWord, paragraphIndex);

    // Extract in-memory token analysis for instant 0ms pre-populated sheet rendering
    List<Map<String, dynamic>>? instantDetails;
    final paragraphData = _paragraphAnalysisData[paragraphIndex];
    if (paragraphData != null) {
      final tokens = (paragraphData['german_analysis'] as List<dynamic>?) ?? [];
      for (var t in tokens) {
        final tokenWord = t['word']?.toString() ?? '';
        final tokenLemma = t['lemma']?.toString() ?? '';
        if (tokenWord.toLowerCase() == cleanWord.toLowerCase() ||
            tokenLemma.toLowerCase() == cleanWord.toLowerCase()) {
          final gender = _getNounGender(cleanWord, t['gender']?.toString(), tokenLemma);
          final trans = t['translation']?.toString().trim();
          instantDetails = [
            {
              'word': tokenWord.isNotEmpty ? tokenWord : cleanWord,
              'base_form': tokenLemma.isNotEmpty ? tokenLemma : cleanWord,
              'pos': t['pos'] ?? 'noun',
              'gender': gender,
              'definition': (trans != null && trans.isNotEmpty) ? trans : '',
              'definitions': (trans != null && trans.isNotEmpty) ? <String>[trans] : <String>[],
              'contextNote': t['note'] ?? '',
            }
          ];
          break;
        }
      }
    }

    GlanceWordSheet.show(
      context,
      word: cleanWord,
      detailsList: instantDetails,
      contextSentence: contextText,
      sourceTitle: widget.article?.title ?? 'Story',
    ).whenComplete(() {
      _tappedWordNotifier.value = null;
    });
  }

  void _editParagraph(int index) async {
    final paragraphs = _getParagraphList();
    if (index < 0 || index >= paragraphs.length) return;

    final currentText = _paragraphAnalysisData[index]?['german_text'] as String? ?? paragraphs[index];
    final controller = TextEditingController(text: currentText);

    final newText = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: Theme.of(sheetContext).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Edit Paragraph',
                    style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 6,
                    style: _getReaderTextStyle(sheetContext).copyWith(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Paragraph text…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext, controller.text.trim()),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (newText == null || newText.isEmpty || newText == currentText) return;
    if (!mounted) return;

    paragraphs[index] = newText;
    // The edited text supersedes any previously cached AI analysis for this
    // paragraph — the old translation/grammar breakdown would now describe
    // text that no longer exists.
    _paragraphAnalysisData.remove(index);
    _visibleParagraphTranslations.remove(index);

    _loadedContent = paragraphs.join('\n\n');

    final storyId = widget.article?.id ?? 'default_story';
    final mediaLibraryService = Provider.of<MediaLibraryService>(context, listen: false);
    if (widget.article != null) {
      await mediaLibraryService.saveCustomContent(widget.article!.id, _loadedContent!);
    }
    await mediaLibraryService.saveCachedAnalysis(storyId, _paragraphAnalysisData);

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paragraph updated'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _deleteParagraph(int index) async {
    List<String> paragraphs = _getParagraphList();
    if (index < 0 || index >= paragraphs.length) return;

    final deletedText = paragraphs[index];
    final deletedAnalysis = _paragraphAnalysisData[index];

    // Remove paragraph
    paragraphs.removeAt(index);

    // Re-index persistent analysis map
    Map<int, Map<String, dynamic>> updatedAnalysis = {};
    for (int i = 0; i < paragraphs.length; i++) {
      int oldIndex = i >= index ? i + 1 : i;
      if (_paragraphAnalysisData.containsKey(oldIndex)) {
        updatedAnalysis[i] = _paragraphAnalysisData[oldIndex]!;
      }
    }

    _loadedContent = paragraphs.join('\n\n');
    _paragraphAnalysisData = updatedAnalysis;

    // Save changes to persistent storage
    final storyId = widget.article?.id ?? 'default_story';
    final mediaLibraryService = Provider.of<MediaLibraryService>(context, listen: false);
    if (widget.article != null) {
      await mediaLibraryService.saveCustomContent(widget.article!.id, _loadedContent!);
    }
    await mediaLibraryService.saveCachedAnalysis(storyId, _paragraphAnalysisData);

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Paragraph deleted'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              paragraphs.insert(index, deletedText);
              _loadedContent = paragraphs.join('\n\n');

              Map<int, Map<String, dynamic>> restoredAnalysis = {};
              for (int i = 0; i < paragraphs.length; i++) {
                if (i == index && deletedAnalysis != null) {
                  restoredAnalysis[i] = deletedAnalysis;
                } else {
                  int srcIndex = i > index ? i - 1 : i;
                  if (_paragraphAnalysisData.containsKey(srcIndex)) {
                    restoredAnalysis[i] = _paragraphAnalysisData[srcIndex]!;
                  }
                }
              }
              _paragraphAnalysisData = restoredAnalysis;

              if (widget.article != null) {
                await mediaLibraryService.saveCustomContent(widget.article!.id, _loadedContent!);
              }
              await mediaLibraryService.saveCachedAnalysis(storyId, _paragraphAnalysisData);

              if (mounted) setState(() {});
            },
          ),
        ),
      );
    }
  }

  // --- IN-APP AI GRAMMAR & SENTENCE EXPLAINER SHEET ---
  void _showAiGrammarExplainer(BuildContext context, String text, int paragraphIndex) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<SentenceAnalysisResult>(
          future: _onDeviceAI.analyzeSentenceLocally(text),
          builder: (context, snapshot) {
            final isLoading = snapshot.connectionState == ConnectionState.waiting;
            final result = snapshot.data;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onTertiaryContainer, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Sentence & Grammar Breakdown',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Paragraph ${paragraphIndex + 1}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  if (isLoading)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Analyzing German grammar & sentence structure...'),
                          ],
                        ),
                      ),
                    )
                  else if (result != null)
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🇩🇪 ', style: TextStyle(fontSize: 18)),
                                Expanded(
                                  child: Text(
                                    result.originalSentence,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.volume_up_rounded),
                                  tooltip: 'Play pronunciation',
                                  onPressed: () => _ttsService.speak(result.originalSentence),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🇬🇧 ', style: TextStyle(fontSize: 18)),
                                Expanded(
                                  child: Text(
                                    result.translatedSentence,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.4,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Text(
                                'Structure: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Chip(
                                label: Text(result.overallStructure),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text(
                            'Word & Part-of-Speech Analysis',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          ...result.tokens.where((token) {
                            final w = token.word.toLowerCase().trim();
                            final lemma = token.lemma.toLowerCase().trim();
                            const obviousWords = {
                              'der', 'die', 'das', 'dem', 'den', 'des',
                              'ein', 'eine', 'einen', 'einem', 'einer', 'eines',
                              'kein', 'keine', 'keinen', 'keinem', 'keiner', 'keines',
                            };
                            return !obviousWords.contains(w) && !obviousWords.contains(lemma);
                          }).map((token) {
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              color: Theme.of(context).colorScheme.surfaceContainerLow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                title: Row(
                                  children: [
                                    Text(
                                      token.word,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        token.partOfSpeech,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Meaning: ${token.translation}'),
                                    if (token.grammarNote.isNotEmpty)
                                      Text(
                                        token.grammarNote,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.style_outlined, size: 20),
                                  tooltip: 'Add to Study Deck',
                                  onPressed: () async {
                                    await _vocabularyService.saveWord(token.word);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Added "${token.word}" to Study Deck!'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- DISPLAY & TYPOGRAPHY SETTINGS SHEET ---
  void _showDisplaySettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reader Preferences & Layout',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Font Family Selector
                  const Text('Font Family', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      {'id': 'Sans', 'label': 'Sans (Modern)'},
                      {'id': 'Serif', 'label': 'Serif (Book)'},
                      {'id': 'Mono', 'label': 'Mono (Focus)'},
                    ].map((f) {
                      final isSelected = _fontFamily == f['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f['label']!),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _fontFamily = f['id']!);
                            setSheetState(() {});
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Line Spacing Selector
                  const Text('Line Spacing', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      {'val': 1.4, 'label': 'Compact (1.4x)'},
                      {'val': 1.6, 'label': 'Normal (1.6x)'},
                      {'val': 1.9, 'label': 'Relaxed (1.9x)'},
                    ].map((h) {
                      final isSelected = (_lineHeight - (h['val'] as double)).abs() < 0.05;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(h['label'] as String),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _lineHeight = h['val'] as double);
                            setSheetState(() {});
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Font Size Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Font Size', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${_fontSize.round()} px', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 14.0,
                          max: 26.0,
                          divisions: 6,
                          onChanged: (val) {
                            setState(() => _fontSize = val);
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sepia Paper Theme Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sepia Warm Paper Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Warm reading tone for lower eye fatigue'),
                    value: _isSepiaMode,
                    onChanged: (val) {
                      setState(() => _isSepiaMode = val);
                      setSheetState(() {});
                    },
                  ),

                  // Noun Gender Highlighting Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Noun Gender Highlighting', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Color der/die/das nouns for easier learning'),
                    value: _showGenderHighlighting,
                    onChanged: (val) {
                      setState(() => _showGenderHighlighting = val);
                      setSheetState(() {});
                    },
                  ),

                  // Auto Scroll Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-Scroll with Speech', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Scroll text automatically as audio plays'),
                    value: _autoScrollWithTts,
                    onChanged: (val) {
                      setState(() => _autoScrollWithTts = val);
                      setSheetState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _toggleAllParagraphTranslations() {
    List<String> paragraphs = _getParagraphList();
    setState(() {
      if (_visibleParagraphTranslations.length == paragraphs.length) {
        _visibleParagraphTranslations.clear();
      } else {
        _visibleParagraphTranslations.addAll(List.generate(paragraphs.length, (i) => i));
      }
    });
  }

  // --- FLOATING GLASSMORPHIC READER TOOLBAR ---
  Widget _buildFloatingReaderToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Play / Pause Full Story Audio
              Row(
                children: [
                  IconButton.filled(
                    icon: Icon(
                      _isPlayingTts ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 24,
                    ),
                    tooltip: _isPlayingTts ? 'Pause' : 'Play',
                    onPressed: _togglePlayAllTts,
                  ),
                  if (_isPlayingTts)
                    IconButton(
                      icon: const Icon(Icons.stop_rounded, size: 22),
                      tooltip: 'Stop',
                      onPressed: () {
                        _ttsService.stop();
                        setState(() => _isPlayingTts = false);
                      },
                    ),
                ],
              ),

              // Speech Speed Selector Pills
              Row(
                children: [0.75, 1.0, 1.25].map((speed) {
                  final ttsRate = 0.5 * speed;
                  final isSelected = (_speechRate - ttsRate).abs() < 0.05;

                  return Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: ChoiceChip(
                      label: Text('${speed}x', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => _changeSpeed(ttsRate),
                    ),
                  );
                }).toList(),
              ),

              // Toggle All Paragraph Translations Button
              IconButton(
                icon: Icon(
                  _visibleParagraphTranslations.length == _getParagraphList().length
                      ? Icons.translate_rounded
                      : Icons.g_translate_rounded,
                  size: 22,
                  color: _visibleParagraphTranslations.length == _getParagraphList().length
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                tooltip: _visibleParagraphTranslations.length == _getParagraphList().length
                    ? 'Hide all translations'
                    : 'Show all translations',
                onPressed: _toggleAllParagraphTranslations,
              ),
            ],
          ),
    );
  }
}
