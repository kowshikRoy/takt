import 'package:flutter/material.dart';
import '../theme/books_modernist_style.dart';
import '../services/dictionary_service.dart';
import '../services/vocabulary_service.dart';
import '../services/tts_service.dart';
import '../models/saved_word.dart';
import '../widgets/word_header_card.dart';
import '../widgets/word_edit_sheet.dart';

class WordDetailScreen extends StatefulWidget {
  final String word;
  final Map<String, dynamic>? wordData;

  const WordDetailScreen({
    super.key,
    required this.word,
    this.wordData,
  });

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final DictionaryService _dictionaryService = DictionaryService();
  final VocabularyService _vocabService = VocabularyService();
  final TtsService _ttsService = TtsService();

  Map<String, dynamic>? _wordDetails;
  Future<String?>? _wordImageFuture;
  int _selectedTabIndex = 1; // Default to 1: Examples
  Set<String> _savedWordIds = {};
  Map<String, VocabCategory> _savedWordCategories = {};
  SavedWord? _savedWord;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedWordStatus();

    if (widget.wordData != null) {
      _wordDetails = Map<String, dynamic>.from(widget.wordData!);
      _wordImageFuture = _dictionaryService.getWordImageUrl(
        widget.word,
        pos: _wordDetails?['pos']?.toString(),
      );
    }

    _fetchFullDetails();
  }

  Future<void> _loadSavedWordStatus() async {
    try {
      final saved = await _vocabService.getSavedWords();
      final currentSaved = await _vocabService.getSavedWordByWord(widget.word) ??
          await _vocabService.getSavedWord(widget.word.toLowerCase().trim());

      if (mounted) {
        setState(() {
          _savedWord = currentSaved;
          _savedWordIds = saved.map((w) => w.id.toLowerCase().trim()).toSet();
          _savedWordCategories = {
            for (var w in saved) w.id.toLowerCase().trim(): w.category,
          };
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchFullDetails() async {
    if (_wordDetails == null) {
      setState(() => _isLoading = true);
    }
    final full = await _dictionaryService.lookupWord(widget.word);
    final currentSaved = await _vocabService.getSavedWordByWord(widget.word) ??
        await _vocabService.getSavedWord(widget.word.toLowerCase().trim());

    if (mounted) {
      setState(() {
        _savedWord = currentSaved;
        if (full != null) {
          _wordDetails = full;
        } else if (_wordDetails == null) {
          _wordDetails = {
            'word': widget.word,
            'pos': '',
            'gender': '',
            'definitions': [],
          };
        }
        _wordImageFuture = _dictionaryService.getWordImageUrl(
          widget.word,
          pos: _wordDetails?['pos']?.toString(),
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _editWord() async {
    if (_wordDetails == null) return;
    final savedWord = await WordEditSheet.show(
      context,
      word: _wordDetails!['word']?.toString() ?? widget.word,
      data: _wordDetails,
    );
    if (savedWord != null && mounted) {
      await _fetchFullDetails();
    }
  }

  Future<void> _setStatus(
      Map<String, dynamic> wordData, VocabCategory category) async {
    final wordStr = wordData['word']?.toString() ?? widget.word;
    final wordId = wordStr.toLowerCase().trim();
    final currentCategory = _savedWordCategories[wordId];

    if (currentCategory == category) {
      await _vocabService.removeWord(wordId);
      setState(() {
        _savedWord = null;
        _savedWordIds.remove(wordId);
        _savedWordCategories.remove(wordId);
      });
    } else {
      final defs = (wordData['definitions'] as List?) ?? [];
      final primaryDef = defs.isNotEmpty ? defs.first.toString() : '';

      final saved = SavedWord(
        id: wordId,
        word: wordStr,
        pos: wordData['pos']?.toString(),
        gender: wordData['gender']?.toString(),
        primaryDefinition: primaryDef,
        category: category,
        contextSentence: _savedWord?.contextSentence,
        sourceTitle: _savedWord?.sourceTitle,
        contextExamples: _savedWord?.contextExamples,
        createdAt: DateTime.now(),
      );

      await _vocabService.upsertWord(saved);
      final updated = await _vocabService.getSavedWord(wordId);
      setState(() {
        _savedWord = updated ?? saved;
        _savedWordIds.add(wordId);
        _savedWordCategories[wordId] = category;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayWord = _wordDetails?['word']?.toString() ?? widget.word;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          displayWord,
          style: BooksModernist.heading(
            size: 18,
            color: colorScheme.onSurface,
            context: context,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: colorScheme.onSurface),
            tooltip: 'Edit word',
            onPressed: _wordDetails == null ? null : _editWord,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading && _wordDetails == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_wordDetails != null)
                      WordHeaderCard(
                        wordData: _wordDetails!,
                        contextSentence: _savedWord?.contextSentence,
                        savedWordIds: _savedWordIds,
                        savedWordCategories: _savedWordCategories,
                        onCategorySelected: (category) =>
                            _setStatus(_wordDetails!, category),
                        wordImageFuture: _wordImageFuture,
                      ),
                    const SizedBox(height: 24),
                    if (_wordDetails != null) ...[
                      _buildTabs(context),
                      const SizedBox(height: 16),
                      _buildTabContent(context, _wordDetails!),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isVerbWord = _isVerb(_wordDetails ?? {});
    final tabs = [
      (
        label: isVerbWord ? 'Conjugation' : 'Declension',
        icon: isVerbWord ? Icons.transform_rounded : Icons.table_chart_outlined,
        activeIcon: isVerbWord ? Icons.transform_rounded : Icons.table_chart_rounded,
      ),
      (
        label: 'Examples',
        icon: Icons.format_quote_outlined,
        activeIcon: Icons.format_quote_rounded,
      ),
      (
        label: 'Related',
        icon: Icons.hub_outlined,
        activeIcon: Icons.hub_rounded,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = _selectedTabIndex == index;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == tabs.length - 1 ? 0 : 4,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _selectedTabIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withValues(alpha: 0.4),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? tab.activeIcon : tab.icon,
                        size: 15,
                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(
      BuildContext context, Map<String, dynamic> wordData) {
    if (_selectedTabIndex == 1) {
      return _buildExamplesTab(context, wordData);
    }
    if (_selectedTabIndex == 2) {
      return _buildRelatedTab(context, wordData);
    }
    return _buildDeclensionTab(context, wordData);
  }

  bool _isVerb(Map<String, dynamic> wordData) {
    final pos = wordData['pos']?.toString().toLowerCase() ?? '';
    if (pos == 'verb' || pos == 'v' || pos == 'verbs') return true;
    final rawForms = wordData['forms'];
    if (rawForms is List) {
      for (final f in rawForms) {
        if (f is! Map) continue;
        final tags = (f['tags'] ?? '').toString().toLowerCase();
        if (tags.contains('first-person') ||
            tags.contains('second-person') ||
            tags.contains('preterite') ||
            tags.contains('participle')) {
          return true;
        }
      }
    }
    return false;
  }

  Widget _buildExamplesTab(
      BuildContext context, Map<String, dynamic> wordData) {
    final dictExamples = (wordData['examples'] as List?) ?? [];
    final colorScheme = Theme.of(context).colorScheme;
    final targetWord = wordData['word']?.toString() ?? widget.word;

    // Collect real-world encounters from articles, movies & books
    final encounters = <WordContextExample>[];
    if (_savedWord != null) {
      if (_savedWord!.contextExamples.isNotEmpty) {
        encounters.addAll(_savedWord!.contextExamples);
      } else if (_savedWord!.contextSentence != null && _savedWord!.contextSentence!.isNotEmpty) {
        encounters.add(
          WordContextExample(
            sentence: _savedWord!.contextSentence!,
            sourceTitle: _savedWord!.sourceTitle ?? 'Saved Context',
            sourceType: SavedWord.inferSourceType(_savedWord!.sourceTitle),
          ),
        );
      }
    }

    if (encounters.isEmpty && dictExamples.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.menu_book_outlined, size: 36, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                'No example sentences available.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🌟 Real-World Encounters Section (Articles, Movies & Books)
        if (encounters.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'REAL-WORLD ENCOUNTERS (${encounters.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Sentences gathered from your articles, movies and books',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                ...encounters.map((ex) {
                  IconData sourceIcon = Icons.article_rounded;
                  String sourceLabel = 'Article';
                  Color badgeColor = colorScheme.secondary;

                  if (ex.sourceType == 'video') {
                    sourceIcon = Icons.movie_rounded;
                    sourceLabel = 'Movie / Media';
                    badgeColor = Colors.purple;
                  } else if (ex.sourceType == 'book') {
                    sourceIcon = Icons.auto_stories_rounded;
                    sourceLabel = 'Book';
                    badgeColor = Colors.teal;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(sourceIcon, size: 12, color: badgeColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    sourceLabel,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ex.sourceTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _ttsService.speak(ex.sentence, lang: 'de-DE'),
                              icon: const Icon(Icons.volume_up_rounded, size: 18),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              tooltip: 'Listen to sentence',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildHighlightedSentence(context, ex.sentence, targetWord),
                        if (ex.translation != null && ex.translation!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            ex.translation!,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        // 📖 Reference Dictionary Examples Section
        if (dictExamples.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'DICTIONARY EXAMPLES (${dictExamples.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...dictExamples.map((ex) {
                  final de = ex['de']?.toString() ?? '';
                  final en = ex['en']?.toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHighlightedSentence(context, de, targetWord),
                              if (en != null && en.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  en,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _ttsService.speak(de, lang: 'de-DE'),
                          icon: const Icon(Icons.volume_up_rounded, size: 18),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: 'Listen to example',
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHighlightedSentence(
      BuildContext context, String sentence, String targetWord) {
    final colorScheme = Theme.of(context).colorScheme;
    if (targetWord.isEmpty) {
      return Text(
        sentence,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colorScheme.onSurface),
      );
    }

    final lowerSentence = sentence.toLowerCase();
    final lowerWord = targetWord.toLowerCase();
    final matchIndex = lowerSentence.indexOf(lowerWord);

    if (matchIndex == -1) {
      return Text(
        sentence,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colorScheme.onSurface),
      );
    }

    final before = sentence.substring(0, matchIndex);
    final matched = sentence.substring(matchIndex, matchIndex + targetWord.length);
    final after = sentence.substring(matchIndex + targetWord.length);

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
          color: colorScheme.onSurface,
          height: 1.4,
        ),
        children: [
          TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                matched,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  List<String> _parseTags(dynamic rawTags) {
    if (rawTags == null) return [];
    if (rawTags is List) {
      return rawTags
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (rawTags is String) {
      if (rawTags.contains(',')) {
        return rawTags
            .split(',')
            .map((e) => e.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      final trimmed = rawTags.trim();
      return trimmed.isNotEmpty ? [trimmed] : [];
    }
    return [rawTags.toString()];
  }

  Widget _buildDeclensionTab(
      BuildContext context, Map<String, dynamic> wordData) {
    final colorScheme = Theme.of(context).colorScheme;
    final rawForms = wordData['forms'];
    final forms = rawForms is List ? rawForms : <dynamic>[];

    if (forms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.table_chart_outlined, size: 36, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                'No inflection forms available.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.table_rows_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'FORMS & INFLECTIONS (${forms.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...forms.map((f) {
            if (f is! Map) return const SizedBox.shrink();
            final formStr = f['form']?.toString() ?? '';
            final tagList = _parseTags(f['tags']);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formStr,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (tagList.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: tagList.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _ttsService.speak(formStr, lang: 'de-DE'),
                    icon: const Icon(Icons.volume_up_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Listen',
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRelatedTab(
      BuildContext context, Map<String, dynamic> wordData) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'No related words available.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
