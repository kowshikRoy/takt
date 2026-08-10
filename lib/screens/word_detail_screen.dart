import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/books_modernist_style.dart';
import '../services/dictionary_service.dart';
import '../services/vocabulary_service.dart';
import '../services/tts_service.dart';
import '../models/saved_word.dart';
import '../widgets/word_header_card.dart';
import '../widgets/word_edit_sheet.dart';
import '../widgets/vocab_status_pills.dart';
import '../widgets/interactive_german_text.dart';
import '../widgets/capped_width.dart';

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
          if (widget.wordData != null && widget.wordData!['context_matched_sense_index'] != null) {
            _wordDetails = {
              ...full,
              'context_matched_sense_index': widget.wordData!['context_matched_sense_index'],
            };
          } else {
            _wordDetails = full;
          }
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
    final rawWord = wordData['word']?.toString() ?? widget.word;
    final baseForm = (wordData['base_form'] as String?)?.trim();
    // Resolve lemma: If base_form is available, use it as the main headword
    final wordStr = (baseForm != null && baseForm.isNotEmpty && baseForm.toLowerCase() != rawWord.toLowerCase())
        ? baseForm
        : rawWord;
    final wordId = wordStr.toLowerCase().trim();
    final rawWordLower = rawWord.toLowerCase().trim();
    final widgetWordLower = widget.word.toLowerCase().trim();
    final currentCategory = _savedWordCategories[wordId] ??
        _savedWordCategories[rawWordLower] ??
        _savedWordCategories[widgetWordLower] ??
        _savedWord?.category;

    if (currentCategory == category ||
        (category == VocabCategory.reviewLater && currentCategory == VocabCategory.learning)) {
      await _vocabService.removeWord(_savedWord?.id ?? wordId);
      await _vocabService.removeWord(wordStr);
      await _vocabService.removeWord(rawWord);
      await _vocabService.removeWord(widget.word);
      setState(() {
        _savedWord = null;
        _savedWordIds.remove(wordId);
        _savedWordCategories.remove(wordId);
        _savedWordIds.remove(rawWordLower);
        _savedWordCategories.remove(rawWordLower);
        _savedWordIds.remove(widgetWordLower);
        _savedWordCategories.remove(widgetWordLower);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed "$wordStr" from saved vocabulary')),
        );
      }
    } else {
      final defs = (wordData['definitions'] as List?) ?? [];
      final primaryDef = defs.isNotEmpty ? defs.first.toString() : '';

      final saved = SavedWord(
        id: wordId,
        word: wordStr,
        baseForm: baseForm ?? wordStr,
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
        _savedWordIds.add(rawWordLower);
        _savedWordCategories[rawWordLower] = category;
        _savedWordIds.add(widgetWordLower);
        _savedWordCategories[widgetWordLower] = category;
      });
      if (mounted) {
        final label = category == VocabCategory.mastered ? 'Known' : 'Study Deck';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved "$wordStr" to $label')),
        );
      }
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
                child: CappedWidth(
                  maxWidth: 760,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_wordDetails != null)
                      WordHeaderCard(
                        wordData: _wordDetails!,
                        contextSentence: _savedWord?.contextSentence,
                        showStatusPills: true,
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

  bool _isAdjective(Map<String, dynamic> wordData) {
    final pos = wordData['pos']?.toString().toLowerCase() ?? '';
    if (pos == 'adj' || pos == 'adjective' || pos == 'adjectives') return true;
    final rawForms = wordData['forms'];
    if (rawForms is List) {
      for (final f in rawForms) {
        if (f is! Map) continue;
        final tags = (f['tags'] ?? '').toString().toLowerCase();
        if (tags.contains('comparative') || tags.contains('superlative') || tags.contains('predicative')) {
          return true;
        }
      }
    }
    return false;
  }

  Widget _buildExamplesTab(
      BuildContext context, Map<String, dynamic> wordData) {
    final rawDictExamples = (wordData['examples'] as List?) ?? [];
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

    // Deduplicate: Don't show user encounters / media transcripts under Dictionary Examples
    final encounterSentences = encounters.map((e) => e.sentence.trim().toLowerCase()).toSet();
    if (_savedWord?.contextSentence != null && _savedWord!.contextSentence!.isNotEmpty) {
      encounterSentences.add(_savedWord!.contextSentence!.trim().toLowerCase());
    }

    final dictExamples = rawDictExamples.where((ex) {
      final de = (ex is Map ? (ex['de'] ?? ex['sentence'] ?? '').toString() : '').trim().toLowerCase();
      if (de.isEmpty) return false;
      return !encounterSentences.contains(de);
    }).toList();

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
    return InteractiveGermanText(
      sentence,
      highlightWord: targetWord,
      sourceTitle: 'Dictionary Example',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
        height: 1.45,
      ),
      highlightStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: colorScheme.primary,
        height: 1.45,
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
      final trimmed = rawTags.trim();
      if (trimmed.isEmpty) return [];
      // The DB stores tags as a JSON array, e.g. '["masculine","nominative"]'.
      // Decode it properly rather than naively splitting on commas, which
      // leaves stray brackets/quotes in each piece.
      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        } catch (_) {
          // fall through to comma-split below
        }
      }
      if (trimmed.contains(',')) {
        return trimmed
            .split(',')
            .map((e) => e.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [trimmed];
    }
    return [rawTags.toString()];
  }

  String _findVerbForm(
    List<dynamic> forms,
    bool Function(String tags) condition, {
    String fallback = '-',
  }) {
    for (final f in forms) {
      if (f is! Map) continue;
      final form = (f['form'] ?? '').toString().trim();
      final tags = _parseTags(f['tags']).join(' ').toLowerCase();
      if (condition(tags) && form.isNotEmpty) {
        return form;
      }
    }
    return fallback;
  }

  String _getPresentFallback(String infinitive, int index) {
    String stem = infinitive;
    if (infinitive.endsWith('en')) {
      stem = infinitive.substring(0, infinitive.length - 2);
    } else if (infinitive.endsWith('n')) {
      stem = infinitive.substring(0, infinitive.length - 1);
    }
    switch (index) {
      case 0:
        return '${stem}e';
      case 1:
        return stem.endsWith('s') || stem.endsWith('z') || stem.endsWith('ß') || stem.endsWith('x')
            ? '${stem}t'
            : '${stem}st';
      case 2:
        return '${stem}t';
      case 3:
        return infinitive;
      case 4:
        return '${stem}t';
      case 5:
      default:
        return infinitive;
    }
  }

  String _getPastFallback(String infinitive, int index) {
    String stem = infinitive;
    if (infinitive.endsWith('en')) {
      stem = infinitive.substring(0, infinitive.length - 2);
    } else if (infinitive.endsWith('n')) {
      stem = infinitive.substring(0, infinitive.length - 1);
    }
    final suffix = (stem.endsWith('t') || stem.endsWith('d')) ? 'et' : 't';
    switch (index) {
      case 0:
        return '$stem${suffix}e';
      case 1:
        return '$stem${suffix}est';
      case 2:
        return '$stem${suffix}e';
      case 3:
        return '$stem${suffix}en';
      case 4:
        return '$stem${suffix}et';
      case 5:
      default:
        return '$stem${suffix}en';
    }
  }

  Widget _buildMiniVerbStat(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    bool isSemiBold = false,
    bool isMuted = false,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      child: Text(
        text,
        maxLines: 2,
        softWrap: true,
        style: TextStyle(
          fontSize: isHeader ? 9.5 : 11.5,
          fontWeight: isHeader
              ? FontWeight.bold
              : (isBold
                  ? FontWeight.bold
                  : (isSemiBold ? FontWeight.w600 : FontWeight.normal)),
          color: isHeader
              ? colorScheme.primary
              : (isMuted
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface),
        ),
      ),
    );
  }

  ({String label, Color color, Color bgColor, Color borderColor})? _getVerbRegularity({
    required String infinitive,
    required List<dynamic> forms,
    String? verbClass,
  }) {
    final lowerInf = infinitive.toLowerCase().trim();

    // 1. Modals & Core Auxiliaries
    const modals = {
      'können',
      'müssen',
      'dürfen',
      'sollen',
      'wollen',
      'mögen',
      'möchte',
      'wissen',
    };
    if (modals.contains(lowerInf)) {
      return (
        label: 'Modal Verb',
        color: const Color(0xFF8E24AA),
        bgColor: const Color(0xFF8E24AA).withValues(alpha: 0.12),
        borderColor: const Color(0xFF8E24AA).withValues(alpha: 0.35),
      );
    }
    if (lowerInf == 'sein' || lowerInf == 'werden' || lowerInf == 'haben') {
      return (
        label: 'Irregular (Auxiliary)',
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFD97706).withValues(alpha: 0.12),
        borderColor: const Color(0xFFD97706).withValues(alpha: 0.35),
      );
    }

    // 2. Direct verb_class from database
    final vClass = verbClass?.toLowerCase().trim();
    if (vClass == 'weak' || vClass == 'regular') {
      return (
        label: 'Regular (Schwach)',
        color: const Color(0xFF16A34A),
        bgColor: const Color(0xFF16A34A).withValues(alpha: 0.12),
        borderColor: const Color(0xFF16A34A).withValues(alpha: 0.35),
      );
    }
    if (vClass == 'strong') {
      return (
        label: 'Irregular (Stark)',
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFD97706).withValues(alpha: 0.12),
        borderColor: const Color(0xFFD97706).withValues(alpha: 0.35),
      );
    }
    if (vClass == 'mixed' || vClass == 'irregular') {
      return (
        label: 'Irregular (Gemischt)',
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFD97706).withValues(alpha: 0.12),
        borderColor: const Color(0xFFD97706).withValues(alpha: 0.35),
      );
    }

    // 3. Check explicit forms tags if present in DB
    for (final f in forms) {
      if (f is! Map) continue;
      final formText = (f['form'] ?? '').toString().toLowerCase().trim();
      final tags = _parseTags(f['tags']).join(' ').toLowerCase();
      if (formText.contains('weak') || tags.contains('weak')) {
        return (
          label: 'Regular (Schwach)',
          color: const Color(0xFF16A34A),
          bgColor: const Color(0xFF16A34A).withValues(alpha: 0.12),
          borderColor: const Color(0xFF16A34A).withValues(alpha: 0.35),
        );
      }
      if (formText.contains('strong') || tags.contains('strong')) {
        return (
          label: 'Irregular (Stark)',
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFD97706).withValues(alpha: 0.12),
          borderColor: const Color(0xFFD97706).withValues(alpha: 0.35),
        );
      }
      if (formText.contains('irregular') || tags.contains('irregular')) {
        return (
          label: 'Irregular (Stark)',
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFD97706).withValues(alpha: 0.12),
          borderColor: const Color(0xFFD97706).withValues(alpha: 0.35),
        );
      }
    }

    return null;
  }

  Widget _buildVerbConjugationTable(
    BuildContext context,
    Map<String, dynamic> wordData,
  ) {
    final forms = (wordData['forms'] as List?) ?? [];
    final colorScheme = Theme.of(context).colorScheme;
    final baseForm = wordData['base_form']?.toString().trim();
    final infinitive = (baseForm != null && baseForm.isNotEmpty)
        ? baseForm
        : (wordData['word']?.toString() ?? '');

    // Determine auxiliary verb
    String aux = 'haben';
    for (final f in forms) {
      if (f is! Map) continue;
      final form = (f['form'] ?? '').toString().trim().toLowerCase();
      final tags = _parseTags(f['tags']).join(' ').toLowerCase();
      if (tags.contains('auxiliary')) {
        if (form == 'sein' || form == 'haben') {
          aux = form;
          break;
        }
      }
    }

    // Determine participle II
    String part2 = _findVerbForm(
      forms,
      (t) =>
          t.contains('participle') &&
          (t.contains('past') || t.contains('perfect')),
      fallback: _findVerbForm(
        forms,
        (t) => t.contains('participle'),
        fallback: '-',
      ),
    );
    if (part2 == '-') {
      String stem = infinitive;
      if (infinitive.endsWith('en')) {
        stem = infinitive.substring(0, infinitive.length - 2);
      } else if (infinitive.endsWith('n')) {
        stem = infinitive.substring(0, infinitive.length - 1);
      }
      part2 = 'ge${stem}t';
    }

    final pronouns = ['ich', 'du', 'er/sie/es', 'wir', 'ihr', 'sie/Sie'];

    bool isPastTag(String t) =>
        t.contains('preterite') ||
        t.contains('past') && !t.contains('participle');

    final presentForms = List.generate(6, (index) {
      bool cond(String t) {
        if (!t.contains('present') || t.contains('subjunctive')) return false;
        switch (index) {
          case 0:
            return t.contains('singular') && t.contains('first-person');
          case 1:
            return t.contains('singular') && t.contains('second-person');
          case 2:
            return t.contains('singular') && t.contains('third-person');
          case 3:
            return t.contains('plural') && t.contains('first-person');
          case 4:
            return t.contains('plural') && t.contains('second-person');
          case 5:
            return t.contains('plural') && t.contains('third-person');
          default:
            return false;
        }
      }

      final found = _findVerbForm(forms, cond, fallback: '-');
      return found != '-' ? found : _getPresentFallback(infinitive, index);
    });

    final pastForms = List.generate(6, (index) {
      bool cond(String t) {
        if (!isPastTag(t) || t.contains('subjunctive')) return false;
        switch (index) {
          case 0:
            return t.contains('singular') && t.contains('first-person');
          case 1:
            return t.contains('singular') && t.contains('second-person');
          case 2:
            return t.contains('singular') && t.contains('third-person');
          case 3:
            return t.contains('plural') && t.contains('first-person');
          case 4:
            return t.contains('plural') && t.contains('second-person');
          case 5:
            return t.contains('plural') && t.contains('third-person');
          default:
            return false;
        }
      }

      final found = _findVerbForm(forms, cond, fallback: '-');
      return found != '-' ? found : _getPastFallback(infinitive, index);
    });

    final auxConjugations = aux == 'sein'
        ? ['bin', 'bist', 'ist', 'sind', 'seid', 'sind']
        : ['habe', 'hast', 'hat', 'haben', 'habt', 'haben'];

    final perfectForms = auxConjugations.map((a) => '$a $part2').toList();

    final regularity = _getVerbRegularity(
      infinitive: infinitive,
      forms: forms,
      verbClass: wordData['verb_class']?.toString(),
    );

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
              Icon(
                Icons.transform_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'VERB CONJUGATION TABLE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: colorScheme.primary,
                ),
              ),
              if (regularity != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: regularity.bgColor,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: regularity.borderColor, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: regularity.color,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        regularity.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: regularity.color,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniVerbStat(
                  context,
                  label: 'Infinitive',
                  value: infinitive,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniVerbStat(
                  context,
                  label: 'Auxiliary',
                  value: aux,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniVerbStat(
                  context,
                  label: 'Partizip II',
                  value: part2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: Table(
              border: TableBorder.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 0.8,
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(0.78),
                1: FlexColumnWidth(1.02),
                2: FlexColumnWidth(1.25),
                3: FlexColumnWidth(1.35),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                  ),
                  children: [
                    _buildTableCell('PRONOUN', isHeader: true, colorScheme: colorScheme),
                    _buildTableCell('PRÄSENS', isHeader: true, colorScheme: colorScheme),
                    _buildTableCell('PAST', isHeader: true, colorScheme: colorScheme),
                    _buildTableCell('PERFECT', isHeader: true, colorScheme: colorScheme),
                  ],
                ),
                ...List.generate(6, (index) {
                  final isAlt = index % 2 == 1;
                  return TableRow(
                    decoration: BoxDecoration(
                      color: isAlt
                          ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                    children: [
                      _buildTableCell(pronouns[index], isBold: true, colorScheme: colorScheme),
                      _buildTableCell(presentForms[index], isSemiBold: true, colorScheme: colorScheme),
                      _buildTableCell(pastForms[index], isSemiBold: true, colorScheme: colorScheme),
                      _buildTableCell(perfectForms[index], isMuted: true, colorScheme: colorScheme),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNounDeclensionTable(
    BuildContext context,
    Map<String, dynamic> wordData,
  ) {
    final forms = (wordData['forms'] as List?) ?? [];
    final colorScheme = Theme.of(context).colorScheme;
    final word = wordData['word']?.toString() ?? '';
    final rawGender = wordData['gender']?.toString().toLowerCase() ?? '';
    final gender = rawGender.startsWith('m')
        ? 'm'
        : (rawGender.startsWith('f') ? 'f' : (rawGender.startsWith('n') ? 'n' : ''));

    final plural = wordData['plural']?.toString() ??
        _findVerbForm(
          forms,
          (t) => t.contains('plural') && t.contains('nominative'),
          fallback: _findVerbForm(forms, (t) => t.contains('plural'), fallback: '$word(e)'),
        );
    final cleanPlural = plural.toLowerCase().startsWith('die ')
        ? plural.substring(4)
        : plural;

    final cases = ['Nominativ', 'Akkusativ', 'Dativ', 'Genitiv'];
    final singularArticles = gender == 'm'
        ? ['der', 'den', 'dem', 'des']
        : (gender == 'f'
            ? ['die', 'die', 'der', 'der']
            : (gender == 'n' ? ['das', 'das', 'dem', 'des'] : ['-', '-', '-', '-']));

    final pluralArticles = ['die', 'die', 'den', 'der'];

    final singularForms = List.generate(4, (i) {
      if (gender == 'm' || gender == 'n') {
        if (i == 3) return '${singularArticles[i]} $word(e)s';
        if (i == 2) return '${singularArticles[i]} $word';
      }
      return '${singularArticles[i]} $word';
    });

    final pluralForms = List.generate(4, (i) {
      if (i == 2) {
        final dativePlural = cleanPlural.endsWith('n') || cleanPlural.endsWith('s')
            ? cleanPlural
            : '${cleanPlural}n';
        return '${pluralArticles[i]} $dativePlural';
      }
      return '${pluralArticles[i]} $cleanPlural';
    });

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
              Icon(Icons.table_chart_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'NOUN DECLENSION TABLE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: Table(
              border: TableBorder.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 0.8,
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(1.1),
                1: FlexColumnWidth(1.4),
                2: FlexColumnWidth(1.4),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                  ),
                  children: [
                    _buildTableCell('CASE', isHeader: true, colorScheme: colorScheme),
                    _buildTableCell('SINGULAR', isHeader: true, colorScheme: colorScheme),
                    _buildTableCell('PLURAL', isHeader: true, colorScheme: colorScheme),
                  ],
                ),
                ...List.generate(4, (index) {
                  final isAlt = index % 2 == 1;
                  return TableRow(
                    decoration: BoxDecoration(
                      color: isAlt
                          ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                    children: [
                      _buildTableCell(cases[index], isBold: true, colorScheme: colorScheme),
                      _buildTableCell(singularForms[index], isSemiBold: true, colorScheme: colorScheme),
                      _buildTableCell(pluralForms[index], isSemiBold: true, colorScheme: colorScheme),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjectiveDeclensionTable(
    BuildContext context,
    Map<String, dynamic> wordData,
  ) {
    final forms = (wordData['forms'] as List?) ?? [];
    final colorScheme = Theme.of(context).colorScheme;
    final baseForm = wordData['base_form']?.toString().trim();
    final positive = (baseForm != null && baseForm.isNotEmpty)
        ? baseForm
        : (wordData['word']?.toString() ?? '');

    bool isPositiveTag(String t) => !t.contains('comparative') && !t.contains('superlative');

    String declined(String genderTag, {bool plural = false, required String caseTag}) {
      return _findVerbForm(
        forms,
        (t) =>
            isPositiveTag(t) &&
            t.contains(caseTag) &&
            (plural ? t.contains('plural') : (t.contains(genderTag) && t.contains('singular'))),
        fallback: '-',
      );
    }

    final cases = ['Nominativ', 'Akkusativ', 'Dativ', 'Genitiv'];
    final caseTags = ['nominative', 'accusative', 'dative', 'genitive'];
    final genderColumns = ['masculine', 'feminine', 'neuter'];

    // Comparative/superlative predicative forms (the plain, undeclined forms
    // used after "sein"/"werden", e.g. "Er ist glühender/am glühendsten").
    final comparative = _findVerbForm(
      forms,
      (t) => t.contains('comparative') && t.contains('predicative'),
      fallback: _findVerbForm(forms, (t) => t.contains('comparative') && !t.contains('plural'), fallback: '-'),
    );
    final superlative = _findVerbForm(
      forms,
      (t) => t.contains('superlative') && t.contains('predicative'),
      fallback: '-',
    );

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
              Icon(Icons.table_chart_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'ADJECTIVE DECLENSION TABLE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniVerbStat(context, label: 'Positive', value: positive),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniVerbStat(context, label: 'Comparative', value: comparative),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniVerbStat(
                  context,
                  label: 'Superlative',
                  value: superlative != '-' ? 'am $superlative' : '-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'STRONG/ATTRIBUTIVE DECLENSION (POSITIVE)',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: Table(
              border: TableBorder.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 0.8,
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(0.95),
                1: FlexColumnWidth(1.15),
                2: FlexColumnWidth(1.1),
                3: FlexColumnWidth(1.15),
                4: FlexColumnWidth(1.0),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                  ),
                  children: [
                    _buildTableCell('CASE', isHeader: true, colorScheme: colorScheme),
                    _buildTableCell('MASC.', isHeader: true, colorScheme: colorScheme),
                    _buildTableCell('FEM.', isHeader: true, colorScheme: colorScheme),
                    _buildTableCell('NEUT.', isHeader: true, colorScheme: colorScheme),
                    _buildTableCell('PLURAL', isHeader: true, colorScheme: colorScheme),
                  ],
                ),
                ...List.generate(4, (index) {
                  final isAlt = index % 2 == 1;
                  final caseTag = caseTags[index];
                  return TableRow(
                    decoration: BoxDecoration(
                      color: isAlt
                          ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                    children: [
                      _buildTableCell(cases[index], isBold: true, colorScheme: colorScheme),
                      ...genderColumns.map((g) => _buildTableCell(
                            declined(g, caseTag: caseTag),
                            isSemiBold: true,
                            colorScheme: colorScheme,
                          )),
                      _buildTableCell(
                        declined('', plural: true, caseTag: caseTag),
                        isSemiBold: true,
                        colorScheme: colorScheme,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeclensionTab(
      BuildContext context, Map<String, dynamic> wordData) {
    if (_isVerb(wordData)) {
      return _buildVerbConjugationTable(context, wordData);
    }
    if (_isAdjective(wordData)) {
      return _buildAdjectiveDeclensionTable(context, wordData);
    }
    final pos = wordData['pos']?.toString().toLowerCase() ?? '';
    final gender = wordData['gender']?.toString() ?? '';
    if (pos == 'noun' || pos == 'n' || pos == 'nouns' || gender.isNotEmpty) {
      return _buildNounDeclensionTable(context, wordData);
    }

    final rawForms = wordData['forms'];
    final forms = rawForms is List ? rawForms : <dynamic>[];

    if (forms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.table_chart_outlined, size: 36, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                'No inflection forms available.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
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
