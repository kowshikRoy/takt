import 'package:flutter/material.dart';
import '../theme/books_modernist_style.dart';
import '../services/dictionary_service.dart';
import '../services/vocabulary_service.dart';
import '../services/tts_service.dart';
import '../models/saved_word.dart';
import '../widgets/word_header_card.dart';

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
      if (mounted) {
        setState(() {
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
    if (mounted) {
      setState(() {
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

  Future<void> _setStatus(
      Map<String, dynamic> wordData, VocabCategory category) async {
    final wordStr = wordData['word']?.toString() ?? widget.word;
    final wordId = wordStr.toLowerCase().trim();
    final currentCategory = _savedWordCategories[wordId];

    if (currentCategory == category) {
      await _vocabService.removeWord(wordId);
      setState(() {
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
        createdAt: DateTime.now(),
      );

      await _vocabService.upsertWord(saved);
      setState(() {
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
      isVerbWord ? 'Conjugation' : 'Declension',
      'Examples',
      'Related',
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isSelected = _selectedTabIndex == index;

          return GestureDetector(
            onTap: () => setState(() => _selectedTabIndex = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
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
    final forms = (wordData['forms'] as List?) ?? [];
    for (final f in forms) {
      if (f is! Map) continue;
      final tags = (f['tags'] ?? '').toString().toLowerCase();
      if (tags.contains('first-person') ||
          tags.contains('second-person') ||
          tags.contains('preterite') ||
          tags.contains('participle')) {
        return true;
      }
    }
    return false;
  }

  Widget _buildExamplesTab(
      BuildContext context, Map<String, dynamic> wordData) {
    final examples = (wordData['examples'] as List?) ?? [];
    final colorScheme = Theme.of(context).colorScheme;

    if (examples.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No example sentences available.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: examples.map((ex) {
          final de = ex['de']?.toString() ?? '';
          final en = ex['en']?.toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        de,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (en != null && en.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          en,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _ttsService.speak(de, lang: 'de-DE'),
                  icon: const Icon(Icons.volume_up_rounded, size: 20),
                  tooltip: 'Listen to example',
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeclensionTab(
      BuildContext context, Map<String, dynamic> wordData) {
    final colorScheme = Theme.of(context).colorScheme;
    final forms = (wordData['forms'] as List?) ?? [];

    if (forms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No inflection forms available.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: forms.map((f) {
          final formStr = f['form']?.toString() ?? '';
          final tags = (f['tags'] as List?)?.join(', ') ?? '';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  tags,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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
