import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../services/dictionary_service.dart';
import '../services/vocabulary_service.dart';
import '../services/tts_service.dart';
import '../models/saved_word.dart';
import '../theme/breakpoints.dart';
import '../theme/books_modernist_style.dart';
import '../services/discovery_service.dart';
import '../widgets/vocab_status_pills.dart';
import '../widgets/word_edit_sheet.dart';
import 'word_detail_screen.dart';

class DictionaryScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final Map<String, dynamic>? initialWordData;
  final VoidCallback? onBackToHome;

  const DictionaryScreen({
    super.key,
    this.initialSearchQuery,
    this.initialWordData,
    this.onBackToHome,
  });

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DictionaryService _dictionaryService = DictionaryService();
  final VocabularyService _vocabService = VocabularyService();
  final TtsService _ttsService = TtsService();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _masterDiscoverWords = DiscoveryService().pool;
  List<Map<String, dynamic>> _recentWords = [];
  Map<String, dynamic>? _selectedWord;
  Future<String?>? _wordImageFuture;

  bool _isSearching = false;
  bool _isLoadingDiscover = DiscoveryService().pool.isEmpty;
  String _selectedPosFilter = 'all'; // 'all', 'noun', 'verb', 'adj', 'saved'
  int _selectedTabIndex = 1; // Default to 1: Examples
  Set<String> _savedWordIds = {};
  Map<String, VocabCategory> _savedWordCategories = {};
  List<SavedWord> _rawSavedWords = [];

  List<Map<String, dynamic>> get _filteredDiscoverWords {
    if (_selectedPosFilter == 'saved') {
      final masterSaved = _masterDiscoverWords.where((w) {
        final wordStr = (w['word']?.toString() ?? '').toLowerCase().trim();
        final idStr = (w['id']?.toString() ?? '').toLowerCase().trim();
        return _savedWordIds.contains(wordStr) || _savedWordIds.contains(idStr);
      }).toList();

      final seenWordIds = masterSaved.map((w) {
        final wordStr = (w['word']?.toString() ?? '').toLowerCase().trim();
        final idStr = (w['id']?.toString() ?? '').toLowerCase().trim();
        return idStr.isNotEmpty ? idStr : wordStr;
      }).toSet();

      final customSaved = <Map<String, dynamic>>[];
      for (final sw in _rawSavedWords) {
        final swId = sw.id.toLowerCase().trim();
        final swWord = sw.word.toLowerCase().trim();
        if (!seenWordIds.contains(swId) && !seenWordIds.contains(swWord)) {
          customSaved.add({
            'id': sw.id,
            'word': sw.word,
            'gender': sw.gender,
            'definition': sw.primaryDefinition,
            'definitions': sw.definitions.isNotEmpty ? sw.definitions : [sw.primaryDefinition],
            'pos': sw.pos,
            'ipa': sw.ipa,
          });
        }
      }

      return [...masterSaved, ...customSaved];
    }
    if (_selectedPosFilter == 'mastered') {
      return _masterDiscoverWords.where((w) {
        final wordStr = (w['word']?.toString() ?? '').toLowerCase().trim();
        final idStr = (w['id']?.toString() ?? '').toLowerCase().trim();
        return _savedWordCategories[wordStr] == VocabCategory.mastered ||
            _savedWordCategories[idStr] == VocabCategory.mastered;
      }).toList();
    }
    if (_selectedPosFilter == 'all') {
      return _masterDiscoverWords;
    }
    return _masterDiscoverWords
        .where(
          (w) =>
              (w['pos']?.toString().toLowerCase() ?? '') ==
              _selectedPosFilter.toLowerCase(),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadDiscoverWords();
    _loadSavedWordStatus();

    if (widget.initialWordData != null) {
      _selectedWord = Map<String, dynamic>.from(widget.initialWordData!);
      final wStr = _selectedWord!['word']?.toString() ?? '';
      if (wStr.isNotEmpty) {
        _searchController.text = wStr;
        _wordImageFuture = _dictionaryService.getWordImageUrl(wStr);
        _isSearching = true;
      }
    } else if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!;
      _selectedWord = {
        'word': widget.initialSearchQuery!,
        'pos': '',
        'gender': '',
        'definitions': [],
      };
      _wordImageFuture =
          _dictionaryService.getWordImageUrl(widget.initialSearchQuery!);
      _isSearching = true;
    }

    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.isNotEmpty) {
      _performInitialDirectLookup(widget.initialSearchQuery!);
    }
  }

  Future<void> _performInitialDirectLookup(String word) async {
    final fullWord = await _dictionaryService.lookupWord(word);
    if (mounted && fullWord != null) {
      setState(() {
        _selectedWord = fullWord;
        _wordImageFuture =
            _dictionaryService.getWordImageUrl(fullWord['word'] ?? word);
      });
    } else if (mounted && _selectedWord == null) {
      _onSearchChanged(word);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedWordStatus() async {
    try {
      final saved = await _vocabService.getSavedWords();
      if (mounted) {
        setState(() {
          _rawSavedWords = saved;
          _savedWordIds = saved.map((w) => w.id.toLowerCase().trim()).toSet();
          _savedWordCategories = {
            for (var w in saved) w.id.toLowerCase().trim(): w.category,
          };
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDiscoverWords({bool forceRefresh = false}) async {
    final discovery = DiscoveryService();
    if (discovery.pool.isNotEmpty && !forceRefresh) {
      if (mounted) {
        setState(() {
          _masterDiscoverWords = discovery.pool;
          _isLoadingDiscover = false;
        });
      }
      return;
    }

    if (_masterDiscoverWords.isEmpty) {
      setState(() => _isLoadingDiscover = true);
    }

    if (forceRefresh) {
      await discovery.discoverMore(limit: 20);
    } else {
      await discovery.loadPool();
    }
    if (mounted) {
      setState(() {
        _masterDiscoverWords = discovery.pool;
        _isLoadingDiscover = false;
      });
    }
  }

  void _onSearchChanged(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await _dictionaryService.search(cleanQuery);

    if (mounted) {
      List<Map<String, dynamic>> filtered;
      if (_selectedPosFilter == 'all') {
        filtered = results;
      } else if (_selectedPosFilter == 'saved') {
        filtered = results.where((r) {
          final wordStr = (r['word']?.toString() ?? '').toLowerCase().trim();
          final idStr = (r['id']?.toString() ?? '').toLowerCase().trim();
          return _savedWordIds.contains(wordStr) || _savedWordIds.contains(idStr);
        }).toList();
      } else {
        filtered = results.where((r) {
          final rPos = DictionaryService.normalizePos(r['pos']?.toString());
          return rPos == _selectedPosFilter || (r['pos']?.toString().toLowerCase() == _selectedPosFilter);
        }).toList();
      }
      setState(() {
        _searchResults = filtered;
      });
    }
  }

  void _onResultSelected(Map<String, dynamic> result) async {
    final rawId = result['id'];
    final intId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final resultWord = result['word']?.toString() ?? '';
    var fullWord = intId != null ? await _dictionaryService.getWordDetails(intId) : null;
    fullWord ??= await _dictionaryService.lookupWord(resultWord);
    fullWord ??= result;

    if (mounted) {
      final selected = fullWord;
      final wordStr = selected['word']?.toString() ?? resultWord;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WordDetailScreen(
            word: wordStr,
            wordData: selected,
          ),
        ),
      );
    }
  }

  bool _handleBack() {
    if ((widget.initialSearchQuery != null || widget.initialWordData != null) &&
        Navigator.canPop(context)) {
      Navigator.pop(context);
      return true;
    }
    if (_selectedWord != null) {
      setState(() {
        _selectedWord = null;
        _wordImageFuture = null;
      });
      return true;
    }
    if (_isSearching || _searchController.text.isNotEmpty) {
      setState(() {
        _searchController.clear();
        _isSearching = false;
        _searchResults.clear();
      });
      return true;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return true;
    }
    if (widget.onBackToHome != null) {
      widget.onBackToHome!();
      return true;
    }
    return false;
  }

  Future<void> _setStatus(
    Map<String, dynamic> wordData,
    VocabCategory targetCategory,
  ) async {
    final wordStr = wordData['word'].toString();
    final wordId = wordStr.toLowerCase().trim();
    final currentCat = _savedWordCategories[wordId];

    if (currentCat == targetCategory) {
      await _vocabService.removeWord(wordId);
      setState(() {
        _savedWordIds.remove(wordId);
        _savedWordCategories.remove(wordId);
        _rawSavedWords.removeWhere((w) => w.id.toLowerCase().trim() == wordId || w.word.toLowerCase().trim() == wordId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed "$wordStr" from list')),
        );
      }
      return;
    }

    final defs = wordData['definitions'] as List?;
    final primaryDef = (defs != null && defs.isNotEmpty)
        ? defs.first.toString()
        : '';
    final existingWord = await _vocabService.getSavedWord(wordId);
    final saved = SavedWord(
      id: wordId,
      word: wordStr,
      gender: wordData['gender']?.toString(),
      ipa: wordData['ipa']?.toString(),
      primaryDefinition: primaryDef,
      category: targetCategory,
      interval: existingWord?.interval ?? 0,
      easeFactor: existingWord?.easeFactor ?? 2.5,
      repetitions: existingWord?.repetitions ?? 0,
      dueDate: existingWord?.dueDate,
      createdAt: existingWord?.createdAt,
    );
    await _vocabService.upsertWord(saved);
    setState(() {
      _savedWordIds.add(wordId);
      _savedWordCategories[wordId] = targetCategory;
      _rawSavedWords.removeWhere((w) => w.id.toLowerCase().trim() == wordId || w.word.toLowerCase().trim() == wordId);
      _rawSavedWords.add(saved);
    });
    if (mounted) {
      final label =
          targetCategory == VocabCategory.mastered
              ? 'Mastered'
              : 'Learning Deck';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked "$wordStr" as $label! 🎉'),
          backgroundColor:
              targetCategory == VocabCategory.mastered
                  ? Colors.amber.shade700
                  : Colors.green,
        ),
      );
    }
  }

  Future<void> _toggleSaveWord(Map<String, dynamic> wordData) async {
    await _setStatus(wordData, VocabCategory.learning);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = WindowClass.of(context).isAtLeastExpanded;
    final bool isDirectLookup =
        widget.initialSearchQuery != null || widget.initialWordData != null;
    final bool canPopNormally = Navigator.canPop(context) &&
        (isDirectLookup ||
            (_selectedWord == null &&
                !_isSearching &&
                _searchController.text.isEmpty));

    return PopScope(
      canPop: canPopNormally,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: isDesktop
              ? _buildDesktopMasterDetailLayout(context)
              : _buildMobileLayout(context),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createNewWord,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Word'),
        ),
      ),
    );
  }

  Future<void> _createNewWord() async {
    final savedWord = await WordEditSheet.show(context, isNew: true);
    if (savedWord != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WordDetailScreen(word: savedWord),
        ),
      );
    }
  }

  Widget _buildDesktopMasterDetailLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Left Master Pane (Search, Filters & Word Feed)
        SizedBox(
          width: 380,
          child: Column(
            children: [
              _buildHeader(context, showBackButton: false),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  children: [
                    _buildSearchBar(context),
                    const SizedBox(height: 10),
                    _buildFilterPills(context),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child:
                      _isSearching &&
                          _searchController.text.isNotEmpty &&
                          _searchResults.isNotEmpty
                      ? _buildSearchResultsList(context)
                      : _buildDiscoverSection(context),
                ),
              ),
            ],
          ),
        ),

        VerticalDivider(
          width: 1,
          thickness: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),

        // Right Detail Pane
        Expanded(
          child: _selectedWord != null
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRecentWordsBar(context),
                          const SizedBox(height: 16),
                          _buildMainCard(context, _selectedWord!),
                          const SizedBox(height: 24),
                          _buildTabs(context),
                          const SizedBox(height: 16),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _buildTabContent(context, _selectedWord!),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 64,
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select a Word to View Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose from the top frequency words or search any German term.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _buildHeader(
          context,
          showBackButton:
              _selectedWord != null ||
              _isSearching ||
              _searchController.text.isNotEmpty,
        ),
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedWord == null) ...[
                      _buildSearchBar(context),
                      const SizedBox(height: 12),
                      _buildFilterPills(context),
                      const SizedBox(height: 20),
                      _buildDiscoverSection(context),
                    ] else ...[
                      _buildRecentWordsBar(context),
                      const SizedBox(height: 14),
                      _buildMainCard(context, _selectedWord!),
                      const SizedBox(height: 20),
                      _buildTabs(context),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 220),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _buildTabContent(context, _selectedWord!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Instant Search Overlay on Mobile
              if (_isSearching &&
                  _searchResults.isNotEmpty &&
                  _selectedWord == null)
                Positioned(
                  top: 60,
                  left: 16,
                  right: 16,
                  child: Material(
                    color: Theme.of(context).cardColor,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 320),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: _buildSearchResultsList(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, {bool showBackButton = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          if (showBackButton) ...[
            IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: colorScheme.onSurface,
              ),
              tooltip: 'Back',
              onPressed: () => _handleBack(),
            ),
            const SizedBox(width: 4),
          ] else if (Navigator.canPop(context)) ...[
            IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: colorScheme.onSurface,
              ),
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'German Dictionary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '50,000+ Words • Frequency Indexed',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _searchResults.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        itemBuilder: (context, index) {
          final item = _searchResults[index];
          final word = item['word'] ?? '';
          final pos = item['pos'] ?? '';
          final gender = item['gender']?.toString();
          final freq = item['freq_rank'];

          Color dotColor = colorScheme.primary;
          if (gender == 'm' || gender == 'masculine')
            dotColor = AppTheme.genderMasc;
          if (gender == 'f' || gender == 'feminine')
            dotColor = AppTheme.genderFem;
          if (gender == 'n' || gender == 'neuter')
            dotColor = AppTheme.genderNeu;

          final isSelected = _selectedWord?['id'] == item['id'];

          return ListTile(
            selected: isSelected,
            selectedTileColor: colorScheme.primaryContainer.withValues(
              alpha: 0.4,
            ),
            leading: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            title: Row(
              children: [
                Text(
                  word,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                if (pos.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      pos.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: null,
            onTap: () => _onResultSelected(item),
          );
        },
      ),
    ));
  }

  Widget _buildRecentWordsBar(BuildContext context) {
    if (_recentWords.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              'Recently Viewed',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recentWords.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = _recentWords[index];
              final word = item['word']?.toString() ?? '';
              final gender = item['gender']?.toString();
              final isSelected = _selectedWord?['id'] == item['id'];

              Color dotColor = colorScheme.primary;
              if (gender == 'm' || gender == 'masculine')
                dotColor = AppTheme.genderMasc;
              if (gender == 'f' || gender == 'feminine')
                dotColor = AppTheme.genderFem;
              if (gender == 'n' || gender == 'neuter')
                dotColor = AppTheme.genderNeu;

              return InkWell(
                onTap: () => _onResultSelected(item),
                borderRadius: BorderRadius.circular(4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        word,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        onSubmitted: (query) {
          if (_searchResults.isNotEmpty) {
            _onResultSelected(_searchResults.first);
          } else if (query.trim().isNotEmpty) {
            _onSearchChanged(query);
          }
        },
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search_rounded, color: colorScheme.primary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _isSearching = false;
                      _searchResults.clear();
                      _selectedWord = null;
                      _wordImageFuture = null;
                    });
                  },
                )
              : null,
          hintText: 'Search German word or definition...',
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildFilterPills(BuildContext context) {
    final filters = [
      {'id': 'all', 'label': 'All'},
      {'id': 'noun', 'label': 'Nouns'},
      {'id': 'verb', 'label': 'Verbs'},
      {'id': 'adj', 'label': 'Adjectives'},
      {'id': 'saved', 'label': 'Saved (${_savedWordIds.length})'},
    ];

    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...filters.map((f) {
              final isSelected = _selectedPosFilter == f['id'];
              final isSavedChip = f['id'] == 'saved';
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  showCheckmark: false,
                  avatar: isSavedChip
                      ? Icon(
                          Icons.bookmark_rounded,
                          size: 13,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.primary,
                        )
                      : null,
                  label: Text(
                    f['label']!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : (isSavedChip
                              ? colorScheme.primary
                              : colorScheme.onSurface),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: colorScheme.primary,
                  backgroundColor: isSavedChip && !isSelected
                      ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                      : colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    side: isSavedChip && !isSelected
                        ? BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.5),
                            width: 0.8,
                          )
                        : BorderSide.none,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedPosFilter = f['id']!;
                      });
                      if (_searchController.text.isNotEmpty) {
                        _onSearchChanged(_searchController.text);
                      }
                    }
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showMyDeckDialog(BuildContext context) async {
    final allWords = await _vocabService.getSavedWords();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _SavedVocabularySheet(
          initialWords: allWords,
          onWordSelected: (savedWord) async {
            Navigator.pop(ctx);
            final fullWord = await _dictionaryService.lookupWord(savedWord.word);
            if (mounted && fullWord != null) {
              _onResultSelected(fullWord);
            } else {
              _searchController.text = savedWord.word;
              _onSearchChanged(savedWord.word);
            }
          },
          onWordDeleted: (wordId) async {
            await _vocabService.removeWord(wordId);
            _loadSavedWordStatus();
          },
          onCategoryChanged: (savedWord, newCategory) async {
            await _setStatus({
              'word': savedWord.word,
              'gender': savedWord.gender,
              'definitions': [savedWord.primaryDefinition],
            }, newCategory);
            _loadSavedWordStatus();
          },
        );
      },
    );
  }

  Widget _buildDiscoverSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayWords = _filteredDiscoverWords;

    if (_isLoadingDiscover) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (displayWords.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          _selectedPosFilter == 'saved'
              ? 'No saved words yet.'
              : 'No matching vocabulary entries found.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    String sectionTitle = 'Explore Top Frequency Words';
    if (_selectedPosFilter == 'saved') {
      sectionTitle = 'Saved Vocabulary Words';
    } else if (_selectedPosFilter == 'noun') {
      sectionTitle = 'Explore Top Nouns';
    } else if (_selectedPosFilter == 'verb') {
      sectionTitle = 'Explore Top Verbs';
    } else if (_selectedPosFilter == 'adj') {
      sectionTitle = 'Explore Top Adjectives';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                sectionTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (_selectedPosFilter == 'saved' && displayWords.isNotEmpty) ...[
              TextButton.icon(
                onPressed: () => _showMyDeckDialog(context),
                icon: const Icon(Icons.style_rounded, size: 16),
                label: const Text('Practice', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              '${displayWords.length} Words',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 280,
            childAspectRatio: 1.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: displayWords.length,
          itemBuilder: (context, index) {
            final item = displayWords[index];
            final word = item['word']?.toString() ?? '';
            final wordStr = word.toLowerCase().trim();
            final wordId = (item['id']?.toString() ?? '').toLowerCase().trim();
            final category =
                _savedWordCategories[wordStr] ?? _savedWordCategories[wordId];
            final gender = item['gender']?.toString();
            final def = item['definition']?.toString() ?? '';
            String article = '';
            Color genderColor = colorScheme.primary;
            final g = gender?.toLowerCase();
            if (g == 'm' || g == 'masc' || g == 'masculine') {
              article = 'der';
              genderColor = AppTheme.genderMasc;
            } else if (g == 'f' || g == 'fem' || g == 'feminine') {
              article = 'die';
              genderColor = AppTheme.genderFem;
            } else if (g == 'n' || g == 'neu' || g == 'neuter') {
              article = 'das';
              genderColor = AppTheme.genderNeu;
            }

            final isSaved = category == VocabCategory.learning ||
                category == VocabCategory.mastered ||
                _savedWordIds.contains(wordStr) ||
                _savedWordIds.contains(wordId);

            return InkWell(
              onTap: () => _onResultSelected(item),
              borderRadius: BorderRadius.circular(6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (article.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: genderColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              article,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: genderColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            word,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _setStatus(item, isSaved ? VocabCategory.learning : VocabCategory.learning),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(
                              isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                              size: 18,
                              color: isSaved ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      def,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _getCefrLevel(int? freqRank) => DictionaryService.getCefrLevel(freqRank);

  /// Renders nothing until (and unless) a real image is found — no
  /// placeholder box for words without one, since most entries (verbs,
  /// adjectives, function words) intentionally never get an image.
  Widget _buildWordImage(BuildContext context) {
    if (_wordImageFuture == null) return const SizedBox.shrink();

    return FutureBuilder<String?>(
      future: _wordImageFuture,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done ||
            url == null ||
            url.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: url,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const SizedBox.shrink(),
              placeholder: (context, url) => Container(
                height: 160,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
            ),
          ),
        );
      },
    );
  }

  String _inferGenderIfNull(String wordStr, String? rawGender, String? pos) {
    if (rawGender != null && rawGender.trim().isNotEmpty) {
      final g = rawGender.trim().toLowerCase();
      if (g == 'masculine' || g == 'm') return 'm';
      if (g == 'feminine' || g == 'f') return 'f';
      if (g == 'neuter' || g == 'n') return 'n';
    }

    final lower = wordStr.trim().toLowerCase();
    
    if (lower.endsWith('schaft') ||
        lower.endsWith('ung') ||
        lower.endsWith('heit') ||
        lower.endsWith('keit') ||
        lower.endsWith('tät') ||
        lower.endsWith('tion') ||
        lower.endsWith('ei') ||
        lower.endsWith('in')) {
      return 'f';
    }
    if (lower.endsWith('chen') ||
        lower.endsWith('lein') ||
        lower.endsWith('tum') ||
        lower.endsWith('ment')) {
      return 'n';
    }
    if (lower.endsWith('ismus') || lower.endsWith('ling') || lower.endsWith('or')) {
      return 'm';
    }

    return '';
  }

  Widget _buildMainCard(BuildContext context, Map<String, dynamic> wordData) {
    final colorScheme = Theme.of(context).colorScheme;
    final word = wordData['word']?.toString() ?? '';
    final pos = wordData['pos']?.toString();
    final rawGender = wordData['gender']?.toString();
    final gender = _inferGenderIfNull(word, rawGender, pos);
    final ipa = wordData['ipa']?.toString();
    final freq = wordData['freq_rank'];
    final defs = (wordData['definitions'] as List?) ?? [];

    Color genderColor = colorScheme.primary;
    String article = "";

    if (gender == 'masculine' || gender == 'm') {
      genderColor = AppTheme.genderMasc;
      article = "Der";
    } else if (gender == 'feminine' || gender == 'f') {
      genderColor = AppTheme.genderFem;
      article = "Die";
    } else if (gender == 'neuter' || gender == 'n') {
      genderColor = AppTheme.genderNeu;
      article = "Das";
    }

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -24,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: genderColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (freq != null)
                  Align(
                    alignment: Alignment.topRight,
                    child: Builder(
                      builder: (context) {
                        final cefr = _getCefrLevel(freq);
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        final cefrColors = AppTheme.getCefrColors(cefr, isDark: isDark);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cefrColors.background,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: cefrColors.border, width: 0.8),
                          ),
                          child: Text(
                            cefr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: cefrColors.foreground,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 16),

                _buildWordImage(context),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (article.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: genderColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: genderColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          article.toUpperCase(),
                          style: TextStyle(
                            color: genderColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          word,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.volume_up_rounded,
                        size: 22,
                        color: genderColor != colorScheme.primary ? genderColor : colorScheme.primary,
                      ),
                      onPressed: () => _ttsService.speak(word, lang: 'de-DE'),
                    ),
                  ],
                ),

                if (ipa != null && ipa.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    ipa,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Clean Arrow Definitions List (Consistent with GlanceWordSheet)
                if (defs.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: defs.map((d) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "→ ",
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                d.toString(),
                                textAlign: TextAlign.left,
                                style: BooksModernist.body(
                                  size: 14.5,
                                  weight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 20),

                // 1-line Vocabulary Status Pills (Consistent with GlanceWordSheet)
                VocabStatusPills(
                  currentCategory: _savedWordCategories[word.toLowerCase().trim()] ??
                      (_savedWordIds.contains(word.toLowerCase().trim()) ? VocabCategory.reviewLater : null),
                  onCategorySelected: (category) => _setStatus(wordData, category),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isVerbWord = _selectedWord != null && _isVerb(_selectedWord!);
    final tabs = [
      isVerbWord ? 'Verb Conjugation' : 'Forms & Declension',
      'Examples',
    ];

    if (_selectedTabIndex >= tabs.length) {
      _selectedTabIndex = 0;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final title = entry.value;
          final isActive = _selectedTabIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive
                      ? Theme.of(context).cardColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4.0),
                  border: isActive
                      ? Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.8)
                      : null,
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, Map<String, dynamic> wordData) {
    if (_selectedTabIndex == 1) {
      return _buildExamplesTab(context, wordData);
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

  String _findVerbForm(
    List<dynamic> forms,
    bool Function(String tags) condition, {
    String fallback = '-',
  }) {
    for (final f in forms) {
      if (f is! Map) continue;
      final form = (f['form'] ?? '').toString().trim();
      final tags = (f['tags'] ?? '').toString().toLowerCase();
      if (form.isNotEmpty && condition(tags)) {
        return form;
      }
    }
    return fallback;
  }

  Widget _buildMiniVerbStat(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
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
        return '${stem}st';
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
    switch (index) {
      case 0:
        return '${stem}te';
      case 1:
        return '${stem}test';
      case 2:
        return '${stem}te';
      case 3:
        return '${stem}ten';
      case 4:
        return '${stem}tet';
      case 5:
      default:
        return '${stem}ten';
    }
  }

  Widget _buildVerbConjugationTable(
    BuildContext context,
    Map<String, dynamic> wordData,
  ) {
    final forms = (wordData['forms'] as List?) ?? [];
    final colorScheme = Theme.of(context).colorScheme;
    final infinitive = wordData['word']?.toString() ?? '';

    // Determine auxiliary verb
    String aux = 'haben';
    for (final f in forms) {
      if (f is! Map) continue;
      final form = (f['form'] ?? '').toString().trim().toLowerCase();
      final tags = (f['tags'] ?? '').toString().toLowerCase();
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
        (t.contains('past') && !t.contains('participle'));

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

    final auxConjugations =
        aux == 'sein'
            ? ['bin', 'bist', 'ist', 'sind', 'seid', 'sind']
            : ['habe', 'hast', 'hat', 'haben', 'habt', 'haben'];

    final perfectForms = auxConjugations.map((a) {
      return '$a $part2';
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.table_chart_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Verb Conjugation Table',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
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
                0: FlexColumnWidth(0.95),
                1: FlexColumnWidth(1.05),
                2: FlexColumnWidth(1.05),
                3: FlexColumnWidth(1.45),
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

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    bool isSemiBold = false,
    bool isMuted = false,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
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

  Widget _buildDeclensionTab(
    BuildContext context,
    Map<String, dynamic> wordData,
  ) {
    if (_isVerb(wordData)) {
      return _buildVerbConjugationTable(context, wordData);
    }
    final forms = (wordData['forms'] as List?) ?? [];
    final colorScheme = Theme.of(context).colorScheme;

    if (forms.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Text(
          'No declension forms available.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
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
        children: [
          Row(
            children: [
              Icon(
                Icons.table_chart_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Inflected & Declension Forms (${forms.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: forms.map<Widget>((f) {
              final formStr = f['form'] ?? '';
              final tagStr = f['tags'] ?? '';
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (tagStr.isNotEmpty)
                      Text(
                        tagStr
                            .toString()
                            .replaceAll('[', '')
                            .replaceAll(']', '')
                            .replaceAll('"', ''),
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExamplesTab(
    BuildContext context,
    Map<String, dynamic> wordData,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    // Real example sentences sourced from Wiktionary/Kaikki at DB-build
    // time (see dictionary_service.dart's getWordDetails). We deliberately
    // do not fabricate sentences when none exist — a made-up example is
    // worse than none, since it can teach the wrong grammar.
    final rawExamples = wordData['examples'];
    final examples = <Map<String, String?>>[];
    if (rawExamples is List) {
      for (final e in rawExamples) {
        if (e is Map) {
          final de = e['de']?.toString();
          if (de != null && de.isNotEmpty) {
            examples.add({'de': de, 'en': e['en']?.toString()});
          }
        }
      }
    }

    if (examples.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(
              Icons.menu_book_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              'No example sentences available for this word yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
          final de = ex['de']!;
          final en = ex['en'];
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

}

class _SavedVocabularySheet extends StatefulWidget {
  final List<SavedWord> initialWords;
  final Function(SavedWord) onWordSelected;
  final Function(String) onWordDeleted;
  final Function(SavedWord, VocabCategory) onCategoryChanged;

  const _SavedVocabularySheet({
    required this.initialWords,
    required this.onWordSelected,
    required this.onWordDeleted,
    required this.onCategoryChanged,
  });

  @override
  State<_SavedVocabularySheet> createState() => _SavedVocabularySheetState();
}

class _SavedVocabularySheetState extends State<_SavedVocabularySheet> {
  final TextEditingController _searchController = TextEditingController();
  final TtsService _ttsService = TtsService();
  late List<SavedWord> _words;
  String _selectedCategory = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _words = List.from(widget.initialWords);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SavedWord> get _filteredWords {
    return _words.where((w) {
      final matchesCategory = _selectedCategory == 'all' ||
          (_selectedCategory == 'learning' && w.category == VocabCategory.learning) ||
          (_selectedCategory == 'mastered' && w.category == VocabCategory.mastered);

      if (!matchesCategory) return false;

      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final wordMatch = w.word.toLowerCase().contains(q);
      final defMatch = w.primaryDefinition.toLowerCase().contains(q);
      return wordMatch || defMatch;
    }).toList();
  }

  int get _learningCount => _words.where((w) => w.category == VocabCategory.learning).length;
  int get _masteredCount => _words.where((w) => w.category == VocabCategory.mastered).length;

  void _startPracticeSession() {
    final filtered = _filteredWords;
    if (filtered.isEmpty) return;

    int practiceIndex = 0;
    bool showAnswer = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final colorScheme = Theme.of(context).colorScheme;
          final item = filtered[practiceIndex];

          Color genderColor = colorScheme.primary;
          if (item.gender == 'm' || item.gender == 'masculine') genderColor = AppTheme.genderMasc;
          if (item.gender == 'f' || item.gender == 'feminine') genderColor = AppTheme.genderFem;
          if (item.gender == 'n' || item.gender == 'neuter') genderColor = AppTheme.genderNeu;

          String article = '';
          final g = item.gender?.toLowerCase();
          if (g == 'm' || g == 'masc' || g == 'masculine') article = 'der';
          if (g == 'f' || g == 'fem' || g == 'feminine') article = 'die';
          if (g == 'n' || g == 'neu' || g == 'neuter') article = 'das';

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
                          'Practice Saved Deck',
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
                    value: (practiceIndex + 1) / filtered.length,
                    minHeight: 6,
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Word ${practiceIndex + 1} of ${filtered.length}',
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
                        if (article.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: genderColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              article,
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
                          if (item.contextSentence != null && item.contextSentence!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              '"${item.contextSentence}"',
                              textAlign: TextAlign.center,
                              style: BooksModernist.body(size: 12, color: colorScheme.onSurfaceVariant, context: context),
                            ),
                          ],
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
                          practiceIndex = (practiceIndex - 1 + filtered.length) % filtered.length;
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
                    FilledButton.icon(
                      onPressed: () {
                        setSheetState(() {
                          showAnswer = false;
                          if (practiceIndex < filtered.length - 1) {
                            practiceIndex++;
                          } else {
                            Navigator.pop(context);
                          }
                        });
                      },
                      icon: Icon(practiceIndex < filtered.length - 1 ? Icons.arrow_forward_rounded : Icons.check_circle_rounded, size: 16),
                      label: Text(practiceIndex < filtered.length - 1 ? 'Next' : 'Finish', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayList = _filteredWords;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6.0)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Saved Vocabulary (${_words.length})',
                        style: BooksModernist.heading(size: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage, search and practice your saved German deck',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (_words.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: _startPracticeSession,
                    icon: const Icon(Icons.psychology_rounded, size: 16),
                    label: const Text('Üben', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                      side: BorderSide(color: colorScheme.primary),
                      foregroundColor: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search saved terms or definitions...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6.0),
                  borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6.0),
                  borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${_words.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('learning', 'Learning ($_learningCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('mastered', 'Mastered ($_masteredCount)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          Expanded(
            child: displayList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_outline_rounded, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No saved words match "$_searchQuery"'
                              : 'No words saved in this category yet.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final item = displayList[index];

                      Color genderColor = colorScheme.primary;
                      if (item.gender == 'm' || item.gender == 'masculine') genderColor = AppTheme.genderMasc;
                      if (item.gender == 'f' || item.gender == 'feminine') genderColor = AppTheme.genderFem;
                      if (item.gender == 'n' || item.gender == 'neuter') genderColor = AppTheme.genderNeu;

                      String article = '';
                      final g = item.gender?.toLowerCase();
                      if (g == 'm' || g == 'masc' || g == 'masculine') article = 'der';
                      if (g == 'f' || g == 'fem' || g == 'feminine') article = 'die';
                      if (g == 'n' || g == 'neu' || g == 'neuter') article = 'das';

                      final isMastered = item.category == VocabCategory.mastered;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10.0),
                        padding: const EdgeInsets.all(12.0),
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
                                if (article.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: genderColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: Text(
                                      article,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: genderColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => widget.onWordSelected(item),
                                    child: Text(
                                      item.word,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isMastered
                                        ? Colors.amber.withValues(alpha: 0.15)
                                        : Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4.0),
                                  ),
                                  child: Text(
                                    isMastered ? 'MASTERED' : 'LEARNING',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isMastered ? Colors.amber.shade800 : Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.primaryDefinition,
                              style: TextStyle(fontSize: 13, color: colorScheme.primary, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  'SRS: ${item.interval}d • Ease: ${item.easeFactor.toStringAsFixed(1)}x',
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                ),
                                const Spacer(),
                                InkWell(
                                  onTap: () => _ttsService.speak(item.word, lang: 'de-DE'),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Icon(Icons.volume_up_rounded, size: 16, color: colorScheme.primary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    final newCategory = isMastered ? VocabCategory.learning : VocabCategory.mastered;
                                    widget.onCategoryChanged(item, newCategory);
                                    setState(() {
                                      final idx = _words.indexWhere((w) => w.id == item.id);
                                      if (idx != -1) {
                                        _words[idx] = SavedWord(
                                          id: item.id,
                                          word: item.word,
                                          gender: item.gender,
                                          ipa: item.ipa,
                                          primaryDefinition: item.primaryDefinition,
                                          category: newCategory,
                                          interval: item.interval,
                                          easeFactor: item.easeFactor,
                                          repetitions: item.repetitions,
                                          dueDate: item.dueDate,
                                          createdAt: item.createdAt,
                                        );
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Icon(
                                      isMastered ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                                      size: 16,
                                      color: isMastered ? colorScheme.onSurfaceVariant : Colors.green,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    widget.onWordDeleted(item.id);
                                    setState(() {
                                      _words.removeWhere((w) => w.id == item.id);
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Icon(Icons.delete_outline_rounded, size: 16, color: colorScheme.error),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String categoryId, String label) {
    final isSelected = _selectedCategory == categoryId;
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      ),
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
      onSelected: (_) => setState(() => _selectedCategory = categoryId),
    );
  }
}
