import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../services/dictionary_service.dart';
import '../services/vocabulary_service.dart';
import '../services/lesson_service.dart';
import '../services/tts_service.dart';
import '../services/ondevice_ai_service.dart';

import '../models/article_model.dart';
import '../widgets/glance_word_sheet.dart';

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

class _StoryReaderScreenState extends State<StoryReaderScreen> {
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

  static final RegExp _wordTokenRegex = RegExp(r'^([^\wäöüÄÖÜß]*)([\wäöüÄÖÜß]+)([^\wäöüÄÖÜß]*)$');

  // Reader Settings State
  final ValueNotifier<double> _scrollProgressNotifier = ValueNotifier<double>(0.0);
  double _fontSize = 18.0;
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
    _scrollController.addListener(_updateScrollProgress);
    _loadContent();
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
      final lessonService = Provider.of<LessonService>(context, listen: false);
      final customData = await lessonService.getCustomContent(widget.article!.id);
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

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollProgress);
    _scrollController.dispose();
    _ttsSubscription?.cancel();
    super.dispose();
  }

  List<String> _getParagraphList() {
    if (_loadedContent != null && _loadedContent!.isNotEmpty) {
      return _loadedContent!.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).toList();
    }
    return [
      'Es war ein kalter, nebliger Morgen. Hannah stand vor dem alten Haus ihrer Großmutter. Die Fenster waren dunkel und das Tor quietschte im Wind. Sie hatte Angst, aber sie musste hineingehen.',
      'Langsam öffnete sie die schwere Eichentür. Der Flur roch nach Staub und alten Büchern. Auf dem kleinen Tisch im Flur lag etwas Glänzendes.',
      'Hannah ging näher heran. Es war ein kleiner, goldener Schmetterling aus Metall.',
      '"Warum liegt das hier?", flüsterte sie. Plötzlich hörte sie ein Geräusch aus dem ersten Stock. War sie wirklich allein?',
      'Ihr Herz klopfte schneller. Sie nahm den Gegenstand und steckte ihn in ihre Tasche.'
    ];
  }

  Future<void> _fetchContextualAnalysis() async {
    setState(() {
      _isLoadingAnalysis = true;
      _paragraphAnalysisData = {};
    });

    final storyId = widget.article?.id ?? 'default_story';
    final lessonService = Provider.of<LessonService>(context, listen: false);

    // 1. Check persistent disk cache first (0ms instantaneous load)
    final cached = await lessonService.getCachedAnalysis(storyId);
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _paragraphAnalysisData = cached;
        _visibleParagraphTranslations.addAll(cached.keys);
        _isLoadingAnalysis = false;
      });
      _loadWordGenders();
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
          _visibleParagraphTranslations.add(i);
        });
      }

      await lessonService.saveCachedAnalysis(storyId, _paragraphAnalysisData);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAnalysis = false;
        });
        _loadWordGenders(); // Query DB for any newly parsed lemmas
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

  void _changeSpeed(double rate) {
    setState(() {
      _speechRate = rate;
    });
    _ttsService.setSpeechRate(rate);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    if (_isSepiaMode) {
      scaffoldBg = isDark ? const Color(0xFF262220) : const Color(0xFFF6F0E6);
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth > 850;

          if (isDesktop) {
            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildStickyHeader(context),
                SliverPadding(
                  padding: const EdgeInsets.all(28),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Story Column (Flex 65)
                            Expanded(
                              flex: 65,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTitleSection(context),
                                  const SizedBox(height: 16),
                                  if (_showGenderHighlighting) _buildGenderLegend(context),
                                  const SizedBox(height: 20),
                                  _buildStoryContent(context),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),

                            // Right Sidebar Column (Flex 35)
                            Expanded(
                              flex: 35,
                              child: _buildDesktopReaderSidebar(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Mobile / Mobile Web Single-Column Layout
          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  _buildStickyHeader(context),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 160 + bottomInset),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 780),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTitleSection(context),
                                const SizedBox(height: 16),
                                if (_showGenderHighlighting) _buildGenderLegend(context),
                                const SizedBox(height: 20),
                                _buildStoryContent(context),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),

              // Floating Bottom Reader Toolbar (Mobile)
              Positioned(
                left: 16,
                right: 16,
                bottom: bottomInset + 12,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: _buildFloatingReaderToolbar(context),
                  ),
                ),
              ),
            ],
          );
        },
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
              borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(16),
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

  Widget _buildStickyHeader(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back Button (40x40)
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Theme.of(context).colorScheme.onSurface),
                onPressed: () {
                  _ttsService.stop();
                  Navigator.pop(context);
                },
              ),
            ),

            // Center Scroll % Badge
            ValueListenableBuilder<double>(
              valueListenable: _scrollProgressNotifier,
              builder: (context, progress, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${(progress * 100).round()}% read',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                );
              },
            ),

            // Right Action Controls (Uniform 40x40 Size & Padding)
            Row(
              children: [
                // Analysis Status Indicator
                Container(
                  width: 40, height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: _isLoadingAnalysis
                      ? SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                        )
                      : Icon(Icons.check_circle_rounded, size: 20, color: Colors.green.shade600),
                ),
                const SizedBox(width: 8),

                // Reader Preferences Sheet Trigger (40x40)
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.tune_rounded, size: 20, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => _showDisplaySettingsSheet(context),
                  ),
                ),
                const SizedBox(width: 8),

                // Dark / Light Theme Switch (40x40)
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.brightness_6_rounded,
                        size: 20, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () {
                      Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderLegend(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    final rawTitle = widget.article?.title ?? 'Der verlorene Schlüssel';
    String mainHeadline = rawTitle;
    String? sourceTag;

    // Clean up domain suffixes like "- sgi-ch.org" into a clean source tag
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
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.article?.level ?? 'KAPITEL 3',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (sourceTag != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sourceTag,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mainHeadline,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (widget.article == null) ...[
            const SizedBox(height: 4),
            Text(
              'The Lost Key',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          padding: const EdgeInsets.only(bottom: 24.0),
          child: _buildInteractiveParagraph(context, germanText, index),
        );
      }),
    );
  }

  TextStyle _getReaderTextStyle(BuildContext context) {
    final baseColor = _isSepiaMode
        ? const Color(0xFF322720)
        : Theme.of(context).colorScheme.onSurface;

    if (_fontFamily == 'Serif') {
      return GoogleFonts.lora(fontSize: _fontSize, height: _lineHeight, color: baseColor);
    } else if (_fontFamily == 'Mono') {
      return GoogleFonts.robotoMono(fontSize: _fontSize, height: _lineHeight, color: baseColor);
    } else {
      return GoogleFonts.splineSans(fontSize: _fontSize, height: _lineHeight, color: baseColor);
    }
  }

  Widget _buildInteractiveParagraph(BuildContext context, String text, int index) {
    final englishTranslation = _paragraphAnalysisData[index]?['english_translation'] as String?;
    final isTranslationVisible = _visibleParagraphTranslations.contains(index);
    final isSpoken = _currentlySpokenParagraphIndex == index && _isPlayingTts;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: isSpoken ? const EdgeInsets.all(10) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isSpoken
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: isSpoken
            ? Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Styled Left Action Column
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Audio Speak Paragraph
                      IconButton(
                        icon: Icon(
                          Icons.volume_up_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'Listen to paragraph',
                        onPressed: () {
                          _ttsService.setSpeechRate(_speechRate);
                          _ttsService.speak(text);
                        },
                      ),
                      const SizedBox(height: 4),

                      // Inline Translation Toggle
                      IconButton(
                        icon: _isLoadingAnalysis && (englishTranslation == null || englishTranslation.isEmpty)
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                              )
                            : Icon(
                                isTranslationVisible ? Icons.translate_rounded : Icons.g_translate_rounded,
                                size: 20,
                                color: isTranslationVisible
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'Toggle paragraph translation',
                        onPressed: () {
                          setState(() {
                            if (_visibleParagraphTranslations.contains(index)) {
                              _visibleParagraphTranslations.remove(index);
                            } else {
                              _visibleParagraphTranslations.add(index);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 4),

                      // In-App AI Grammar Explainer Sheet Trigger
                      IconButton(
                        icon: Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'AI Grammar Breakdown',
                        onPressed: () => _showAiGrammarExplainer(context, text, index),
                      ),
                      const SizedBox(height: 4),

                      // Delete Paragraph Trigger
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'Delete paragraph',
                        onPressed: () => _deleteParagraph(index),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Paragraph Body & Translation
              Expanded(
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
                  if (isTranslationVisible && englishTranslation != null && englishTranslation.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 10.0),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                            width: 3.5,
                          ),
                        ),
                      ),
                      child: Text(
                        englishTranslation,
                        style: GoogleFonts.splineSans(
                          fontSize: (_fontSize - 3).clamp(12.0, 20.0),
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
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
        }

        final tappedData = _tappedWordNotifier.value;
        final isTappedWord = tappedData != null &&
            tappedData.paragraphIndex == paragraphIndex &&
            word.toLowerCase() == tappedData.word.toLowerCase();

        Color? backgroundColor;
        Color? textColor = isHighlighted ? Theme.of(context).colorScheme.onPrimary : wordColor;

        if (isTappedWord) {
          backgroundColor = Theme.of(context).colorScheme.primaryContainer;
          textColor = Theme.of(context).colorScheme.onPrimaryContainer;
        } else if (isHighlighted) {
          backgroundColor = Theme.of(context).colorScheme.primary;
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
              ..onTapDown = (details) {
                _handleWordTap(word, text, details.globalPosition, paragraphIndex);
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

  void _handleWordTap(String word, String contextText, Offset tapPosition, int paragraphIndex) {
    final cleanWord = word.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '').trim();
    if (cleanWord.isEmpty) return;

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
          instantDetails = [
            {
              'word': tokenWord.isNotEmpty ? tokenWord : cleanWord,
              'base_form': tokenLemma.isNotEmpty ? tokenLemma : cleanWord,
              'pos': t['pos'] ?? 'noun',
              'gender': gender,
              'definitions': <String>[],
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
    final lessonService = Provider.of<LessonService>(context, listen: false);
    if (widget.article != null) {
      await lessonService.saveCustomContent(widget.article!.id, _loadedContent!);
    }
    await lessonService.saveCachedAnalysis(storyId, _paragraphAnalysisData);

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
                await lessonService.saveCustomContent(widget.article!.id, _loadedContent!);
              }
              await lessonService.saveCachedAnalysis(storyId, _paragraphAnalysisData);

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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                              borderRadius: BorderRadius.circular(12),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🇬🇧 ', style: TextStyle(fontSize: 18)),
                                Expanded(
                                  child: Text(
                                    result.translatedSentence,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontStyle: FontStyle.italic,
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
                                borderRadius: BorderRadius.circular(10),
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
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                                  icon: const Icon(Icons.bookmark_border_rounded, size: 20),
                                  onPressed: () async {
                                    await _vocabularyService.saveWord(token.word);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Saved "${token.word}" to Vocabulary!'),
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
        borderRadius: BorderRadius.circular(30),
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
                    onPressed: _togglePlayAllTts,
                  ),
                  if (_isPlayingTts)
                    IconButton(
                      icon: const Icon(Icons.stop_rounded, size: 22),
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
